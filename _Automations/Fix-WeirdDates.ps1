param(
    [string[]]$RootPaths = @("E:\", "D:\"),
    [string]$ExifToolPath = "C:\Windows\exiftool.exe",
    [switch]$Execute = $false
)

$ErrorActionPreference = 'SilentlyContinue'
$WeirdYearsRegex = "^(19\d{2}|20[3-9]\d|2000)$" # Matches 19xx, 2030-2099, and 2000 (often default reset date)
$ValidYearMin = 2001
$ValidYearMax = 2026

function Get-RealDate {
    param($FileItem)
    
    $date = $null

    # 1. Filename Pattern (Very reliable for WA/Phone)
    # Matches YYYYMMDD or YYYY-MM-DD
    if ($FileItem.Name -match "(20\d{2})[-_]?(\d{2})[-_]?(\d{2})") {
        try {
            $y = [int]$matches[1]
            $m = [int]$matches[2]
            $d = [int]$matches[3]
            if ($y -ge $ValidYearMin -and $y -le $ValidYearMax -and $m -ge 1 -and $m -le 12 -and $d -le 31) {
                # Construct datetime
                $date = Get-Date -Year $y -Month $m -Day $d -Hour 12 -Minute 0 -Second 0
                return $date
            }
        }
        catch {}
    }

    # 2. ExifTool (if available)
    if (Test-Path $ExifToolPath) {
        # Quick shell to exiftool to get CreateDate
        $res = & $ExifToolPath -s3 -d "%Y-%m-%d %H:%M:%S" -DateTimeOriginal -CreateDate -MediaCreateDate "$($FileItem.FullName)" 2>$null
        if ($res) {
            # Take first valid line
            foreach ($line in $res) {
                if ($line -match "^(20\d{2})-(\d{2})-(\d{2})") {
                    $y = [int]$matches[1]
                    if ($y -ge $ValidYearMin -and $y -le $ValidYearMax) {
                        return [DateTime]$line
                    }
                }
            }
        }
    }

    # 3. LastWriteTime (sanity check)
    if ($FileItem.LastWriteTime.Year -ge $ValidYearMin -and $FileItem.LastWriteTime.Year -le $ValidYearMax) {
        return $FileItem.LastWriteTime
    }

    return $null
}

Write-Host "=== FIXING WEIRD DATES (YEARS < $ValidYearMin OR > $ValidYearMax) ===" -ForegroundColor Cyan
if ($Execute) { Write-Host "WARNING: EXECUTION MODE - files will be modified/moved!" -ForegroundColor Red }
else { Write-Host "INFO: PREVIEW MODE" -ForegroundColor Yellow }

foreach ($root in $RootPaths) {
    if (-not (Test-Path $root)) { continue }
    
    # Find Weird Year Folders
    $weirdFolders = Get-ChildItem $root -Directory | Where-Object { $_.Name -match $WeirdYearsRegex }
    
    foreach ($wf in $weirdFolders) {
        Write-Host "Checking Weird Folder: $($wf.FullName)" -ForegroundColor Magenta
        
        $files = Get-ChildItem $wf.FullName -Recurse -File
        
        foreach ($file in $files) {
            $realDate = Get-RealDate -FileItem $file
            
            if ($realDate) {
                $targetYear = $realDate.Year
                Write-Host "  File: $($file.Name)"
                Write-Host "    Current Date: $($file.LastWriteTime)"
                Write-Host "    DETECTED REAL DATE: $realDate (Year $targetYear)" -ForegroundColor Green
                
                if ($Execute) {
                    # 1. Fix File Date
                    $file.LastWriteTime = $realDate
                    $file.CreationTime = $realDate
                    
                    # 2. Move to Correct Location
                    # Reconstruct path structure relative to the weird folder
                    # e.g. E:\1980\Spagna\file.jpg -> E:\2023\Spagna\file.jpg
                    
                    $relativePath = $file.DirectoryName.Substring($wf.FullName.Length)
                    if ($relativePath.StartsWith("\")) { $relativePath = $relativePath.Substring(1) }
                    
                    # If relative path is empty (file at root of weird folder), just use filename? 
                    # Usually weird folders are E:\1980\EventName...
                    # So we want E:\TargetYear\EventName
                    
                    $targetRoot = Join-Path $root "$targetYear"
                    if (-not (Test-Path $targetRoot)) { New-Item -Path $targetRoot -ItemType Directory | Out-Null }
                    
                    $destDir = Join-Path $targetRoot $relativePath
                    if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory | Out-Null }
                    
                    $destFile = Join-Path $destDir $file.Name
                    
                    # Handle Collision
                    if (Test-Path $destFile) {
                        Write-Host "    [SKIP] Destination exists: $destFile" -ForegroundColor Red
                    }
                    else {
                        Move-Item -Path $file.FullName -Destination $destFile
                        Write-Host "    -> Moved to $destFile" -ForegroundColor Cyan
                    }
                }
            }
            else {
                Write-Host "  File: $($file.Name) - COULD NOT DETERMINE DATE." -ForegroundColor Gray
            }
        }
        
        # Cleanup Empty Folders
        if ($Execute) {
            $remaining = Get-ChildItem $wf.FullName -Recurse -File
            if ($remaining.Count -eq 0) {
                Write-Host "  Folder Empty. Deleting $($wf.Name)..." -ForegroundColor Yellow
                Remove-Item $wf.FullName -Recurse -Force
            }
            else {
                Write-Host "  Folder not empty ($($remaining.Count) files remain)."
            }
        }
    }
}
