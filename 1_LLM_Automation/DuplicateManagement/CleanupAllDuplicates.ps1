$folders = @(
    @{Path = "D:\2023"; Expected = "11.77 GB" },
    @{Path = "D:\2022"; Expected = "1.41 GB" },
    @{Path = "E:\2024"; Expected = "1.18 GB" },
    @{Path = "D:\2019"; Expected = "0.48 GB" },
    @{Path = "D:\2018 e pre"; Expected = "0.17 GB" },
    @{Path = "E:\2025"; Expected = "0.07 GB" },
    @{Path = "D:\2020"; Expected = "0.003 GB" }
)

$scriptPath = Join-Path $PSScriptRoot "SmartDuplicateFinder.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FULL DUPLICATE CLEANUP - DELETE MODE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "WARNING: This will MOVE duplicate files to the Recycle Bin!" -ForegroundColor Red
Write-Host "NOTE: Disk space is freed only after emptying the Recycle Bin." -ForegroundColor Yellow
Write-Host "Estimated recovery (after empty): ~15.5 GB" -ForegroundColor Yellow
Write-Host ""

$totalDeleted = 0
$totalSpaceFreed = 0

foreach ($folder in $folders) {
    $path = $folder.Path
    $expected = $folder.Expected
    
    if (-not (Test-Path $path)) {
        Write-Host "[SKIP] $path - not found" -ForegroundColor Gray
        continue
    }
    
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "Cleaning: $path" -ForegroundColor Yellow
    Write-Host "Expected: $expected" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -SourcePath $path -Delete -Force 2>&1 | Out-String
    
    # Parse results
    if ($output -match "Duplicates found: (\d+)") {
        $deleted = [int]$Matches[1]
        $totalDeleted += $deleted
    }
    
    if ($output -match "Potential space savings: ([\d.]+) MB") {
        $spaceMB = [double]$Matches[1]
        $totalSpaceFreed += $spaceMB
    }
    
    Write-Host "[DONE] $path" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "CLEANUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Total files deleted: $totalDeleted" -ForegroundColor Yellow
Write-Host "Total space freed: $([math]::Round($totalSpaceFreed / 1024, 2)) GB" -ForegroundColor Yellow
Write-Host ""
Write-Host "Verifying final drive status..." -ForegroundColor Cyan

# Show final drive status
Get-PSDrive D, E | Format-Table Name, @{N = 'Used(GB)'; E = { [math]::Round($_.Used / 1GB, 2) } }, @{N = 'Free(GB)'; E = { [math]::Round($_.Free / 1GB, 2) } }, @{N = 'Total(GB)'; E = { [math]::Round(($_.Used + $_.Free) / 1GB, 2) } } -AutoSize
