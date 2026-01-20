# ============================================================================
# NOME: Sync-Mobile.ps1
# DESCRIZIONE: Sincronizza media tra PC e Pixel 8 usando ADB (No Popup, High Speed).
# MODALITA':
#   - PC2Phone: Mirroring (PC -> Phone). Distruttivo su Phone (Safe Scope).
#   - Phone2PC: Import (Phone -> PC). Soft Delete su PC (_trash). Smart Move Detection.
# DETTAGLI:
#   - Architettura Dual Root: _gallery <-> DCIM\SSD, _mobile <-> SSD.
#   - Supporto cartella "pc" su telefono -> "_pc" su PC.
# ============================================================================

param(
    [ValidateSet('PC2Phone', 'Phone2PC')]
    [string]$Mode = 'PC2Phone',

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

# ----------------------------------------------------------------------------
# HELPER: DISTRIBUTED FOLDER MAP
# Tracks where root folders (e.g. "2023", "meme") belong (E: or D:)
# stored in X:\_sys\drive_map.json
# ----------------------------------------------------------------------------
function Get-MergedDriveMap ($disks) {
    $masterMap = @{} # Key: FolderName, Value: DriveLetter (E: or D:)
    
    # 1. Load from JSONs (History)
    foreach ($d in $disks) {
        $jsonPath = Join-Path $d "_sys\drive_map.json"
        if (Test-Path $jsonPath) {
            try {
                $chk = Get-Content $jsonPath -Raw | ConvertFrom-Json
                # Merge logic: Simple overwrite for now. Ideally check timestamps.
                # Since we read all, last loaded wins? No.
                # We assume maps are mostly synced. 
                foreach ($prop in $chk.PSObject.Properties) {
                    $masterMap[$prop.Name] = $prop.Value
                }
            }
            catch { Write-Warning "Corrupt Map on $d" }
        }
    }
    
    # 2. Update with REALITY (Current Scan) creates Authority
    # If folder physically exists on a connected disk, that overrides history.
    foreach ($d in $disks) {
        $roots = Get-ChildItem $d -Directory -ErrorAction SilentlyContinue
        foreach ($r in $roots) {
            if ($r.Name.StartsWith("_") -or $r.Name.StartsWith(".")) { continue } # Skip _sys, _trash, etc.
            $masterMap[$r.Name] = $d # E:\ or D:\
        }
    }
    return $masterMap
}

function Save-DriveMap ($map, $disks) {
    $json = $map | ConvertTo-Json -Depth 2
    foreach ($d in $disks) {
        $sysDir = Join-Path $d "_sys"
        if (-not (Test-Path $sysDir)) { New-Item -ItemType Directory -Path $sysDir -Force | Out-Null }
        $jsonPath = Join-Path $sysDir "drive_map.json"
        $json | Set-Content -Path $jsonPath -Force
    }
}
# ----------------------------------------------------------------------------

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SYNC MOBILE (ADB) - Mode: $Mode" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Connected PC Disks: $($pcDisks -join ', ')" -ForegroundColor Yellow

# 1. STARTUP: Load Map
$folderSchema = Get-MergedDriveMap $pcDisks
# Save immediately to sync discrepancies between disks (if both connected)
if ($pcDisks.Count -gt 0) { Save-DriveMap $folderSchema $pcDisks }

# 2. Check ADB
Write-Host "Checking ADB connection..." -NoNewline
$devs = & $adb devices
if ($devs -notmatch "device" -or $devs -match "unauthorized") {
    Write-Host " FAILED." -ForegroundColor Red
    Write-Host "Please unlock phone and Accept USB Debugging prompt." -ForegroundColor Yellow
    exit 1
}
Write-Host " OK." -ForegroundColor Green

# 3. INVENTORY PHASE
Write-Host "Scanning PC..." -ForegroundColor Yellow
$pcMap = @{} # Key: "PhonePath" (Pivot), Value: PCFileInfo

foreach ($disk in $pcDisks) {
    # Scan logic update: We check folders physically exists, handled by Get-ChildItem below.
    $files = Get-ChildItem -Path $disk -Recurse -File -ErrorAction SilentlyContinue

    foreach ($f in $files) {
        if ($f.FullName -match '\\_trash\\') { continue }
        
        # Mapping Logic
        $rel = $f.FullName.Substring($disk.Length)
        $parts = $rel -split '\\'
        
        $isGallery = ($parts -contains "_gallery" -or $parts -contains "Gallery")
        $isMobile = ($parts -contains "_mobile" -or $parts -contains "Mobile")
        $isPc = ($parts -contains "_pc")
        
        if (-not $isGallery -and -not $isMobile -and -not $isPc) { continue }
        
        # Clean path (remove wrappers)
        $cleanParts = $parts | Where-Object { $_ -ne "_gallery" -and $_ -ne "Gallery" -and $_ -ne "_mobile" -and $_ -ne "Mobile" -and $_ -ne "_pc" }
        $cleanRel = $cleanParts -join '/' 
        
        # For Phone path: if it was _pc on PC, where does it go on Phone?
        # User requested: SSD/.../pc/file ?
        # Standard: _gallery->DCIM/SSD, _mobile->SSD.
        # _pc -> SSD (as Archive) but maybe inside a 'pc' subfolder if we want symmetry?
        # Let's map _pc -> SSD (same as mobile) for now, or keep user logic.
        # The user said: "mettere una cartella 'pc' dentro le cartelle SSD/*" -> phone to pc.
        # PC to Phone: _pc should probably go to SSD/.../pc ? 
        # For simplicity in Mirroring, let's map _pc -> SSD/_pc pattern?
        # Current logic is Pivot Key = PhonePath.
        
        $destRoot = if ($isGallery) { $GalleryDest } else { $MobileDest }
        
        # If it is _pc, we append /pc to the phone path?
        if ($isPc) { 
            # E:\2025\Event\_pc\file.jpg -> SSD/2025/Event/pc/file.jpg
            # cleanRel has 2025/Event/file.jpg
            # We need to inject 'pc' before filename.
            $fName = Split-Path $cleanRel -Leaf
            $fDir = Split-Path $cleanRel -Parent
            $phonePath = "$destRoot/$fDir/pc/$fName"
            $phonePath = $phonePath -replace '\\', '/' -replace '//', '/'
        }
        else {
            $phonePath = "$destRoot/$cleanRel"
        }
        
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
            $toCopy += [pscustomobject]@{ Source = $pcFile; Dest = $key; Reason = "New" }
        }
        elseif ($phoneMap[$key] -ne $pcFile.Length) {
            $toCopy += [pscustomobject]@{ Source = $pcFile; Dest = $key; Reason = "Changed" }
        }
    }

    # Delete (exists on Phone, missing on PC)
    foreach ($key in $phoneMap.Keys) {
        if (-not $pcMap.ContainsKey($key)) {
            # Check Safe Scope
            $shouldCheck = $false
            if ($key -match "/(202[4-9]|20[3-9][0-9])/") { if ($connectedRoots.ContainsKey("E:")) { $shouldCheck = $true } }
            elseif ($key -match "/(201[0-9]|202[0-3]|200[0-9]|19[0-9][0-9])/") { if ($connectedRoots.ContainsKey("D:")) { $shouldCheck = $true } }
            else { if ($connectedRoots.ContainsKey("E:") -and $connectedRoots.ContainsKey("D:")) { $shouldCheck = $true } }
            
            if ($shouldCheck) {
                $toDelete += $key # Phone Path to delete
            }
        }
    }

}
elseif ($Mode -eq 'Phone2PC') {
    # === PHONE -> PC ===
    
    foreach ($phoneKey in $phoneMap.Keys) {
        # 1. Parse Phone Path
        $isGallery = $phoneKey.StartsWith($GalleryDest)
        $relPath = if ($isGallery) { $phoneKey.Substring($GalleryDest.Length) } else { $phoneKey.Substring($MobileDest.Length) }
        
        if ($relPath.StartsWith("/")) { $relPath = $relPath.Substring(1) }
        $pathParts = $relPath -split '/'
        
        # 2. Determine Disk & Wrapper
        $wrapper = if ($isGallery) { "_gallery" } else { "_mobile" }
        $rootFolder = $pathParts[0]
        
        $targetDisk = $null
        
        # Priority 1: Check Schema (Authoritative)
        if ($folderSchema.ContainsKey($rootFolder)) {
            $assignedDisk = $folderSchema[$rootFolder] # "E:\" or "D:\"
            
            # Is the assigned disk connected?
            # We compare just the letter (E:) to handle inconsistent trailing slashes
            $assignedLetter = $assignedDisk.Substring(0, 2)
            
            if ($connectedRoots.ContainsKey($assignedLetter)) {
                $targetDisk = $assignedDisk
            }
            else {
                # DISK MISSING!
                # Safety -> SKIP. Do NOT put on the wrong disk.
                # Write-Host "Skipping $phoneKey (Belongs to $assignedLetter which is offline)" -ForegroundColor DarkGray
                continue
            }
        } 
        
        # Priority 2: New Folder (Not in Schema)
        if (-not $targetDisk) {
            # Folder is completely new to the system.
            # Default to E: (Recent) if available.
            if ($connectedRoots.ContainsKey("E:")) { $targetDisk = "E:\" }
            elseif ($connectedRoots.ContainsKey("D:")) { $targetDisk = "D:\" }
             
            # Register new folder for future consistency
            if ($targetDisk) {
                $folderSchema[$rootFolder] = $targetDisk
                # We trigger a save at the end (or now? End is better for performance)
            }
        }
        
        if (-not $targetDisk) { continue }
        
        # 3. Construct PC Path with wrapper (_mobile/_gallery/_pc)
        $pcPathStr = $targetDisk 
        
        $collectedFolders = @()
        for ($i = 0; $i -lt ($pathParts.Count - 1); $i++) {
            $part = $pathParts[$i]
            # Check for special "pc" folder at the leaf level -> Wrapper _pc
            if ($i -eq ($pathParts.Count - 2) -and $part -eq "pc") {
                $wrapper = "_pc"
                # Skip adding "pc" to path
            }
            else {
                $collectedFolders += $part
            }
        }
        
        foreach ($folder in $collectedFolders) {
            $pcPathStr = Join-Path $pcPathStr $folder
        }
        
        $pcPathStr = Join-Path $pcPathStr $wrapper
        $pcPathStr = Join-Path $pcPathStr $pathParts[$pathParts.Count - 1]
        
        $targetPcPath = $pcPathStr
        
        # Check against PC Inventory
        if (-not $pcMap.ContainsKey($phoneKey)) {
            $toCopy += [pscustomobject]@{ Source = $phoneKey; Dest = $targetPcPath; Reason = "NewOnPhone" }
        }
        elseif ($pcMap[$phoneKey].Length -ne $phoneMap[$phoneKey]) {
            $toCopy += [pscustomobject]@{ Source = $phoneKey; Dest = $pcMap[$phoneKey].FullName; Reason = "ChangedOnPhone" }
        }
    }

    # Delete (Exists on PC, missing on Phone) -> Delete Local PC File
    foreach ($key in $pcMap.Keys) {
        if (-not $phoneMap.ContainsKey($key)) {
            $pcFileInfo = $pcMap[$key]
            $toDelete += $pcFileInfo.FullName
        }
    }
}

Write-Host ""
Write-Host "PLAN SUMMARY ($Mode):" -ForegroundColor Cyan
if ($Mode -eq 'PC2Phone') {
    Write-Host "  Push to Phone : $($toCopy.Count)" -ForegroundColor Green
    Write-Host "  Delete on Phone: $($toDelete.Count)" -ForegroundColor Red
}
else {
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
    
    # ---------------------------
    # Backup Logic for Phone2PC (Trim Detection)
    # ---------------------------
    if ($Mode -eq 'Phone2PC') {
        foreach ($item in $toCopy) {
            if (Test-Path $item.Dest) {
                try {
                    $existingFile = Get-Item $item.Dest
                    $phoneSize = $phoneMap[$item.Source]
                    $isTrim = ($existingFile.Length -gt ($phoneSize + 1048576)) # >1MB diff
                    
                    $parentDir = $existingFile.Directory
                    if ($parentDir.Name -eq "_mobile" -or $parentDir.Name -eq "_gallery" -or $parentDir.Name -eq "_pc") {
                        $trashDir = Join-Path -Path $parentDir.Parent.FullName -ChildPath "_trash"
                    }
                    else {
                        $trashDir = Join-Path -Path $parentDir.FullName -ChildPath ".trash" 
                    }
                    if (-not (Test-Path $trashDir)) { New-Item -ItemType Directory -Path $trashDir -Force | Out-Null }
                    
                    $bakName = if ($isTrim) { "$($existingFile.BaseName)(long)$($existingFile.Extension)" } 
                    else { "$($existingFile.BaseName)_$(Get-Date -Format 'yyyyMMdd-HHmmss')$($existingFile.Extension)" }
                    
                    Move-Item -Path $item.Dest -Destination (Join-Path $trashDir $bakName) -Force -ErrorAction SilentlyContinue
                }
                catch {}
            }
        }
    }

    $i = 0
    foreach ($item in $toCopy) {
        $i++; if ($i % 50 -eq 0) { Write-Host "." -NoNewline }
        
        $src = $item.Source; $dest = $item.Dest
        
        if ($Mode -eq 'PC2Phone') {
            # Source is FileInfo Object - need FullName property
            & $adb push "$($src.FullName)" "$dest" | Out-Null
        }
        else {
            # Pull
            $localDir = [System.IO.Path]::GetDirectoryName($dest)
            if (-not (Test-Path $localDir)) { New-Item -ItemType Directory -Path $localDir | Out-Null }
            & $adb pull "$src" "$dest" | Out-Null
        }
    }
    Write-Host " Done."
}

# Delete
if ($toDelete.Count -gt 0) {
    Write-Host "Deleting $($toDelete.Count) files..." -ForegroundColor Red
    
    if ($Mode -eq 'PC2Phone') {
        # Remote Delete from Phone
        $batch = @()
        foreach ($item in $toDelete) {
            $safePath = $item -replace "'", "\'"; $batch += "'$safePath'"
            if ($batch.Count -ge 50) {
                $list = $batch -join " "; & $adb shell "rm $list"; $batch = @(); Write-Host "." -NoNewline
            }
        }
        if ($batch.Count -gt 0) { $list = $batch -join " "; & $adb shell "rm $list" }
    }
    else {
        # Local Delete (PC) -> SMART MOVE DETECTION LOGIC
        
        # Build Index of Incoming Files
        # Key: "FileName|Length" -> Value: True
        $incomingIndex = @{}
        foreach ($inc in $toCopy) { 
            # In Phone2PC: Source=PhonePath, but we need SIZE. Dest=PCPath.
            # $phoneMap has size of Source.
            $sz = $phoneMap[$inc.Source]
            $nm = Split-Path $inc.Dest -Leaf
            $key = "$nm|$sz"
            $incomingIndex[$key] = $true
        }
        
        foreach ($item in $toDelete) {
            # $item is Local PC Path
            try {
                $fileObj = Get-Item $item -ErrorAction Stop
                $sigKey = "$($fileObj.Name)|$($fileObj.Length)"
                
                if ($incomingIndex.ContainsKey($sigKey)) {
                    # MOVE DETECTED -> Destroy Source
                    Remove-Item -Path $item -Force
                    Write-Host "X" -NoNewline
                    continue
                }
                
                # SOFT DELETE
                $parentDir = $fileObj.Directory
                if ($parentDir.Name -match "^_mobile|_gallery|_pc|Mobile|Gallery$") {
                    $trashDir = Join-Path -Path $parentDir.Parent.FullName -ChildPath "_trash"
                    if (-not (Test-Path $trashDir)) { New-Item -ItemType Directory -Path $trashDir -Force | Out-Null }
                    
                    $destPath = Join-Path -Path $trashDir -ChildPath $fileObj.Name
                    if (Test-Path $destPath) {
                        $destPath = Join-Path -Path $trashDir -ChildPath "$($fileObj.BaseName)_$(Get-Date -Format 'yyyyMMdd-HHmmss')$($fileObj.Extension)"
                    }
                    Move-Item -Path $item -Destination $destPath -Force
                    Write-Host "M" -NoNewline
                }
                else {
                    Rename-Item -Path $item -NewName "$($fileObj.Name).trash" -Force
                }
            }
            catch { Write-Host "!" -NoNewline }
        }
    }
    Write-Host " Done."
}

# Cleanup Empty Dirs
# Cleanup Empty Dirs (Both modes remove empty dirs on destination usually, but ADB find handles phone)
Write-Host "Cleaning empty directories on Phone..." -ForegroundColor Yellow
& $adb shell "find '$MobileDest' '$GalleryDest' -type d -empty -delete"

# Update Schema Map (Persist new folders found)
if ($pcDisks.Count -gt 0) {
    Save-DriveMap $folderSchema $pcDisks
    Write-Host "Drive Map Updated on: $($pcDisks -join ', ')" -ForegroundColor DarkGray
}

Write-Host "SYNC COMPLETE." -ForegroundColor Green
