/// Firewall Manager for Windows
///
/// Handles Windows Firewall rules for the RemoteKeyboard application.
/// Automatically creates firewall rules to allow incoming connections.

use std::process::Command;
use tracing::{info, warn, error};

/// Firewall manager for Windows
pub struct FirewallManager {
    port: u16,
    rule_name: String,
}

impl FirewallManager {
    /// Create a new firewall manager
    pub fn new(port: u16) -> Self {
        FirewallManager {
            port,
            rule_name: format!("RemoteKeyboard-{}", port),
        }
    }

    /// Get the rule name
    pub fn rule_name(&self) -> &str {
        &self.rule_name
    }

    /// Check if firewall rule exists
    pub fn rule_exists(&self) -> bool {
        let output = Command::new("netsh")
            .args(&[
                "advfirewall",
                "firewall",
                "show",
                "rule",
                "name=all",
            ])
            .output();

        match output {
            Ok(out) => {
                let stdout = String::from_utf8_lossy(&out.stdout);
                stdout.contains(&self.rule_name)
            }
            Err(e) => {
                warn!("Failed to check firewall rules: {}", e);
                false
            }
        }
    }

    /// Check if port is allowed through firewall
    pub fn is_port_allowed(&self) -> bool {
        // Try to check if rule exists and is enabled
        let output = Command::new("netsh")
            .args(&[
                "advfirewall",
                "firewall",
                "show",
                "rule",
                "name=all",
            ])
            .output();

        match output {
            Ok(out) => {
                let stdout = String::from_utf8_lossy(&out.stdout);
                // Check if our rule exists and is enabled
                stdout.contains(&self.rule_name) && stdout.contains("Enabled: Yes")
            }
            Err(e) => {
                warn!("Failed to check port status: {}", e);
                false
            }
        }
    }

    /// Add firewall rule to allow incoming connections
    /// 
    /// This requires administrator privileges.
    pub fn add_rule(&self) -> Result<(), String> {
        info!("Adding firewall rule: {}", self.rule_name);

        // Remove existing rule if it exists
        let _ = self.remove_rule();

        // Add new rule for TCP port
        let output = Command::new("netsh")
            .args(&[
                "advfirewall",
                "firewall",
                "add",
                "rule",
                &format!("name={}", self.rule_name),
                "dir=in",
                "action=allow",
                "protocol=TCP",
                &format!("localport={}", self.port),
                "profile=any",
                &format!("description=RemoteKeyboard PC server on port {}", self.port),
            ])
            .output();

        match output {
            Ok(out) => {
                if out.status.success() {
                    info!("Firewall rule added successfully");
                    Ok(())
                } else {
                    let stderr = String::from_utf8_lossy(&out.stderr);
                    let stdout = String::from_utf8_lossy(&out.stdout);
                    
                    // Check if it's a permission error
                    if stderr.contains("Access is denied") || stdout.contains("Access is denied") {
                        Err("Administrator privileges required. Please run as Administrator.".to_string())
                    } else {
                        Err(format!("Failed to add rule: {}", stderr))
                    }
                }
            }
            Err(e) => {
                Err(format!("Failed to execute netsh: {}", e))
            }
        }
    }

    /// Remove firewall rule
    pub fn remove_rule(&self) -> Result<(), String> {
        info!("Removing firewall rule: {}", self.rule_name);

        let output = Command::new("netsh")
            .args(&[
                "advfirewall",
                "firewall",
                "delete",
                "rule",
                &format!("name={}", self.rule_name),
            ])
            .output();

        match output {
            Ok(out) => {
                if out.status.success() {
                    info!("Firewall rule removed successfully");
                    Ok(())
                } else {
                    // Rule might not exist, which is fine
                    warn!("No existing rule to remove");
                    Ok(())
                }
            }
            Err(e) => {
                Err(format!("Failed to remove rule: {}", e))
            }
        }
    }

    /// Ensure firewall rule exists (create if not)
    pub fn ensure_rule_exists(&self) -> Result<(), String> {
        if self.is_port_allowed() {
            info!("Firewall rule already exists and is enabled");
            return Ok(());
        }

        self.add_rule()
    }

    /// Check if running as administrator
    pub fn is_admin() -> bool {
        // Try to open a protected system file - will fail if not admin
        let test_path = r"C:\Windows\System32\config";
        std::fs::read_dir(test_path).is_ok()
    }

    /// Restart as administrator (UAC prompt)
    pub fn restart_as_admin() -> Result<(), String> {
        use std::env;
        use std::process;

        let args: Vec<String> = env::args().collect();
        let exe = env::current_exe().map_err(|e| e.to_string())?;

        // Use PowerShell to restart with admin privileges
        let ps_args = format!(
            "Start-Process '{}' -ArgumentList '{}' -Verb RunAs -Wait",
            exe.display(),
            args[1..].join(" ")
        );

        let output = Command::new("powershell")
            .args(&["-Command", &ps_args])
            .output();

        match output {
            Ok(out) => {
                if out.status.success() {
                    // Exit current process
                    process::exit(0);
                } else {
                    Err("User declined UAC prompt or failed to elevate".to_string())
                }
            }
            Err(e) => Err(format!("Failed to restart as admin: {}", e)),
        }
    }
}

impl Drop for FirewallManager {
    fn drop(&mut self) {
        // Optionally remove rule on exit (commented out - keep rule for future use)
        // let _ = self.remove_rule();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_admin() {
        // This will be true if running as admin
        let is_admin = FirewallManager::is_admin();
        println!("Running as admin: {}", is_admin);
    }

    #[test]
    fn test_firewall_manager_creation() {
        let manager = FirewallManager::new(8765);
        assert_eq!(manager.port, 8765);
        assert_eq!(manager.rule_name, "RemoteKeyboard-8765");
    }
}
