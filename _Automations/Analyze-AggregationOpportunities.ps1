param(
    [string[]]$RootPaths = @("E:\", "D:\"),
    [string]$ReportFile = "$PSScriptRoot\AGGREGATION_REPORT.md"
)

$ErrorActionPreference = 'SilentlyContinue'

function Get-FolderDateStats {
    param($Path)
    $files = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match "\.(mp4|mov|jpg|png|heic)$" }
    
    if (-not $files -or $files.Count -eq 0) { return $null }

    $min = [DateTime]::MaxValue
    $max = [DateTime]::MinValue
    $total = $files.Count
    
    foreach ($f in $files) {
        $d = $null
        if ($f.Name -match "20\d{2}[-_]?\d{2}[-_]?\d{2}") {
            try {
                $dstr = $matches[0] -replace "[-_]", ""
                $d = [DateTime]::ParseExact($dstr, "yyyyMMdd", $null)
            }
            catch {}
        }
        if (-not $d) { $d = $f.LastWriteTime }
        if ($d -lt $min) { $min = $d }
        if ($d -gt $max) { $max = $d }
    }

    return [PSCustomObject]@{
        Path     = $Path
        Name     = $Path | Split-Path -Leaf
        Parent   = ($Path | Split-Path -Parent) | Split-Path -Leaf
        Drive    = (Split-Path $Path -Qualifier)
        Count    = $total
        MinDate  = $min
        MaxDate  = $max
        SpanDays = ($max - $min).Days
    }
}

Write-Host "=== AGGREGATION ANALYSIS (CROSS-DRIVE) ===" -ForegroundColor Cyan

$AllEvents = @()
$Orphans = @()

foreach ($root in $RootPaths) {
    if (-not (Test-Path $root)) { continue }
    Write-Host "Scanning Root: $root" -ForegroundColor Cyan
    $YearFolders = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^(20\d{2}|19\d{2})" }
    
    foreach ($yf in $YearFolders) {
        $subfolders = Get-ChildItem $yf.FullName -Directory
        foreach ($sub in $subfolders) {
            $potentialOrphans = Get-ChildItem $sub.FullName -Directory | Where-Object { $_.Name -match "^\d{4}$" }
            foreach ($p in $potentialOrphans) {
                $stats = Get-FolderDateStats $p.FullName
                if ($stats) {
                    $Orphans += [PSCustomObject]@{
                        Path               = $p.FullName
                        HostFolder         = $sub.Name
                        CurrentYearContext = $yf.Name
                        TargetYear         = $p.Name
                        StatCount          = $stats.Count
                    }
                }
            }
            $stats = Get-FolderDateStats $sub.FullName
            if ($stats) { $AllEvents += $stats }
        }
    }
}

Write-Host "`nFound $($AllEvents.Count) event folders total."

# 2. MATCHING LOGIC
$Matches = @()
$SortedEvents = $AllEvents | Sort-Object MinDate

for ($i = 0; $i -lt $SortedEvents.Count - 1; $i++) {
    $current = $SortedEvents[$i]
    for ($j = $i + 1; $j -lt $SortedEvents.Count; $j++) {
        $next = $SortedEvents[$j]
        if (($next.MinDate - $current.MaxDate).TotalDays -gt 10) { break }
        
        $overlap = ($current.MaxDate -ge $next.MinDate)
        if ($overlap) {
            $nameSim = 0
            if ($current.Name -eq $next.Name) { $nameSim = 100 }
            elseif ($current.Name.Replace(" ", "").ToLower() -eq $next.Name.Replace(" ", "").ToLower()) { $nameSim = 95 }
            elseif ($current.Name.StartsWith($next.Name) -or $next.Name.StartsWith($current.Name)) { $nameSim = 80 }
            
            $bothShort = ($current.SpanDays -lt 7 -and $next.SpanDays -lt 7)

            if ($nameSim -gt 50 -or $bothShort) {
                # FILTER: Don't match Parent with Child (e.g. Folder vs Folder\2021)
                if ($current.Path.StartsWith($next.Path) -or $next.Path.StartsWith($current.Path)) { continue }

                $Matches += [PSCustomObject]@{
                    Info       = "[$($current.Drive)] vs [$($next.Drive)]"
                    FolderA    = "$($current.Parent)\$($current.Name)"
                    FolderB    = "$($next.Parent)\$($next.Name)"
                    DateRangeA = "$($current.MinDate.ToString('yyyy-MM-dd'))"
                    DateRangeB = "$($next.MinDate.ToString('yyyy-MM-dd'))"
                    Reason     = if ($nameSim -gt 50) { "Similar Name ($nameSim%)" } else { "Overlapping Time" }
                }
            }
        }
    }
}

# 3. REPORT
$rpt = @()
$rpt += "# 🧩 ANALYSIS: AGGREGATION & CLEANUP (CROSS-DRIVE)"
$rpt += "Roots Scanned: $($RootPaths -join ', ')"
$rpt += ""
$rpt += "## 1️⃣ ORPHAN FOLDERS (Nested Year Folders)"
if ($Orphans.Count -eq 0) { $rpt += "_No orphans found._" }
else {
    $rpt += "| Current Location | Target Year | Files | Action Needed |"
    $rpt += "|------------------|-------------|-------|---------------|"
    foreach ($o in $Orphans) {
        $rpt += "| `$($o.Path)` | **$($o.TargetYear)** | $($o.StatCount) | Move to `E:\$($o.TargetYear)\$($o.HostFolder)` |"
    }
}

$rpt += ""
$rpt += "## 2️⃣ MATCHING EVENTS (Possible Duplicates/Splits)"
if ($Matches.Count -eq 0) { $rpt += "_No aggregation candidates found._" }
else {
    $rpt += "| Drives | Folder A | Folder B | Dates (Start) | Reason |"
    $rpt += "|--------|----------|----------|---------------|--------|"
    foreach ($m in $Matches) {
        $rpt += "| $($m.Info) | `$($m.FolderA)` | `$($m.FolderB)` | $($m.DateRangeA) / $($m.DateRangeB) | $($m.Reason) |"
    }
}

$rpt | Out-File $ReportFile -Encoding UTF8
Write-Host "Report generated: $ReportFile" -ForegroundColor Green
