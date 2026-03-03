//! RemoteKeyboard PC Application - Main Entry Point
//!
//! Starts WebSocket server, mDNS discovery, and executes commands.
//! Automatically configures Windows Firewall if needed.

// Always use console for logging (even in release)
// #![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tracing_subscriber::{self, EnvFilter};

fn main() {
    // Load configuration FIRST (before logging init)
    let config = remote_keyboard_pc::infrastructure::config::AppConfig::load();
    let log_level = config.get_log_level();

    // Initialize logging with configured level
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::from_default_env()
                .add_directive(format!("remote_keyboard_pc={}", log_level).parse().unwrap())
                .add_directive("info".parse().unwrap()),
        )
        .init();

    println!("🎹 RemoteKeyboard PC");
    println!("===================");
    println!();

    let port = 8765;

    // Configure firewall
    println!("🔒 Configuring Windows Firewall...");
    use remote_keyboard_pc::infrastructure::firewall::FirewallManager;
    
    let firewall = FirewallManager::new(port);
    
    if !FirewallManager::is_admin() {
        println!("⚠️  Not running as Administrator");
        println!("   Firewall configuration may fail");
        println!();
    }
    
    match firewall.ensure_rule_exists() {
        Ok(()) => {
            println!("✅ Firewall rule configured: {}", firewall.rule_name());
        }
        Err(e) => {
            println!("⚠️  Firewall configuration: {}", e);
            println!("   If connection fails, manually allow port {} through firewall", port);
        }
    }
    println!();

    // Setup mDNS advertiser
    println!("📡 Starting mDNS advertiser...");
    use remote_keyboard_pc::infrastructure::mdns::{MdnsAdvertiser, MdnsConfig};
    
    let mdns_config = MdnsConfig {
        service_type: "_remotekeyboard._tcp.local.".to_string(),
        instance_name: "RemoteKeyboard-PC".to_string(),
        hostname: format!("{}.local.", hostname::get().unwrap_or_default().to_string_lossy()),
        port,
        version: "1.0".to_string(),
        path: "/remote".to_string(),
    };

    if let Ok(advertiser) = MdnsAdvertiser::new(mdns_config) {
        if let Err(e) = advertiser.advertise() {
            println!("⚠️  mDNS advertise failed: {}", e);
        } else {
            println!("✅ mDNS advertising: _remotekeyboard._tcp.local.");
        }
    }

    // Setup WebSocket server
    println!("🔌 Starting WebSocket server...");
    use remote_keyboard_pc::infrastructure::websocket::{WebSocketServer, WebSocketConfig};

    let ws_config = WebSocketConfig {
        host: "0.0.0.0".to_string(),
        port,
        path: "/remote".to_string(),
        heartbeat_interval_secs: 5,
        connection_timeout_secs: 30,
    };

    let ws_server = WebSocketServer::new(ws_config);

    // Setup input adapter for executing commands
    println!("⌨️  Initializing input adapter...");
    use remote_keyboard_pc::infrastructure::input::EnigoInputAdapter;
    use remote_keyboard_pc::domain::services::InputExecutor;

    let input_adapter = match EnigoInputAdapter::new() {
        Ok(adapter) => {
            println!("✅ Input adapter ready (enigo)");
            std::sync::Arc::new(adapter)
        }
        Err(e) => {
            println!("❌ Failed to initialize input adapter: {}", e);
            return;
        }
    };
    println!();

    // Run the server
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        if let Err(e) = ws_server.start().await {
            println!("❌ WebSocket server error: {}", e);
            return;
        }

        println!("✅ WebSocket server listening on port {}", port);
        println!();
        println!("📱 Ready to receive commands from mobile!");
        println!("   Press Ctrl+C to stop");
        println!();

        // Subscribe to commands and execute them
        let mut command_rx = ws_server.subscribe_commands();

        // Command processing loop
        println!("✅ Command listener ready - waiting for commands...");
        println!();

        loop {
            tokio::select! {
                Ok(incoming) = command_rx.recv() => {
                    use remote_keyboard_pc::domain::entities::command::Command;

                    match incoming.command {
                        Command::Mouse(cmd) => {
                            println!("🖱️  [RECEIVED] Mouse command: {:?}", cmd);
                            let adapter = input_adapter.clone();
                            tokio::spawn(async move {
                                match adapter.execute_mouse(&cmd).await {
                                    Ok(_) => println!("✅ [EXECUTED] Mouse command successful"),
                                    Err(e) => println!("❌ [FAILED] Mouse command error: {}", e),
                                }
                            });
                        }
                        Command::Keyboard(cmd) => {
                            println!("⌨️  [RECEIVED] Keyboard command: {:?}", cmd);
                            let adapter = input_adapter.clone();
                            tokio::spawn(async move {
                                match adapter.execute_keyboard(&cmd).await {
                                    Ok(_) => println!("✅ [EXECUTED] Keyboard command successful"),
                                    Err(e) => println!("❌ [FAILED] Keyboard command error: {}", e),
                                }
                            });
                        }
                        Command::Media(cmd) => {
                            println!("🎵 [RECEIVED] Media command: {:?}", cmd);
                            let adapter = input_adapter.clone();
                            tokio::spawn(async move {
                                match adapter.execute_media(&cmd).await {
                                    Ok(_) => println!("✅ [EXECUTED] Media command successful"),
                                    Err(e) => println!("❌ [FAILED] Media command error: {}", e),
                                }
                            });
                        }
                        Command::Custom(_) => {
                            println!("🔧 [RECEIVED] Custom command");
                        }
                    }
                }
                _ = tokio::time::sleep(tokio::time::Duration::from_secs(60)) => {
                    // Timeout - just continue
                }
            }
        }
    });
}
