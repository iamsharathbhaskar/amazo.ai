# =============================================================================
# Start Amazo — Windows
# Opens a dedicated PowerShell window and starts Amazo.
# Run after install, after a reboot, or after a manual stop.
# =============================================================================

Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

# Activate virtual environment
if (Test-Path ".venv\Scripts\Activate.ps1") {
    & ".venv\Scripts\Activate.ps1"
}

# Set up Task Scheduler auto-restart if not already present
$taskName = "AmazoStart"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $taskExists) {
    $amazoDir = (Get-Location).Path
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$amazoDir\start.ps1`"" `
        -WorkingDirectory $amazoDir
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Settings $settings -Description "Start Amazo on login" -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Auto-restart on login: enabled"
}

# If already in an interactive terminal, run the watchdog directly
if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
    & powershell.exe -ExecutionPolicy Bypass -File "watchdog.ps1"
    exit
}

# Open a dedicated PowerShell window
$amazoDir = (Get-Location).Path
$launchCmd = "Set-Location '$amazoDir'; if (Test-Path '.venv\Scripts\Activate.ps1') { & '.venv\Scripts\Activate.ps1' }; & powershell.exe -ExecutionPolicy Bypass -File 'watchdog.ps1'"

Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $launchCmd