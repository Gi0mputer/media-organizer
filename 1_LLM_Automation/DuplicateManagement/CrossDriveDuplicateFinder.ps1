param(
    [string[]]$SearchPaths = @("D:\", "E:\"),
    [string]$LogFile = (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "Analysis") ("CROSS_DRIVE_DUPLICATES_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss')))
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "=== CROSS-DRIVE DUPLICATE FINDER ===" -ForegroundColor Cyan
Write-Host "Scanning Paths: $($SearchPaths -join ', ')"

$allFiles = @()

foreach ($path in $SearchPaths) {
    if (Test-Path $path) {
        Write-Host "Scanning $path ..."
        # Only scan relevant media extensions to be faster
        $files = Get-ChildItem -Path $path -Recurse -File -Include "*.mp4", "*.mov", "*.jpg", "*.jpeg", "*.png", "*.heic" | Select-Object FullName, Length, Name
        $allFiles += $files
        Write-Host "  Found $($files.Count) media files."
    }
}

Write-Host "Total files to analyze: $($allFiles.Count)"
Write-Host "Grouping by Size..."

# Group by size first (fastest filter)
$sizeGroups = $allFiles | Group-Object Length | Where-Object { $_.Count -gt 1 }
Write-Host "Found $($sizeGroups.Count) potential duplicate groups (by size)."

$dupes = @()
$counter = 0

foreach ($group in $sizeGroups) {
    $counter++
    if ($counter % 100 -eq 0) { Write-Progress -Activity "Hashing Candidates" -Status "$counter / $($sizeGroups.Count)" -PercentComplete (($counter / $sizeGroups.Count) * 100) }
    
    # Hash check
    $hashGroup = $group.Group | Get-FileHash -Algorithm MD5 | Group-Object Hash | Where-Object { $_.Count -gt 1 }
    
    foreach ($h in $hashGroup) {
        $dupes += [PSCustomObject]@{
            Hash  = $h.Name
            Files = $h.Group.Path
            Count = $h.Group.Count
            Size  = $group.Group[0].Length
        }
    }
}

Write-Host ""
Write-Host "Confirmed Duplicates Groups: $($dupes.Count)"
$totalWasted = ($dupes | Measure-Object -Property Size -Sum).Sum / 1GB
Write-Host "Total Space Wasted (approx): $([math]::Round($totalWasted, 2)) GB" -ForegroundColor Red

# Generate Report
$report = @()
$report += "CROSS-DRIVE DUPLICATE REPORT"
$report += "Date: $(Get-Date)"
$report += "Total Wasted: $([math]::Round($totalWasted, 2)) GB"
$report += ""

foreach ($d in $dupes) {
    $report += "HASH: $($d.Hash) (Size: $([math]::Round($d.Size/1MB, 2)) MB)"
    foreach ($f in $d.Files) {
        $report += "  - $f"
    }
    $report += ""
}

$report | Out-File $LogFile -Encoding UTF8
Write-Host "Report saved to $LogFile" -ForegroundColor Green
