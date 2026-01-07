$shell = New-Object -ComObject Shell.Application
$pc = $shell.Namespace(0x11)

Write-Host "=== MTP DEVICES CHECK ===" -ForegroundColor Cyan
Write-Host ""

foreach ($item in $pc.Items()) {
    Write-Host "Device: $($item.Name)" -ForegroundColor Green
    
    if ($item.Name -like "*Pixel*") {
        Write-Host "  ^ This is your phone!" -ForegroundColor Yellow
        
        $phoneFolder = $shell.Namespace($item)
        if ($phoneFolder) {
            Write-Host "  Children:" -ForegroundColor Gray
            foreach ($child in $phoneFolder.Items()) {
                Write-Host "    - $($child.Name)" -ForegroundColor White
            }
        }
    }
}

Write-Host ""
Write-Host "If Pixel 8 is not listed, please:" -ForegroundColor Yellow
Write-Host "1. Unlock the phone" -ForegroundColor White
Write-Host "2. Reconnect the USB cable" -ForegroundColor White
Write-Host "3. Select 'File Transfer' mode on the phone" -ForegroundColor White
