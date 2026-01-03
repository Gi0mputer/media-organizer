param(
    [string]$Root,
    [string]$ExifToolPath
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "Analyzing folder: $Root"
if (-not (Test-Path -LiteralPath $Root)) {
    Write-Host "[ERROR] Invalid folder."
    exit 1
}

if ($ExifToolPath -and (Test-Path -LiteralPath $ExifToolPath)) {
    Write-Host "ExifTool: $ExifToolPath"
} else {
    Write-Host "ExifTool: (missing)"
    $ExifToolPath = $null
}
Write-Host ""

# == EXIFTOOL BRANCH ==
if ($ExifToolPath) {
    $csv = & $ExifToolPath -q -q -api QuickTimeUTC=1 -csv -r -d "%Y-%m-%dT%H:%M:%S" `
        -FilePath -FileType -FileSize# `
        -EXIF:DateTimeOriginal -EXIF:CreateDate -EXIF:ModifyDate `
        -QuickTime:CreateDate -QuickTime:ModifyDate -QuickTime:TrackCreateDate -QuickTime:TrackModifyDate -QuickTime:MediaCreateDate -QuickTime:MediaModifyDate -Keys:CreationDate `
        -CreationTime `
        -FileCreateDate -FileModifyDate `
        -- "$Root"
    $rows = $csv | ConvertFrom-Csv
} else {
    # == NO EXIFTOOL BRANCH: Filesystem only ==
    $rows = Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
        [pscustomobject]@{
            FilePath = $_.FullName
            FileType = $_.Extension.ToLower()
            'FileSize#' = $_.Length
            'EXIF:DateTimeOriginal' = ''
            'EXIF:CreateDate' = ''
            'EXIF:ModifyDate' = ''
            'QuickTime:CreateDate' = ''
            'QuickTime:ModifyDate' = ''
            'QuickTime:TrackCreateDate' = ''
            'QuickTime:TrackModifyDate' = ''
            'QuickTime:MediaCreateDate' = ''
            'QuickTime:MediaModifyDate' = ''
            'Keys:CreationDate' = ''
            CreationTime = ''
            FileCreateDate = $_.CreationTime.ToString('s')
            FileModifyDate = $_.LastWriteTime.ToString('s')
        }
    }
}

$total = ($rows | Measure-Object).Count
Write-Host ("Total files: {0}" -f $total)
if ($total -eq 0) { exit 0 }
Write-Host ""

# -- Extension from path --
$rows = $rows | ForEach-Object {
    $_ | Add-Member -PassThru NoteProperty Ext ([System.IO.Path]::GetExtension($_.FilePath).ToLower())
}

$byExt = $rows | Group-Object Ext | Sort-Object Count -Descending
Write-Host "== Top Extensions =="
$byExt | Select-Object -First 12 | ForEach-Object { "{0,6}  {1}" -f $_.Count, (if ($_.Name) { $_.Name } else { '(empty)' }) } | ForEach-Object { Write-Host $_ }
Write-Host ""

function Pick-Date($r) {
    $cands = @(
        $r.'EXIF:DateTimeOriginal',
        $r.'QuickTime:CreateDate',
        $r.'QuickTime:MediaCreateDate',
        $r.'EXIF:CreateDate',
        $r.'CreationTime',
        $r.'FileCreateDate',
        $r.'FileModifyDate'
    ) | Where-Object { $_ -and $_.Trim() -ne '' }
    foreach ($d in $cands) { try { return [datetime]$d } catch {} }
    return $null
}

$aug = $rows | ForEach-Object {
    $best = Pick-Date $_
    $src = ''
    if ($best) {
        if ($_.'EXIF:DateTimeOriginal' -and $best -eq [datetime]$_.'EXIF:DateTimeOriginal') { $src = 'EXIF:DateTimeOriginal' }
        elseif ($_.'QuickTime:CreateDate' -and $best -eq [datetime]$_.'QuickTime:CreateDate') { $src = 'QuickTime:CreateDate' }
        elseif ($_.'QuickTime:MediaCreateDate' -and $best -eq [datetime]$_.'QuickTime:MediaCreateDate') { $src = 'QuickTime:MediaCreateDate' }
        elseif ($_.'EXIF:CreateDate' -and $best -eq [datetime]$_.'EXIF:CreateDate') { $src = 'EXIF:CreateDate' }
        elseif ($_.'CreationTime' -and $best -eq [datetime]$_.'CreationTime') { $src = 'CreationTime' }
        elseif ($_.'FileCreateDate' -and $best -eq [datetime]$_.'FileCreateDate') { $src = 'FileCreateDate' }
        elseif ($_.'FileModifyDate' -and $best -eq [datetime]$_.'FileModifyDate') { $src = 'FileModifyDate' }
    }
    [pscustomobject]@{ Path = $_.FilePath; Ext = $_.Ext; BestDate = ($(if ($best) { $best.ToString('s') } else { '' })); BestDateSource = $src }
}

$withBest = ($aug | Where-Object { $_.BestDate -and $_.BestDate.Trim() -ne '' }).Count
Write-Host ("With BestDate: {0}  ({1}%)" -f $withBest, [math]::Round(100.0 * $withBest / [math]::Max($total, 1), 1))
Write-Host ""
Write-Host "== BestDate Source =="
($aug | Group-Object BestDateSource | Sort-Object Count -Descending) | ForEach-Object { "{0,6}  {1}" -f $_.Count, (if ($_.Name) { $_.Name } else { '(empty)' }) } | ForEach-Object { Write-Host $_ }
Write-Host ""
$noBest = $aug | Where-Object { -not $_.BestDate -or $_.BestDate.Trim() -eq '' } | Select-Object -First 5
if ($noBest) {
    Write-Host "== Examples without BestDate (max 5) =="
    $noBest | ForEach-Object { " - " + $_.Path } | ForEach-Object { Write-Host $_ }
}
Write-Host ""
