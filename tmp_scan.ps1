param([string]$Path, [int]$ExpectedYear = 0)
$files = Get-ChildItem $Path -Recurse -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|mp4|mov|png|heic|avi|mkv|3gp)$' }
Write-Host "Totale: $($files.Count) file"
$sorted = $files | Sort-Object LastWriteTime
Write-Host "Primo:  $($sorted[0].LastWriteTime.ToString('yyyy-MM-dd'))  $($sorted[0].Name)"
Write-Host "Ultimo: $($sorted[-1].LastWriteTime.ToString('yyyy-MM-dd'))  $($sorted[-1].Name)"
Write-Host ""
$files | Group-Object { $_.LastWriteTime.ToString('yyyy-MM') } | Sort-Object Name | ForEach-Object {
    "$($_.Name)  ->  $($_.Count) file"
}
if ($ExpectedYear -gt 0) {
    Write-Host ""
    $outliers = $files | Where-Object { $_.LastWriteTime.Year -ne $ExpectedYear }
    if ($outliers) {
        Write-Host "Outlier (anno != $ExpectedYear):"
        $outliers | Sort-Object LastWriteTime | Select-Object Name, @{n='Data';e={$_.LastWriteTime.ToString('yyyy-MM-dd')}} | Format-Table -AutoSize
    } else { Write-Host "Nessun outlier." }
}
