# DragDrop Tools - User Utilities

## Scopo

**Strumenti rapidi drag & drop** per operazioni comuni sul media archive, utilizzabili **direttamente dall'utente senza chiamate LLM**.

Focus su:
- Compressione video batch
- Riparazione file corrotti
- Standardizzazione formati per editing
- Utilities generali

## Come Usare

### Drag & Drop Workflow

1. Trova il `.bat` file appropriato
2. Trascina file/cartelle sul `.bat`
3. Lo script processa automaticamente
4. Risultato: File processati nella stessa posizione (o specificata)

**Esempio**:
```
Trascina "video.mp4" su → COMPRIMI_VIDEO_1080p_REPLACE.bat
Risultato: video.mp4 compresso con HEVC 1080p, originale sostituito
```

## Catalogo Tools

### 📹 VideoCompression/

#### `COMPRIMI_VIDEO_1080p_REPLACE.bat` ⭐
**Cosa fa**: Comprime video a 1920px HEVC con GPU (NVENC)
**Input**: File video o cartelle (multi-file/recursive)
**Output**: Video compresso, originale sostituito
**Features**:
- Full GPU pipeline (decode, scale, encode)
- Auto-detect audio (skip se assente)
- Preserva metadata CreationTime
- Skip file già compressi (con "(small)" nel nome)
- Progress counter per batch

**Parametri HEVC**:
```
Codec: HEVC (H.265)
Encoder: hevc_nvenc (GPU)
Risoluzione: 1920px lato lungo
CQ: 24
Preset: p4
Audio: AAC 128k (se presente)
```

**Quando usare**:
- Video drone 4K > 100 MB
- Video pre-2021 con bitrate eccessivi
- Preparare video per mobile/cloud

#### `Converti-4K-a-1080p.bat`
**Cosa fa**: Conversione 4K → 1080p più conservativa
**Differenza**: Mantiene codec originale se già compresso

#### `Downscale1920_HEVC.bat`
**Cosa fa**: Downscale + HEVC generico
**Uso**: Alternativa legacy, preferire COMPRIMI_VIDEO_1080p_REPLACE

#### `SmartDownscale_1920_OLD.bat`
**Stato**: Obsoleto, mantenuto per reference

---

### 🔧 VideoRepair/

#### `Repair_Insta360_INS_Videos.bat`
**Cosa fa**: Ripara video `.insv` corrotti da Insta360
**Problema risolto**: File .insv non apribili dopo export/import
**Metodo**: Re-mux stream con ffmpeg

#### `RiparaMini5.bat`
**Cosa fa**: Ripara video corrotti da Insta360 GO 3
**Uso**: Specifico per mini-cam GO 3

**Note**: Insta360 usa formati proprietari che a volte si corrompono durante:
- Export da app
- Copy/paste veloce
- Interruzione processo

---

### 🎬 VideoStandardization/

#### `Standardize-Videos.ps1`
**Cosa fa**: Uniforma FPS e codec per merge/editing
**Use case**: Mergiare video da fonti diverse (drone, telefono, action cam)
**Output**: Tutti video con stesso FPS, risoluzione, codec

**Parametri target**:
```
FPS: 30 (o specificato)
Risoluzione: 1920x1080
Codec: H.264
Audio: AAC
```

**Quando usare**:
- Prima di merge multi-video in editor
- Creare timeline coerente

---

### 🧰 Utilities/

#### `Test-NVENC.bat`
**Cosa fa**: Test disponibilità hardware encoding NVIDIA
**Output**: [PASS] o [FAIL] per HEVC/H.264 NVENC
**Uso**: Diagnostica se GPU supporta encoding

#### `Check_ExifTool.bat`
**Cosa fa**: Verifica installazione ExifTool
**Output**: Versione installata o errore

#### `fixTimestamp.bat`
**Cosa fa**: Fix timestamp generico (legacy)

---

### 📝 MetadataTools/ (Da Creare)

**Future tools**:
- Uniform-DateToSingleDay.bat
- Verify-MetadataAlignment.bat
- Extract-GPS-Coordinates.bat

---

## Problemi Noti & Soluzioni

### ⚠️ Problema: AVOption b:a not used
**Causa**: Video senza audio, script tenta encoding audio stream vuoto
**Soluzione**: ✅ Risolto - Auto-detect audio con ffprobe, usa `-an` se assente
**Script**: COMPRIMI_VIDEO_1080p_REPLACE.ps1

### ⚠️ Problema: PowerShell non drag & drop
**Causa**: `.ps1` non accetta drag & drop diretto in Windows
**Soluzione**: ✅ Wrapper `.bat` che chiama `.ps1` con parametri
**Pattern**:
```batch
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0SCRIPT.ps1" %*
```

