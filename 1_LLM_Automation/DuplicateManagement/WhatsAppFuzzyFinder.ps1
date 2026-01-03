param(
    [string]$RootPath = "D:\",
    [string]$ReportFile = "$env:USERPROFILE\Desktop\WhatsApp_FuzzyAnalysis.txt"
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "=== WHATSAPP FUZZY FINDER ===" -ForegroundColor Cyan
Write-Host "Scanning $RootPath for potential original-vs-whatsapp pairs..."

# 1. Gather Files
$allFiles = Get-ChildItem -Path $RootPath -Recurse -File -Include "*.mp4", "*.mov"
$waFiles = $allFiles | Where-Object { $_.Name -match "WA\d+|WhatsApp" }
$potentialOrigins = $allFiles | Where-Object { $_.Name -notmatch "WA\d+|WhatsApp" }

Write-Host "  Found $($waFiles.Count) WA videos."
Write-Host "  Found $($potentialOrigins.Count) potential original videos."

$matches = @()

# Helper to get numeric duration (cached ideally, but simplified here)
function Get-Dur {
    param($P)
    $res = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$P" 2>$null
    if ($res) { return [double]$res } else { return 0 }
}

$counter = 0
foreach ($wa in $waFiles) {
    $counter++
    if ($counter % 10 -eq 0) { Write-Progress -Activity "Matching WA Files" -Status "$counter / $($waFiles.Count)" -PercentComplete (($counter / $waFiles.Count) * 100) }
    
    $waDur = Get-Dur $wa.FullName
    if ($waDur -eq 0) { continue }

    # Look for candidates
    # Rules:
    # 1. Must be in same Directory OR Parent Directory
    # 2. Duration roughly equal (+- 2 seconds)
    # 3. NOT the same file
    
    $candidates = $potentialOrigins | Where-Object { 
        ($_.DirectoryName -eq $wa.DirectoryName) -or ($_.DirectoryName -eq $wa.Directory.Parent.FullName)
    }

    foreach ($cand in $candidates) {
        $candDur = Get-Dur $cand.FullName
        $diff = [math]::Abs($candDur - $waDur)
        
        if ($diff -lt 2.0) {
            # 2 seconds tolerance
            $matches += [PSCustomObject]@{
                WhatsAppFile = $wa.Name
                OriginalFile = $cand.Name
                Folder       = $wa.DirectoryName
                DurationDiff = [math]::Round($diff, 2)
                SizeWA_MB    = [math]::Round($wa.Length / 1MB, 2)
                SizeOrig_MB  = [math]::Round($cand.Length / 1MB, 2)
            }
        }
    }
}

Write-Host ""
Write-Host "Found $($matches.Count) potential pairs." -ForegroundColor Green

$matches | Format-Table -AutoSize | Out-String | Write-Host

$matches | Export-Csv -Path "$env:USERPROFILE\Desktop\WA_Matches.csv" -NoTypeInformation
Write-Host "Full CSV report at: $env:USERPROFILE\Desktop\WA_Matches.csv"
