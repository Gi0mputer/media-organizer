# Video Health Diagnostic Report
Generated: 2026-01-03 12:37:56
Scanned: E:\2024\Attraversamento lago
Files Analyzed: 9

## Summary

| Category | Count |
|----------|-------|
| Corrupted Metadata | 4 |
| Merge Problems | 0 |
| Playback Issues | 4 |
| Format Issues | 0 |
| Suspect but Healthy | 0 |

---
## [CRITICAL] Playback Issues (4)

### VID-20240724-WA0009.mp4
- **Problems**: FPS metadata corrupted: 29.97 fps
- **Severity**: HIGH
- **Suggestion**: Re-encode with STANDARDIZE_VIDEO.bat
- **Path**: `E:\2024\Attraversamento lago\VID-20240724-WA0009.mp4`

### VID_20240723_193802.mp4
- **Problems**: FPS metadata corrupted: 30.01 fps
- **Severity**: HIGH
- **Suggestion**: Re-encode with STANDARDIZE_VIDEO.bat
- **Path**: `E:\2024\Attraversamento lago\Mobile\VID_20240723_193802.mp4`

### VID-20240724-WA0002.mp4
- **Problems**: FPS metadata corrupted: 29.97 fps
- **Severity**: HIGH
- **Suggestion**: Re-encode with STANDARDIZE_VIDEO.bat
- **Path**: `E:\2024\Attraversamento lago\Mobile\VID-20240724-WA0002.mp4`

### VID-20240724-WA0004.mp4
- **Problems**: FPS metadata corrupted: 29.97 fps
- **Severity**: HIGH
- **Suggestion**: Re-encode with STANDARDIZE_VIDEO.bat
- **Path**: `E:\2024\Attraversamento lago\Mobile\VID-20240724-WA0004.mp4`

---

## [WARNING] Merge Problems (0)

No merge problems detected!

---

## [INFO] Corrupted Metadata (4)
- **VID-20240724-WA0009.mp4**: FPS metadata corrupted: 29.97 fps - Re-encode with STANDARDIZE_VIDEO.bat
- **VID_20240723_193802.mp4**: FPS metadata corrupted: 30.01 fps - Re-encode with STANDARDIZE_VIDEO.bat
- **VID-20240724-WA0002.mp4**: FPS metadata corrupted: 29.97 fps - Re-encode with STANDARDIZE_VIDEO.bat
- **VID-20240724-WA0004.mp4**: FPS metadata corrupted: 29.97 fps - Re-encode with STANDARDIZE_VIDEO.bat

---

## Recommendations

### Immediate Action Required (4 files)
1. Re-encode critical files with `STANDARDIZE_VIDEO.bat`
2. Verify output plays correctly
3. Replace original with standardized version

### Batch Repair Workflow
1. Drag problematic files/folders onto `REPAIR_VIDEO.bat`
2. Script will auto-fix metadata and re-encode if needed
3. Verify output in VLC/Media Player

