//! End-to-End Integration Test
//!
//! Tests the full flow: mDNS advertising → WebSocket connection → Command execution

use std::time::Duration;
use tokio::time::sleep;
use futures_util::{SinkExt, StreamExt};

use crate::domain::entities::command::{Command, MediaCommand, MouseCommand, KeyboardCommand};
use crate::domain::entities::command::ProtocolMessage;
use crate::infrastructure::mdns::{MdnsAdvertiser, MdnsConfig};
use crate::infrastructure::websocket::{WebSocketServer, WebSocketConfig};
use crate::infrastructure::input::EnigoInputAdapter;
use crate::domain::services::InputExecutor;

#[tokio::test]
async fn test_full_command_flow() {
    // Setup mDNS advertiser
    let mdns_config = MdnsConfig {
        service_type: "_test-integration._tcp.local.".to_string(),
        instance_name: "TestPC".to_string(),
        hostname: "testpc.local.".to_string(),
        port: 8799,
        version: "1.0".to_string(),
        path: "/remote".to_string(),
    };
    
    let advertiser = MdnsAdvertiser::new(mdns_config.clone()).unwrap();
    advertiser.advertise().unwrap();
    
    // Setup WebSocket server
    let ws_config = WebSocketConfig {
        host: "127.0.0.1".to_string(),
        port: 8799,
        path: "/remote".to_string(),
        heartbeat_interval_secs: 5,
        connection_timeout_secs: 30,
    };
    
    let ws_server = WebSocketServer::new(ws_config.clone());
    ws_server.start().await.unwrap();
    
    // Give server time to start
    sleep(Duration::from_millis(100)).await;
    
    // Setup input adapter
    let input_adapter = EnigoInputAdapter::new().unwrap();
    
    // Subscribe to commands
    let mut command_rx = ws_server.subscribe_commands();
    
    // Simulate receiving a mouse move command
    let mouse_cmd = Command::Mouse(MouseCommand::move_relative(10, -5));
    let msg = ProtocolMessage::from_command(mouse_cmd.clone());
    let json = serde_json::to_string(&msg).unwrap();
    
    // Send via WebSocket (simulate client)
    use tokio::net::TcpStream;
    use tokio_tungstenite::{connect_async, tungstenite::Message};
    
    let url = format!("ws://127.0.0.1:{}/remote", ws_config.port);
    let (ws_stream, _) = connect_async(&url).await.unwrap();
    let (mut writer, mut reader) = ws_stream.split();
    
    // Send mouse move
    writer.send(Message::Text(json)).await.unwrap();
    
    // Wait for command to be processed
    sleep(Duration::from_millis(50)).await;
    
    // Receive command from channel
    let incoming = tokio::time::timeout(
        Duration::from_millis(100),
        command_rx.recv()
    ).await.unwrap().unwrap();
    
    // Verify command
    match incoming.command {
        Command::Mouse(MouseCommand::Move { dx, dy }) => {
            assert_eq!(dx, 10);
            assert_eq!(dy, -5);
        }
        _ => panic!("Expected MouseCommand::Move"),
    }
    
    // Test media command
    let media_cmd = Command::Media(MediaCommand::PlayPause);
    let msg = ProtocolMessage::from_command(media_cmd.clone());
    let json = serde_json::to_string(&msg).unwrap();
    
    writer.send(Message::Text(json)).await.unwrap();
    
    sleep(Duration::from_millis(50)).await;
    
    let incoming = tokio::time::timeout(
        Duration::from_millis(100),
        command_rx.recv()
    ).await.unwrap().unwrap();
    
    match incoming.command {
        Command::Media(MediaCommand::PlayPause) => {
            // Correct!
        }
        _ => panic!("Expected MediaCommand::PlayPause"),
    }
    
    // Test keyboard command
    let keyboard_cmd = Command::Keyboard(KeyboardCommand::text("Hello"));
    let msg = ProtocolMessage::from_command(keyboard_cmd.clone());
    let json = serde_json::to_string(&msg).unwrap();
    
    writer.send(Message::Text(json)).await.unwrap();
    
    sleep(Duration::from_millis(50)).await;
    
    let incoming = tokio::time::timeout(
        Duration::from_millis(100),
        command_rx.recv()
    ).await.unwrap().unwrap();
    
    match incoming.command {
        Command::Keyboard(KeyboardCommand::TypeText { text }) => {
            assert_eq!(text, "Hello");
        }
        _ => panic!("Expected KeyboardCommand::TypeText"),
    }
    
    // Cleanup
    advertiser.stop_advertising().unwrap();
    ws_server.stop();
}

#[tokio::test]
async fn test_input_adapter_with_commands() {
    // This test verifies that commands can be executed through the input adapter
    // Note: We don't actually execute them to avoid side effects during testing
    
    let adapter = EnigoInputAdapter::new().unwrap();
    
    // Test mouse command (would move mouse if executed)
    let mouse_cmd = MouseCommand::move_relative(0, 0);
    let result = adapter.execute_mouse(&mouse_cmd).await;
    assert!(result.is_ok());
    
    // Test media command (would press Play/Pause if executed)
    let media_cmd = MediaCommand::PlayPause;
    let result = adapter.execute_media(&media_cmd).await;
    assert!(result.is_ok());
    
    // Test keyboard command (would type if executed)
    let keyboard_cmd = KeyboardCommand::text("Test");
    let result = adapter.execute_keyboard(&keyboard_cmd).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_mdns_and_websocket_together() {
    // Test that mDNS and WebSocket can run simultaneously
    
    let port = 8800;
    
    // Setup mDNS
    let mdns_config = MdnsConfig {
        service_type: "_test-mdns-ws._tcp.local.".to_string(),
        instance_name: "TestPC2".to_string(),
        hostname: "testpc2.local.".to_string(),
        port,
        version: "1.0".to_string(),
        path: "/remote".to_string(),
    };
    
    let advertiser = MdnsAdvertiser::new(mdns_config.clone()).unwrap();
    advertiser.advertise().unwrap();
    
    assert!(advertiser.is_advertising());
    
    // Setup WebSocket
    let ws_config = WebSocketConfig {
        host: "127.0.0.1".to_string(),
        port,
        path: "/remote".to_string(),
        heartbeat_interval_secs: 5,
        connection_timeout_secs: 30,
    };
    
    let ws_server = WebSocketServer::new(ws_config.clone());
    ws_server.start().await.unwrap();
    
    assert!(ws_server.is_running());
    
    // Both should work together
    sleep(Duration::from_millis(100)).await;
    
    assert!(advertiser.is_advertising());
    assert!(ws_server.is_running());
    
    // Cleanup
    advertiser.stop_advertising().unwrap();
    ws_server.stop();
}
