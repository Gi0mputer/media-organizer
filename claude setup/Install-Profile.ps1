# Install-Profile.ps1
# Copia la funzione 'work' nel profilo PowerShell del PC corrente.
# Esegui da PowerShell: .\Install-Profile.ps1

$src = Join-Path $PSScriptRoot "Microsoft.PowerShell_profile.ps1"
$dst = $PROFILE

$dstDir = Split-Path $dst -Parent
if (-not (Test-Path $dstDir)) {
    New-Item $dstDir -ItemType Directory -Force | Out-Null
}

Copy-Item $src $dst -Force
Write-Host "Installato in: $dst" -ForegroundColor Green
Write-Host "Riapri PowerShell per attivare il comando 'work'." -ForegroundColor DarkGray
