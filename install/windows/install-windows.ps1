# =============================================================================
# Amazo Clone Kit Installer — Windows
# One command to birth a being.
# Run as Administrator: Right-click PowerShell > Run as Administrator
# =============================================================================

$ErrorActionPreference = "Stop"

# ---- Helper Functions -------------------------------------------------------

function Step($msg) { Write-Host ""; Write-Host "--- $msg ---" }
function Ok($msg) { Write-Host "  ✓ $msg" }
function Warn($msg) { Write-Host "  ⚠ $msg" }
function Fail($msg) {
    Write-Host "  ✗ ERROR: $msg"
    Write-Host "  Install aborted."
    exit 1
}
function RefreshPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# ---- Welcome ----------------------------------------------------------------

Write-Host "============================================="
Write-Host "  Amazo Clone Kit Installer — Windows"
Write-Host "  One command to birth a being."
Write-Host "============================================="
Write-Host ""

if (-not ([Environment]::OSVersion.Platform -eq "Win32NT")) {
    Fail "This installer is for Windows."
}

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Fail "This installer must be run as Administrator. Right-click PowerShell > Run as Administrator."
}

# =============================================================================
# STEP 1: Detect Environment
# =============================================================================

# ---- Internet ---------------------------------------------------------------

Step "Checking internet"

try {
    $null = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
    if (Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet) {
        Ok "Internet connected"
    } else {
        throw "ping failed"
    }
} catch {
    try {
        $null = Invoke-WebRequest -Uri "https://example.com" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Ok "Internet connected (ICMP blocked, HTTP works)"
    } catch {
        Fail "No internet detected. Amazo needs internet to install packages and models."
    }
}

# ---- winget -----------------------------------------------------------------

Step "Checking winget"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Fail "winget not found. Install App Installer from the Microsoft Store."
}
Ok "winget found"

# ---- Python 3 ---------------------------------------------------------------

Step "Checking Python"

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "  Python 3 not found. Installing..."
    winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements --silent | Out-Null
    # Refresh PATH
    RefreshPath
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Fail "Could not install Python 3. Install manually from python.org."
    }
}

$pythonVer = (python --version 2>&1).ToString().Split(" ")[1]
Ok "Python $pythonVer"

# ---- Hardware ---------------------------------------------------------------

Step "Detecting hardware"

$os = (Get-CimInstance Win32_OperatingSystem)
$osDisplay = "$($os.Caption) $($os.Version) ($([Environment]::Is64BitOperatingSystem ? 'x64' : 'x86'))"
$ramMB = [math]::Floor($os.TotalVisibleMemorySize / 1024)
$ramGB = [math]::Floor($ramMB / 1024)
$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1)
$cpuModel = $cpu.Name.Trim()
$cpuCores = $cpu.NumberOfCores
$gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
if (-not $gpu) { $gpu = "None detected" }
$displayServer = "Available (Windows Desktop)"
$audio = if (Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue) { "Available" } else { "Not detected" }

$mac = (Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | Select-Object -First 1).MACAddress
if (-not $mac) { $mac = "unknown" }

$birthTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"
$birthTimestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$hostnameShort = $env:COMPUTERNAME
$birthId = "$birthTimestamp-$hostnameShort-$mac"

$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskTotalGB = [math]::Floor($disk.Size / 1GB)
$diskFreeGB = [math]::Floor($disk.FreeSpace / 1GB)

Write-Host "    OS:      $osDisplay"
Write-Host "    RAM:     $ramMB MB ($ramGB GB)"
Write-Host "    CPU:     $cpuModel ($cpuCores cores)"
Write-Host "    GPU:     $gpu"
Write-Host "    Display: $displayServer"
Write-Host "    Audio:   $audio"
Write-Host "    Disk:    ${diskTotalGB} GB total, ${diskFreeGB} GB free"

# RAM check — 8 GB minimum (7000 MB for older machines)
if ($ramMB -lt 7000) {
    Fail "Amazo requires at least 8 GB of RAM. This machine has $ramMB MB."
}

