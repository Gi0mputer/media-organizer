# CORE CONTEXT - Media Archive Management (LEGGI SEMPRE ALL’INIZIO)

Questo documento contiene le regole permanenti del progetto: path hardcoded, struttura archivio, naming, gestione date e principi fondamentali. Va letto all’inizio di ogni chat.

---

## Paths hardcoded (setup specifico)

### Hard disk
```
E:\  = Recent SSD (2024+)
  - Cartelle: 2024\, 2025\, ...

D:\  = Old SSD (fino al 2023 incluso)
  - Cartelle: 2018\, 2019\, 2020\, 2021\, 2022\, 2023\, ...

IMPORTANTE: Old e Recent NON hanno mai intersezione temporale.
```

### Telefono (iPhone)
```
Destinazione finale: Apple Photos (Galleria iPhone).
Ordina per data EXIF — non per data filesystem.

Accesso da PC via USB:
- libimobiledevice (ideviceinfo, idevicepair)
- ifuse (monta DCIM\ come drive) — richiede WinFsp installato prima

Path montato con ifuse (da configurare):
  → scrittura in DCIM\ = i file appaiono in Apple Photos automaticamente

NOTE iOS:
- Album = viste filtrate, non cartelle fisiche (Cartella > Album > Foto)
- App File iOS = file system vero, ma NON appare in Galleria
- Le app di editing (CapCut, DaVinci, Insta360) esportano in Foto, non in File
- Spostamenti tra File e Foto sono sempre copie (non move)
```

### Progetto
```
Il repo si clona su ogni PC (vedi SETUP.md).
Struttura interna:

1_LLM_Automation\    = workflow assistiti / euristiche / report
2_DragDrop_Tools\    = tool drag & drop per uso quotidiano
3_Sync_Mobile_Drive\ = sync mobile (cartelle ADB/Android sono obsolete — iPhone in sviluppo)

Config per-PC (non committata): pc_config.local.json
```

---

## Cartelle di servizio (CRITICO)

Cartelle di servizio comuni (canonical + alias legacy):
- `_mobile\` (alias: `Mobile\`) -> subset privato/di lavoro
- `_gallery\` (alias: `Gallery\`) -> subset visibile (Google Foto)
- `_trash\` (alias: `Trash\`) -> “cestino” logico su PC (preferire Recycle Bin)
- `Drive\` -> subset per cloud
- `MERGE\`, `RAW\` -> cartelle tecniche

Regola fondamentale:
- le cartelle di servizio sono **trasparenti** per naming/contesto
- non danno mai il nome ai file: il nome deriva dalla cartella padre “evento”

Esempio:
```
E:\2025\Elba\_mobile\clip.mp4   -> nome evento: Elba (NON _mobile)
E:\2025\Elba\MERGE\out.mp4      -> nome evento: Elba (NON MERGE)
```

---

## Naming convention (standard)

Formato:
```
YYYYMMDD_NomeDescrittivo_N.ext
```

Regole:
- `N` è senza zeri (1, 2, 10… NON 001/002)
- `N` è omesso se il file è unico per quella data+nome

Esempi:
```
20190814_SpagnaCalaLevado.jpg
20190814_SpagnaCalaLevado_1.jpg
20190814_SpagnaCalaLevado_2.jpg
```

---

## Date management (regole critiche)

### Fonti di verità (ordine)
1. GPS DateTime
2. EXIF/QuickTime (DateTimeOriginal / CreateDate / MediaCreateDate, ecc.)
3. LastWriteTime (solo se coerente con anno/contesto)
4. Deduzione contestuale (cartella, altri file, eventi)
5. Input manuale

### Strategia per anomalie
Se un file è outlier (anno sbagliato / fuori range evento):
- forzare alla **MAX date** (fine intervallo), NON mediana
- obiettivo: preservare cronologia visuale in galleria (gli outlier vanno “in fondo” all’evento)

Quando si forza una data:
- aggiornare **metadati** + **filesystem timestamps** in modo coerente (Creation/LastWrite)

---

## Marker folders `1day` / `Nday` (sorting)

### `1day\` (single-day)
- Nome: `1day\` oppure `1day_2\`, `1day_3\`, ecc.
- Contenuto: tutto appartiene a **un singolo giorno**
- Azione: deduci la data corretta, allinea metadati, sposta i contenuti fuori dalla cartella, elimina la cartella marker

### `Nday\` (range breve)
- Nome: `2day\`, `3day\`, `4day\`… (+ suffix `4day_2\`, ecc.)
- `N` è un limite superiore “per eccesso” (non mesi)
- Azione:
  - rileva range reale dai file “buoni”
  - se ci sono outlier oltre il range -> forzali **a fine intervallo (MAX)**
  - sposta i contenuti fuori e elimina la cartella marker

Tool:
- Script: `1_LLM_Automation/Maintenance/Process-DayMarkerFolders.ps1`
- Wrapper drag & drop: `2_DragDrop_Tools/MetadataTools/PROCESS_DAY_MARKERS.bat`

---

## Sync (iPhone) - regole chiave

Il paradigma Android/Pixel 8 (ADB, _gallery, _mobile, .nomedia) è obsoleto.

Pipeline attuale PC → iPhone:
1. Risolvi marker folders `1day/Nday`
2. Audit/correggi date EXIF (ExifTool) — Apple Photos ordina per data EXIF
3. Trasferisci su iPhone via USB (ifuse) o Google Drive
4. Su iPhone: editing leggero se necessario, poi salva in Apple Photos
5. Organizza in album per tema/anno

Tool USB (libimobiledevice):
- `idevicepair pair`  — prima volta su ogni PC (trust)
- `ideviceinfo`       — verifica connessione
- `ifuse`             — monta DCIM\ per scrittura diretta in Apple Photos

---

## Documenti da mantenere aggiornati

- `CORE_CONTEXT.md` (questo file)
- `1_LLM_Automation/README.md`, `1_LLM_Automation/TODO.md`
- `2_DragDrop_Tools/README.md`, `2_DragDrop_Tools/TODO.md`
- `3_Sync_Mobile_Drive/README.md`, `3_Sync_Mobile_Drive/TODO.md`, `3_Sync_Mobile_Drive/device_config.json`
- `1_LLM_Automation/HANDOFF_PROSSIMA_CHAT.md` quando cambi chat/argomento

---

## Cose da NON fare mai

- Non eliminare definitivamente senza log + sicurezza (preferire Recycle Bin quando possibile)
- Non assumere path: verificare esistenza dischi/cartelle
- Non usare numeri zero-padded nel naming
- Non usare mediana per date forzate (sempre MAX)

---

## Dependencies
Richiesti in PATH:
- `exiftool`
- `ffmpeg`
- `ffprobe`
- `ideviceinfo` / `idevicepair` (libimobiledevice — per sync iPhone via USB)

Installazione automatica: `Setup-Environment.ps1` (vedi SETUP.md)

PowerShell:
- Windows PowerShell 5.1+
- quando serve: `powershell -NoProfile -ExecutionPolicy Bypass -File "script.ps1" ...`

---

**Ultima modifica**: 2026-03-16
**Status**: permanente (modificare solo se cambiano fondamentali)
