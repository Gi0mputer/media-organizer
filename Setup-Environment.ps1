# Setup-Environment.ps1
# Installa tutte le dipendenze del progetto media-organizer via winget.
# Eseguire una volta su ogni nuovo PC.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File "Setup-Environment.ps1"

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    [!!] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "    [XX] $msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. Verifica winget
# ---------------------------------------------------------------------------
Write-Step "Verifica winget..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Fail "winget non trovato. Installalo da: https://aka.ms/getwinget"
    exit 1
}
Write-OK "winget disponibile"

# ---------------------------------------------------------------------------
# 2. Pacchetti da installare
# ---------------------------------------------------------------------------
$packages = @(
    @{ Id = "OliverBetz.ExifTool";               Name = "ExifTool";           Check = "exiftool" },
    @{ Id = "Gyan.FFmpeg";                        Name = "FFmpeg";             Check = "ffmpeg"   },
    @{ Id = "WinFsp.WinFsp";                      Name = "WinFsp (per ifuse)"; Check = $null      },
    @{ Id = "libimobiledevice.libimobiledevice";  Name = "libimobiledevice";   Check = "ideviceinfo" }
)

# ---------------------------------------------------------------------------
# 3. Installazione
# ---------------------------------------------------------------------------
Write-Step "Installazione pacchetti..."

foreach ($pkg in $packages) {
    Write-Host "`n  -> $($pkg.Name) ($($pkg.Id))" -ForegroundColor White

    $installed = winget list --id $pkg.Id --exact 2>$null | Select-String $pkg.Id
    if ($installed) {
        Write-OK "Gia installato"
        continue
    }

    try {
        winget install --id $pkg.Id --exact --silent --accept-package-agreements --accept-source-agreements
        Write-OK "Installato"
    }
    catch {
        Write-Warn "Installazione via winget fallita: $_"
        Write-Warn "Installa manualmente: winget install $($pkg.Id)"
    }
}

# ---------------------------------------------------------------------------
# 4. Verifica tool in PATH
# ---------------------------------------------------------------------------
Write-Step "Verifica tool in PATH (potrebbe richiedere riapertura PowerShell)..."

$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH", "User")

$checks = @(
    @{ Cmd = "exiftool"    },
    @{ Cmd = "ffmpeg"      },
    @{ Cmd = "ffprobe"     },
    @{ Cmd = "ideviceinfo" }
)

$allOk = $true
foreach ($c in $checks) {
    if (Get-Command $c.Cmd -ErrorAction SilentlyContinue) {
        Write-OK "$($c.Cmd) trovato in PATH"
    } else {
        Write-Warn "$($c.Cmd) NON trovato in PATH - riapri PowerShell dopo l'installazione"
        $allOk = $false
    }
}

# ---------------------------------------------------------------------------
# 5. Config locale per-PC
# ---------------------------------------------------------------------------
Write-Step "Controllo pc_config.local.json..."

$configPath = Join-Path $PSScriptRoot "pc_config.local.json"
if (-not (Test-Path $configPath)) {
    $defaultConfig = @{
        RecentDrive = "E:\\"
        OldDrive    = "D:\\"
        PCLabel     = $env:COMPUTERNAME
    } | ConvertTo-Json -Depth 2

    Set-Content -Path $configPath -Value $defaultConfig -Encoding UTF8
    Write-OK "Creato pc_config.local.json con valori default - modificalo se i drive hanno lettere diverse"
} else {
    Write-OK "pc_config.local.json gia presente"
    $config = Get-Content $configPath | ConvertFrom-Json
    Write-Host "    RecentDrive: $($config.RecentDrive)" -ForegroundColor Gray
    Write-Host "    OldDrive:    $($config.OldDrive)" -ForegroundColor Gray
    Write-Host "    PCLabel:     $($config.PCLabel)" -ForegroundColor Gray
}

# ---------------------------------------------------------------------------
# 6. Riepilogo
# ---------------------------------------------------------------------------
Write-Host ""
if ($allOk) {
    Write-Host "==> Setup completato. Ambiente pronto." -ForegroundColor Green
} else {
    Write-Host "==> Setup completato con avvisi. Riapri PowerShell e ri-esegui per verificare." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Prossimi passi:" -ForegroundColor White
Write-Host "  1. Collega iPhone via USB"
Write-Host "  2. Sul telefono: consenti accesso e fidati del PC"
Write-Host "  3. Verifica pairing: idevicepair pair"
Write-Host "  4. Verifica connessione: ideviceinfo"
Write-Host ""