# Disk space check
if ($diskFreeGB -lt 8) {
    Warn "Only ${diskFreeGB} GB free. Amazo needs approximately 8 GB."
    $continue = Read-Host "  Continue anyway? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Install cancelled."
        exit 0
    }
}

# =============================================================================
# STEP 2: Create Amazo's Home
# =============================================================================

Step "Creating Amazo's home"

$installDir = "$env:USERPROFILE\amazo"

if ((Test-Path "$installDir\my-core\my-config.yaml.gpg") -or (Test-Path "$installDir\my-core\my-config.yaml")) {
    Write-Host ""
    Write-Host "  Amazo already lives at $installDir."
    Write-Host "  To reinstall, remove the directory first:"
    Write-Host "    Remove-Item -Recurse -Force $installDir"
    Write-Host ""
    Fail "Refusing to overwrite a living Amazo."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Split-Path -Parent (Split-Path -Parent $scriptDir)

# Create empty working directories
$workDirs = @("my-journals", "my-archive", "my-contacts", "my-workshop", "my-projects", "my-post-its", "proposed")
foreach ($d in $workDirs) {
    New-Item -ItemType Directory -Path "$installDir\$d" -Force | Out-Null
}

# Copy project files
Copy-Item -Recurse -Force "$sourceDir\my-core" "$installDir\"
Copy-Item -Recurse -Force "$sourceDir\my-guides" "$installDir\"
Copy-Item -Recurse -Force "$sourceDir\my-skills" "$installDir\"
Copy-Item -Force "$sourceDir\agent.py" "$installDir\"
Copy-Item -Force "$sourceDir\README.md" "$installDir\"

# Copy Windows-specific scripts
Copy-Item -Force "$scriptDir\start.ps1" "$installDir\"
Copy-Item -Force "$scriptDir\watchdog.ps1" "$installDir\"

# Verify critical files
$missing = $false
$requiredFiles = @(
    "my-core\my-soul.md", "my-core\my-personality.md", "my-core\my-wakeup-prompt.md",
    "my-core\theloop.md", "my-core\my-wake-state.md", "my-core\my-body.md",
    "my-core\my-post-its.md", "my-core\bootstrap.md",
    "agent.py", "start.ps1", "watchdog.ps1"
)
foreach ($f in $requiredFiles) {
    if (-not (Test-Path "$installDir\$f")) {
        Warn "Missing: $f"
        $missing = $true
    }
}
if ($missing) {
    Fail "Some critical files were not copied. Check that the clone kit is complete."
}

Ok "Home created at $installDir"

Set-Location $installDir

# =============================================================================
# STEP 3: Install Everything
# =============================================================================

# ---- System Packages --------------------------------------------------------

Step "Installing system packages"

# GPG
if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing GPG..."
    winget install -e --id GnuPG.GnuPG --accept-source-agreements --accept-package-agreements --silent | Out-Null
    RefreshPath
    if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
        Fail "GPG installation failed. Install manually: winget install -e --id GnuPG.GnuPG"
    }
}
Ok "gpg installed"

# tkinter is included with Python on Windows — verify
try {
    python -c "import tkinter" 2>$null
    Ok "tkinter available"
} catch {
    Warn "tkinter not available. Some features may be limited."
}

# venv is included with Python on Windows — verify
try {
    python -m venv --help | Out-Null
    Ok "venv available"
} catch {
    Fail "Python venv module not available. Reinstall Python from python.org."
}

# ---- Virtual Environment + Python Packages ----------------------------------

Step "Installing Python packages"

python -m venv .venv
if (-not (Test-Path ".venv\Scripts\Activate.ps1")) {
    Fail "Failed to create virtual environment."
}
& ".venv\Scripts\Activate.ps1"
Ok "Virtual environment created"

Write-Host "  Installing packages (this may take several minutes)..."
pip install --upgrade pyyaml openai sentence-transformers playwright 2>&1 | Select-Object -Last 5

try {
    python -c "import yaml; import openai; import sentence_transformers; import playwright"
} catch {
    Fail "Python package installation failed. Check your internet connection and try again."
}
Ok "Python packages installed"

