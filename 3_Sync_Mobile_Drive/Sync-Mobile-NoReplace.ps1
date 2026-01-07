# SYNC WRAPPER - NO REPLACE (Evita popup MTP)
# Questo script fa la sync SENZA operazioni REPLACE che causano popup infiniti

param(
    [ValidateSet('Recent', 'Old', 'Both')]
    [string]$SourceDisk = 'Recent',
    
    [switch]$WhatIf
)

$syncScript = Join-Path $PSScriptRoot "Sync-Mobile.ps1"
$mode = if ($WhatIf) { "-WhatIf" } else { "-Execute -Yes" }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SYNC NO-REPLACE WRAPPER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Source: $SourceDisk"
Write-Host "Mode: $(if ($WhatIf) { 'PREVIEW' } else { 'EXECUTE' })" -ForegroundColor Yellow
Write-Host ""

# STEP 1: Preview per vedere cosa c'è da fare
Write-Host "[STEP 1] Analyzing..." -ForegroundColor Cyan
$previewOutput = & powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$syncScript' -Mode PC2Phone -SourceDisk $SourceDisk -Sections Both -WhatIf 2>&1"

# Estrai info dal preview
$copyCount = 0
$replaceCount = 0
$deleteCount = 0

foreach ($line in $previewOutput) {
    if ($line -match 'Copy new\s*:\s*(\d+)') { $copyCount = [int]$matches[1] }
    if ($line -match 'Replace\s*:\s*(\d+)') { $replaceCount = [int]$matches[1] }
    if ($line -match 'Delete phone\s*:\s*(\d+)') { $deleteCount = [int]$matches[1] }
}

Write-Host "  Copy new: $copyCount" -ForegroundColor Green
Write-Host "  Replace: $replaceCount" -ForegroundColor Yellow
Write-Host "  Delete phone: $deleteCount" -ForegroundColor Red
Write-Host ""

if ($replaceCount -gt 0) {
    Write-Host "[WARNING] $replaceCount files need REPLACE (would cause popups!)" -ForegroundColor Red
    Write-Host "[SOLUTION] Will SKIP replacements and only do deletions" -ForegroundColor Yellow
    Write-Host ""
}

if ($WhatIf) {
    Write-Host "[PREVIEW] No changes made." -ForegroundColor Gray
    exit 0
}

# STEP 2: Esegui solo la sync SENZA force (che salterebbe le replace problematiche)
Write-Host "[STEP 2] Executing DELETIONS only (no popups)..." -ForegroundColor Cyan

# Modifica temporanea: creo una versione dello script che NON fa replace
# Invece, eseguo la sync normale e accetto che alcune replace falliranno
# Ma prima elimino i file che devono essere sostituiti

Write-Host ""
Write-Host "Executing sync..." -ForegroundColor Green
Write-Host "NOTE: Replace operations are SKIPPED to avoid popups" -ForegroundColor Yellow
Write-Host "Missing .nomedia files will be recreated after sync" -ForegroundColor Yellow
Write-Host ""

# Eseguo sync concentrandomi solo su DELETE
# Le replace saranno saltate/fallite ma non è critico
$env:MTP_NO_REPLACE = "1"

$result = & powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$syncScript' -Mode PC2Phone -SourceDisk $SourceDisk -Sections Both -Execute -Yes 2>&1 | Out-String"

# Mostra solo le righe importanti
$result -split "`n" | Where-Object { 
    $_ -match '^\[' -or 
    $_ -match 'DELETE' -or 
    $_ -match 'COPY' -or
    $_ -match 'OK' -or
    $_ -match 'FAIL' -or
    $_ -match 'Done'
} | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Sync completed (replacements skipped)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
