# Transfer unique Insta360 files from phone to PC

$adb = "$PSScriptRoot\Tools\platform-tools\adb.exe"
$destFolder = "E:\_telefono_backup\Insta360"

# Load final report
$report = Get-Content "$PSScriptRoot\insta360_final_report.json" | ConvertFrom-Json

Write-Host "=== TRANSFERRING INSTA360 FILES ===" -ForegroundColor Cyan
Write-Host "Files to transfer: $($report.TrulyUnique.Count)" -ForegroundColor Yellow
Write-Host "Destination: $destFolder`n" -ForegroundColor Gray

$i = 0
$errors = 0

foreach ($file in $report.TrulyUnique) {
    $i++
    $destPath = Join-Path $destFolder $file.Name
    
    Write-Host "[$i/$($report.TrulyUnique.Count)] $($file.Name) " -NoNewline
    
    try {
        & $adb pull "$($file.PhonePath)" "$destPath" 2>&1 | Out-Null
        
        if (Test-Path $destPath) {
            Write-Host "OK" -ForegroundColor Green
        }
        else {
            Write-Host "FAILED" -ForegroundColor Red
            $errors++
        }
    }
    catch {
        Write-Host "ERROR" -ForegroundColor Red
        $errors++
    }
}

Write-Host "`nTransfer complete!" -ForegroundColor Cyan
Write-Host "  Success: $($i - $errors)" -ForegroundColor Green
Write-Host "  Errors: $errors" -ForegroundColor Red
