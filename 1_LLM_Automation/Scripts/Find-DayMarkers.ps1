# Quick script to find day marker folders
param([string]$ScanPath = 'E:\')

Get-ChildItem -Path $ScanPath -Directory -Recurse -ErrorAction SilentlyContinue | 
Where-Object { $_.Name -match '^(1day|[2-9]day)(_\d+)?$' } | 
Select-Object FullName, Name | 
Format-Table -AutoSize
