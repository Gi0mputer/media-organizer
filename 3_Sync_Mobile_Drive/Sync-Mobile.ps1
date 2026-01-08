# ============================================================================
# NOME: Sync-Mobile.ps1
# DESCRIZIONE: Sincronizza media tra PC e Pixel 8 usando ADB (No Popup, High Speed).
#
# DETTAGLI:
#   - Architettura Dual Root:
#     * _gallery (PC) -> DCIM\SSD (Tel) [Visibile Google Foto]
#     * _mobile (PC)  -> SSD (Tel)      [Archivio]
#   - Safety Logic (Source-Aware Delete):
#     * Elimina file dal telefono SOLO se il disco PC di origine corrispondente è CONNESSO.
#     * Se un disco (es. D: Old) è scollegato, i suoi file sul telefono vengono preservati.
#   - Modalità default: PC2Phone (Mirroring sicuro).
#   - Richiede: Debug USB attivato sul telefono.
# ============================================================================

param(
    [ValidateSet('PC2Phone', 'Phone2PC')]
    [string]$Mode = 'PC2Phone', # Direction

    [switch]$Execute,     # Runs commands (otherwise Preview)
    [switch]$Force        # Force overwrite
)

$adb = "$PSScriptRoot\Tools\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { Write-Error "ADB not found. Run Setup-ADB.ps1"; exit 1 }

# Config Paths
$PhoneSdCard = "/sdcard" 
$MobileDest = "$PhoneSdCard/SSD"
$GalleryDest = "$PhoneSdCard/DCIM/SSD"

# PC Source Paths & Detection
$pcDisks = @()
$connectedRoots = @{} 