### ⚠️ Problema: Compressione troppo lenta (CPU)
**Causa**: Fallback CPU invece di GPU per scale/encode
**Soluzione**: ✅ Risolto - Full GPU pipeline con `hwaccel cuda` + `scale_cuda`
**Speed**: Da ~2x realtime → ~14x realtime

### ⚠️ Problema: File .insv non riparabili
**Causa**: Corruzione header non recuperabile
**Soluzione**: ⚠️ Parziale - Alcuni file irrecuperabili, provare Insta360 Studio

### ⚠️ Problema: Merge video fail "codec not compatible"
**Causa**: FPS/codec diversi tra clip
**Soluzione**: ✅ Usare Standardize-Videos.ps1 prima di merge

---

## Preferenze & Best Practices

### Compressione Video

**Quando comprimere**:
- ✅ Video > 100 MB
- ✅ Drone 4K 60fps (overkill per archivio)
- ✅ Pre-2021 (bitrate eccessivi epoca)
- ❌ Video già compressi (ricompressione degrada qualità)
- ❌ Video per editing professionale (mantenere qualità max)

**Parametri preferiti**:
- CQ 24 (ottimo compromesso qualità/dimensione)
- HEVC > H.264 (50% meno spazio, stessa qualità)
- Preset p4/p5 (velocità GPU vs qualità)

### Naming Output

**Preferenza**: Sostituire originale invece di creare copia
- ✅ Evita duplicati
- ✅ Mantiene naming/posizione
- ❌ Rischio perdita se errore → sempre testare prima su sample

### Batch Operations

**Best Practice**:
1. Testare su 1-2 file prima di batch completo
2. Verificare spazio disco (compressione crea temporanei)
3. Non interrompere batch (può lasciare file corrotti)
4. Backup cartelle importanti prima di operazioni distruttive

---

## Performance Tips

### GPU Encoding

**Requisiti**:
- GPU NVIDIA con NVENC (GTX 1050+, RTX series)
- Driver aggiornati
- ffmpeg compilato con `--enable-nvenc`

**Verifica**: Esegui `Test-NVENC.bat`

**Ottimizzazioni**:
- Chiudi app GPU-intensive durante batch
- Usa `-hwaccel cuda -hwaccel_output_format cuda` per full GPU
- Evita `-vf scale` (CPU) → usa `scale_cuda` (GPU)

### Parallel Processing

**Attenzione**: Non processare troppi video in parallelo
- GPU può saturare (artifacts/crash)
- Meglio: Queue sequenziale con progress

---

## Prossimi Strumenti

Vedi [TODO.md](./TODO.md) per tool pianificati.

---

## ? TOOL PRINCIPALE RACCOMANDATO

### `STANDARDIZE_VIDEO.bat` (Root Level)

**IL TOOL DA USARE** per standardizzare qualsiasi video per archivio/merge.

**Drag & Drop**: Trascina video o cartelle ? automaticamente convertiti

**Output**: 
- Risoluzione: 1080p (preserva aspect ratio)
- FPS: 30fps (standard)
- Codec: H.264 (max compatibilit� LosslessCut)
- Audio: AAC 128k
- Nome: `originale_STD.mp4`

**Caratteristiche**:
? Gestisce QUALSIASI formato input (MP4, MOV, AVI, MKV, etc.)
? Auto-detect Portrait/Landscape
? GPU accelerated (NVENC) se disponibile
? Preserva metadata e timestamp
? Skip file gi� standardizzati (`_STD` suffix)
? Batch support (multi-file/cartelle)

**Quando usare**:
- Prima di merge video in LosslessCut
- Ridurre dimensioni archivio (video ricordo)
- Uniformare video da fonti diverse (drone, telefono, action cam)

**Esempio**:
\\\
Input: viaggio_4k_60fps.mov (2GB, 3840x2160 60fps HEVC)
Output: viaggio_4k_60fps_STD.mp4 (400MB, 1920x1080 30fps H.264)
\\\

---

---

## ? NUOVO: Video Repair System

### `REPAIR_VIDEO.bat` (Root Level)

**Automatic video repair** for corrupted files and merge glitches.

**Drag & Drop**: Trascina video problematici ? auto-fix

**Fixes**:
- ? Corrupted FPS metadata (90000fps, division by zero)
- ? Duration mismatches (file vs stream)
- ? Broken LosslessCut merges (glitches, lag durante playback)
- ? Container corruption

**Strategy**:
- **Re-mux**: Fixes container issues (fast, no quality loss)
- **Re-encode**: Fixes metadata corruption + standardizes (slower but comprehensive)
- Auto-detect which strategy to use

**Output**: `filename_FIXED.mp4`

**Companion Tool**: `Video-Health-Diagnostics.ps1` (in 1_LLM_Automation/Analysis)
- Scansiona archivio e trova problemi
- Report markdown dettagliato
- Use before batch repair to identify files

---
