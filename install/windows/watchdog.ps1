# =============================================================================
# Amazo Watchdog — Windows
# Runs agent.py in the foreground and restarts it if it crashes or hangs.
# =============================================================================

Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

$HeartbeatFile = "my-core\my-heartbeat.txt"
$HeartbeatTimeout = 1800
$CheckInterval = 60

while ($true) {

    # Start background heartbeat monitor
    $monitorJob = Start-Job -ScriptBlock {
        param($hbFile, $hbTimeout, $interval)
        while ($true) {
            Start-Sleep -Seconds $interval
            if (Test-Path $hbFile) {
                $age = ((Get-Date) - (Get-Item $hbFile).LastWriteTime).TotalSeconds
                if ($age -gt $hbTimeout) {
                    Write-Output "[watchdog] Heartbeat stale (${age}s). Restarting agent..."
                    Get-Process -Name "python*" -ErrorAction SilentlyContinue |
                        Where-Object { $_.CommandLine -match "agent\.py" } |
                        Stop-Process -Force -ErrorAction SilentlyContinue
                    return
                }
            }
        }
    } -ArgumentList $HeartbeatFile, $HeartbeatTimeout, $CheckInterval

    # Run agent in foreground — output visible in terminal
    python agent.py
    $exitCode = $LASTEXITCODE

    # Clean up monitor
    Stop-Job $monitorJob -ErrorAction SilentlyContinue
    Remove-Job $monitorJob -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "[watchdog] agent.py exited (code: $exitCode). Restarting in 5 seconds..."
    Start-Sleep -Seconds 5
}