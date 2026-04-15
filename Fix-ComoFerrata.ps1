$baseComo = "F:\2025\2025Como"
$baseComoPc = "F:\2025\2025Como\_pc"

$comoMap = @(
    # main
    @{ Dir=$baseComo; Old="PXL_20250531_150731961.MP.jpg"; Date="2025:05:31 15:07:31"; New="20250531_Como_01.jpg" },
    @{ Dir=$baseComo; Old="PXL_20250531_150958875.LS.mp4"; Date="2025:05:31 15:09:58"; New="20250531_Como_02.mp4" },
    @{ Dir=$baseComo; Old="PXL_20250531_155149756.mp4"; Date="2025:05:31 15:51:49"; New="20250531_Como_03.mp4" },
    @{ Dir=$baseComo; Old="PXL_20250531_201827663.NIGHT.jpg"; Date="2025:05:31 20:18:27"; New="20250531_Como_04.jpg" },
    @{ Dir=$baseComo; Old="PXL_20250601_101149092.jpg"; Date="2025:06:01 10:11:49"; New="20250601_Como_01.jpg" },
    @{ Dir=$baseComo; Old="PXL_20250601_101251376.MP.jpg"; Date="2025:06:01 10:12:51"; New="20250601_Como_02.jpg" },
    @{ Dir=$baseComo; Old="IMG-20250602-WA0005.jpg"; Date="2025:06:02 12:00:01"; New="20250602_Como_01.jpg" },
    @{ Dir=$baseComo; Old="PXL_20250602_121727696.mp4"; Date="2025:06:02 12:17:27"; New="20250602_Como_02.mp4" },
    @{ Dir=$baseComo; Old="PXL_20250602_123944115.mp4"; Date="2025:06:02 12:39:44"; New="20250602_Como_03.mp4" },
    @{ Dir=$baseComo; Old="IMG-20250603-WA0002.jpg"; Date="2025:06:03 12:00:01"; New="20250603_Como_01.jpg" },
    @{ Dir=$baseComo; Old="IMG-20250603-WA0010.jpg"; Date="2025:06:03 12:00:02"; New="20250603_Como_02.jpg" },
    # _pc
    @{ Dir=$baseComoPc; Old="PXL_20250601_101238392.MP.jpg"; Date="2025:06:01 10:12:38"; New="20250601_Como_PC01.jpg" },
    @{ Dir=$baseComoPc; Old="PXL_20250602_124415652.MP.jpg"; Date="2025:06:02 12:44:15"; New="20250602_Como_PC01.jpg" },
    @{ Dir=$baseComoPc; Old="PXL_20250602_124415652_exported_67_174887124063(1).jpg"; Date="2025:06:02 12:44:16"; New="20250602_Como_PC02.jpg" },
    @{ Dir=$baseComoPc; Old="PXL_20250602_130229189.mp4"; Date="2025:06:02 13:02:29"; New="20250602_Como_PC03.mp4" },
    @{ Dir=$baseComoPc; Old="IMG-20250503-WA0000.jpg"; Date="2025:06:03 23:59:01"; New="20250603_Como_PC03.jpg" },
    @{ Dir=$baseComoPc; Old="IMG-20250607-WA0022.jpg"; Date="2025:06:03 23:59:02"; New="20250603_Como_PC04.jpg" }
)

$baseAquile = "F:\2025\2025FerrataAquile"
$baseAquilePc = "F:\2025\2025FerrataAquile\_pc"

$aquileMap = @(
    # main
    @{ Dir=$baseAquile; Old="PXL_20250719_104504692.mp4"; Date="2025:07:19 10:45:04"; New="20250719_FerrataAquile_01.mp4" },
    @{ Dir=$baseAquile; Old="PXL_20250719_105857953.mp4"; Date="2025:07:19 10:58:57"; New="20250719_FerrataAquile_02.mp4" },
    @{ Dir=$baseAquile; Old="PXL_20250719_110029421.mp4"; Date="2025:07:19 11:00:29"; New="20250719_FerrataAquile_03.mp4" },
    @{ Dir=$baseAquile; Old="PXL_20250719_112243548.MP.jpg"; Date="2025:07:19 11:22:43"; New="20250719_FerrataAquile_04.jpg" },
    @{ Dir=$baseAquile; Old="PXL_20250719_112352081.jpg"; Date="2025:07:19 11:23:52"; New="20250719_FerrataAquile_05.jpg" },
    @{ Dir=$baseAquile; Old="PXL_20250719_115356970.mp4"; Date="2025:07:19 11:53:56"; New="20250719_FerrataAquile_06.mp4" },
    @{ Dir=$baseAquile; Old="IMG-20250719-WA0002.jpg"; Date="2025:07:19 12:00:00"; New="20250719_FerrataAquile_07.jpg" },
    @{ Dir=$baseAquile; Old="PXL_20250719_124228940.jpg"; Date="2025:07:19 12:42:28"; New="20250719_FerrataAquile_08.jpg" },
    @{ Dir=$baseAquile; Old="FerrataDelleAcquileHoriz.mp4"; Date="2025:07:19 23:59:01"; New="20250719_FerrataAquile_09.mp4" },
    @{ Dir=$baseAquile; Old="FerrataDelleAcquileVertical.mp4"; Date="2025:07:19 23:59:02"; New="20250719_FerrataAquile_10.mp4" },
    # _pc
    @{ Dir=$baseAquilePc; Old="PXL_20250719_112349590.jpg"; Date="2025:07:19 11:23:49"; New="20250719_FerrataAquile_PC01.jpg" },
    @{ Dir=$baseAquilePc; Old="PXL_20250719_113333430.MP.jpg"; Date="2025:07:19 11:33:33"; New="20250719_FerrataAquile_PC02.jpg" },
    @{ Dir=$baseAquilePc; Old="PXL_20250719_113506969.jpg"; Date="2025:07:19 11:35:06"; New="20250719_FerrataAquile_PC03.jpg" },
    @{ Dir=$baseAquilePc; Old="VID-20250719-WA0001.mp4"; Date="2025:07:19 12:00:01"; New="20250719_FerrataAquile_PC04.mp4" }
)

$allFiles = $comoMap + $aquileMap

foreach ($f in $allFiles) {
    if (-not (Test-Path $f.Dir)) { continue }
    $fullOld = Join-Path $f.Dir $f.Old
    $fullNew = Join-Path $f.Dir $f.New
    $date = $f.Date
    
    if (-not (Test-Path $fullOld)) {
        Write-Host "Not found: $fullOld"
        continue
    }

    $ext = [System.IO.Path]::GetExtension($f.Old).ToLower()
    
    Write-Host "Fixing EXIF for $($f.Old)..."
    if ($ext -match "\.jpg$|\.jpeg$") {
        exiftool -q -overwrite_original "-DateTimeOriginal=$date" "-CreateDate=$date" "-ModifyDate=$date" "-FileModifyDate=$date" $fullOld
    } elseif ($ext -match "\.mp4$|\.mov$") {
        exiftool -q -overwrite_original -api QuickTimeUTC=1 "-CreateDate=$date" "-ModifyDate=$date" "-TrackCreateDate=$date" "-TrackModifyDate=$date" "-MediaCreateDate=$date" "-MediaModifyDate=$date" "-FileModifyDate=$date" $fullOld
    }
    
    Rename-Item -Path $fullOld -NewName $f.New -Force
    Write-Host "Renamed $($f.Old) -> $($f.New)" -ForegroundColor Green
}
