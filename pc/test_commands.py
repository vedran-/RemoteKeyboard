"""
Test WebSocket Client - Sends real commands to PC server
This will help us debug if commands are being received and executed.
"""

import asyncio
import websockets
import json
import time

async def test_media_keys():
    uri = "ws://127.0.0.1:8765/remote"
    
    print("=" * 60)
    print("WebSocket Command Test - Media Keys")
    print("=" * 60)
    print()
    print(f"Connecting to {uri}...")
    
    try:
        async with websockets.connect(uri) as websocket:
            print("[OK] Connected to PC server!")
            print()
            
            # Wait for connection_accepted
            response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
            data = json.loads(response)
            print(f"Received: {data}")
            print()
            
            if data.get('type') != 'connection_accepted':
                print("[ERROR] Did not receive connection_accepted!")
                return
            
            print("[OK] Connection accepted by server")
            print()
            print("Now sending media commands...")
            print("Watch your PC - media should respond to these commands!")
            print()
            
            # Test 1: Play/Pause
            print("[1/4] Sending PLAY_PAUSE...")
            command = {
                "type": "media",
                "payload": "play_pause",  # snake_case as server expects
                "timestamp": int(time.time() * 1000)
            }
            await websocket.send(json.dumps(command))
            print("      Sent. Check if media played/paused!")
            await asyncio.sleep(1)
            
            # Test 2: Mute
            print("[2/4] Sending MUTE...")
            command = {
                "type": "media",
                "payload": "mute",  # snake_case as server expects
                "timestamp": int(time.time() * 1000)
            }
            await websocket.send(json.dumps(command))
            print("      Sent. Check if sound muted!")
            await asyncio.sleep(1)
            
            # Test 3: Volume Up
            print("[3/4] Sending VOLUME_UP...")
            command = {
                "type": "media",
                "payload": "vol_up",  # snake_case as server expects
                "timestamp": int(time.time() * 1000)
            }
            await websocket.send(json.dumps(command))
            print("      Sent. Check if volume increased!")
            await asyncio.sleep(1)
            
            # Test 4: Volume Down
            print("[4/4] Sending VOLUME_DOWN...")
            command = {
                "type": "media",
                "payload": "vol_down",  # snake_case as server expects
                "timestamp": int(time.time() * 1000)
            }
            await websocket.send(json.dumps(command))
            print("      Sent. Check if volume decreased!")
            await asyncio.sleep(1)
            
            print()
            print("=" * 60)
            print("TEST COMPLETE")
            print("=" * 60)
            print()
            print("Did any of the media commands work?")
            print("- Play/Pause should toggle media player")
            print("- Mute should mute system volume")
            print("- Volume Up/Down should change volume")
            print()
            print("If NOT, the bug is in the PC server's command execution.")
            print()
            
    except Exception as e:
        print(f"[ERROR] {e}")
        print()
        print("Troubleshooting:")
        print("1. Make sure PC server is running")
        print("2. Check if port 8765 is listening: netstat -ano | findstr :8765")
        print("3. Check Windows Firewall settings")

if __name__ == "__main__":
    asyncio.run(test_media_keys())
    input("Press Enter to exit...")