if (Test-Path "E:\") { $pcDisks += "E:\"; $connectedRoots["E:"] = $true }
if (Test-Path "D:\") { $pcDisks += "D:\"; $connectedRoots["D:"] = $true }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SYNC MOBILE (ADB) - Mode: $Mode" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Connected PC Disks: $($pcDisks -join ', ')" -ForegroundColor Yellow

# 1. Check ADB
Write-Host "Checking ADB connection..." -NoNewline
$devs = & $adb devices
if ($devs -notmatch "device" -or $devs -match "unauthorized") {
    Write-Host " FAILED." -ForegroundColor Red
    Write-Host "Please unlock phone and Accept USB Debugging prompt." -ForegroundColor Yellow
    exit 1
}
Write-Host " OK." -ForegroundColor Green

# 2. INVENTORY PHASE
Write-Host "Scanning PC..." -ForegroundColor Yellow
$pcMap = @{} # Key: "PhonePath" (Pivot), Value: PCFileInfo

foreach ($disk in $pcDisks) {
    $files = Get-ChildItem -Path $disk -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        if ($f.FullName -match '\\_trash\\') { continue }
        
        # Mapping Logic
        $rel = $f.FullName.Substring($disk.Length)
        $parts = $rel -split '\\'
        
        $isGallery = ($parts -contains "_gallery" -or $parts -contains "Gallery")
        $isMobile = ($parts -contains "_mobile" -or $parts -contains "Mobile")
        
        if (-not $isGallery -and -not $isMobile) { continue }
        
        # Clean path (remove wrappers)
        $cleanParts = $parts | Where-Object { $_ -ne "_gallery" -and $_ -ne "Gallery" -and $_ -ne "_mobile" -and $_ -ne "Mobile" }
        $cleanRel = $cleanParts -join '/' 
        
        $destRoot = if ($isGallery) { $GalleryDest } else { $MobileDest }
        $phonePath = "$destRoot/$cleanRel"
        
        $pcMap[$phonePath] = $f
    }
}
Write-Host "  PC Files (Mapped): $($pcMap.Count)" -ForegroundColor Green

Write-Host "Scanning Phone (via ADB)..." -ForegroundColor Yellow
$cmd = "find '$MobileDest' '$GalleryDest' -type f -printf '%p|%s\n' 2>/dev/null"
$phoneOut = & $adb shell $cmd

$phoneMap = @{} # Key: PhonePath, Value: Size
foreach ($line in $phoneOut) {
    if ($line -match "^(.*)\|(\d+)$") {
        $path = $matches[1]
        $size = [long]$matches[2]
        $phoneMap[$path] = $size
    }
}
Write-Host "  Phone Files found: $($phoneMap.Count)" -ForegroundColor Green

# 3. PLANNING PHASE
Write-Host "Planning..." -ForegroundColor Yellow
$toCopy = @()
$toDelete = @()

if ($Mode -eq 'PC2Phone') {
    # === PC -> PHONE ===
    
    # Push (exists on PC, missing/different on Phone)
    foreach ($key in $pcMap.Keys) {
        $pcFile = $pcMap[$key]
        if (-not $phoneMap.ContainsKey($key)) {
            $toCopy += [pscustomobject]@{ Source=$pcFile.FullName; Dest=$key; Reason="New" }
        } elseif ($phoneMap[$key] -ne $pcFile.Length) {
            $toCopy += [pscustomobject]@{ Source=$pcFile.FullName; Dest=$key; Reason="Changed" }
        }
    }

    # Delete (exists on Phone, missing on PC)
    foreach ($key in $phoneMap.Keys) {
        if (-not $pcMap.ContainsKey($key)) {
            # Check Safe Scope (same logic as before)
            $shouldCheck = $false
            if ($key -match "/(202[4-9]|20[3-9][0-9])/") { if ($connectedRoots.ContainsKey("E:")) { $shouldCheck = $true } }
            elseif ($key -match "/(201[0-9]|202[0-3]|200[0-9]|19[0-9][0-9])/") { if ($connectedRoots.ContainsKey("D:")) { $shouldCheck = $true } }
            else { if ($connectedRoots.ContainsKey("E:") -and $connectedRoots.ContainsKey("D:")) { $shouldCheck = $true } }
            
            if ($shouldCheck) {
                $toDelete += $key # Phone Path to delete
            }
        }
    }

} elseif ($Mode -eq 'Phone2PC') {
    # === PHONE -> PC ===
    
    # Copy (Phone -> PC)
    # We iterate Phone files. If mapped PC path is valid (disk connected) and file missing/diff, Pull.
    
    foreach ($phoneKey in $phoneMap.Keys) {
        # Determine PC Destination
        # Logic: Reverse map PhonePath -> PCPath?
        # Problem: We assume the folder structure exists in PCMap?
        # If file is NEW on phone (e.g. moved via Android File Manager), it might be in a folder that PCMap knows about.
        
        # Heuristic to find PC Target Folder:
        # /sdcard/SSD/2025/Evento/file.jpg -> E:\2025\Evento\_mobile\file.jpg
        
        # 1. Parse Phone Path
        $isGallery = $phoneKey.StartsWith($GalleryDest)
        $relPath = if ($isGallery) { $phoneKey.Substring($GalleryDest.Length) } else { $phoneKey.Substring($MobileDest.Length) }
        # relPath: /2025/Evento/file.jpg
        
        if ($relPath.StartsWith("/")) { $relPath = $relPath.Substring(1) } # 2025/Evento/file.jpg
        $pathParts = $relPath -split '/'
        
        # 2. Determine Disk & Wrapper
        # Year check for Disk
        $year = $pathParts[0]
        $targetDisk = $null
        if ($year -match "^(202[4-9]|20[3-9][0-9])$") { $targetDisk = "E:\" }
        elseif ($year -match "^(201[0-9]|202[0-3]|200[0-9]|19[0-9][0-9])$") { $targetDisk = "D:\" }
        
        if (-not $targetDisk -or -not $connectedRoots.ContainsKey($targetDisk.Substring(0,2))) {
            # Msg: "Skipping $phoneKey (Disk not connected or unknown year)"
            continue 
        }
        
        # 3. Construct PC Path with wrapper (_mobile/_gallery)
        # We need to inject wrapper! Where?
        # Spec: Year/Event/_wrapper/File  OR  Year/_wrapper/File?
        # Current standard: Year/Event/_wrapper/File.
        
        # If parts count >= 2 (Year/File), usually wrapper is deep.
        # But we can try to math existing PC folder structure if possible.
        # If completely new folder, we follow standard: Year/Event/_mobile/File.
        
        # Simplification: Use the Parent of the file as the Event folder.
        # Structure: DISK:\Year\Event\_wrapper\File
        
        $wrapper = if ($isGallery) { "_gallery" } else { "_mobile" }
        
        # Build PC Path components
        # [0]=2025, [1]=Evento, [2]=file.jpg  -> E:\2025\Evento\_mobile\file.jpg
        # [0]=2025, [1]=file.jpg              -> E:\2025\_mobile\file.jpg
        
        $pcPathList = @($targetDisk)
        
        # Add all parts except last (filename)
        for ($i=0; $i -lt ($pathParts.Count - 1); $i++) {
            $pcPathList += $pathParts[$i]
        }
        
        $pcPathList += $wrapper
        $pcPathList += $pathParts[$pathParts.Count - 1]
        
        $targetPcPath = [System.IO.Path]::Combine($pcPathList)
        
        # Check against PC Inventory
        if (-not $pcMap.ContainsKey($phoneKey)) {
             # Not in map -> New on Phone
             $toCopy += [pscustomobject]@{ Source=$phoneKey; Dest=$targetPcPath; Reason="NewOnPhone" }
        } elseif ($pcMap[$phoneKey].Length -ne $phoneMap[$phoneKey]) {
             # Exists in map, but changed size
             $toCopy += [pscustomobject]@{ Source=$phoneKey; Dest=$pcMap[$phoneKey].FullName; Reason="ChangedOnPhone" }
        }
    }

    # Delete (Exists on PC, missing on Phone) -> Delete Local PC File
    foreach ($key in $pcMap.Keys) {
        if (-not $phoneMap.ContainsKey($key)) {
            $pcFileInfo = $pcMap[$key]
            # Safe Guard: We are deleting from PC!
            $toDelete += $pcFileInfo.FullName
        }
    }
}

Write-Host ""
Write-Host "PLAN SUMMARY ($Mode):" -ForegroundColor Cyan
if ($Mode -eq 'PC2Phone') {
    Write-Host "  Push to Phone : $($toCopy.Count)" -ForegroundColor Green
    Write-Host "  Delete on Phone: $($toDelete.Count)" -ForegroundColor Red
} else {
    Write-Host "  Pull to PC     : $($toCopy.Count)" -ForegroundColor Green
    Write-Host "  Delete on PC   : $($toDelete.Count)" -ForegroundColor Red
}
Write-Host ""

if (-not $Execute) {
    Write-Host "[PREVIEW] Sample Actions (Run with -Execute to apply):" -ForegroundColor Yellow
    if ($toCopy.Count -gt 0) {
        Write-Host "  COPY:" -ForegroundColor Green
        $toCopy | Select-Object -First 5 | ForEach-Object { Write-Host "    $($_.Dest)" }
    }
    if ($toDelete.Count -gt 0) {
        Write-Host "  DELETE:" -ForegroundColor Red
        $toDelete | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" }
    }
    exit 0
}

# 4. EXECUTE
# Copy
if ($toCopy.Count -gt 0) {
    Write-Host "Copying $($toCopy.Count) files..." -ForegroundColor Green
    $i = 0
    foreach ($item in $toCopy) {
        $i++
        if ($i % 10 -eq 0) { Write-Host "." -NoNewline }
        
        $src = $item.Source
        $dest = $item.Dest
        
        if ($Mode -eq 'PC2Phone') {
            # ADB Push: src=Local, dest=Remote
            & $adb push "$src" "$dest" | Out-Null
        } else {
            # ADB Pull: src=Remote, dest=Local
            # Create local dir if missing
            $localDir = [System.IO.Path]::GetDirectoryName($dest)
            if (-not (Test-Path $localDir)) { New-Item -ItemType Directory -Path $localDir | Out-Null }
            
            # --- SAFETY BACKUP (Before Overwrite) ---
            if (Test-Path $dest) {
                try {
                    $existingFile = Get-Item $dest
                    $phoneSize = $phoneMap[$item.Source] # Get size from inventory
                    
                    # Logic: If existing PC file is significantly larger (>1MB) than incoming Phone file -> It's a TRIM.
                    $isTrim = ($existingFile.Length -gt ($phoneSize + 1048576))
                    
                    # Determine Trash Path
                    $parentDir = $existingFile.Directory
                    # Try to locate sibling _trash
                    if ($parentDir.Name -eq "_mobile" -or $parentDir.Name -eq "_gallery") {
                         $trashDir = Join-Path -Path $parentDir.Parent.FullName -ChildPath "_trash"
                    } else {
                         # Fallback inside same folder
                         $trashDir = Join-Path -Path $parentDir.FullName -ChildPath ".trash" 
                    }
                    if (-not (Test-Path $trashDir)) { New-Item -ItemType Directory -Path $trashDir -Force | Out-Null }
                    
                    # Determine Backup Name
                    if ($isTrim) {
                        # Nome(long).ext
                        $bakName = "$($existingFile.BaseName)(long)$($existingFile.Extension)"
                    } else {
                        # Nome_TIMESTAMP.ext
                        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                        $bakName = "$($existingFile.BaseName)_$timestamp$($existingFile.Extension)"
                    }
                    
                    $bakPath = Join-Path -Path $trashDir -ChildPath $bakName
                    
                    # Move to Trash
                    Move-Item -Path $dest -Destination $bakPath -Force -ErrorAction SilentlyContinue
                    # Write-Host " (Backup: $bakName)" -NoNewline -ForegroundColor DarkGray
                } catch {
                    Write-Host " [BackupFailed]" -NoNewline -ForegroundColor Red
                }
            }
            # ----------------------------------------

            & $adb pull "$src" "$dest" | Out-Null
        }
    }
    Write-Host " Done."
}

# Delete
if ($toDelete.Count -gt 0) {
    Write-Host "Deleting $($toDelete.Count) files..." -ForegroundColor Red
    
    if ($Mode -eq 'PC2Phone') {
        # Remote Delete
        $batch = @()
        foreach ($item in $toDelete) {
            $safePath = $item -replace "'", "\'"; $batch += "'$safePath'"
            if ($batch.Count -ge 50) {
                $list = $batch -join " "; & $adb shell "rm $list"; $batch = @(); Write-Host "." -NoNewline
            }
        }
        if ($batch.Count -gt 0) { $list = $batch -join " "; & $adb shell "rm $list" }
    } else {
        # Local Delete (PC) -> SOFT DELETE (Move to _trash)
        foreach ($item in $toDelete) {
            # $item is the full path on PC, e.g. E:\2025\Evento\_mobile\foto.jpg
            
            try {
                $fileObj = Get-Item $item -ErrorAction Stop
                $parentDir = $fileObj.Directory
                
                # Verify we are inside a standard structure (_mobile/_gallery)
                if ($parentDir.Name -eq "_mobile" -or $parentDir.Name -eq "_gallery" -or $parentDir.Name -eq "Mobile" -or $parentDir.Name -eq "Gallery") {
                    
                    # Target: ../_trash/
                    $grandParent = $parentDir.Parent
                    $trashDir = Join-Path -Path $grandParent.FullName -ChildPath "_trash"
                    
                    if (-not (Test-Path $trashDir)) {
                        New-Item -ItemType Directory -Path $trashDir -Force | Out-Null
                    }
                    
                    # Move
                    $destPath = Join-Path -Path $trashDir -ChildPath $fileObj.Name
                    
                    # Handle Collision (Timestamp rename)
                    if (Test-Path $destPath) {
                        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                        $newName = "$($fileObj.BaseName)_$timestamp$($fileObj.Extension)"
                        $destPath = Join-Path -Path $trashDir -ChildPath $newName
                    }
                    
                    Move-Item -Path $item -Destination $destPath -Force
                    Write-Host "M" -NoNewline # Descriptors: M=Moved to trash
                } else {
                    # Non-standard folder structure? Safety fallback: RENAME .trash
                    # User asked specifically for _trash sibling. If we can't find sibling, we skip or rename locally.
                    # Let's rename locally to be safe.
                    $newName = "$($fileObj.Name).trash"
                    Rename-Item -Path $item -NewName $newName -Force
                    Write-Host "r" -NoNewline
                }
            } catch {
                Write-Host "!" -NoNewline
            }
        }
    }
    Write-Host " Done."
}

# Cleanup Empty Dirs
Write-Host "Cleaning empty directories..." -ForegroundColor Yellow
if ($Mode -eq 'PC2Phone') {
    & $adb shell "find '$MobileDest' '$GalleryDest' -type d -empty -delete"
} else {
    # Local Cleanup (Optional/Complex on PC, skipped for safety or minimal implementation)
    # We can use the existing Remove-EmptyFolders.ps1 if needed.
    Write-Host " (Skipped on PC side)" -ForegroundColor DarkGray
}

Write-Host "SYNC COMPLETE." -ForegroundColor Green
