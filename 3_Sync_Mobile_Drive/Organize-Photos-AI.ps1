# Intelligent Photo Organization
# Match folders from Pictures to E:\2025 and remove duplicates from Camera

Write-Host "=== INTELLIGENT PHOTO ORGANIZATION ===" -ForegroundColor Cyan

# PART 1: Analyze and match folders
Write-Host "`n1. ANALYZING FOLDER STRUCTURE..." -ForegroundColor Yellow

$picturesBase = "E:\_telefono_backup\Pictures"
$target2025 = "E:\2025"
$cameraPath = "E:\_telefono_backup\DCIM\Camera"

# Get folders
$pictureFolders = Get-ChildItem -Path $picturesBase -Directory | Where-Object { $_.Name -ne '.thumbnails' }
$target2025Folders = Get-ChildItem -Path $target2025 -Directory

Write-Host "Pictures folders: $($pictureFolders.Count)" -ForegroundColor Gray
Write-Host "E:\2025 folders: $($target2025Folders.Count)" -ForegroundColor Gray

# Create mapping using fuzzy matching
$matches = @()

foreach ($pFolder in $pictureFolders) {
    $bestMatch = $null
    $bestScore = 0
    
    foreach ($tFolder in $target2025Folders) {
        # Simple similarity: compare lowercase, remove spaces/special chars
        $pName = $pFolder.Name.ToLower() -replace '[^a-z0-9]', ''
        $tName = $tFolder.Name.ToLower() -replace '[^a-z0-9]', ''
        
        # Check if one contains the other or very similar
        if ($pName -eq $tName) {
            $score = 100
        }
        elseif ($pName.Contains($tName) -or $tName.Contains($pName)) {
            $score = 80
        }
        elseif ($pName.StartsWith($tName.Substring(0, [Math]::Min(4, $tName.Length)))) {
            $score = 60
        }
        else {
            $score = 0
        }
        
        if ($score -gt $bestScore -and $score -ge 60) {
            $bestScore = $score
            $bestMatch = $tFolder
        }
    }
    
    if ($bestMatch) {
        $matches += [pscustomobject]@{
            SourceFolder = $pFolder.FullName
            TargetFolder = $bestMatch.FullName
            SourceName   = $pFolder.Name
            TargetName   = $bestMatch.Name
            Confidence   = $bestScore
        }
    }
}

Write-Host "`nFound $($matches.Count) folder matches:" -ForegroundColor Green
$matches | Format-Table SourceName, TargetName, Confidence -AutoSize

# PART 2: Build file index to detect duplicates
Write-Host "`n2. BUILDING FILE INDEX..." -ForegroundColor Yellow

$allFiles = @{}

# Index E:\2025 files
Write-Host "Indexing E:\2025..." -NoNewline
$existing2025 = Get-ChildItem -Path $target2025 -Recurse -File -ErrorAction SilentlyContinue
foreach ($f in $existing2025) {
    $key = "$($f.Name)|$($f.Length)"
    $allFiles[$key] = $f.FullName
}
Write-Host " $($existing2025.Count) files" -ForegroundColor Gray

# PART 3: Move files from Pictures to 2025 (avoiding duplicates)
Write-Host "`n3. MOVING FILES FROM PICTURES TO E:\2025..." -ForegroundColor Yellow

$moved = 0
$skipped = 0

foreach ($match in $matches) {
    $sourceFiles = Get-ChildItem -Path $match.SourceFolder -Recurse -File -ErrorAction SilentlyContinue
    
    Write-Host "`n  Processing $($match.SourceName) -> $($match.TargetName) ($($sourceFiles.Count) files)..." -ForegroundColor Cyan
    
    foreach ($file in $sourceFiles) {
        $key = "$($file.Name)|$($file.Length)"
        
        if ($allFiles.ContainsKey($key)) {
            # Duplicate - skip
            $skipped++
            Write-Host "    SKIP (duplicate): $($file.Name)" -ForegroundColor DarkGray
        }
        else {
            # Move to target
            $destPath = Join-Path $match.TargetFolder $file.Name
            
            try {
                Move-Item $file.FullName $destPath -Force -ErrorAction Stop
                $allFiles[$key] = $destPath
                $moved++
                Write-Host "    MOVE: $($file.Name)" -ForegroundColor Green
            }
            catch {
                Write-Host "    ERROR: $($file.Name)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`nPictures organization:" -ForegroundColor Cyan
Write-Host "  Files moved: $moved" -ForegroundColor Green
Write-Host "  Duplicates skipped: $skipped" -ForegroundColor Yellow

# PART 4: Find and remove duplicates between Camera and Pictures
Write-Host "`n4. FINDING DUPLICATES CAMERA vs PICTURES..." -ForegroundColor Yellow

if (Test-Path $cameraPath) {
    $cameraFiles = Get-ChildItem -Path $cameraPath -File -ErrorAction SilentlyContinue
    Write-Host "Camera files: $($cameraFiles.Count)" -ForegroundColor Gray
    
    $duplicatesFound = 0
    $duplicatesDeleted = 0
    
    foreach ($cFile in $cameraFiles) {
        $key = "$($cFile.Name)|$($cFile.Length)"
        
        if ($allFiles.ContainsKey($key)) {
            $duplicatesFound++
            
            Write-Host "  DELETE (duplicate): $($cFile.Name)" -ForegroundColor Red
            
            try {
                Remove-Item $cFile.FullName -Force -ErrorAction Stop
                $duplicatesDeleted++
            }
            catch {
                Write-Host "    ERROR deleting" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`nCamera cleanup:" -ForegroundColor Cyan
    Write-Host "  Duplicates found: $duplicatesFound" -ForegroundColor Yellow
    Write-Host "  Duplicates deleted: $duplicatesDeleted" -ForegroundColor Green
}
else {
    Write-Host "Camera folder not found" -ForegroundColor Gray
}

Write-Host "`n=== ORGANIZATION COMPLETE ===" -ForegroundColor Green
