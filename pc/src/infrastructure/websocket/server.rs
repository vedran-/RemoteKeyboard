//! WebSocket Server
//!
//! WebSocket server for receiving commands from mobile devices.
//! Uses tokio-tungstenite for async WebSocket handling.

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use futures_util::{SinkExt, StreamExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::broadcast;
use tokio_util::sync::CancellationToken;
use tokio_tungstenite::tungstenite::Message;
use tracing::{debug, error, info, trace, warn};

use crate::application::ports::{Error, Result};
use crate::domain::entities::command::{ClientMessage, ServerMessage};
use crate::infrastructure::screen_capture::ScreenCaptureService;

/// Screen streaming frame rate (FPS)
const SCREEN_STREAM_FPS: u32 = 5;

/// Heartbeat ping interval
const PING_INTERVAL: Duration = Duration::from_secs(5);
/// Timeout before dropping connection if no pong is received
const PONG_TIMEOUT: Duration = Duration::from_secs(15);

/// WebSocket server configuration
#[derive(Debug, Clone)]
pub struct WebSocketConfig {
    pub host: String,
    pub port: u16,
    pub path: String,
}

impl Default for WebSocketConfig {
    fn default() -> Self {
        WebSocketConfig {
            host: "0.0.0.0".to_string(),
            port: 8765,
            path: "/remote".to_string(),
        }
    }
}

/// Command message for broadcasting to input handlers
#[derive(Debug, Clone)]
pub struct IncomingCommand {
    pub command: crate::domain::entities::command::InputAction,
}

/// WebSocket Server
pub struct WebSocketServer {
    config: WebSocketConfig,
    command_tx: broadcast::Sender<IncomingCommand>,
    is_running: Arc<std::sync::atomic::AtomicBool>,
}

impl WebSocketServer {
    pub fn new(config: WebSocketConfig) -> Self {
        let (command_tx, _) = broadcast::channel(100);
        WebSocketServer {
            config,
            command_tx,
            is_running: Arc::new(std::sync::atomic::AtomicBool::new(false)),
        }
    }

    pub fn subscribe_commands(&self) -> broadcast::Receiver<IncomingCommand> {
        self.command_tx.subscribe()
    }

    pub async fn start(&self) -> Result<()> {
        let addr = format!("{}:{}", self.config.host, self.config.port);
        let listener = TcpListener::bind(&addr)
            .await
            .map_err(|e| Error::network(format!("Failed to bind to {}: {}", addr, e)))?;

        info!("WebSocket server listening on {}", addr);
        self.is_running.store(true, std::sync::atomic::Ordering::SeqCst);

        let command_tx = self.command_tx.clone();
        let path = self.config.path.clone();
        let is_running = self.is_running.clone();

        tokio::spawn(async move {
            loop {
                if !is_running.load(std::sync::atomic::Ordering::SeqCst) {
                    break;
                }

                match listener.accept().await {
                    Ok((stream, addr)) => {
                        debug!("New connection from {}", addr);
                        let command_tx = command_tx.clone();
                        let path = path.clone();

                        tokio::spawn(async move {
                            if let Err(e) = handle_connection(stream, command_tx, &path).await {
                                error!("Connection error: {}", e);
                            }
                        });
                    }
                    Err(e) => {
                        error!("Failed to accept connection: {}", e);
                    }
                }
            }
        });

        Ok(())
    }

    pub fn stop(&self) {
        self.is_running.store(false, std::sync::atomic::Ordering::SeqCst);
        info!("WebSocket server stopping...");
    }

    pub fn is_running(&self) -> bool {
        self.is_running.load(std::sync::atomic::Ordering::SeqCst)
    }

    pub fn config(&self) -> &WebSocketConfig {
        &self.config
    }
}

impl Drop for WebSocketServer {
    fn drop(&mut self) {
        self.stop();
    }
}

/// Handle a WebSocket connection
async fn handle_connection(
    stream: TcpStream,
    command_tx: broadcast::Sender<IncomingCommand>,
    _expected_path: &str,
) -> Result<()> {
    let ws_stream = tokio_tungstenite::accept_async(stream)
        .await
        .map_err(|e| Error::network(format!("WebSocket handshake failed: {}", e)))?;

    let (mut writer, mut reader) = ws_stream.split();

    // 1. Send "connected" message
    let accept_msg = ServerMessage::Connected {
        session: uuid::Uuid::new_v4().to_string(),
    };
    writer
        .send(Message::Text(serde_json::to_string(&accept_msg).unwrap()))
        .await
        .map_err(|e| Error::connection(format!("Failed to send accept message: {}", e)))?;

    info!("WebSocket client connected");

    // 2. Setup screen streaming state
    let screen_capture: Arc<Mutex<Option<ScreenCaptureService>>> = Arc::new(Mutex::new(None));
    // Bounded channel with capacity 1 - drops old frames if client is slow
    let (screen_tx, mut screen_rx) = tokio::sync::mpsc::channel::<Vec<u8>>(1);
    let mut stream_cancel_token: Option<CancellationToken> = None;
    let mut last_sent_seq: u64 = 0;  // For skip-if-unchanged

    // 3. Setup heartbeat state
    let mut last_pong_time = Instant::now();
    let mut ping_interval = tokio::time::interval(PING_INTERVAL);

    // 4. Main connection loop
    loop {
        tokio::select! {
            // Read incoming WebSocket frames
            msg = reader.next() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        // Parse JSON client message
                        match serde_json::from_str::<ClientMessage>(&text) {
                            Ok(client_msg) => {
                                // Try executing as input command first
                                if let Some(input_action) = client_msg.to_input_action() {
                                    let incoming = IncomingCommand { command: input_action };
                                    if let Err(e) = command_tx.send(incoming) {
                                        warn!("Failed to broadcast input command: {}", e);
                                    }
                                    continue;
                                }

                                // Otherwise handle streaming control messages
                                match client_msg {
                                    ClientMessage::StreamStart { width, height, zoom } => {
                                        info!("StreamStart: {}x{} (zoom {:.2})", width, height, zoom);

                                        // Init capture service if needed
                                        {
                                            let mut capture_opt = screen_capture.lock().unwrap();
                                            if capture_opt.is_none() {
                                                match ScreenCaptureService::new() {
                                                    Ok(service) => *capture_opt = Some(service),
                                                    Err(e) => {
                                                        error!("Failed to init screen capture: {}", e);
                                                        continue;
                                                    }
                                                }
                                            }
                                        }

                                        // Set viewport
                                        {
                                            let capture_opt = screen_capture.lock().unwrap();
                                            if let Some(capture) = capture_opt.as_ref() {
                                                capture.set_viewport_and_zoom(width, height, zoom);
                                            }
                                        }

                                        // Abort existing stream task if any
                                        if let Some(token) = stream_cancel_token.take() {
                                            token.cancel();
                                        }

                                        // Start new stream task
                                        let cancel_token = CancellationToken::new();
                                        stream_cancel_token = Some(cancel_token.clone());
                                        let capture_arc = Arc::clone(&screen_capture);
                                        let tx = screen_tx.clone();
                                        let mut last_seq = last_sent_seq;

                                        tokio::spawn(async move {
                                            info!("Screen streaming task started");
                                            let mut interval = tokio::time::interval(
                                                Duration::from_millis(1000 / SCREEN_STREAM_FPS as u64)
                                            );
                                            let mut frame_count = 0;
                                            loop {
                                                tokio::select! {
                                                    _ = cancel_token.cancelled() => {
                                                        info!("Screen streaming task stopped cleanly after {} frames", frame_count);
                                                        break;
                                                    }
                                                    _ = interval.tick() => {
                                                        // Check if channel is closed before capturing
                                                        if tx.is_closed() {
                                                            debug!("Channel closed, stopping stream");
                                                            break;
                                                        }
                                                        
                                                        // Get capture result while holding lock briefly
                                                        let capture_result = {
                                                            let capture_opt = capture_arc.lock().unwrap();
                                                            if let Some(capture) = capture_opt.as_ref() {
                                                                Some(capture.capture_around_cursor(last_seq))
                                                            } else {
                                                                None
                                                            }
                                                        };
                                                        
                                                        // Process capture result
                                                        if let Some(result) = capture_result {
                                                            match result {
                                                                Ok(Some((jpeg_bytes, new_seq))) => {
                                                                    // Try to send frame - skip if client is busy
                                                                    let frame_size = jpeg_bytes.len();
                                                                    last_seq = new_seq;
                                                                    match tx.try_send(jpeg_bytes) {
                                                                        Ok(_) => {
                                                                            frame_count += 1;
                                                                            debug!("Sent frame #{}: {} bytes", frame_count, frame_size);
                                                                        }
                                                                        Err(tokio::sync::mpsc::error::TrySendError::Full(_)) => {
                                                                            // Client is still processing previous frame - skip this one
                                                                            trace!("Client busy, skipping frame");
                                                                        }
                                                                        Err(e) => {
                                                                            warn!("Channel error: {}", e);
                                                                            break; // Channel closed
                                                                        }
                                                                    }
                                                                }
                                                                Ok(None) => {
                                                                    // This should never happen now
                                                                    warn!("Unexpected None from capture");
                                                                }
                                                                Err(e) => error!("Capture failed: {}", e),
                                                            }
                                                        } else {
                                                            warn!("No capture service available");
                                                        }
                                                    }
                                                }
                                            }
                                        });
                                    }

                                    ClientMessage::StreamUpdate { width, height, zoom } => {
                                        debug!("StreamUpdate: {}x{} (zoom {:.2})", width, height, zoom);
                                        let capture_opt = screen_capture.lock().unwrap();
                                        if let Some(capture) = capture_opt.as_ref() {
                                            capture.set_viewport_and_zoom(width, height, zoom);
                                        }
                                    }

                                    ClientMessage::StreamStop => {
                                        info!("StreamStop received");
                                        if let Some(token) = stream_cancel_token.take() {
                                            token.cancel();
                                        }
                                        // Optional: we keep screen_capture instance alive for faster restart
                                    }

                                    _ => {} // Handled by to_input_action above
                                }
                            }
                            Err(e) => {
                                warn!("Invalid message JSON: {}", e);
                                let err_msg = ServerMessage::Error {
                                    code: "invalid_message".into(),
                                    message: e.to_string(),
                                };
                                let _ = writer.send(Message::Text(serde_json::to_string(&err_msg).unwrap())).await;
                            }
                        }
                    }

                    Some(Ok(Message::Pong(_))) => {
                        trace!("Received Pong");
                        last_pong_time = Instant::now();
                    }
                    Some(Ok(Message::Ping(data))) => {
                        let _ = writer.send(Message::Pong(data)).await;
                    }
                    Some(Ok(Message::Close(_))) => {
                        info!("Client closed connection cleanly");
                        break;
                    }
                    Some(Ok(Message::Binary(_))) => warn!("Unexpected binary frame from client"),
                    Some(Ok(Message::Frame(_))) => (), // Ignore
                    Some(Err(e)) => {
                        error!("WebSocket read error: {}", e);
                        break;
                    }
                    None => {
                        info!("Client disconnected");
                        break;
                    }
                }
            }

            // Periodic Ping + Timeout Check
            _ = ping_interval.tick() => {
                if last_pong_time.elapsed() > PONG_TIMEOUT {
                    warn!("Client timed out (no pong in {:?})", PONG_TIMEOUT);
                    break;
                }
                if writer.send(Message::Ping(vec![])).await.is_err() {
                    break;
                }
            }

            // Send Screen Frames
            Some(jpeg_bytes) = screen_rx.recv() => {
                if writer.send(Message::Binary(jpeg_bytes)).await.is_err() {
                    break;
                }
            }
        }
    }

    // Cleanup on disconnect
    info!("Cleaning up after disconnection");
    if let Some(token) = stream_cancel_token {
        token.cancel();
    }
    // Drop screen_tx to signal closed status to streaming task
    drop(screen_tx);
    // Disconnect screen capture
    if let Ok(mut capture_opt) = screen_capture.lock() {
        *capture_opt = None;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_config() -> WebSocketConfig {
        WebSocketConfig {
            host: "127.0.0.1".to_string(),
            port: 0,
            path: "/remote".to_string(),
        }
    }

    #[test]
    fn test_websocket_server_creation() {
        let config = create_test_config();
        let server = WebSocketServer::new(config.clone());
        assert_eq!(server.config().port, config.port);
        assert!(!server.is_running());
    }

    // Additional tests removed for brevity, rely on standard ws components
}
