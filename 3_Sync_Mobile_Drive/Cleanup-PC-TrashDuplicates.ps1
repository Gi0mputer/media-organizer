# Clean _trash folders and find duplicates on PC

Write-Host "=== PC CLEANUP: TRASH & DUPLICATES ===" -ForegroundColor Cyan

# 1. Clean _trash folders
Write-Host "`n1. CLEANING _TRASH FOLDERS..." -ForegroundColor Yellow

$drives = @("E:\", "D:\")
$totalTrashSize = 0
$totalTrashFolders = 0

foreach ($drive in $drives) {
    if (-not (Test-Path $drive)) { continue }
    
    Write-Host "`nScanning $drive for _trash folders..." -NoNewline
    
    $trashFolders = Get-ChildItem -Path $drive -Recurse -Directory -Filter "_trash" -ErrorAction SilentlyContinue
    
    foreach ($folder in $trashFolders) {
        $size = (Get-ChildItem $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
        
        if ($size) {
            $totalTrashSize += $size
        }
        
        Write-Host "`n  Deleting: $($folder.FullName) ($([math]::Round($size/1MB, 2)) MB)..." -NoNewline
        
        try {
            Remove-Item $folder.FullName -Recurse -Force -ErrorAction Stop
            $totalTrashFolders++
            Write-Host " OK" -ForegroundColor Green
        }
        catch {
            Write-Host " FAILED" -ForegroundColor Red
        }
    }
}

Write-Host "`n_trash cleanup complete:" -ForegroundColor Cyan
Write-Host "  Folders deleted: $totalTrashFolders" -ForegroundColor Green
Write-Host "  Space freed: $([math]::Round($totalTrashSize/1GB, 2)) GB" -ForegroundColor Green

# 2. Find duplicates (by name and size)
Write-Host "`n2. SCANNING FOR DUPLICATES..." -ForegroundColor Yellow
Write-Host "Building file index (this may take a few minutes)..." -ForegroundColor Gray

$fileMap = @{}
$duplicates = @()

foreach ($drive in $drives) {
    if (-not (Test-Path $drive)) { continue }
    
    Write-Host "  Indexing $drive..." -NoNewline
    
    $files = Get-ChildItem -Path $drive -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\_trash\\' -and $_.FullName -notmatch '\\_sys\\' -and $_.FullName -notmatch '\\_telefono_backup\\' }
    
    Write-Host " $($files.Count) files" -ForegroundColor Green
    
    foreach ($file in $files) {
        $key = "$($file.Name)|$($file.Length)"
        
        if (-not $fileMap.ContainsKey($key)) {
            $fileMap[$key] = @()
        }
        
        $fileMap[$key] += $file.FullName
    }
}

# Find duplicates
Write-Host "`nAnalyzing for duplicates..." -NoNewline

foreach ($key in $fileMap.Keys) {
    $paths = $fileMap[$key]
    
    if ($paths.Count -gt 1) {
        $size = ($key -split '\|')[1]
        $name = ($key -split '\|')[0]
        
        $duplicates += [pscustomobject]@{
            Name  = $name
            Size  = [long]$size
            Count = $paths.Count
            Paths = $paths
        }
    }
}

Write-Host " Found $($duplicates.Count) duplicate groups" -ForegroundColor Yellow

# Calculate duplicate space
$wastedSpace = ($duplicates | ForEach-Object { $_.Size * ($_.Count - 1) } | Measure-Object -Sum).Sum

Write-Host "`nDuplicate analysis:" -ForegroundColor Cyan
Write-Host "  Duplicate file groups: $($duplicates.Count)" -ForegroundColor Yellow
Write-Host "  Wasted space (keeping 1 copy): $([math]::Round($wastedSpace/1GB, 2)) GB" -ForegroundColor Yellow

# Show top duplicates
Write-Host "`nTop 10 largest duplicates:" -ForegroundColor Yellow
$duplicates | Sort-Object { $_.Size * ($_.Count - 1) } -Descending | Select-Object -First 10 | 
ForEach-Object {
    $waste = $_.Size * ($_.Count - 1) / 1MB
    Write-Host "  $($_.Name) - $($_.Count) copies ($([math]::Round($waste, 2)) MB wasted)" -ForegroundColor Gray
    $_.Paths | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
}

# Export full report
$report = @{
    Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    TrashCleanup = @{
        FoldersDeleted = $totalTrashFolders
        SpaceFreedGB   = [math]::Round($totalTrashSize / 1GB, 2)
    }
    Duplicates   = $duplicates
    Summary      = @{
        DuplicateGroups = $duplicates.Count
        WastedSpaceGB   = [math]::Round($wastedSpace / 1GB, 2)
    }
}

$report | ConvertTo-Json -Depth 5 | Set-Content "$PSScriptRoot\pc_cleanup_report.json"
Write-Host "`nFull report saved: pc_cleanup_report.json" -ForegroundColor Gray
