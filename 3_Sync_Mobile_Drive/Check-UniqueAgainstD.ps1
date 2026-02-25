# Check unique files against D:\ to eliminate false positives

Write-Host "Checking unique files against D:\..." -ForegroundColor Yellow

# Load previous report
$report = Get-Content "$PSScriptRoot\phone_comparison_report.json" | ConvertFrom-Json

# Scan D:\
Write-Host "Scanning D:\..." -NoNewline
$pcFilesD = @{}
$pcItemsD = Get-ChildItem -Path "D:\" -Recurse -File -ErrorAction SilentlyContinue | 
Where-Object { $_.FullName -notmatch '\\_trash\\' }

foreach ($f in $pcItemsD) {
    $key = "$($f.Name)|$($f.Length)"
    if (-not $pcFilesD.ContainsKey($key)) {
        $pcFilesD[$key] = @()
    }
    $pcFilesD[$key] += $f.FullName
}
Write-Host " Found $($pcFilesD.Count) unique files on D:\" -ForegroundColor Green

# Cross-check unique files
$stillUnique = @()
$foundOnD = @()

foreach ($u in $report.UniquePhone) {
    $key = "$($u.Name)|$($u.Size)"
    
    if ($pcFilesD.ContainsKey($key)) {
        # File is on D:\
        $foundOnD += [pscustomobject]@{
            PhonePath = $u.PhonePath
            PCPath    = $pcFilesD[$key][0]
            Name      = $u.Name
            Size      = $u.Size
        }
    }
    else {
        # Still unique (not on E:\ AND not on D:\)
        $stillUnique += $u
    }
}

Write-Host "`nRESULTS:" -ForegroundColor Yellow
Write-Host "  Found on D:\ (can delete from phone): $($foundOnD.Count)" -ForegroundColor Green
Write-Host "  Still unique (need to save): $($stillUnique.Count)" -ForegroundColor Red

$spaceOnD = ($foundOnD | Measure-Object -Property Size -Sum).Sum / 1GB
Write-Host "`nAdditional space to free (files on D:\): $([math]::Round($spaceOnD, 2)) GB" -ForegroundColor Cyan

# Update report
$finalReport = @{
    Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    SafeToDelete = @{
        OnE = $report.Identical
        OnD = $foundOnD
    }
    TruelyUnique = $stillUnique
    Summary      = @{
        SafeToDeleteCount  = $report.Identical.Count + $foundOnD.Count
        UniqueCount        = $stillUnique.Count
        TotalSpaceToFreeGB = [math]::Round(($report.Summary.SpaceToFreeGB + $spaceOnD), 2)
    }
}

$finalReport | ConvertTo-Json -Depth 5 | Set-Content "$PSScriptRoot\phone_final_report.json"
Write-Host "`nFinal report saved: phone_final_report.json" -ForegroundColor Gray

# Show samples
Write-Host "`n=== SAMPLE FILES FOUND ON D:\ (First 10) ===" -ForegroundColor Cyan
$foundOnD | Select-Object -First 10 | Format-Table -AutoSize PhonePath, Name

Write-Host "`n=== TRULY UNIQUE FILES (First 10) ===" -ForegroundColor Yellow
$stillUnique | Select-Object -First 10 | Format-Table -AutoSize PhonePath, Name, Size
