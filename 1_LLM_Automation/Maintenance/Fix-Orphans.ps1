param(
    [string[]]$RootPaths = @("E:\", "D:\"),
    [switch]$Execute = $false
)

$ErrorActionPreference = 'SilentlyContinue'

function Get-ArchiveRootForYear {
    param([int]$Year)
    if ($Year -ge 2024) { return "E:\" }
    return "D:\"
}

Write-Host "=== FIXING ORPHAN FOLDERS ===" -ForegroundColor Cyan
if ($Execute) { Write-Host "WARNING: EXECUTION MODE - Moving folders..." -ForegroundColor Red }
else { Write-Host "INFO: PREVIEW MODE - Use -Execute to apply changes" -ForegroundColor Yellow }

foreach ($root in $RootPaths) {
    if (-not (Test-Path $root)) { continue }
    
    # Get Year Folders (e.g., 2018 e pre, 2019, 2020...)
    $YearFolders = Get-ChildItem $root -Directory | Where-Object { $_.Name -match "^(20\d{2}|19\d{2})" }

    foreach ($yf in $YearFolders) {
        $parentYearName = $yf.Name
        
        $eventFolders = Get-ChildItem $yf.FullName -Directory
        
        foreach ($eventFolder in $eventFolders) {
            # Look for nested year folders (Orphans)
            $orphans = Get-ChildItem $eventFolder.FullName -Directory | Where-Object { $_.Name -match "^\d{4}$" }
            
            foreach ($orphan in $orphans) {
                # Source: E:\2019\Lucca\2020
                # Target Year: 2020
                # Event Name: Lucca
                # Desired Dest: E:\2020\Lucca
                
                $targetYear = $orphan.Name
                $eventName = $eventFolder.Name
                $sourcePath = $orphan.FullName
                
                # Construct Destination Path
                # Note: Choose disk root based on year (pre-2024 -> D:\, 2024+ -> E:\)
                $targetRoot = $null
                try { $targetRoot = Get-ArchiveRootForYear -Year ([int]$targetYear) } catch { $targetRoot = $root }
                $targetYearRoot = Join-Path $targetRoot $targetYear
                $destPath = Join-Path $targetYearRoot $eventName
                
                Write-Host "Found Orphan: $sourcePath"
                
                if ($targetYear -eq $parentYearName -or ($parentYearName -match "^$targetYear")) {
                    # CASE 1: Same Year (Redundant nesting)
                    # E:\2019\Lucca\2019 -> Move contents to E:\2019\Lucca
                    Write-Host "  -> MERGE UP (Redundant): Move contents to $eventFolder" -ForegroundColor Green
                    
                    if ($Execute) {
                        Get-ChildItem $sourcePath | Move-Item -Destination $eventFolder.FullName -Force
                        Remove-Item $sourcePath -Force
                    }
                }
                else {
                    # CASE 2: Different Year (Move to correct year root)
                    # E:\2019\Lucca\2020 -> Move to E:\2020\Lucca
                    Write-Host "  -> PROMOTE: Move to $destPath" -ForegroundColor Cyan
                    
                    if ($Execute) {
                        # Ensure Root Year Folder Exists (E:\2020)
                        if (-not (Test-Path $targetYearRoot)) {
                            New-Item -Path $targetYearRoot -ItemType Directory | Out-Null
                        }
                        
                        # Check if Destination Event Folder Exists (E:\2020\Lucca)
                        if (Test-Path $destPath) {
                            # If it exists, we must merge contents
                            Write-Host "     (Destination exists, merging contents)" -ForegroundColor Gray
                            Get-ChildItem $sourcePath | Move-Item -Destination $destPath -Force
                            Remove-Item $sourcePath -Force
                        }
                        else {
                            # If it doesn't exist, we can just move the directory
                            Move-Item -Path $sourcePath -Destination $destPath
                        }
                    }
                }
            }
        }
    }
}
