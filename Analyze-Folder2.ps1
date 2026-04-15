param([string]$folderPath)

$folderName = Split-Path $folderPath -Leaf
$prefix = $folderName -replace '^(2025|20\d\d)', ''
if (-not $prefix) { $prefix = $folderName }

Add-Content -Path F:\2025\Result.txt -Value "`n==============================================="
Add-Content -Path F:\2025\Result.txt -Value "ANALYZING: $folderName"
Add-Content -Path F:\2025\Result.txt -Value "==============================================="

$files = Get-ChildItem -Path $folderPath -File -Recurse | Where-Object { $_.Name -match "\.(jpg|jpeg|mp4|mov)$" }

$fileData = @()

foreach ($file in $files) {
    $targetDate = $null
    
    if ($file.Name -match "(IMG|VID|PXL|20\d\d)[_-]?(\d{8})[_-]?") {
        $dateStr = $matches[2]
        if ($file.Name -match "PXL_\d{8}_(\d{6})") {
            try { $targetDate = [datetime]::ParseExact("$dateStr $($matches[1])", "yyyyMMdd HHmmss", $null) } catch {}
        } elseif ($file.Name -match "20\d\d(\d{4})_(\d{6})") {
            try { $targetDate = [datetime]::ParseExact("$dateStr $($matches[2])", "yyyyMMdd HHmmss", $null) } catch {}
        } else {
            try { $targetDate = [datetime]::ParseExact("$dateStr 120000", "yyyyMMdd HHmmss", $null) } catch {}
        }
    }
    
    if (-not $targetDate) {
        $targetDate = $file.CreationTime
    }
    
    $fileData += [PSCustomObject]@{
        FileInfo = $file
        ComputedDate = $targetDate
        Day = $targetDate.Date
    }
}

if ($fileData.Count -eq 0) {
    Add-Content -Path F:\2025\Result.txt -Value "No media files found."
    exit
}

$days = $fileData.Day | Sort-Object
$medianDay = $days[$days.Count / 2]

$coreFiles = @()
$outliers = @()

foreach ($fd in $fileData) {
    $diff = ($fd.Day - $medianDay).TotalDays
    if ([math]::Abs($diff) -le 15) {
        $coreFiles += $fd
    } else {
        $outliers += $fd
    }
}

$coreFiles = $coreFiles | Sort-Object ComputedDate
$maxCoreDate = if ($coreFiles) { ($coreFiles[-1]).ComputedDate } else { [datetime]::Now }

$outlierCounter = 1
$finalActions = @()

foreach ($fd in $coreFiles) {
    $finalActions += [PSCustomObject]@{
        OldFile = $fd.FileInfo.FullName
        Name = $fd.FileInfo.Name
        IsDirPC = ($fd.FileInfo.DirectoryName -match "_pc$")
        NewDate = $fd.ComputedDate
        IsOutlier = $false
    }
}

foreach ($fd in $outliers) {
    $clampedDate = $maxCoreDate.AddSeconds($outlierCounter)
    $outlierCounter++
    
    $finalActions += [PSCustomObject]@{
        OldFile = $fd.FileInfo.FullName
        Name = $fd.FileInfo.Name
        IsDirPC = ($fd.FileInfo.DirectoryName -match "_pc$")
        NewDate = $clampedDate
        IsOutlier = $true
        OriginalDate = $fd.ComputedDate
    }
}

$finalActions = $finalActions | Sort-Object NewDate

Write-Host "TOTAL FILES: $($finalActions.Count)"
Write-Host "OUTLIERS: $($outliers.Count)"
Write-Host "CORE RANGE: $($coreFiles[0].ComputedDate) TO $maxCoreDate"

Write-Host "`n[ OUTLIER ACTIONS ]"
foreach ($fa in $finalActions | Where-Object IsOutlier) {
    Write-Host "OUTLIER: $($fa.Name) (Orig: $($fa.OriginalDate.ToString('yyyy-MM-dd'))) -> Clamped to $($fa.NewDate.ToString('yyyy-MM-dd HH:mm:ss'))"
}
