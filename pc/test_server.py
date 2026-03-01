"""
Simple WebSocket Server Test
This creates a minimal WebSocket server to verify the CLIENT works.
Run this, then try to connect from the Windows/Android app.
"""

import asyncio
import websockets
import json

async def handler(websocket, path):
    print(f"[SERVER] Client connected from {websocket.remote_address}")
    
    # Send connection_accepted immediately (like PC server does)
    response = {
        "type": "connection_accepted",
        "payload": {
            "session_id": "test-session-123"
        },
        "timestamp": 1234567890
    }
    
    print(f"[SERVER] Sending: {response}")
    await websocket.send(json.dumps(response))
    
    # Listen for commands
    try:
        async for message in websocket:
            data = json.loads(message)
            print(f"[SERVER] Received command: {data}")
            
            # Echo back
            await websocket.send(json.dumps({"type": "ack", "received": data.get("type")}))
    except websockets.exceptions.ConnectionClosed:
        print("[SERVER] Client disconnected")

async def main():
    print("=" * 50)
    print("WebSocket Server Test")
    print("=" * 50)
    print()
    print("Server listening on ws://127.0.0.1:8765/remote")
    print()
    print("Now try to connect from the Windows/Android app:")
    print("1. Open RemoteKeyboard app")
    print("2. Add PC manually")
    print("3. IP: 127.0.0.1, Port: 8765")
    print("4. Try to connect")
    print()
    print("If connection succeeds, you'll see messages above.")
    print("If it fails, the bug is in the CLIENT (Flutter app).")
    print()
    print("Press Ctrl+C to stop")
    print()
    
    async with websockets.serve(handler, "127.0.0.1", 8765):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nServer stopped")
