# CREATE MISSING .nomedia FILES ON PHONE
# This fixes the popup issue by pre-creating .nomedia files before sync

param(
    [string]$PhoneBasePath = "PC\Pixel 8\Memoria condivisa interna\SSD"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CREATE .nomedia FILES ON PHONE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Connect to phone
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
    Write-Host "[OK] Connected to: $PhoneBasePath" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "[ERROR] Cannot connect to phone" -ForegroundColor Red
    exit 1
}

# Function to find all Mobile folders recursively
function Find-MobileFolders($folder, $path = '') {
    $results = @()
    foreach ($item in $folder.Items()) {
        if ($item.IsFolder) {
            $currentPath = if ($path) { "$path\$($item.Name)" } else { $item.Name }
            
            # Check if this is a Mobile folder
            if ($item.Name -eq 'Mobile') {
                $results += [pscustomobject]@{
                    Path = $currentPath
                    Folder = $shell.Namespace($item)
                }
            }
            
            # Recurse into subfolders
            $subFolder = $shell.Namespace($item)
            if ($subFolder) {
                $results += Find-MobileFolders $subFolder $currentPath
            }
        }
    }
    return $results
}

Write-Host "Scanning for Mobile folders..." -ForegroundColor Cyan
$mobileFolders = @(Find-MobileFolders $phoneRoot)

Write-Host "Found $($mobileFolders.Count) Mobile folders" -ForegroundColor Green
Write-Host ""

if ($mobileFolders.Count -eq 0) {
    Write-Host "[OK] No Mobile folders found (nothing to do)" -ForegroundColor Gray
    exit 0
}

# Check each Mobile folder for .nomedia
$created = 0
$existing = 0

foreach ($mf in $mobileFolders) {
    $hasNomedia = $false
    
    # Check if .nomedia exists
    foreach ($item in $mf.Folder.Items()) {
        if ($item.Name -eq '.nomedia') {
            $hasNomedia = $true
            break
        }
    }
    
    if ($hasNomedia) {
        Write-Host "[SKIP] $($mf.Path)\.nomedia (already exists)" -ForegroundColor Gray
        $existing++
    } else {
        Write-Host "[CREATE] $($mf.Path)\.nomedia" -ForegroundColor Yellow
        
        # Create .nomedia file
        # We need to create it on PC first, then copy to phone
        $tempFile = [System.IO.Path]::GetTempFileName()
        $nomediaFile = [System.IO.Path]::ChangeExtension($tempFile, '.nomedia')
        
        # Create empty .nomedia
        Set-Content -Path $nomediaFile -Value $null -NoNewline
        
        try {
            # Copy to phone folder
            $mf.Folder.CopyHere($nomediaFile, 16) # 16 = no UI
            Start-Sleep -Milliseconds 500 # Wait for copy
            Remove-Item $nomediaFile -Force
            
            Write-Host "  [OK] Created" -ForegroundColor Green
            $created++
        } catch {
            Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red
            Remove-Item $nomediaFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Created: $created" -ForegroundColor Green
Write-Host "  Already existed: $existing" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($created -gt 0) {
    Write-Host "SUCCESS! You can now run Sync-Mobile.ps1 without popups." -ForegroundColor Green
} else {
    Write-Host "All .nomedia files already exist." -ForegroundColor Gray
}
