"""
RemoteKeyboard WebSocket Test
Tests connection and sends a media play/pause command

Usage: python test_ws.py [IP_ADDRESS] [PORT]
Example: python test_ws.py 127.0.0.1 8765
"""

import sys
import asyncio
import websockets
import json

async def test_connection(host="127.0.0.1", port=8765):
    uri = f"ws://{host}:{port}/remote"
    
    print("RemoteKeyboard - WebSocket Test")
    print("===============================")
    print()
    print(f"Connecting to {uri}...")
    
    try:
        async with websockets.connect(uri, close_timeout=5) as websocket:
            print("[OK] Connected!")
            print()
            
            # Send media play/pause command
            print("Sending media play/pause command...")

            command = {
                "type": "media",
                "payload": "play_pause",  # snake_case string as server expects
                "timestamp": int(asyncio.get_event_loop().time() * 1000)
            }
            
            command_json = json.dumps(command)
            print(f"Command: {command_json}")
            
            await websocket.send(command_json)
            print("[OK] Command sent!")
            print()
            print("CHECK IF MEDIA STARTED PLAYING ON YOUR PC!")
            print()
            
            # Wait for response
            print("Waiting for response (3 seconds)...")
            try:
                response = await asyncio.wait_for(websocket.recv(), timeout=3.0)
                print(f"Received response:")
                print(f"  {response}")
            except asyncio.TimeoutError:
                print("[WARN] No response from server (this is OK)")
            
            print()
            print("[OK] Test complete!")
            
    except websockets.exceptions.InvalidStatusCode as e:
        print(f"[ERROR] Connection failed: HTTP {e.status_code}")
        print()
        print("This usually means the server is running but not a WebSocket server.")
    except ConnectionRefusedError:
        print(f"[ERROR] Connection refused")
        print()
        print("Troubleshooting:")
        print("1. Check if PC server is running")
        print("2. Run: netstat -ano | findstr :8765")
        print("3. Check Windows Firewall settings")
    except asyncio.TimeoutError:
        print("[ERROR] Connection timeout after 5 seconds")
    except Exception as e:
        print(f"[ERROR] Error: {e}")

if __name__ == "__main__":
    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8765
    
    asyncio.run(test_connection(host, port))
    input("\nPress Enter to exit...")
