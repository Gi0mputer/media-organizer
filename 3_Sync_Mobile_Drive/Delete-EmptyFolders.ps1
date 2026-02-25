# Delete empty folders from backup and drives

Write-Host "=== DELETING EMPTY FOLDERS ===" -ForegroundColor Cyan

$paths = @(
    "E:\_telefono_backup"
    "E:\"
    "D:\"
)

$totalDeleted = 0

foreach ($path in $paths) {
    if (-not (Test-Path $path)) { 
        Write-Host "`n$path not available, skipping" -ForegroundColor Gray
        continue 
    }
    
    Write-Host "`nScanning $path..." -ForegroundColor Yellow
    
    # Find empty directories (multiple passes to handle nested empties)
    $pass = 1
    $deletedThisPath = 0
    
    do {
        $emptyDirs = Get-ChildItem -Path $path -Recurse -Directory -ErrorAction SilentlyContinue | 
        Where-Object { 
            (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0 
        }
        
        if ($emptyDirs) {
            Write-Host "  Pass $pass : Found $($emptyDirs.Count) empty folders" -ForegroundColor Gray
            
            foreach ($dir in $emptyDirs) {
                try {
                    Remove-Item $dir.FullName -Force -ErrorAction Stop
                    $deletedThisPath++
                    $totalDeleted++
                    Write-Host "    DELETED: $($dir.FullName)" -ForegroundColor DarkGray
                }
                catch {
                    Write-Host "    ERROR: $($dir.FullName)" -ForegroundColor Red
                }
            }
            
            $pass++
        }
        
    } while ($emptyDirs -and $pass -le 5)
    
    Write-Host "  Deleted from $path : $deletedThisPath folders" -ForegroundColor Green
}

Write-Host "`n=== CLEANUP COMPLETE ===" -ForegroundColor Cyan
Write-Host "Total empty folders deleted: $totalDeleted" -ForegroundColor Green
