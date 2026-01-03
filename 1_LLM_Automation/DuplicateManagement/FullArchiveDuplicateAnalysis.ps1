param(
    [string[]]$Targets = @(
        "D:\2025",
        "D:\Insta360x4",
        "D:\2024",
        "D:\2023",
        "D:\2022",
        "E:\2018 e pre",
        "E:\2019",
        "E:\2020",
        "E:\2021",
        "E:\2022",
        "E:\2023"
    ),
    [string]$ConsolidatedReport = "$env:USERPROFILE\Desktop\FullDuplicateAnalysis.txt"
)

$scriptPath = Join-Path $PSScriptRoot "SmartDuplicateFinder.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FULL ARCHIVE DRY-RUN ANALYSIS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$totalDuplicates = 0
$totalSpaceSavings = 0
$results = @()

foreach ($target in $Targets) {
    if (-not (Test-Path $target)) {
        Write-Host "[SKIP] $target - not found" -ForegroundColor Gray
        continue
    }
    
    Write-Host "`n>>> Analyzing: $target" -ForegroundColor Yellow
    $tempReport = "$env:TEMP\dup_$(Split-Path $target -Leaf)_$([guid]::NewGuid().ToString().Substring(0,8)).txt"
    
    # Run the duplicate finder and capture output
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -SourcePath $target -LogFile $tempReport 2>&1 | Out-String
    
    # Wait for file to be fully written
    Start-Sleep -Milliseconds 500
    
    # Parse from output first (more reliable)
    $dupes = 0
    $space = 0
    
    if ($output -match "Duplicates found: (\d+)") {
        $dupes = [int]$Matches[1]
        $totalDuplicates += $dupes
    }
    
    if ($output -match "Potential space savings: ([\d.]+) MB") {
        $space = [double]$Matches[1]
        $totalSpaceSavings += $space
    }
    
    # Fallback: try reading from file if output parsing failed
    if ($dupes -eq 0 -and $space -eq 0 -and (Test-Path $tempReport)) {
        $content = Get-Content $tempReport -Raw -ErrorAction SilentlyContinue
        
        if ($content -match "Duplicates found: (\d+)") {
            $dupes = [int]$Matches[1]
            $totalDuplicates += $dupes
        }
        
        if ($content -match "Potential space savings: ([\d.]+) MB") {
            $space = [double]$Matches[1]
            $totalSpaceSavings += $space
        }
    }
    
    $results += [PSCustomObject]@{
        Folder     = $target
        Duplicates = $dupes
        SpaceMB    = $space
        SpaceGB    = [math]::Round($space / 1024, 2)
    }
    
    Write-Host "  Found: $dupes duplicates, $([math]::Round($space/1024, 2)) GB" -ForegroundColor $(if ($dupes -gt 0) { 'Red' } else { 'Green' })
}

# Create consolidated report
$report = @()
$report += "=" * 80
$report += "FULL ARCHIVE DUPLICATE ANALYSIS - DRY RUN"
$report += "Generated: $(Get-Date)"
$report += "=" * 80
$report += ""
$report += "SUMMARY BY FOLDER"
$report += "-" * 80
$report += "{0,-30} {1,12} {2,15}" -f "Folder", "Duplicates", "Space (GB)"
$report += "-" * 80

foreach ($result in $results | Sort-Object SpaceMB -Descending) {
    $report += "{0,-30} {1,12} {2,15}" -f $result.Folder, $result.Duplicates, $result.SpaceGB
}

$report += "-" * 80
$report += "{0,-30} {1,12} {2,15}" -f "TOTAL", $totalDuplicates, ([math]::Round($totalSpaceSavings / 1024, 2))
$report += "=" * 80
$report += ""
$report += "RECOMMENDATION:"
if ($totalDuplicates -gt 0) {
    $report += "Found $totalDuplicates duplicate files across all folders."
    $report += "Potential space savings: $([math]::Round($totalSpaceSavings / 1024, 2)) GB"
    $report += ""
    $report += "To proceed with deletion, run:"
    $report += "  SmartDuplicateFinder.ps1 -SourcePath '<folder>' -Delete"
}
else {
    $report += "No duplicates found. Archive is clean!"
}

$report | Out-File -FilePath $ConsolidatedReport -Encoding UTF8

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "ANALYSIS COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Total Duplicates: $totalDuplicates" -ForegroundColor Yellow
Write-Host "Total Space Savings: $([math]::Round($totalSpaceSavings / 1024, 2)) GB" -ForegroundColor Yellow
Write-Host ""
Write-Host "Consolidated report: $ConsolidatedReport" -ForegroundColor Cyan
Write-Host ""

# Display summary table
Write-Host "SUMMARY:" -ForegroundColor Cyan
$results | Sort-Object SpaceMB -Descending | Format-Table Folder, Duplicates, @{N = 'SpaceGB'; E = { $_.SpaceGB }; F = 'N2' } -AutoSize
