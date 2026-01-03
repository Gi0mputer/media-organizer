param(
    [string[]]$RootPaths = @("D:\"),
    [switch]$Execute = $false
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "=== EMPTY FOLDER CLEANUP ===" -ForegroundColor Cyan
if ($Execute) { 
    Write-Host "WARNING: EXECUTION MODE - Empty folders will be DELETED!" -ForegroundColor Red 
}
else {
    Write-Host "INFO: PREVIEW MODE - No changes will be made." -ForegroundColor Yellow
}
Write-Host ""

$emptyFolders = @()

foreach ($root in $RootPaths) {
    if (-not (Test-Path $root)) { 
        Write-Host "Path not found: $root" -ForegroundColor Red
        continue 
    }
    
    Write-Host "Scanning: $root"
    
    # Get all directories, sorted by depth (deepest first)
    # This ensures we delete child empty folders before checking parents
    $allDirs = Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue
    $sortedDirs = $allDirs | Sort-Object { $_.FullName.Split('\').Count } -Descending
    
    foreach ($dir in $sortedDirs) {
        # Check if folder is empty (no files and no subdirectories)
        $children = Get-ChildItem -Path $dir.FullName -Force -ErrorAction SilentlyContinue
        
        if ($children.Count -eq 0) {
            $emptyFolders += $dir.FullName
            
            if ($Execute) {
                try {
                    Remove-Item -Path $dir.FullName -Force -ErrorAction Stop
                    Write-Host "  [DELETED] $($dir.FullName)" -ForegroundColor Green
                }
                catch {
                    Write-Host "  [ERROR] Could not delete: $($dir.FullName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "  [EMPTY] $($dir.FullName)" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total empty folders found: $($emptyFolders.Count)" -ForegroundColor Cyan

if (-not $Execute) {
    Write-Host ""
    Write-Host "To DELETE these folders, run with -Execute flag:" -ForegroundColor Yellow
    Write-Host "  .\Remove-EmptyFolders.ps1 -Execute" -ForegroundColor White
}
