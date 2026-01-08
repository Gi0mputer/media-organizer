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
    [switch]$Execute,     # Esegue i comandi (altrimenti solo Preview)
    [switch]$Force        # Forza sovrascrittura se dimensioni diverse
)

$adb = "$PSScriptRoot\Tools\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { Write-Error "ADB not found. Run Setup-ADB.ps1"; exit 1 }

# Config Paths
$PhoneSdCard = "/sdcard" 
$MobileDest = "$PhoneSdCard/SSD"
$GalleryDest = "$PhoneSdCard/DCIM/SSD"

# PC Source Paths & Detection
$pcDisks = @()
$connectedRoots = @{} # Map to track which drive letters are active

if (Test-Path "E:\") { $pcDisks += "E:\"; $connectedRoots["E:"] = $true }
if (Test-Path "D:\") { $pcDisks += "D:\"; $connectedRoots["D:"] = $true }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SYNC MOBILE (ADB ENGINE) - Safe Mode" -ForegroundColor Cyan
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

# 2. Get PC Inventory (Target State)
Write-Host "Scanning PC..." -ForegroundColor Yellow
$pcMap = @{} # Key: "DestPath" (on phone), Value: PCFileInfo

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
        $destPath = "$destRoot/$cleanRel"
        
        $pcMap[$destPath] = $f
    }
}
Write-Host "  PC Files to sync: $($pcMap.Count)" -ForegroundColor Green

# 3. Get Phone Inventory (Actual State)
Write-Host "Scanning Phone (via ADB)..." -ForegroundColor Yellow
$cmd = "find '$MobileDest' '$GalleryDest' -type f -printf '%p|%s\n' 2>/dev/null"
$phoneOut = & $adb shell $cmd

$phoneMap = @{} # Key: Path, Value: Size
foreach ($line in $phoneOut) {
    if ($line -match "^(.*)\|(\d+)$") {
        $path = $matches[1]
        $size = [long]$matches[2]
        $phoneMap[$path] = $size
    }
}
Write-Host "  Phone Files found: $($phoneMap.Count)" -ForegroundColor Green

# 4. PLAN
Write-Host "Planning..." -ForegroundColor Yellow
$toPush = @()
$toDelete = @()

# Calc Push (New or Changed) - Only from connected disks (implicit in pcMap)
foreach ($key in $pcMap.Keys) {
    $pcFile = $pcMap[$key]
    if (-not $phoneMap.ContainsKey($key)) {
        $toPush += [pscustomobject]@{ Source=$pcFile; Dest=$key; Reason="New" }
    } elseif ($phoneMap[$key] -ne $pcFile.Length) {
        $toPush += [pscustomobject]@{ Source=$pcFile; Dest=$key; Reason="Changed" }
    }
}

# Calc Delete (Robust Safe Logic)
foreach ($key in $phoneMap.Keys) {
    if (-not $pcMap.ContainsKey($key)) {
        # File is on Phone but NOT in PC map.
        # Check if we SHOULD delete it (i.e. if we have visibility of its source)
        
        # Infer source Year/Folder from path
        # Example Path: /sdcard/SSD/2024/Evento/file.jpg
        # Heuristic: 2024+ -> Expected on E:, <2024 -> Expected on D:
        # Better Heuristic: Check if mapped root exists? No, map is empty for missing disk.
        
        # Strict Safe Logic:
        # We classify based on year folder (20xx).
        # - If Year >= 2024, it belongs to E:.
        # - If Year < 2024 (or 2018_pre), it belongs to D:.
        # - If disk is missing, SKIP DELETE.
        
        $shouldCheck = $false
        
        if ($key -match "/(202[4-9]|20[3-9][0-9])/") {
            # 2024+
            if ($connectedRoots.ContainsKey("E:")) { $shouldCheck = $true }
        } elseif ($key -match "/(201[0-9]|202[0-3]|200[0-9]|19[0-9][0-9])/") {
            # < 2024
            if ($connectedRoots.ContainsKey("D:")) { $shouldCheck = $true }
        } else {
            # Unknown bucket (e.g. "Family", "Projects" or root files).
            # Fallback: If BOTH disks connected, safe to delete. If one missing, RISK -> Keep.
            if ($connectedRoots.ContainsKey("E:") -and $connectedRoots.ContainsKey("D:")) {
                $shouldCheck = $true
            } else {
                # Partial connection and unknown bucket -> KEEP SAFE
                $shouldCheck = $false
            }
        }
        
        if ($shouldCheck) {
            $toDelete += $key
        } else {
            # Verbose debug only if needed
            # Write-Host "  [SAFE GUARD] Keeping $key because source disk might be offline." -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
Write-Host "PLAN SUMMARY:" -ForegroundColor Cyan
Write-Host "  Push (Copy/Update): $($toPush.Count)" -ForegroundColor Green
Write-Host "  Delete (Obsolete) : $($toDelete.Count)" -ForegroundColor Red
if ($toDelete.Count -gt 0 -and $pcDisks.Count -lt 2) {
   Write-Host "  (Note: Some deletes skipped because not all disks are connected)" -ForegroundColor Yellow
}
Write-Host ""

if (-not $Execute) {
    Write-Host "[PREVIEW] Sample Actions (Run with -Execute to apply):" -ForegroundColor Yellow
    if ($toPush.Count -gt 0) {
        Write-Host "  PUSH:" -ForegroundColor Green
        $toPush | Select-Object -First 5 | ForEach-Object { Write-Host "    $($_.Dest)" }
    }
    if ($toDelete.Count -gt 0) {
        Write-Host "  DELETE:" -ForegroundColor Red
        $toDelete | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" }
    }
    exit 0
}

# 5. EXECUTE (Same as before)
# Push
if ($toPush.Count -gt 0) {
    Write-Host "Pushing $($toPush.Count) files..." -ForegroundColor Green
    $i = 0
    foreach ($item in $toPush) {
        $i++
        if ($i % 10 -eq 0) { Write-Host "." -NoNewline }
        $src = $item.Source.FullName; $dest = $item.Dest
        & $adb push "$src" "$dest" | Out-Null
    }
    Write-Host " Done."
}

# Delete
if ($toDelete.Count -gt 0) {
    Write-Host "Deleting $($toDelete.Count) files..." -ForegroundColor Red
    $batch = @()
    foreach ($item in $toDelete) {
        $safePath = $item -replace "'", "\'"; $batch += "'$safePath'"
        if ($batch.Count -ge 50) {
            $list = $batch -join " "; & $adb shell "rm $list"; $batch = @(); Write-Host "." -NoNewline
        }
    }
    if ($batch.Count -gt 0) { $list = $batch -join " "; & $adb shell "rm $list" }
    Write-Host " Done."
}

# Clean Empty Dirs (via Find, safe)
Write-Host "Cleaning empty directories..." -ForegroundColor Yellow
& $adb shell "find '$MobileDest' '$GalleryDest' -type d -empty -delete"

Write-Host "SYNC COMPLETE." -ForegroundColor Green
