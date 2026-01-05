# DragDrop Tools - User Utilities

## Scopo
Strumenti rapidi drag & drop per operazioni comuni sul Media Archive, utilizzabili direttamente dall’utente (senza LLM).

Focus:
- Compressione video batch
- Riparazione file corrotti
- Standardizzazione video per merge/editing
- Fix metadata/timestamp in casi tipici (taglio/export)

## Struttura
Cartelle principali:
- `2_DragDrop_Tools/VideoCompression/`
- `2_DragDrop_Tools/VideoRepair/`
- `2_DragDrop_Tools/Utilities/`
- `2_DragDrop_Tools/MetadataTools/`

Tool root-level (i più importanti):
- `2_DragDrop_Tools/STANDARDIZE_VIDEO.bat`
- `2_DragDrop_Tools/REPAIR_VIDEO.bat`

## Come usare (Drag & Drop)
1. Trova il `.bat` appropriato
2. Trascina file/cartelle sul `.bat`
3. Lo script fa preview (quando previsto) e poi chiede conferma

## Tool principali consigliati

### `STANDARDIZE_VIDEO.bat` (root)
Tool consigliato per rendere compatibili i video (LosslessCut/merge/archivio):
- Output: 1080p, 30fps, H.264, AAC
- Nome: `originale_STD.mp4`
- Batch support (file/cartelle)
- GPU accelerated se disponibile

### `COMPRIMI_VIDEO_1080p_REPLACE.bat` (`VideoCompression/`)
Compressione aggressiva per ridurre spazio (sostituisce l’originale):
- HEVC 1080p (NVENC se disponibile)
- Skip file già compressi
- Preserva timestamp (quando possibile)

### `Repair_Insta360_INS_Videos.bat` / `RiparaMini5.bat` (`VideoRepair/`)
Repair dedicati per file specifici (Insta360 / GO).

### `REPAIR_VIDEO.bat` (root)
Repair automatico per file corrotti o con metadata problematici (merge glitch, FPS fuori scala, container rotto).

## MetadataTools
Cartella: `2_DragDrop_Tools/MetadataTools/`

### `FIX_DATE_FROM_FILENAME.bat`
Fix rapido per file con data “oggi” dopo taglio/export:
- Legge `YYYYMMDD` dal filename (Pixel/WA/Archivio)
- Riscrive metadati + filesystem timestamps
- Safe default nel `.ps1`: agisce solo su file “recenti” (ultimi 2 giorni); usare `-Force` per forzare

### `FIX_DATE_FROM_REFERENCE.bat`
Single-day fix (tutta la cartella alla stessa data):
- Drag & drop 1 file reference
- Wrapper per `1_LLM_Automation/Scripts/Force-DateFromReference.ps1`

### `PROCESS_DAY_MARKERS.bat`
Workflow `1day/Nday`:
- Fix date/metadati
- Sposta contenuti fuori dalla cartella marker
- Elimina la cartella marker
- Wrapper per `1_LLM_Automation/Maintenance/Process-DayMarkerFolders.ps1`

### `RENAME_SERVICE_FOLDERS_TO_UNDERSCORE.bat`
One-time normalizzazione cartelle servizio:
- `Mobile/Gallery/Trash` -> `_mobile/_gallery/_trash`
- Merge safe + conflitti in `_CONFLICTS_*`
- Wrapper per `1_LLM_Automation/Maintenance/Rename-ServiceFoldersToUnderscore.ps1`

## Problemi noti (e soluzioni)

### PowerShell non supporta drag & drop diretto
Usare i wrapper `.bat` (pattern standard):
```bat
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SCRIPT.ps1" %*
```

### Compressione lenta (CPU)
Se la GPU non viene usata:
- eseguire `2_DragDrop_Tools/Utilities/Test-NVENC.bat`
- verificare ffmpeg con NVENC

## Prossimi strumenti
Vedi `2_DragDrop_Tools/TODO.md`.
