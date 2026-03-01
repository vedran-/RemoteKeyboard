# RemoteKeyboard WebSocket Test Script
# Tests connection and sends a media play/pause command

param(
    [string]$pcIp = "127.0.0.1",
    [int]$port = 8765
)

Write-Host "🎹 RemoteKeyboard - WebSocket Test" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Connecting to ws://$pcIp`: $port/remote..." -ForegroundColor Yellow

try {
    # Create WebSocket client
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    
    # Connect with 5 second timeout
    $timeout = [Threading.CancellationToken]::None
    $connectTask = $ws.ConnectAsync([uri]"ws://$pcIp`: $port/remote", $timeout)
    
    # Wait for connection
    if ($connectTask.Wait(5000)) {
        Write-Host "✅ Connected!" -ForegroundColor Green
        Write-Host "   State: $($ws.State)" -ForegroundColor Gray
        Write-Host ""
        
        # Send media play/pause command
        Write-Host "📤 Sending media play/pause command..." -ForegroundColor Yellow
        
        $command = @{
            type = "media"
            payload = @{
                action = "play_pause"
            }
            timestamp = [int64](Get-Date -UFormat "%s") * 1000
        } | ConvertTo-Json -Compress
        
        Write-Host "   Command: $command" -ForegroundColor Gray
        
        # Convert to bytes
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($command)
        $buffer = [System.ArraySegment[byte]]::new($bytes)
        
        # Send message
        $sendTask = $ws.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $timeout)
        $sendTask.Wait(3000)
        
        Write-Host "✅ Command sent!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎵 Check if media started playing on your PC!" -ForegroundColor Cyan
        Write-Host ""
        
        # Wait for response
        Write-Host "⏳ Waiting for response (3 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        
        # Try to read response
        $receiveBuffer = [System.ArraySegment[byte]]::new([byte[]]::new(1024))
        try {
            $receiveTask = $ws.ReceiveAsync($receiveBuffer, $timeout)
            if ($receiveTask.Wait(2000)) {
                $result = $receiveTask.Result
                if ($result.Count -gt 0) {
                    $response = [System.Text.Encoding]::UTF8.GetString($receiveBuffer.Array, 0, $result.Count)
                    Write-Host "📩 Received response:" -ForegroundColor Green
                    Write-Host "   $response" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "⚠️  No response from server (this is OK)" -ForegroundColor Yellow
        }
        
        # Close connection
        $closeTask = $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Done", $timeout)
        $closeTask.Wait(2000)
        
        Write-Host ""
        Write-Host "✅ Test complete!" -ForegroundColor Green
        
    } else {
        Write-Host "❌ Connection timeout after 5 seconds" -ForegroundColor Red
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "1. Check if PC server is running" -ForegroundColor Gray
        Write-Host "2. Run: netstat -ano | findstr :8765" -ForegroundColor Gray
        Write-Host "3. Check Windows Firewall settings" -ForegroundColor Gray
    }
    
    $ws.Dispose()
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Exception details:" -ForegroundColor Gray
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Press Enter to exit..."
Read-Host
