$folder = "F:\2025\arezzo"

$files = @(
    @{ Old="IMG-20250620-WA0030.jpg"; Date="2025:06:20 12:00:00"; New="20250620_Arezzo_01.jpg" },
    @{ Old="IMG-20250620-WA0031.jpg"; Date="2025:06:20 12:00:00"; New="20250620_Arezzo_02.jpg" },
    @{ Old="PXL_20250620_180710568.MP.jpg"; Date="2025:06:20 18:07:10"; New="20250620_Arezzo_03.jpg" },
    @{ Old="PXL_20250620_203755879.mp4"; Date="2025:06:20 20:37:55"; New="20250620_Arezzo_04.mp4" },
    @{ Old="PXL_20250620_223508548.mp4"; Date="2025:06:20 22:35:08"; New="20250620_Arezzo_05.mp4" },
    @{ Old="PXL_20250620_234601545.MP.jpg"; Date="2025:06:20 23:46:01"; New="20250620_Arezzo_06.jpg" },
    @{ Old="PXL_20250621_003055676.mp4"; Date="2025:06:21 00:30:55"; New="20250621_Arezzo_01.mp4" },
    @{ Old="PXL_20250621_015749164.NIGHT.jpg"; Date="2025:06:21 01:57:49"; New="20250621_Arezzo_02.jpg" },
    @{ Old="PXL_20250621_145106467.mp4"; Date="2025:06:21 14:51:06"; New="20250621_Arezzo_03.mp4" },
    @{ Old="PXL_20250621_173425485.mp4"; Date="2025:06:21 17:34:25"; New="20250621_Arezzo_04.mp4" },
    @{ Old="PXL_20250622_1348226551.mp4"; Date="2025:06:22 13:48:22"; New="20250622_Arezzo_01.mp4" },
    @{ Old="PXL_20250622_150601086.MP.jpg"; Date="2025:06:22 15:06:01"; New="20250622_Arezzo_02.jpg" },
    @{ Old="Abbandonato.mp4"; Date="2025:06:22 23:59:01"; New="20250622_Arezzo_03.mp4" },
    @{ Old="IMG-20250707-WA0016.jpg"; Date="2025:06:22 23:59:02"; New="20250622_Arezzo_04.jpg" },
    @{ Old="VID-20250731-WA0061.mp4"; Date="2025:06:22 23:59:03"; New="20250622_Arezzo_05.mp4" }
)

foreach ($f in $files) {
    $fullOld = Join-Path $folder $f.Old
    $fullNew = Join-Path $folder $f.New
    $date = $f.Date
    
    if (-not (Test-Path $fullOld)) {
        Write-Host "File not found: $($f.Old)" -ForegroundColor Red
        continue
    }

    $ext = [System.IO.Path]::GetExtension($f.Old).ToLower()
    
    Write-Host "Processing $($f.Old)..."
    if ($ext -match "\.jpg$|\.jpeg$") {
        exiftool -q -overwrite_original "-DateTimeOriginal=$date" "-CreateDate=$date" "-ModifyDate=$date" "-FileModifyDate=$date" $fullOld
    } elseif ($ext -match "\.mp4$|\.mov$") {
        exiftool -q -overwrite_original -api QuickTimeUTC=1 "-CreateDate=$date" "-ModifyDate=$date" "-TrackCreateDate=$date" "-TrackModifyDate=$date" "-MediaCreateDate=$date" "-MediaModifyDate=$date" "-FileModifyDate=$date" $fullOld
    }
    
    Rename-Item -Path $fullOld -NewName $f.New -Force
    Write-Host "Renamed to $($f.New)" -ForegroundColor Green
}
