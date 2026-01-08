# SETUP ADB LOCALMENTE
# Scarica e installa adb.exe nella cartella Tools del progetto

$toolsDir = "$PSScriptRoot\Tools\platform-tools"
$zipPath = "$PSScriptRoot\Tools\platform-tools.zip"
$url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

# Create Tools dir
if (-not (Test-Path "$PSScriptRoot\Tools")) { New-Item -ItemType Directory -Path "$PSScriptRoot\Tools" | Out-Null }

# Check i adb exists
if (Test-Path "$toolsDir\adb.exe") {
    Write-Host "ADB already installed at: $toolsDir\adb.exe" -ForegroundColor Green
    exit 0
}

Write-Host "Downloading ADB from Google..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $url -OutFile $zipPath
} catch {
    Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Extracting..." -ForegroundColor Cyan
Expand-Archive -Path $zipPath -DestinationPath "$PSScriptRoot\Tools" -Force

# Cleanup zip
Remove-Item $zipPath -Force

if (Test-Path "$toolsDir\adb.exe") {
    Write-Host "SUCCESS: ADB installed." -ForegroundColor Green
    & "$toolsDir\adb.exe" version
} else {
    Write-Host "ERROR: Extraction failed." -ForegroundColor Red
    exit 1
}
