# Force delete all remaining folders in Pictures (empty or not)

$picturesPath = "E:\_telefono_backup\Pictures"

Write-Host "=== CLEANING REMAINING PICTURES FOLDERS ===" -ForegroundColor Cyan

if (Test-Path $picturesPath) {
    $folders = Get-ChildItem -Path $picturesPath -Directory -ErrorAction SilentlyContinue
    
    Write-Host "`nFound $($folders.Count) folders in Pictures" -ForegroundColor Yellow
    
    foreach ($folder in $folders) {
        $fileCount = (Get-ChildItem $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        
        Write-Host "`n$($folder.Name) - $fileCount files" -ForegroundColor Gray
        
        if ($fileCount -eq 0) {
            Write-Host "  DELETING (empty)..." -NoNewline
            try {
                Remove-Item $folder.FullName -Recurse -Force -ErrorAction Stop
                Write-Host " OK" -ForegroundColor Green
            }
            catch {
                Write-Host " FAILED" -ForegroundColor Red
            }
        }
        else {
            Write-Host "  KEEPING (has $fileCount files)" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "Pictures folder not found" -ForegroundColor Red
}

Write-Host "`n=== DONE ===" -ForegroundColor Cyan
