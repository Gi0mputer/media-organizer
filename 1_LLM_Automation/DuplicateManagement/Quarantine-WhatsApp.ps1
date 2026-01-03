param(
    [string]$CsvPath = "$env:USERPROFILE\Desktop\WA_Matches.csv",
    [string]$LocalQuarantineName = "_TO_CHECK_WA",
    [switch]$Execute = $false
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "=== WHATSAPP LOCAL QUARANTINE MOVER ===" -ForegroundColor Cyan
if (-not (Test-Path $CsvPath)) {
    Write-Host "[ERROR] CSV Report not found."
    exit
}

$matches = Import-Csv -Path $CsvPath
if ($matches.Count -eq 0) { Write-Host "No matches."; exit }

Write-Host "Loaded $($matches.Count) candidates. Grouping by folder..."
if ($Execute) { Write-Host "WARNING: EXECUTION MODE" -ForegroundColor Red }

# Optimize: Process file moves
foreach ($row in $matches) {
    $waFileName = $row.WhatsAppFile
    $folderPath = $row.Folder
    $fullPath = Join-Path $folderPath $waFileName
    
    if (Test-Path $fullPath) {
        # Create quarantine folder LOCALLY inside the source folder
        # e.g. D:\2021\Sardegna\_TO_CHECK_WA
        $quarantinePath = Join-Path $folderPath $LocalQuarantineName
        
        Write-Host "File: $waFileName"
        Write-Host "  -> Move to: $quarantinePath"
        
        if ($Execute) {
            if (-not (Test-Path $quarantinePath)) {
                New-Item -Path $quarantinePath -ItemType Directory -Force | Out-Null
            }
            
            # Check collision
            $destFile = Join-Path $quarantinePath $waFileName
            if (Test-Path $destFile) {
                Write-Host "    [SKIP] Already exists." -ForegroundColor Yellow
            } else {
                Move-Item -Path $fullPath -Destination $quarantinePath
                Write-Host "    [OK]" -ForegroundColor Green
            }
        }
    }
}
