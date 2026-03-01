//! WebSocket Server
//!
//! WebSocket server for receiving commands from mobile devices.
//! Uses tokio-tungstenite for async WebSocket handling.

use std::sync::Arc;

use futures_util::{SinkExt, StreamExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::broadcast;
use tokio_tungstenite::tungstenite::Message;
use tracing::{debug, error, info, warn};

use crate::application::ports::{Result, Error};
use crate::domain::entities::command::{Command, ProtocolMessage, MessageType, ScreenControl};
use crate::infrastructure::screen_capture::ScreenCaptureService;

/// Screen streaming frame rate (FPS)
const SCREEN_STREAM_FPS: u32 = 5;

/// WebSocket server configuration
#[derive(Debug, Clone)]
pub struct WebSocketConfig {
    /// Host address to bind to
    pub host: String,
    /// Port to listen on
    pub port: u16,
    /// WebSocket path
    pub path: String,
    /// Heartbeat interval in seconds
    pub heartbeat_interval_secs: u64,
    /// Connection timeout in seconds
    pub connection_timeout_secs: u64,
}

impl Default for WebSocketConfig {
    fn default() -> Self {
        WebSocketConfig {
            host: "0.0.0.0".to_string(),
            port: 8765,
            path: "/remote".to_string(),
            heartbeat_interval_secs: 5,
            connection_timeout_secs: 30,
        }
    }
}

/// Command message for broadcasting to handlers
#[derive(Debug, Clone)]
pub struct IncomingCommand {
    pub command: Command,
    pub timestamp: i64,
}

/// WebSocket Server
pub struct WebSocketServer {
    config: WebSocketConfig,
    command_tx: broadcast::Sender<IncomingCommand>,
    is_running: Arc<std::sync::atomic::AtomicBool>,
}

impl WebSocketServer {
    /// Create a new WebSocket server
    pub fn new(config: WebSocketConfig) -> Self {
        let (command_tx, _) = broadcast::channel(100);
        
        WebSocketServer {
            config,
            command_tx,
            is_running: Arc::new(std::sync::atomic::AtomicBool::new(false)),
        }
    }
    
    /// Get the command receiver stream
    pub fn subscribe_commands(&self) -> broadcast::Receiver<IncomingCommand> {
        self.command_tx.subscribe()
    }
    
    /// Start the WebSocket server
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
    
    /// Stop the WebSocket server
    pub fn stop(&self) {
        self.is_running.store(false, std::sync::atomic::Ordering::SeqCst);
        info!("WebSocket server stopping...");
    }
    
    /// Check if server is running
    pub fn is_running(&self) -> bool {
        self.is_running.load(std::sync::atomic::Ordering::SeqCst)
    }
    
    /// Get server configuration
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

    // Send connection accepted message
    let accept_msg = ProtocolMessage::new(
        MessageType::ConnectionAccepted,
        serde_json::json!({ "session_id": uuid::Uuid::new_v4().to_string() }),
        ProtocolMessage::now_timestamp(),
    );

    writer
        .send(Message::Text(serde_json::to_string(&accept_msg).unwrap()))
        .await
        .map_err(|e| Error::connection(format!("Failed to send accept message: {}", e)))?;

    info!("WebSocket client connected");

    // Screen capture service (lazy init - only created when streaming enabled)
    let mut screen_capture: Option<ScreenCaptureService> = None;
    let mut screen_streaming_enabled = false;
    
    // Channel for screen frames
    let (screen_tx, mut screen_rx) = tokio::sync::mpsc::channel::<String>(5);
    let mut screen_stream_handle: Option<tokio::task::JoinHandle<()>> = None;

    // Create channel for heartbeat messages
    let (heartbeat_tx, mut heartbeat_rx) = tokio::sync::mpsc::channel::<String>(10);

    // Spawn heartbeat task (send heartbeat every 5 seconds)
    let heartbeat_writer_tx = heartbeat_tx.clone();
    let heartbeat_handle = tokio::spawn(async move {
        let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(5));
        loop {
            interval.tick().await;
            let heartbeat = ProtocolMessage::new(
                MessageType::Heartbeat,
                serde_json::json!({ "timestamp": chrono::Utc::now().timestamp_millis() }),
                chrono::Utc::now().timestamp_millis(),
            );
            if let Ok(json) = serde_json::to_string(&heartbeat) {
                if heartbeat_writer_tx.send(json).await.is_err() {
                    break;
                }
            }
        }
    });

    // Read messages from client, send heartbeats, and send screen frames
    loop {
        tokio::select! {
            // Read from client
            msg = reader.next() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        // Check message type by parsing JSON
                        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                            // Check if this is a screen control message (type: custom with screen control payload)
                            if json.get("type").and_then(|v| v.as_str()) == Some("custom") {
                                if let Some(payload) = json.get("payload") {
                                    if let Ok(control) = serde_json::from_value::<ScreenControl>(payload.clone()) {
                                        // Handle screen control message
                                        if control.enabled && !screen_streaming_enabled {
                                            // Start streaming
                                            info!("Screen streaming enabled");
                                            screen_streaming_enabled = true;

                                            // Always re-initialize screen capture for fresh start
                                            match ScreenCaptureService::new() {
                                                Ok(service) => {
                                                    screen_capture = Some(service);

                                                    // Set capture dimensions if specified
                                                    if let (Some(width), Some(height)) = (control.capture_width, control.capture_height) {
                                                        if let Some(ref capture) = screen_capture {
                                                            capture.set_capture_dimensions(width, height);
                                                            info!("Capture dimensions set to {}x{}", width, height);
                                                        }
                                                    }

                                                    // Set max dimension for downscaling if specified
                                                    if let Some(max_dim) = control.max_dimension {
                                                        if let Some(ref capture) = screen_capture {
                                                            capture.set_max_dimension(max_dim);
                                                            info!("Max dimension set to {}", max_dim);
                                                        }
                                                    }

                                                    // Start screen streaming task
                                                    let capture: Option<ScreenCaptureService> = screen_capture.clone();
                                                    let tx = screen_tx.clone();
                                                    screen_stream_handle = Some(tokio::spawn(async move {
                                                        info!("Screen streaming task started, FPS: {}", SCREEN_STREAM_FPS);
                                                        let mut interval = tokio::time::interval(
                                                            tokio::time::Duration::from_millis(1000 / SCREEN_STREAM_FPS as u64)
                                                        );
                                                        let mut frame_count = 0u32;
                                                        loop {
                                                            interval.tick().await;
                                                            frame_count += 1;
                                                            if let Some(ref capture) = capture {
                                                                debug!("Screen streaming: capturing frame #{}", frame_count);
                                                                match capture.capture_around_cursor() {
                                                                    Ok(frame) => {
                                                                        debug!("Screen streaming: captured frame #{}: {}x{}", frame_count, frame.capture_width, frame.capture_height);
                                                                        // Send screen frame directly (not wrapped in ProtocolMessage)
                                                                        let screen_msg = serde_json::json!({
                                                                            "type": "screen_frame",
                                                                            "cursor_x": frame.cursor_x,
                                                                            "cursor_y": frame.cursor_y,
                                                                            "monitor_id": frame.monitor_id,
                                                                            "capture_width": frame.capture_width,
                                                                            "capture_height": frame.capture_height,
                                                                            "data": frame.data,
                                                                        });
                                                                        match serde_json::to_string(&screen_msg) {
                                                                            Ok(json) => {
                                                                                if tx.send(json).await.is_err() {
                                                                                    error!("Screen streaming: failed to send frame #{} - channel closed", frame_count);
                                                                                    break;
                                                                                }
                                                                                debug!("Screen streaming: sent frame #{}", frame_count);
                                                                            }
                                                                            Err(e) => error!("Screen streaming: failed to serialize frame #{}: {}", frame_count, e),
                                                                        }
                                                                    }
                                                                    Err(e) => error!("Screen streaming: failed to capture frame #{}: {}", frame_count, e),
                                                                }
                                                            } else {
                                                                error!("Screen streaming: capture service is None!");
                                                            }
                                                        }
                                                    }));
                                                }
                                                Err(e) => {
                                                    error!("Failed to initialize screen capture: {}", e);
                                                    screen_streaming_enabled = false;
                                                }
                                            }
                                        } else if !control.enabled && screen_streaming_enabled {
                                            // Stop streaming
                                            info!("Screen streaming disabled");
                                            screen_streaming_enabled = false;
                                            if let Some(handle) = screen_stream_handle.take() {
                                                handle.abort();
                                            }
                                        }

                                        // Adjust capture dimensions if specified
                                        if let (Some(width), Some(height)) = (control.capture_width, control.capture_height) {
                                            if let Some(ref capture) = screen_capture {
                                                capture.set_capture_dimensions(width, height);
                                                info!("Capture dimensions adjusted to {}x{}", width, height);
                                            }
                                        }

                                        // Adjust max dimension if specified
                                        if let Some(max_dim) = control.max_dimension {
                                            if let Some(ref capture) = screen_capture {
                                                capture.set_max_dimension(max_dim);
                                                info!("Max dimension adjusted to {}", max_dim);
                                            }
                                        }
                                        continue;  // Skip ProtocolMessage parsing for screen control
                                    }
                                }
                            }
                            
                            // For messages with payload field, parse as ProtocolMessage (mouse/keyboard/media commands)
                            if json.get("payload").is_some() {
                                if let Err(e) = handle_message(&text, &command_tx) {
                                    warn!("Failed to handle message: {}", e);

                                    // Send error response
                                    let error_msg = ProtocolMessage::new(
                                        MessageType::Error,
                                        serde_json::json!({
                                            "code": "invalid_message",
                                            "message": e.to_string()
                                        }),
                                        ProtocolMessage::now_timestamp(),
                                    );

                                    let _ = writer.send(Message::Text(serde_json::to_string(&error_msg).unwrap())).await;
                                }
                            } else {
                                // This is a control message (heartbeat_ack, etc.) - just log it
                                debug!("Received control message: {}", text);
                            }
                        }
                    }
                    Some(Ok(Message::Ping(data))) => {
                        // Respond with pong
                        let _ = writer.send(Message::Pong(data)).await;
                    }
                    Some(Ok(Message::Pong(_))) => {
                        // Heartbeat acknowledgment
                        debug!("Received heartbeat pong");
                    }
                    Some(Ok(Message::Close(_))) => {
                        info!("WebSocket client disconnected");
                        break;
                    }
                    Some(Ok(Message::Binary(_))) => {
                        warn!("Received binary message, expected text");
                    }
                    Some(Ok(Message::Frame(_))) => {
                        // Ignore raw frames
                    }
                    Some(Err(e)) => {
                        error!("WebSocket error: {}", e);
                        break;
                    }
                    None => break,
                }
            }
            // Send heartbeat
            Some(heartbeat_json) = heartbeat_rx.recv() => {
                if writer.send(Message::Text(heartbeat_json)).await.is_err() {
                    break;
                }
            }
            // Send screen frame
            Some(screen_json) = screen_rx.recv() => {
                if screen_streaming_enabled {
                    if writer.send(Message::Text(screen_json)).await.is_err() {
                        break;
                    }
                }
            }
        }
    }

    // Cancel heartbeat and screen streaming tasks
    heartbeat_handle.abort();
    if let Some(handle) = screen_stream_handle {
        handle.abort();
    }

    Ok(())
}