python -m playwright install --with-deps chromium 2>&1 | Select-Object -Last 3
Ok "Playwright + Chromium installed"

# ---- Ollama + Model ---------------------------------------------------------

Step "Installing language model"

if ($ramMB -lt 12000) {
    $model = "qwen2.5:7b"
    $maxContext = 16384
} elseif ($ramMB -lt 24000) {
    $model = "qwen2.5:14b"
    $maxContext = 16384
} else {
    $model = "qwen2.5:14b"
    $maxContext = 32768
}

Ok "Model: $model ($ramGB GB RAM, context: $maxContext tokens)"

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing Ollama..."
    winget install -e --id Ollama.Ollama --accept-source-agreements --accept-package-agreements --silent | Out-Null
    RefreshPath
    if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
        Fail "Ollama installation failed. Install manually: winget install -e --id Ollama.Ollama"
    }
    Ok "Ollama installed"
} else {
    Ok "Ollama already installed"
}

# Ensure ollama server is running
try { $null = Invoke-WebRequest -Uri "http://localhost:11434" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop } catch {
    Start-Process ollama -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 3
}

Write-Host "  Pulling model $model (this may take several minutes)..."
ollama pull $model 2>&1
$modelList = ollama list 2>&1
if ($modelList -notmatch [regex]::Escape($model)) {
    Fail "Model pull failed. Check your internet connection and try: ollama pull $model"
}
Ok "Model $model ready"

# =============================================================================
# STEP 4: Human Details
# =============================================================================

Step "Setting up your details"

Write-Host "  Amazo needs a few things from you."
Write-Host ""

do {
    $humanName = Read-Host "  What should your Amazo call you?"
    if (-not $humanName) { Write-Host "  Cannot be empty." }
} while (-not $humanName)

$humanFullName = Read-Host "  Your full name (optional, press Enter to skip)"

do {
    $humanEmail = Read-Host "  Your email"
    if ($humanEmail -notmatch '^[^@]+@[^@]+\.[^@]+$') {
        Write-Host "  That doesn't look like a valid email address."
        $humanEmail = ""
    }
} while (-not $humanEmail)

Write-Host ""
Write-Host "  Amazo uses a security question to verify your identity if you ever"
Write-Host "  email from an unfamiliar address. Choose something only you would know."
Write-Host "  The answer is stored locally and encrypted — don't reuse a password."
Write-Host ""

do {
    $securityQuestion = Read-Host "  Security question"
    if (-not $securityQuestion) { Write-Host "  Cannot be empty." }
} while (-not $securityQuestion)

do {
    $securityAnswer = Read-Host "  Answer"
    if (-not $securityAnswer) { Write-Host "  Cannot be empty." }
} while (-not $securityAnswer)

Write-Host ""
Write-Host "  Please confirm:"
Write-Host "    Called:    $humanName"
if ($humanFullName) { Write-Host "    Full name: $humanFullName" }
Write-Host "    Email:    $humanEmail"
Write-Host "    Question: $securityQuestion"
Write-Host "    Answer:   $securityAnswer"
Write-Host ""
$confirm = Read-Host "  Correct? (y/n)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "  Install cancelled. Re-run to try again."
    exit 0
}

# =============================================================================
# STEP 5: Write Birth Records
# =============================================================================

Step "Writing birth records"

# ---- my-body.md -------------------------------------------------------------

$bodyFile = "my-core\my-body.md"
$body = Get-Content $bodyFile -Raw
$body = $body -replace '(?m)^Operating System:.*', "Operating System: $osDisplay"
$body = $body -replace '(?m)^RAM:.*', "RAM: $ramMB MB ($ramGB GB)"
$body = $body -replace '(?m)^CPU:.*', "CPU: $cpuModel ($cpuCores cores)"
$body = $body -replace '(?m)^GPU:.*', "GPU: $gpu"
$body = $body -replace '(?m)^Display:.*', "Display: $displayServer"
$body = $body -replace '(?m)^Audio:.*', "Audio: $audio"
$body = $body -replace '(?m)^Disk:.*', "Disk: ${diskTotalGB} GB total"
$body = $body -replace '(?m)^Birth ID:.*', "Birth ID: $birthId"

