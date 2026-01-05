# TODO - DragDrop Tools

## Priority High

### MetadataTools

- [x] **FIX_DATE_FROM_REFERENCE.bat**
  - Forza tutti i file della cartella a una data singola usando un file reference (metadata corrette)
  - Drag & drop 1 file reference -> applica a tutta la cartella
  - Wrapper per `1_LLM_Automation/Scripts/Force-DateFromReference.ps1`

- [x] **FIX_DATE_FROM_FILENAME.bat**
  - Fix rapido per file con data “oggi” (tipico dopo taglio/export)
  - Legge data dal filename (Pixel/WA/Archivio) e riscrive metadati + filesystem times
  - Safe default: nel `.ps1` modifica solo file con filesystem date recente (ultimi 2 giorni). Usa `-Force` per forzare

- [x] **PROCESS_DAY_MARKERS.bat**
  - Processa cartelle `1day\` (alias legacy: `sameday\`) e `Nday\` (es. `4day\`): fix date/metadati + sposta contenuti fuori + elimina cartella
  - Supporta suffix: `1day_2\`, `4day_3\`, ecc.
  - Wrapper per `1_LLM_Automation/Maintenance/Process-DayMarkerFolders.ps1`

- [x] **RENAME_SERVICE_FOLDERS_TO_UNDERSCORE.bat**
  - One-time: normalizza `Mobile/Gallery/Trash` -> `_mobile/_gallery/_trash` (merge safe + conflitti in `_CONFLICTS_*`)
  - Wrapper per `1_LLM_Automation/Maintenance/Rename-ServiceFoldersToUnderscore.ps1`

- [ ] **Verify-MetadataAlignment.bat**
  - Verifica allineamento EXIF vs filesystem timestamps
  - Report file con mismatch
  - Auto-fix opzionale
  - Use case: post-resize, post-copy

### Video Tools Enhancement

- [ ] **Batch-Merge-Videos.bat**
  - Merge automatico video stessa cartella
  - Pre-standardizzazione automatica (FPS, codec)
  - Output: `MergedVideo_YYYYMMDD.mp4`
  - Use case: unire clip viaggio/evento

- [ ] **Extract-VideoThumbnails.bat**
  - Estrae thumbnail da video
  - Utile per preview rapido senza aprire
  - Output: `video_thumb.jpg` accanto a ogni `.mp4`

## Priority Medium

### Repair & Recovery

- [ ] **Repair-LosslessCut-Files.bat**
  - Fix specifico per file corrotti da LosslessCut
  - Problema: a volte LosslessCut lascia video non riproducibili
  - Soluzione: re-mux con ffmpeg

- [ ] **Detect-Corrupted-Videos.bat**
  - Scansiona cartella e trova video corrotti
  - Report: file non apribili/riproducibili
  - Suggerisce tool repair appropriato

### Compression Enhancements

- [ ] **Smart-Compression-Profile.bat**
  - Auto-detect miglior profilo compressione per tipo video
  - Drone -> HEVC CQ24
  - Telefono -> H.264 CQ26
  - Action cam -> HEVC CQ22 (movimento)

- [ ] **Selective-Frame-Compression.bat**
  - Comprime solo video oltre soglia dimensione/bitrate
  - Skip quelli già ottimizzati
  - Batch intelligente

## Priority Low

### Utilities

- [ ] **Bulk-Rename-Tool.bat**
  - Rinomina batch con pattern
  - GUI semplice per non-tecnici
  - Preview prima di applicare

- [ ] **Extract-Audio-From-Video.bat**
  - Estrae traccia audio da video
  - Output: file `.mp3` o `.aac`
  - Use case: podcast, memo vocali

### Image Tools

- [ ] **Batch-Resize-Images.bat**
  - Resize batch immagini mantenendo aspect ratio
  - Preset: 1920px, 1280px, 800px
  - Preserva EXIF metadata

- [ ] **Convert-HEIC-to-JPG.bat**
  - Converte foto iPhone HEIC -> JPG
  - Mantiene metadati EXIF

## Nice to Have

### Advanced Features

- [ ] **Video-to-GIF.bat**
  - Converte segmenti video in GIF animate
  - Per condivisione rapida social/chat

- [ ] **Create-Video-Contact-Sheet.bat**
  - Crea griglia thumbnails da video (contact sheet)
  - Overview visivo contenuto

- [ ] **Watermark-Videos.bat**
  - Aggiunge watermark automatico
  - Use case: video da pubblicare

### Integration

- [ ] **Upload-to-GoogleDrive.bat**
  - Wrapper per upload diretto a Drive
  - Con progress bar

- [ ] **Generate-Video-Previews.bat**
  - Crea preview video ridotto (primi 10 secondi)
  - Per sharing rapido

## Completed

- [x] COMPRIMI_VIDEO_1080p_REPLACE (GPU full pipeline) - 2025-12
- [x] Repair_Insta360_INS_Videos - 2025-11
- [x] Standardize-Videos (FPS/codec unification) - 2025-11
- [x] Test-NVENC (diagnostica GPU encoding) - 2025-12
- [x] Drag & drop support per PowerShell (wrapper .bat) - 2025-12
- [x] Auto-detect audio stream (evita AVOption warning) - 2025-12
- [x] Multi-file/folder batch support - 2025-12
- [x] Progress counter per batch operations - 2025-12
- [x] Skip already compressed files - 2025-12

- [x] **STANDARDIZE_VIDEO.bat - Universal Video Standardizer** - 2026-01-03
  - Unifica tutti gli script di conversione in uno solo
  - 1080p 30fps H.264 per archivio + LosslessCut compatibility
  - Auto-detect portrait/landscape, GPU accelerated
  - Script legacy spostati in `_Legacy/`

- [x] **Video-Health-Diagnostics.ps1** - Intelligent video scanner - 2026-01-03
  - Detects corrupted metadata, merge problems, playback issues
  - Categorized report with repair suggestions
  - Location: `1_LLM_Automation/Analysis/`

- [x] **REPAIR_VIDEO.bat** - Automatic video repair - 2026-01-03
  - Auto-fix corrupted FPS, duration, container issues
  - Smart re-mux vs re-encode decision
  - Handles broken LosslessCut merges

---

**Note**: Priorità basata su frequenza d’uso e richieste utente.