/// Handle an incoming message
fn handle_message(text: &str, command_tx: &broadcast::Sender<IncomingCommand>) -> Result<()> {
    // Debug: Log raw message
    debug!("Received raw message: {}", text);
    
    // Parse the message
    let msg: ProtocolMessage = serde_json::from_str(text)
        .map_err(|e| {
            debug!("Failed to parse as ProtocolMessage: {}", e);
            Error::protocol(format!("Invalid JSON: {}", e))
        })?;
    
    // Convert to command based on message type
    let command = match msg.message_type {
        MessageType::Mouse => {
            let cmd: Command = serde_json::from_value(
                serde_json::json!({ "type": "mouse", "payload": msg.payload })
            )?;
            cmd
        }
        MessageType::Keyboard => {
            let cmd: Command = serde_json::from_value(
                serde_json::json!({ "type": "keyboard", "payload": msg.payload })
            )?;
            cmd
        }
        MessageType::Media => {
            let cmd: Command = serde_json::from_value(
                serde_json::json!({ "type": "media", "payload": msg.payload })
            )?;
            cmd
        }
        MessageType::Custom => {
            let cmd: Command = serde_json::from_value(
                serde_json::json!({ "type": "custom", "payload": msg.payload })
            )?;
            cmd
        }
        MessageType::Batch => {
            // Handle batch commands
            #[derive(serde::Deserialize)]
            struct BatchPayload {
                commands: Vec<serde_json::Value>,
            }
            
            let payload: BatchPayload = serde_json::from_value(msg.payload)?;
            for cmd_value in payload.commands {
                let cmd: Command = serde_json::from_value(cmd_value)?;
                let incoming = IncomingCommand {
                    command: cmd,
                    timestamp: msg.timestamp,
                };
                let _ = command_tx.send(incoming);
            }
            return Ok(());
        }
        _ => {
            return Err(Error::protocol(format!("Unexpected message type: {:?}", msg.message_type)));
        }
    };
    
    // Broadcast the command
    let incoming = IncomingCommand {
        command,
        timestamp: msg.timestamp,
    };
    
    let _ = command_tx.send(incoming);
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    fn create_test_config() -> WebSocketConfig {
        WebSocketConfig {
            host: "127.0.0.1".to_string(),
            port: 0, // Let OS assign a free port
            path: "/remote".to_string(),
            heartbeat_interval_secs: 5,
            connection_timeout_secs: 30,
        }
    }
    
    #[test]
    fn test_websocket_config_default() {
        let config = WebSocketConfig::default();
        
        assert_eq!(config.host, "0.0.0.0");
        assert_eq!(config.port, 8765);
        assert_eq!(config.path, "/remote");
        assert_eq!(config.heartbeat_interval_secs, 5);
        assert_eq!(config.connection_timeout_secs, 30);
    }
    
    #[test]
    fn test_websocket_server_creation() {
        let config = create_test_config();
        let server = WebSocketServer::new(config.clone());
        
        assert_eq!(server.config().port, config.port);
        assert!(!server.is_running());
    }
    
    #[test]
    fn test_websocket_server_subscribe() {
        let config = create_test_config();
        let server = WebSocketServer::new(config);
        
        let _rx1 = server.subscribe_commands();
        let _rx2 = server.subscribe_commands();
        
        // Should be able to subscribe multiple times
    }
    
    #[tokio::test]
    async fn test_websocket_server_start_stop() {
        let config = create_test_config();
        let server = WebSocketServer::new(config);
        
        assert!(!server.is_running());
        
        let result = server.start().await;
        assert!(result.is_ok());
        
        // Give it a moment to start
        tokio::time::sleep(Duration::from_millis(50)).await;
        
        assert!(server.is_running());
        
        server.stop();
        
        // Give it a moment to stop
        tokio::time::sleep(Duration::from_millis(50)).await;
        
        assert!(!server.is_running());
    }
    
    #[test]
    fn test_handle_message_mouse() {
        let (tx, _rx) = broadcast::channel(10);
        
        let json = r#"{
            "type": "mouse",
            "payload": { "action": "move", "data": { "dx": 10, "dy": -5 } },
            "timestamp": 1234567890
        }"#;
        
        let result = handle_message(json, &tx);
        assert!(result.is_ok());
    }
    
    #[test]
    fn test_handle_message_keyboard() {
        let (tx, _rx) = broadcast::channel(10);
        
        let json = r#"{
            "type": "keyboard",
            "payload": { "action": "type_text", "data": { "text": "Hello" } },
            "timestamp": 1234567890
        }"#;
        
        let result = handle_message(json, &tx);
        assert!(result.is_ok());
    }
    
    #[test]
    fn test_handle_message_media() {
        let (tx, _rx) = broadcast::channel(10);
        
        let json = r#"{
            "type": "media",
            "payload": "play_pause",
            "timestamp": 1234567890
        }"#;
        
        let result = handle_message(json, &tx);
        assert!(result.is_ok());
    }
    
    #[test]
    fn test_handle_message_invalid_json() {
        let (tx, _rx) = broadcast::channel(10);
        
        let json = "invalid json";
        
        let result = handle_message(json, &tx);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("JSON"));
    }
    
    #[test]
    fn test_handle_message_unknown_type() {
        let (tx, _rx) = broadcast::channel(10);
        
        let json = r#"{
            "type": "unknown_type",
            "payload": {},
            "timestamp": 1234567890
        }"#;
        
        let result = handle_message(json, &tx);
        assert!(result.is_err());
    }
}