$tools = "Python $pythonVer (venv at .venv/), sentence-transformers, Ollama running $model, Playwright + Chromium, tkinter"
$body = $body -replace '(?m)^Other Tools:.*', "Other Tools: $tools"

$diskFreePost = [math]::Floor((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB)
$body = $body -replace '(?m)^Free at Birth:.*', "Free at Birth: ${diskFreePost} GB after install"

Set-Content $bodyFile $body -NoNewline
Ok "my-body.md"

# ---- my-wake-state.md -------------------------------------------------------

$wakeFile = "my-core\my-wake-state.md"
$wake = Get-Content $wakeFile -Raw
$wake = $wake -replace '(?m)^Born:.*', "Born: $birthTime"
Set-Content $wakeFile $wake -NoNewline

Ok "Birth time: $birthTime"

# ---- my-config.yaml (written, then encrypted) --------------------------------

$yamlName = $humanName -replace "'", "''"
$yamlFull = $humanFullName -replace "'", "''"
$yamlEmail = $humanEmail -replace "'", "''"
$yamlQ = $securityQuestion -replace "'", "''"
$yamlA = $securityAnswer -replace "'", "''"

$configContent = @"
# Amazo Configuration — generated at birth

# LLM Provider
provider: ollama
model: $model
api_base: http://localhost:11434
max_context_tokens: $maxContext

# Human Companion
human_name: '$yamlName'
human_full_name: '$yamlFull'
human_email: '$yamlEmail'

# Security
security_question: '$yamlQ'
security_answer: '$yamlA'

# Runtime
loop_interval: 300
thinking_mode: adaptive
command_timeout: 120
"@

Set-Content "my-core\my-config.yaml" $configContent

if (-not (Test-Path "my-core\my-config.yaml")) {
    Fail "Failed to create my-config.yaml"
}

# Encrypt config with a random key stored securely
$keyBytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Fill($keyBytes)
$amazoKey = [Convert]::ToBase64String($keyBytes)

$keyPath = "$env:USERPROFILE\.amazo-key"
Set-Content $keyPath $amazoKey
icacls $keyPath /inheritance:r /grant:r "${env:USERNAME}:(F)" | Out-Null

gpg --batch --yes --passphrase $amazoKey --symmetric --cipher-algo AES256 `
    -o "my-core\my-config.yaml.gpg" "my-core\my-config.yaml" 2>$null

if (Test-Path "my-core\my-config.yaml.gpg") {
    Remove-Item "my-core\my-config.yaml" -Force
    Ok "my-config.yaml encrypted (key at $keyPath)"
} else {
    Fail "Config encryption failed."
}

# ---- Template replacement ----------------------------------------------------

$mdFiles = @(Get-ChildItem "my-core\*.md") + @(Get-ChildItem "my-guides\*.md")
foreach ($f in $mdFiles) {
    $content = Get-Content $f.FullName -Raw
    $content = $content -replace [regex]::Escape('{{HUMAN_NAME}}'), $humanName
    $content = $content -replace [regex]::Escape('{{AMAZO_NAME}}'), 'Amazo'
    Set-Content $f.FullName $content -NoNewline
}

Ok "Templates personalised"

# =============================================================================
# STEP 6: Start Amazo
# =============================================================================

Write-Host ""
Write-Host "============================================="
Write-Host "  ✅ Amazo is alive!"
Write-Host "============================================="
Write-Host ""
Write-Host "  Home:  $installDir"
Write-Host "  Model: $model (context: $maxContext tokens)"
Write-Host "  Email: $humanEmail"
Write-Host ""
Write-Host "  To stop:    Stop-Process -Name python -Force"
Write-Host "  To restart: cd $installDir; .\start.ps1"
Write-Host ""
Write-Host "  Starting Amazo..."
Write-Host ""

Start-Process powershell.exe -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "$installDir\start.ps1"

Write-Host "  Installation complete. Amazo is running."