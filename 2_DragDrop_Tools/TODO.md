# TODO - DragDrop Tools

## Priority High 🔴

### MetadataTools (Nuova Categoria)

- [ ] **Uniform-DateToSingleDay.bat**
  - Forza tutti file cartella a data singola
  - Drag & drop cartella → chiede conferma data → applica a tutti
  - Safe: Preview prima di applicare
  - Wrapper per LLM script o standalone con GUI

- [ ] **Verify-MetadataAlignment.bat**
  - Verifica allineamento EXIF vs filesystem timestamps
  - Report file con mismatch
  - Auto-fix opzionale
  - Use case: Post-resize, post-copy

- [ ] **Quick-DateFix.bat**
  - Fix rapido data per piccoli batch (1-10 file)
  - Popup chiede data → applica
  - No need LLM per casi semplici

### Video Tools Enhancement

- [ ] **Batch-Merge-Videos.bat**
  - Merge automatico video stessa cartella
  - Pre-standardizzazione automatica (FPS, codec)
  - Output: `MergedVideo_YYYYMMDD.mp4`
  - Use case: Unire clip viaggio/evento

- [ ] **Extract-VideoThumbnails.bat**
  - Estrae thumbnail da video
  - Utile per preview rapido senza aprire
  - Output: `video_thumb.jpg` accanto a ogni `.mp4`

## Priority Medium 🟡

### Repair & Recovery

- [ ] **Repair-LosslessCut-Files.bat**
  - Fix specifico per file corrotti da LosslessCut
  - Problema: A volte LosslessCut lascia video non riproducibili
  - Soluzione: Re-mux con ffmpeg

- [ ] **Detect-Corrupted-Videos.bat**
  - Scansiona cartella e trova video corrotti
  - Report: File non apribili/riproducibili
  - Suggerisce tool repair appropriato

### Compression Enhancements

- [ ] **Smart-Compression-Profile.bat**
  - Auto-detect miglior profilo compressione per tipo video
  - Drone → HEVC CQ24
  - Telefono → H.264 CQ26
  - Action cam → HEVC CQ22 (movimento)

- [ ] **Selective-Frame-Compression.bat**
  - Comprime solo video oltre soglia dimensione/bitrate
  - Skip quelli già ottimizzati
  - Batch intelligente

## Priority Low 🟢

### Utilities

- [ ] **Bulk-Rename-Tool.bat**
  - Rinomina batch con pattern
  - GUI semplice per non-tecnici
  - Preview prima di applicare

- [ ] **Extract-Audio-From-Video.bat**
  - Estrae traccia audio da video
  - Output: File `.mp3` o `.aac`
  - Use case: Podcast, memo vocali

### Image Tools

- [ ] **Batch-Resize-Images.bat**
  - Resize batch immagini mantenendo aspect ratio
  - Preset: 1920px, 1280px, 800px
  - Preserva EXIF metadata

- [ ] **Convert-HEIC-to-JPG.bat**
  - Converte foto iPhone HEIC → JPG
  - Mantiene metadati EXIF

## Nice to Have 💡

### Advanced Features

- [ ] **Video-to-GIF.bat**
  - Converte segmenti video in GIF animate
  - Per condivisione rapida social/chat

- [ ] **Create-Video-Contact-Sheet.bat**
  - Crea griglia thumbnails da video (contact sheet)
  - Overview visivo contenuto

- [ ] **Watermark-Videos.bat**
  - Aggiunge watermark automatico
  - Use case: Video da pubblicare

### Integration

- [ ] **Upload-to-GoogleDrive.bat**
  - Wrapper per up load diretto a Drive
  - Con progress bar

- [ ] **Generate-Video-Previews.bat**
  - Crea preview video ridotto (primi 10 secondi)
  - Per sharing rapido

## Completed ✅

- [x] COMPRIMI_VIDEO_1080p_REPLACE (GPU full pipeline) - 2025-12
- [x] Repair_Insta360_INS_Videos - 2025-11
- [x] Standardize-Videos (FPS/codec unification) - 2025-11
- [x] Test-NVENC (diagnostica GPU encoding) - 2025-12
- [x] Drag & drop support per PowerShell (wrapper .bat) - 2025-12
- [x] Auto-detect audio stream (evita AVOption warning) - 2025-12
- [x] Multi-file/folder batch support - 2025-12
- [x] Progress counter per batch operations - 2025-12
- [x] Skip already compressed files - 2025-12

---

**Note**: Priorità basata su frequenza uso e richieste utente.

- [x] **STANDARDIZE_VIDEO.bat - Universal Video Standardizer** - 2026-01-03
  - Unifica tutti gli script di conversione in uno solo
  - 1080p 30fps H.264 per archivio + LosslessCut compatibility
  - Auto-detect portrait/landscape, GPU accelerated
  - Script legacy spostati in _Legacy/


## Completed (2026-01-03)

- [x] **Video-Health-Diagnostics.ps1** - Intelligent video scanner
  - Detects corrupted metadata, merge problems, playback issues
  - Categorized report with repair suggestions
  - Location: 1_LLM_Automation/Analysis/
  
- [x] **REPAIR_VIDEO.bat** - Automatic video repair
  - Auto-fix corrupted FPS, duration, container issues
  - Smart re-mux vs re-encode decision
  - Handles broken LosslessCut merges
