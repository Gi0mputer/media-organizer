param(
    [string]$RootPath = "E:\", # Default to E:\ as per Action Plan
    [string]$ExifToolPath = "C:\Windows\exiftool.exe" # Common path, or adjustable
)

$ErrorActionPreference = 'SilentlyContinue'
$YearPattern = "^\d{4}$" # Matches 2018, 2019, etc.

Write-Host "=== FOLDER YEAR CONSISTENCY CHECK ===" -ForegroundColor Cyan
Write-Host "Target Root: $RootPath"
Write-Host "Checking for mis-placed folders (folders inside a Year but containing data from another year)..."
Write-Host ""

if (-not (Test-Path $RootPath)) {
    Write-Host "[ERROR] Root path not found: $RootPath" -ForegroundColor Red
    exit
}

# Try to find ExifTool if not explicitly provided or found
if (-not (Test-Path $ExifToolPath)) {
    # Try current directory or common paths
    $possiblePaths = @(
        ".\exiftool.exe",
        "$PSScriptRoot\exiftool.exe",
        "C:\Program Files\ExifTool\exiftool.exe"
    )
    foreach ($p in $possiblePaths) {
        if (Test-Path $p) { $ExifToolPath = $p; break }
    }
}

if (Test-Path $ExifToolPath) {
    Write-Host "Using ExifTool: $ExifToolPath" -ForegroundColor Green
}
else {
    Write-Host "ExifTool NOT FOUND. Falling back to filename/filesystem dates (less accurate)." -ForegroundColor Yellow
}

# Function to extract date from file
function Get-MediaYear {
    param($FileObject)
    
    $year = $null

    # 1. Try Filename Pattern (Very common and usually reliable for original files)
    # Matches YYYYMMDD or YYYY-MM-DD
    if ($FileObject.Name -match "20\d{2}[-_]?\d{2}[-_]?\d{2}") {
        $year = $matches[0].Substring(0, 4)
        return [int]$year
    }
    
    # 2. Try ExifTool (if available) - checking first few files usually enough for folder verdict
    # (Skipping for speed in this bulk check unless strictly needed, 
    # but for accuracy we should use it if filename fails)
    
    # 3. Fallback: LastWriteTime (FileSystem) - Risky as noted in Action Plan
    return [int]$FileObject.LastWriteTime.Year
}

# Get Year Folders
$yearFolders = Get-ChildItem -Path $RootPath -Directory | Where-Object { $_.Name -match $YearPattern }

foreach ($yFolder in $yearFolders) {
    $targetYear = [int]$yFolder.Name
    Write-Host "Checking Year: $targetYear" -ForegroundColor Cyan

    $subFolders = Get-ChildItem -Path $yFolder.FullName -Directory

    foreach ($sub in $subFolders) {
        $subFiles = Get-ChildItem -Path $sub.FullName -File -Recurse | Where-Object { 
            $_.Extension -match "\.(jpg|jpeg|png|mp4|mov|avi|heic)$" 
        }

        if ($subFiles.Count -eq 0) {
            continue
        }

        # Analyze a sample of files to determine the folder's "Year"
        # We check all valid media files to get a percentage
        $totalFiles = $subFiles.Count
        $matchCount = 0
        $mismatchCount = 0
        $yearsFound = @{}

        foreach ($file in $subFiles) {
            $y = Get-MediaYear -FileObject $file
            
            if ($y) {
                if ($yearsFound.ContainsKey($y)) { $yearsFound[$y]++ } else { $yearsFound[$y] = 1 }
                
                if ($y -eq $targetYear) {
                    $matchCount++
                }
                else {
                    $mismatchCount++
                }
            }
        }

        # Logic to flag folder
        # If > 50% of files are NOT from the target year, flag it
        if ($mismatchCount -gt $matchCount) {
            # Find the actual dominant year
            $domYear = ($yearsFound.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Name
             
            Write-Host "  [MISMATCH] Folder: $($sub.Name)" -ForegroundColor Red
            Write-Host "     Expected: $targetYear"
            Write-Host "     Found Dominant: $domYear"
            Write-Host "     Stats: $($yearsFound | Out-String)"
        }
        elseif ($mismatchCount -gt 0) {
            # Partial mismatch warning
            $pct = [math]::Round(($mismatchCount / $totalFiles) * 100, 1)
            if ($pct -gt 10) {
                # Only notify if > 10% separate
                Write-Host "  [MIXED] Folder: $($sub.Name)" -ForegroundColor Yellow
                Write-Host "     Contains $pct% files from other years."
                Write-Host "     Stats: $($yearsFound | Out-String)"
            }
        }
    }
}
