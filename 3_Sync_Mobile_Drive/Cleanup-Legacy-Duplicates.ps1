# FIND AND MOVE LEGACY DUPLICATES TO TRASH
# Trova file duplicati (stessa cartella, uno dentro Mobile e uno fuori)

param(
    [string]$PhoneBasePath = "PC\Pixel 8\Memoria condivisa interna\SSD",
    [switch]$WhatIf
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FIND LEGACY DUPLICATES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Mode: $(if ($WhatIf) { 'PREVIEW' } else { 'MOVE TO TRASH' })" -ForegroundColor $(if ($WhatIf) { 'Gray' } else { 'Yellow' })
Write-Host ""

# Connect
$shell = New-Object -ComObject Shell.Application
$segments = ($PhoneBasePath -split '\\') | Where-Object { $_ -and $_ -notmatch '^PC$|^Questo PC$|^This PC$' }

try {
    $current = $shell.Namespace(0x11)
    foreach ($seg in $segments) {
        $match = $null
        foreach ($item in $current.Items()) {
            if ($item.Name -ieq $seg) { $match = $item; break }
        }
        if (-not $match) {
            Write-Host "[ERROR] Cannot find '$seg'" -ForegroundColor Red
            exit 1
        }
        $current = $shell.Namespace($match)
    }
    $phoneRoot = $current
    Write-Host "[OK] Connected: $PhoneBasePath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Cannot connect" -ForegroundColor Red
    exit 1
}

# Get all files recursively
function Get-AllFilesRecursive($folder, $prefix = '') {
    $results = @()
    foreach ($item in $folder.Items()) {
        if ($item.IsFolder) {
            # Skip _trash
            if ($item.Name -eq '_trash') { continue }
            
            $subFolder = $shell.Namespace($item)
            if ($subFolder) {
                $nextPrefix = if ($prefix) { "$prefix\$($item.Name)" } else { $item.Name }
                $results += Get-AllFilesRecursive $subFolder $nextPrefix
            }
        } else {
            $fileName = $item.Name
            $relativePath = if ($prefix) { "$prefix\$fileName" } else { $fileName }
            $results += [pscustomobject]@{
                Path = $relativePath
                Name = $fileName
                Folder = $folder
                Item = $item
            }
        }
    }
    return $results
}

Write-Host ""
Write-Host "Scanning all files on phone..." -ForegroundColor Cyan
$allFiles = @(Get-AllFilesRecursive $phoneRoot)
Write-Host "  Found $($allFiles.Count) files" -ForegroundColor Green
Write-Host ""

# Find duplicates: same filename, one in Mobile\ and one outside
Write-Host "Analyzing for legacy duplicates..." -ForegroundColor Cyan

$duplicates = @()
$checked = @{}

foreach ($file in $allFiles) {
    $path = $file.Path.ToLower()
    $name = $file.Name.ToLower()
    
    # Check if this file has \mobile\ in path
    $isInMobile = $path -match '\\mobile\\'
    
    if ($isInMobile) {
        # This is inside Mobile folder
        # Check if same file exists outside Mobile (in parent)
        $pathOutsideMobile = $path -replace '\\mobile\\', '\'
        
        foreach ($otherFile in $allFiles) {
            $otherPath = $otherFile.Path.ToLower()
            if ($otherPath -eq $pathOutsideMobile) {
                # Found duplicate! The one OUTSIDE Mobile should be deleted
                $key = $otherFile.Path
                if (-not $checked.ContainsKey($key)) {
                    $duplicates += [pscustomobject]@{
                        File = $otherFile
                        Reason = "Duplicate (exists in Mobile\)"
                        MobileVersion = $file.Path
                    }
                    $checked[$key] = $true
                }
            }
        }
    }
}

Write-Host "  Legacy duplicates found: $($duplicates.Count)" -ForegroundColor $(if ($duplicates.Count -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

if ($duplicates.Count -eq 0) {
    Write-Host "[OK] No legacy duplicates found!" -ForegroundColor Green
    exit 0
}

# Show sample
Write-Host "Sample duplicates (showing first 20):" -ForegroundColor Yellow
$duplicates | Select-Object -First 20 | ForEach-Object {
    Write-Host "  DELETE: $($_.File.Path)" -ForegroundColor Red
    Write-Host "    (exists in: $($_.MobileVersion))" -ForegroundColor Gray
}
if ($duplicates.Count -gt 20) {
    Write-Host "  ... and $($duplicates.Count - 20) more" -ForegroundColor Gray
}

Write-Host ""

if ($WhatIf) {
    Write-Host "[PREVIEW] No changes made." -ForegroundColor Gray
    Write-Host "Run without -WhatIf to move these to _trash" -ForegroundColor Yellow
    exit 0
}

# Create _trash if needed
$trashFolder = $null
foreach ($item in $phoneRoot.Items()) {
    if ($item.IsFolder -and $item.Name -eq '_trash') {
        $trashFolder = $shell.Namespace($item)
        break
    }
}

if (-not $trashFolder) {
    Write-Host "Creating _trash folder..." -ForegroundColor Cyan
    $phoneRoot.NewFolder('_trash')
    Start-Sleep -Seconds 2
    foreach ($item in $phoneRoot.Items()) {
        if ($item.IsFolder -and $item.Name -eq '_trash') {
            $trashFolder = $shell.Namespace($item)
            break
        }
    }
}

if (-not $trashFolder) {
    Write-Host "[ERROR] Cannot create _trash" -ForegroundColor Red
    exit 1
}

# Move duplicates to trash
Write-Host "Moving $($duplicates.Count) duplicates to _trash..." -ForegroundColor Yellow
$moved = 0
$failed = 0

foreach ($dup in $duplicates) {
    try {
        $trashFolder.MoveHere($dup.File.Item, 16) # 16 = no UI
        $moved++
        if ($moved % 10 -eq 0) {
            Write-Host "  Moved $moved/$($duplicates.Count)..." -ForegroundColor Gray
        }
    } catch {
        $failed++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green
Write-Host "  Moved to _trash: $moved" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Gray' })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEP: Delete _trash folder on phone to free space!" -ForegroundColor Yellow
