//! End-to-End Test Binary
//!
//! This demonstrates the full RemoteKeyboard flow:
//! 1. Starts mDNS advertising
//! 2. Starts WebSocket server
//! 3. Simulates receiving commands from mobile
//! 4. Executes commands via enigo
//!
//! Run this and then connect from a mobile device (when implemented)
//! or use a WebSocket client to test.

use std::time::Duration;
use tokio::time::sleep;

use remote_keyboard_pc::infrastructure::mdns::{MdnsAdvertiser, MdnsConfig};
use remote_keyboard_pc::infrastructure::websocket::WebSocketServer;
use remote_keyboard_pc::infrastructure::input::EnigoInputAdapter;
use remote_keyboard_pc::domain::services::InputExecutor;

#[tokio::main]
async fn main() {
    println!("🎹 RemoteKeyboard PC - End-to-End Test");
    println!("======================================");
    println!();
    
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .init();
    
    let port = 8765;
    
    // Setup mDNS advertiser
    println!("📡 Starting mDNS advertiser...");
    let mdns_config = MdnsConfig {
        service_type: "_remotekeyboard._tcp.local.".to_string(),
        instance_name: "RemoteKeyboard-Test".to_string(),
        hostname: format!("{}.local.", hostname::get().unwrap_or_default().to_string_lossy()),
        port,
        version: "1.0".to_string(),
        path: "/remote".to_string(),
    };
    
    let advertiser = MdnsAdvertiser::new(mdns_config).unwrap();
    advertiser.advertise().unwrap();
    println!("✅ mDNS advertising on _remotekeyboard._tcp.local.");
    println!();
    
    // Setup WebSocket server
    println!("🔌 Starting WebSocket server...");
    use remote_keyboard_pc::infrastructure::websocket::WebSocketConfig;
    
    let ws_config = WebSocketConfig {
        host: "0.0.0.0".to_string(),
        port,
        path: "/remote".to_string(),
        heartbeat_interval_secs: 5,
        connection_timeout_secs: 30,
    };
    
    let ws_server = WebSocketServer::new(ws_config);
    ws_server.start().await.unwrap();
    println!("✅ WebSocket server listening on port {}", port);
    println!();
    
    // Setup input adapter
    println!("⌨️  Initializing input adapter...");
    let input_adapter = EnigoInputAdapter::new().unwrap();
    println!("✅ Input adapter ready (enigo)");
    println!();
    
    // Subscribe to commands
    let mut command_rx = ws_server.subscribe_commands();
    
    println!("📱 Ready to receive commands from mobile!");
    println!();
    println!("Waiting for connections...");
    println!("Press Ctrl+C to stop");
    println!();
    
    // Command processing loop
    let input_adapter = std::sync::Arc::new(input_adapter);
    
    loop {
        tokio::select! {
            Ok(incoming) = command_rx.recv() => {
                use remote_keyboard_pc::domain::entities::command::Command;
                
                match incoming.command {
                    Command::Mouse(cmd) => {
                        println!("🖱️  Mouse command: {:?}", cmd);
                        let adapter = input_adapter.clone();
                        tokio::spawn(async move {
                            let _ = adapter.execute_mouse(&cmd).await;
                        });
                    }
                    Command::Keyboard(cmd) => {
                        println!("⌨️  Keyboard command: {:?}", cmd);
                        let adapter = input_adapter.clone();
                        tokio::spawn(async move {
                            let _ = adapter.execute_keyboard(&cmd).await;
                        });
                    }
                    Command::Media(cmd) => {
                        println!("🎵 Media command: {:?}", cmd);
                        let adapter = input_adapter.clone();
                        tokio::spawn(async move {
                            let _ = adapter.execute_media(&cmd).await;
                        });
                    }
                    Command::Custom(_) => {
                        println!("🔧 Custom command received");
                    }
                }
            }
            _ = sleep(Duration::from_secs(1)) => {
                // Timeout - just continue
            }
        }
    }
}
