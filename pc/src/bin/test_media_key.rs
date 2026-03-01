//! Test binary to verify media key simulation works
//! 
//! Run this and it will press the Play/Pause media key on your PC.
//! You should see your media player (Spotify, YouTube, VLC, etc.) play or pause.

use enigo::{Enigo, Key, Settings, Keyboard};
use std::thread;
use std::time::Duration;

fn main() {
    println!("🎵 Media Key Test - Play/Pause");
    println!("================================");
    println!();
    println!("This will press the Play/Pause media key in 3 seconds...");
    println!("Make sure you have a media player open (Spotify, YouTube, VLC, etc.)");
    println!();
    
    // Countdown
    for i in 3..0 {
        if i > 0 {
            println!("  {}...", i);
            thread::sleep(Duration::from_secs(1));
        }
    }
    
    println!();
    println!("Pressing Play/Pause key now...");
    
    // Create enigo instance
    let mut enigo = Enigo::new(&Settings::default()).expect("Failed to initialize enigo");
    
    // Press the Play/Pause media key
    enigo.key(Key::MediaPlayPause, enigo::Direction::Click)
        .expect("Failed to press media key");
    
    println!("✅ Media key pressed!");
    println!();
    println!("Did your media player respond?");
    println!();
    println!("Testing again in 2 seconds...");
    thread::sleep(Duration::from_secs(2));
    
    println!("Pressing Play/Pause again...");
    enigo.key(Key::MediaPlayPause, enigo::Direction::Click)
        .expect("Failed to press media key");
    
    println!("✅ Done!");
    println!();
    println!("If this worked, the PC input simulation is working correctly!");
}
