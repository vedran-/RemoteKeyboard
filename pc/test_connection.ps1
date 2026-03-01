# RemoteKeyboard WebSocket Test Script
# Tests connection from Windows to PC server

param(
    [string]$pcIp = "127.0.0.1",
    [int]$port = 8765
)

Write-Host "🎹 RemoteKeyboard - WebSocket Test Client" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$wsUrl = "ws://$pcIp`: $port/remote"
Write-Host "📡 Testing connection to $wsUrl..." -ForegroundColor Yellow
Write-Host ""

try {
    # Test TCP connection first
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connectResult = $tcpClient.BeginConnect($pcIp, $port, $null, $null)
    $connected = $connectResult.AsyncWaitHandle.WaitOne(3000)
    
    if ($connected -and $tcpClient.Connected) {
        Write-Host "✅ TCP Connection SUCCESS" -ForegroundColor Green
        Write-Host "   Port $port is open and accepting connections" -ForegroundColor Gray
        $tcpClient.Close()
        
        Write-Host ""
        Write-Host "✅ PC Server is RUNNING and REACHABLE!" -ForegroundColor Green
        Write-Host ""
        Write-Host "If the mobile app can't connect, check:" -ForegroundColor Yellow
        Write-Host "1. Mobile device is on the SAME WiFi network" -ForegroundColor Gray
        Write-Host "2. Firewall allows incoming connections on port $port" -ForegroundColor Gray  
        Write-Host "3. Try using the PC's actual IP (not localhost) on mobile" -ForegroundColor Gray
        Write-Host ""
        Write-Host "PC IP Address:" -ForegroundColor Gray
        ipconfig | Select-String "IPv4" | ForEach-Object { Write-Host "   $_" -ForegroundColor Cyan }
        
    } else {
        Write-Host "❌ TCP Connection FAILED" -ForegroundColor Red
        Write-Host "   Port $port is not reachable" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "1. Make sure PC server is running" -ForegroundColor Gray
        Write-Host "2. Check Windows Firewall settings" -ForegroundColor Gray
        Write-Host "3. Run: netstat -ano | findstr :$port" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Gray
Read-Host
