# SYNC MOBILE - CLEANUP ONLY (NO POPUP)
# Versione semplificata che FA SOLO DELETE, evitando completamente REPLACE che causano popup

param(
    [ValidateSet('Recent', 'Old', 'Both')]
    [string]$SourceDisk = 'Recent',
    
    [switch]$WhatIf
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SYNC CLEANUP (Delete Only - No Popups)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Source: $SourceDisk" -ForegroundColor White
Write-Host "Mode: $(if ($WhatIf) { 'PREVIEW' } else { 'EXECUTE' })" -ForegroundColor $(if ($WhatIf) { 'Gray' } else { 'Yellow' })
Write-Host ""
Write-Host "This script will:" -ForegroundColor Cyan
Write-Host "  1. Connect to Pixel 8" -ForegroundColor White
Write-Host "  2. Delete obsolete files from phone" -ForegroundColor Red
Write-Host "  3. SKIP all file replacements (to avoid popups)" -ForegroundColor Yellow
Write-Host ""

# Import device config
$configPath = Join-Path $PSScriptRoot "device_config.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$phoneBasePath = $config.phone.basePath
$recentDisk = if ($config.disks.recent.path) { $config.disks.recent.path.TrimEnd('\') + '\' } else { 'E:\' }
$oldDisk = if ($config.disks.old.path) { $config.disks.old.path.TrimEnd('\') + '\' } else { 'D:\' }

# Determine which disk(s) to use
$disksToScan = @()
if ($SourceDisk -eq 'Both' -or $SourceDisk -eq 'Recent') {
    if (Test-Path $recentDisk) { $disksToScan += $recentDisk }
}
if ($SourceDisk -eq 'Both' -or $SourceDisk -eq 'Old') {
    if (Test-Path $oldDisk) { $disksToScan += $oldDisk }
}

if ($disksToScan.Count -eq 0) {
    Write-Host "[ERROR] No disks found!" -ForegroundColor Red
    exit 1
}

Write-Host "Scanning disks: $($disksToScan -join ', ')" -ForegroundColor Gray
Write-Host ""

# Step 1: Get PC files list
Write-Host "[1/3] Scanning PC files..." -ForegroundColor Cyan
$pcFiles = @{}

foreach ($disk in $disksToScan) {
    # Find all _gallery and _mobile folders
    $galleryFolders = Get-ChildItem -Path $disk -Directory -Recurse -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -in @('_gallery', 'Gallery') }
    
    $mobileFolders = Get-ChildItem -Path $disk -Directory -Recurse -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -in @('_mobile', 'Mobile') }
    
    foreach ($folder in ($galleryFolders + $mobileFolders)) {
        $files = Get-ChildItem -Path $folder.FullName -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($disk.Length)
            # Normalize path for comparison
            $normalizedPath = $relativePath.ToLower().Replace('\_gallery\', '\').Replace('\gallery\', '\').Replace('\_mobile\', '\mobile\').Replace('\mobile\', '\mobile\')
            $pcFiles[$normalizedPath] = $file.FullName
        }
    }
}

Write-Host "  Found $($pcFiles.Count) files on PC" -ForegroundColor Green
Write-Host ""

# Step 2: Connect to phone
Write-Host "[2/3] Connecting to phone..." -ForegroundColor Cyan

$shell = New-Object -ComObject Shell.Application
$segments = ($phoneBasePath -split '\\') | Where-Object { $_ -and $_ -notmatch '^PC$|^Questo PC$|^This PC$' }

try {
    $current = $shell.Namespace(0x11) # This PC
    foreach ($seg in $segments) {
        $match = $null
        foreach ($item in $current.Items()) {
            if ($item.Name -ieq $seg) { $match = $item; break }
        }
        if (-not $match) {
            Write-Host "[ERROR] Cannot find '$seg' on phone" -ForegroundColor Red
            Write-Host "Make sure phone is unlocked and in File Transfer mode" -ForegroundColor Yellow
            exit 1
        }
        $current = $shell.Namespace($match)
    }
    
    $phoneFolder = $current
    Write-Host "  Connected: $phoneBasePath" -ForegroundColor Green
    Write-Host ""
    
}
catch {
    Write-Host "[ERROR] Cannot access phone: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Get phone files and delete obsolete ones
Write-Host "[3/3] Scanning phone and deleting obsolete files..." -ForegroundColor Cyan

function Get-PhoneFilesRecursive($folder, $prefix = '') {
    $results = @()
    foreach ($item in $folder.Items()) {
        if ($item.IsFolder) {
            $subFolder = $shell.Namespace($item)
            if ($subFolder) {
                $nextPrefix = if ($prefix) { "$prefix\$($item.Name)" } else { $item.Name }
                $results += Get-PhoneFilesRecursive $subFolder $nextPrefix
            }
        }
        else {
            # Get filename with extension
            $fileName = $null
            try { $fileName = $item.ExtendedProperty('System.FileName') } catch {}
            if (-not $fileName) { $fileName = $item.Name }
            
            $relativePath = if ($prefix) { "$prefix\$fileName" } else { $fileName }
            $results += [pscustomobject]@{
                Path   = $relativePath
                Item   = $item
                Folder = $folder
            }
        }
    }
    return $results
}

$phoneFiles = @(Get-PhoneFilesRecursive $phoneFolder)
Write-Host "  Found $($phoneFiles.Count) files on phone" -ForegroundColor Green
Write-Host ""

# Find obsolete files (on phone but not on PC)
$toDelete = @()
foreach ($phoneFile in $phoneFiles) {
    $normalized = $phoneFile.Path.ToLower()
    if (-not $pcFiles.ContainsKey($normalized)) {
        $toDelete += $phoneFile
    }
}

Write-Host "Files to delete: $($toDelete.Count)" -ForegroundColor Red
Write-Host ""

if ($toDelete.Count -eq 0) {
    Write-Host "[OK] Phone is already in sync! Nothing to delete." -ForegroundColor Green
    exit 0
}

if ($WhatIf) {
    Write-Host "[PREVIEW] Would delete these files:" -ForegroundColor Yellow
    $toDelete | Select-Object -First 20 | ForEach-Object {
        Write-Host "  - $($_.Path)" -ForegroundColor Gray
    }
    if ($toDelete.Count -gt 20) {
        Write-Host "  ... and $($toDelete.Count - 20) more" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "[PREVIEW] No changes made. Run without -WhatIf to execute." -ForegroundColor Gray
    exit 0
}

# Execute deletions
Write-Host "Deleting obsolete files..." -ForegroundColor Yellow
$deleted = 0
$failed = 0

foreach ($file in $toDelete) {
    try {
        $file.Item.InvokeVerb('Delete')
        $deleted++
        if ($deleted % 10 -eq 0) {
            Write-Host "  Deleted $deleted/$($toDelete.Count)..." -ForegroundColor Gray
        }
    }
    catch {
        $failed++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green
Write-Host "  Deleted: $deleted files" -ForegroundColor Green
Write-Host "  Failed: $failed files" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Gray' })
Write-Host "========================================" -ForegroundColor Cyan
