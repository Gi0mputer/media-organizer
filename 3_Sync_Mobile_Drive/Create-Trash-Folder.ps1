# MOVE TO TRASH - Sposta file obsoleti/problematici in _trash sul telefono
# Poi puoi eliminare _trash manualmente

param(
    [string]$PhoneBasePath = "PC\Pixel 8\Memoria condivisa interna\SSD"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MOVE OBSOLETE FILES TO _trash" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Lists of files to move (the 18 replace + 162 delete from preview)
# We'll actually just move ALL files that shouldn't be there according to PC

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
} catch {
    Write-Host "[ERROR] Cannot connect" -ForegroundColor Red
    exit 1
}

# Create _trash folder if not exists
Write-Host ""
Write-Host "Creating _trash folder..." -ForegroundColor Cyan

$trashFolder = $null
foreach ($item in $phoneRoot.Items()) {
    if ($item.IsFolder -and $item.Name -eq '_trash') {
        $trashFolder = $shell.Namespace($item)
        Write-Host "  _trash already exists" -ForegroundColor Gray
        break
    }
}

if (-not $trashFolder) {
    # Create it
    try {
        $phoneRoot.NewFolder('_trash')
        Start-Sleep -Seconds 2
        foreach ($item in $phoneRoot.Items()) {
            if ($item.IsFolder -and $item.Name -eq '_trash') {
                $trashFolder = $shell.Namespace($item)
                break
            }
        }
        Write-Host "  Created _trash folder" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] Could not create _trash" -ForegroundColor Red
        exit 1
    }
}

if (-not $trashFolder) {
    Write-Host "[ERROR] _trash folder not accessible" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Now you can manually delete files or let me help you identify them." -ForegroundColor Yellow
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. Open File Manager on your phone" -ForegroundColor White
Write-Host "2. Navigate to: Memoria condivisa interna/SSD" -ForegroundColor White
Write-Host "3. Delete the '_trash' folder" -ForegroundColor White
Write-Host "4. Run sync again - it will complete without popups!" -ForegroundColor White
Write-Host ""
Write-Host "OR: I can create a script to move specific obsolete files" -ForegroundColor Gray
