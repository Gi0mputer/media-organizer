# ============================================================================
# NOME: Analyze-MediaArchive.ps1
# DESCRIZIONE: Genera un report completo sullo stato dell'archivio media.
#
# DETTAGLI:
#   - Analizza distribuzione estensioni, dimensioni top folder e file outlier.
#   - Supporta analisi su due dischi (Recent/Old).
#   - Output: Report Markdown dettagliato.
# ============================================================================

param(
    [string]$RecentPath = "E:\",
    [string]$OldPath = "D:\",
    [string]$OutputPath = (Join-Path $PSScriptRoot ("MEDIA_ARCHIVE_ANALYSIS_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss')))
)

Write-Host "=== MEDIA ARCHIVE ANALYSIS ===" -ForegroundColor Cyan
Write-Host "Recent SSD: $RecentPath"
Write-Host "Old SSD: $OldPath"
Write-Host ""

$report = @(
    "# Media Archive Analysis"
    ""
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    ""
    "- Recent SSD: ``$RecentPath``"
    "- Old SSD: ``$OldPath``"
    ""
)

# Video extensions
$videoExts = @('.mp4', '.mov', '.avi', '.mkv', '.insv', '.m4v', '.wmv', '.flv', '.webm', '.mpg', '.mpeg')
$photoExts = @('.jpg', '.jpeg', '.png', '.heic', '.raw', '.cr2', '.nef', '.dng', '.arw', '.gif', '.bmp', '.tiff')

function Get-RelPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$FullName
    )
    $r = $Root.TrimEnd('\')
    if ($FullName.StartsWith($r, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $FullName.Substring($r.Length).TrimStart('\')
    }
    return $FullName
}

function Analyze-Drive {
    param($Path, $Name)
    
    Write-Host "`n[ANALYZING: $Name]" -ForegroundColor Yellow
    $localReport = @()
    $localReport += "## Drive: $Name (`$Path`)"
    $localReport += ""

    if (-not (Test-Path -LiteralPath $Path)) {
        $localReport += "> [SKIP] Path not found."
        $localReport += ""
        return $localReport
    }
    
    # Get all files
    Write-Host "  Scanning files..." -ForegroundColor Gray
    $allFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
    
    $totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum / 1GB
    $totalCount = $allFiles.Count
    
    $localReport += "### Overall"
    $localReport += ""
    $localReport += "- Total files: **$totalCount**"
    $localReport += "- Total size: **$([math]::Round($totalSize, 2)) GB**"
    
    # Video analysis
    Write-Host "  Analyzing videos..." -ForegroundColor Gray
    $videos = $allFiles | Where-Object { $videoExts -contains $_.Extension.ToLower() }
    $videosByExt = $videos | Group-Object Extension | Sort-Object Count -Descending
    
    $localReport += ""
    $localReport += "### Video Files"
    $localReport += ""
    $localReport += "- Total videos: **$($videos.Count)**"
    $localReport += "- Total size: **$([math]::Round(($videos | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) GB**"
    $localReport += ""
    $localReport += "**By extension**"
    foreach ($ext in $videosByExt) {
        $size = [math]::Round(($ext.Group | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
        $localReport += "- $($ext.Name): $($ext.Count) files, $size GB"
    }
    
    # .insv analysis (360 files - outliers)
    $insvFiles = $videos | Where-Object { $_.Extension.ToLower() -eq '.insv' }
    if ($insvFiles.Count -gt 0) {
        $localReport += ""
        $localReport += "**360 files (.insv)**"
        $localReport += "- Count: $($insvFiles.Count)"
        $localReport += "- Size: $([math]::Round(($insvFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) GB"
    }
    
    # Photo analysis
    Write-Host "  Analyzing photos..." -ForegroundColor Gray
    $photos = $allFiles | Where-Object { $photoExts -contains $_.Extension.ToLower() }
    $photosByExt = $photos | Group-Object Extension | Sort-Object Count -Descending
    
    $localReport += ""
    $localReport += "### Photo Files"
    $localReport += ""
    $localReport += "- Total photos: **$($photos.Count)**"
    $localReport += "- Total size: **$([math]::Round(($photos | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) GB**"
    $localReport += ""
    $localReport += "**By extension (top 10)**"
    foreach ($ext in $photosByExt | Select-Object -First 10) {
        $size = [math]::Round(($ext.Group | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
        $localReport += "- $($ext.Name): $($ext.Count) files, $size GB"
    }
    
    # All extensions (top by count)
    $extStats = $allFiles | Group-Object Extension | ForEach-Object {
        $extName = if ($_.Name) { $_.Name.ToLower() } else { "(none)" }
        [PSCustomObject]@{
            Ext    = $extName
            Count  = $_.Count
            SizeGB = [math]::Round(($_.Group | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
        }
    } | Sort-Object Count -Descending

    $localReport += ""
    $localReport += "### Top Extensions (by count)"
    $localReport += ""
    $localReport += "| Ext | Count | Size (GB) |"
    $localReport += "|-----|------:|----------:|"
    foreach ($e in ($extStats | Select-Object -First 20)) {
        $localReport += "| $($e.Ext) | $($e.Count) | $($e.SizeGB) |"
    }

    # Top 20 largest files
    Write-Host "  Finding largest files..." -ForegroundColor Gray
    $largest = $allFiles | Sort-Object Length -Descending | Select-Object -First 20
    
    $localReport += ""
    $localReport += "### Top 20 Largest Files"
    $localReport += ""
    $localReport += "| Size (MB) | Path |"
    $localReport += "|----------:|------|"
    foreach ($file in $largest) {
        $sizeMB = [math]::Round($file.Length / 1MB, 2)
        $relPath = Get-RelPath -Root $Path -FullName $file.FullName
        $localReport += "| $sizeMB | ``$relPath`` |"
    }
    
    # Folder analysis by year
    Write-Host "  Analyzing folders by year..." -ForegroundColor Gray
    $rootNorm = $Path.TrimEnd('\')
    $topFolders = $allFiles | ForEach-Object {
        $rel = $_.FullName.Substring($rootNorm.Length).TrimStart('\')
        $top = ($rel -split '\\')[0]
        [PSCustomObject]@{
            Top    = $top
            Ext    = $_.Extension.ToLower()
            Length = $_.Length
        }
    } | Group-Object Top | ForEach-Object {
        [PSCustomObject]@{
            Name   = $_.Name
            Files  = $_.Count
            SizeGB = [math]::Round(($_.Group | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
            Videos = ($_.Group | Where-Object { $videoExts -contains $_.Ext }).Count
            Photos = ($_.Group | Where-Object { $photoExts -contains $_.Ext }).Count
        }
    } | Sort-Object Name

    $yearFolders = $topFolders | Where-Object { $_.Name -match '^(19|20)\d{2}(\s+e\s+pre)?$' }
    $otherTopFolders = $topFolders | Where-Object { $_.Name -and ($_.Name -notmatch '^(19|20)\d{2}(\s+e\s+pre)?$') }

    $localReport += ""
    $localReport += "### Top-Level Year Folders"
    $localReport += ""
    $localReport += "| Folder | Files | Size (GB) | Videos | Photos |"
    $localReport += "|--------|------:|----------:|-------:|-------:|"
    foreach ($folder in $yearFolders) {
        $localReport += "| $($folder.Name) | $($folder.Files) | $($folder.SizeGB) | $($folder.Videos) | $($folder.Photos) |"
    }

    if ($otherTopFolders.Count -gt 0) {
        $localReport += ""
        $localReport += "### Top-Level Non-Year Folders"
        $localReport += ""
        $localReport += "| Folder | Files | Size (GB) | Videos | Photos |"
        $localReport += "|--------|------:|----------:|-------:|-------:|"
        foreach ($folder in ($otherTopFolders | Sort-Object SizeGB -Descending | Select-Object -First 15)) {
            $localReport += "| $($folder.Name) | $($folder.Files) | $($folder.SizeGB) | $($folder.Videos) | $($folder.Photos) |"
        }
    }
    
    # Mobile subset (files inside any Mobile\ folder)
    $mobileFiles = $allFiles | Where-Object { $_.FullName -match '(?i)\\Mobile\\' }
    $mobileSizeGB = [math]::Round(($mobileFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
    $localReport += ""
    $localReport += "### Mobile Subset (`Mobile\\`)"
    $localReport += ""
    $localReport += "- Files in any ``Mobile\\`` folder: **$($mobileFiles.Count)**"
    $localReport += "- Total size: **$mobileSizeGB GB**"
    
    Write-Host "  Done!" -ForegroundColor Green
    $localReport += ""
    return $localReport
}

# Analyze both drives
$report += Analyze-Drive -Path $RecentPath -Name "RECENT"
$report += Analyze-Drive -Path $OldPath -Name "OLD"

# Save report
$report | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "`n=== ANALYSIS COMPLETE ===" -ForegroundColor Green
Write-Host "Report saved to: $OutputPath" -ForegroundColor Cyan
Write-Host ""

# Display summary
Write-Host "`nQUICK SUMMARY:" -ForegroundColor Yellow
$report | Select-String -Pattern "^- Total files:|^- Total size:|^- Total videos:|^- Total photos:" | ForEach-Object { Write-Host "  $_" }
