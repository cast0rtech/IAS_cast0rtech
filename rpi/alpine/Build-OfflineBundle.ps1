# ==============================================================================
# EMA Industrial Alpine OS - 100% Offline / Air-Gapped Bundle Generator (Windows)
# Generates a bootable, self-contained zip for Raspberry Pi (3B+, 4, 5, CM4, CM5)
# Zero internet required at target plant/device!
# ==============================================================================

$ErrorActionPreference = "Stop"

$AlpineVersion = "3.20.3"
$AlpineTar = "alpine-rpi-${AlpineVersion}-aarch64.tar.gz"
$AlpineUrl = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/aarch64/${AlpineTar}"

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$OutputDir = "$RepoRoot\dist\alpine-ema-os"
$CacheDir = "$OutputDir\cache"
$BootFsDir = "$OutputDir\bootfs"
$ApkovlSource = "$PSScriptRoot\apkovl"
$WheelsDir = "$PSScriptRoot\wheels"

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  EMA Industrial Alpine OS - Offline Air-Gapped Package Builder" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan

# 1. Ensure Directories
New-Item -ItemType Directory -Force -Path $CacheDir, $BootFsDir | Out-Null

# 2. Download Official Alpine aarch64 base if needed
$AlpineTarPath = "$CacheDir\$AlpineTar"
if (-not (Test-Path $AlpineTarPath)) {
    Write-Host "[1/5] Downloading Alpine Linux aarch64 base v$AlpineVersion..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $AlpineUrl -OutFile $AlpineTarPath
} else {
    Write-Host "[1/5] Alpine base archive found in cache." -ForegroundColor Green
}

# 3. Extract Alpine Base System
Write-Host "[2/5] Extracting Alpine base files into bootfs..." -ForegroundColor Yellow
Get-ChildItem -Path $BootFsDir -Exclude "cache" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
tar -xzf $AlpineTarPath -C $BootFsDir

# 4. Prepare Staging for apkovl
Write-Host "[3/5] Packaging offline overlay (ema-gateway.apkovl.tar.gz)..." -ForegroundColor Yellow
$TempOverlay = "$OutputDir\temp_apkovl"
if (Test-Path $TempOverlay) { Remove-Item -Recurse -Force $TempOverlay }
New-Item -ItemType Directory -Force -Path "$TempOverlay\etc", "$TempOverlay\opt\ema" | Out-Null

# Copy apkovl configuration files
Copy-Item -Path "$ApkovlSource\*" -Destination "$TempOverlay" -Recurse -Force

# Create OpenRC runlevels symlinks
New-Item -ItemType Directory -Force -Path "$TempOverlay\etc\runlevels\default" | Out-Null
Set-Content -Path "$TempOverlay\etc\hostname" -Value "ema-gateway"

# Copy EMA Codebase
Write-Host "      Adding EMA backend, frontend, and offline wheels..." -ForegroundColor DarkGray
Copy-Item -Path "$RepoRoot\backend" -Destination "$TempOverlay\opt\ema\backend" -Recurse -Force
Copy-Item -Path "$RepoRoot\frontend" -Destination "$TempOverlay\opt\ema\frontend" -Recurse -Force
Copy-Item -Path "$RepoRoot\alarme.csv" -Destination "$TempOverlay\opt\ema\alarme.csv" -Force
if (Test-Path "$RepoRoot\.env") {
    Copy-Item -Path "$RepoRoot\.env" -Destination "$TempOverlay\opt\ema\.env" -Force
} else {
    Copy-Item -Path "$RepoRoot\.env.example" -Destination "$TempOverlay\opt\ema\.env" -Force
}

# Copy Offline Wheels
New-Item -ItemType Directory -Force -Path "$TempOverlay\opt\ema\vendor\wheels" | Out-Null
Copy-Item -Path "$WheelsDir\*.whl" -Destination "$TempOverlay\opt\ema\vendor\wheels" -Force

# Build apkovl tar.gz
$ApkovlTarget = "$BootFsDir\ema-gateway.apkovl.tar.gz"
Push-Location $TempOverlay
tar -czf $ApkovlTarget etc opt
Pop-Location
Start-Sleep -Seconds 1
try {
    Remove-Item -Recurse -Force $TempOverlay -ErrorAction SilentlyContinue
} catch {}

# 5. Configure Raspberry Pi firmware settings (usercfg.txt)
Write-Host "[4/5] Configuring firmware settings (usercfg.txt)..." -ForegroundColor Yellow
$UserCfg = @"
# Hardware Watchdog enabled for industrial freeze prevention
dtparam=watchdog=on

# Conserve RAM & power
dtoverlay=disable-bt
dtparam=audio=off

# HDMI Hotplug
hdmi_force_hotplug=1
"@
Set-Content -Path "$BootFsDir\usercfg.txt" -Value $UserCfg

# 6. Create Offline Zip Archive
$ReleaseZip = "$OutputDir\ema-alpine-offline-airgap.zip"
if (Test-Path $ReleaseZip) { Remove-Item -Force $ReleaseZip }

Write-Host "[5/6] Compressing full offline release into: $ReleaseZip..." -ForegroundColor Yellow
Compress-Archive -Path "$BootFsDir\*" -DestinationPath $ReleaseZip -CompressionLevel Optimal

# 7. Generate Raw .img for Balena Etcher / Raspberry Pi Imager
Write-Host "[6/6] Generating bootable .img for Balena Etcher and Raspberry Pi Imager..." -ForegroundColor Yellow
$PythonCmd = "$RepoRoot\.venv\Scripts\python.exe"
if (-not (Test-Path $PythonCmd)) { $PythonCmd = "python" }

& $PythonCmd "$PSScriptRoot\build-raw-image.py"

Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "SUCCESS: Flashable Images & Offline Package Created!" -ForegroundColor Green
Write-Host "Balena / Pi Imager Image: $OutputDir\ema-alpine-os.img.zip" -ForegroundColor Cyan
Write-Host "Raw Disk Image:           $OutputDir\ema-alpine-os.img" -ForegroundColor Cyan
Write-Host "FAT32 Extracted Archive:  $ReleaseZip" -ForegroundColor Cyan
Write-Host ""
Write-Host "How to flash with Balena Etcher or Raspberry Pi Imager:" -ForegroundColor White
Write-Host "1. Open Balena Etcher or Raspberry Pi Imager." -ForegroundColor White
Write-Host "2. Select 'Flash from file' / 'Use Custom' and pick:" -ForegroundColor White
Write-Host "   $OutputDir\ema-alpine-os.img.zip" -ForegroundColor White
Write-Host "3. Choose your SD Card and click Flash!" -ForegroundColor White
Write-Host "=====================================================================" -ForegroundColor Green
