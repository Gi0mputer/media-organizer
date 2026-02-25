# Delete all .trash files from E:\ and D:\

Write-Host "=== DELETING .TRASH FILES ON PC ===" -ForegroundColor Cyan

$drives = @("E:\", "D:\")
$totalDeleted = 0
$totalSize = 0

foreach ($drive in $drives) {
    if (-not (Test-Path $drive)) {
        Write-Host "`n$drive not available, skipping" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "`nScanning $drive..." -NoNewline
    
    $trashFiles = Get-ChildItem -Path $drive -Recurse -File -Filter "*.trash" -ErrorAction SilentlyContinue
    
    $count = ($trashFiles | Measure-Object).Count
    $size = ($trashFiles | Measure-Object -Property Length -Sum).Sum
    
    Write-Host " Found $count .trash files ($([math]::Round($size/1GB, 2)) GB)" -ForegroundColor Yellow
    
    if ($count -gt 0) {
        Write-Host "Deleting..." -NoNewline
        
        foreach ($file in $trashFiles) {
            try {
                Remove-Item $file.FullName -Force -ErrorAction Stop
                $totalDeleted++
                $totalSize += $file.Length
            }
            catch {
                Write-Host "`nError deleting: $($file.FullName)" -ForegroundColor Red
            }
        }
        
        Write-Host " Done!" -ForegroundColor Green
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "  Files deleted: $totalDeleted" -ForegroundColor Green
Write-Host "  Space freed: $([math]::Round($totalSize/1GB, 2)) GB" -ForegroundColor Green
