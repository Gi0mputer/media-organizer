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

FileSystem (setup attuale): **exFAT** (compatibile iPhone).
```

### Telefono (iPhone - attuale)

Su iPhone non esiste un filesystem tipo `/sdcard` utilizzabile per una sync ADB-style.
La gestione si divide in due mondi:

- **Foto (Photos)**: timeline/albums (non è una cartella). Opzionale: iCloud Photos come ponte verso Windows.
- **File (Files / SSD esterno)**: filesystem vero (consigliato: SSD exFAT).

Guida: `3_Sync_Mobile_Drive/IPHONE_WINDOWS.md`

### Legacy (Android - Pixel 8, ADB)
```
Path telefono: PC\Pixel 8\Memoria condivisa interna\SSD\
Sync engine: ADB (Dual Root — _gallery → DCIM\SSD, _mobile → SSD)
```

### Progetto
```
Il repo si clona su ogni PC (vedi SETUP.md).
Struttura interna:

1_LLM_Automation\    = workflow assistiti / euristiche / report
2_DragDrop_Tools\    = tool drag & drop per uso quotidiano
3_Sync_Mobile_Drive\ = sync mobile (Android legacy + iPhone roadmap)

Config per-PC (non committata): pc_config.local.json
```

---

## Cartelle di servizio (CRITICO)

### Nuovo paradigma (2026-03-16) — phone-first

La struttura di ogni cartella evento è ora **phone-first**:

```
EventFolder/          <- file phone-worthy (vanno su iPhone)
EventFolder/_pc/      <- tutto il resto (solo PC, editing, raw, ecc.)
```

**`_mobile` e `_gallery` sono ABOLITI** come cartelle di servizio.
Tutto ciò che era in `_mobile` o `_gallery` è stato dissolto nella cartella padre.
Tutto il resto è stato spostato in `_pc`.

### Cartelle di servizio attive
- `_pc\` -> contenuto solo-PC (non va su iPhone)
- `_trash\` (alias: `Trash\`) -> “cestino” logico su PC (preferire Recycle Bin)
- `Drive\` -> subset per cloud
- `MERGE\`, `RAW\` -> cartelle tecniche (dentro `_pc` tipicamente)

### Insta360 — struttura centralizzata
I raw Insta360 non stanno più nelle sottocartelle evento ma in:
```
E:\Insta360\YYYYNomeEvento\    (es: 2025KayakScoltenna, 2025Stubai, ...)
```
Tool: `1_LLM_Automation/Maintenance/Migrate-Insta360.ps1`

Regola fondamentale:
- le cartelle di servizio sono **trasparenti** per naming/contesto
- non danno mai il nome ai file: il nome deriva dalla cartella padre “evento”

Esempio:
```
E:\2025\Elba\clip.mp4        -> phone-worthy (va su iPhone)
E:\2025\Elba\_pc\raw.mp4     -> solo PC
E:\2025\Elba\MERGE\out.mp4   -> nome evento: Elba (NON MERGE)
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

Paradigma (phone-first):
- **PC è Master** (D:\ + E:\).
- File nella **root di ogni evento** = phone-worthy → vanno su iPhone Files.
- File in **`_pc\`** = solo PC, non sincronizzati.
- Raw Insta360 centralizzati in `E:\Insta360\` → non sincronizzati su iPhone.

### `E:\Foto\` — galleria curata per iPhone Photos
Cartella parallela agli anni (E:\2024, E:\2025, ...).
Contiene file destinati a **iPhone Photos** (camera roll / album).
In futuro: sincronizzata via iCloud Photos o Apple Devices app.

### Flusso Phone Mode (Export PC → iPhone)

```
Enable-PhoneMode -Execute          → MOVE file phone-worthy in E:\_iphone\
[manuale] copia _iphone\ su iPhone Files
Restore-PCMode -Execute            → rimette tutto al posto, aggiorna history
```

Dal secondo sync: `Enable-PhoneMode -Execute -DeltaOnly` (solo novita').

### Flusso Import (iPhone → PC)

```
[manuale] copia albero da iPhone Files in E:\_iphone\ (sovrascrive)
Import-PhoneChanges -Execute       → applica delta su PC
```

Delta logic: RelPath + Size + LastWrite.
- Nuovo da iPhone → importato nella posizione originale su PC
- Modificato → aggiorna PC (vecchio va in `_pc\_trash`)
- Eliminato su iPhone → spostato in `Evento\_pc\_trash\`

### File di sistema (in `E:\_sys\`)
- `_iphone_history.json` — history cumulativa trasferimenti (persiste tra cicli)
- `_iphone_manifest.json` — presente solo durante Phone Mode attiva

Tool: `3_Sync_Mobile_Drive/` — `Enable-PhoneMode.ps1`, `Restore-PCMode.ps1`, `Import-PhoneChanges.ps1`
BAT wrappers: `PREVIEW_*/RUN_*` per ogni script.
Dettagli: `3_Sync_Mobile_Drive/README.md`, `3_Sync_Mobile_Drive/IPHONE_WINDOWS.md`


## Documenti da mantenere aggiornati

- `CORE_CONTEXT.md` (questo file)
- `1_LLM_Automation/README.md`, `1_LLM_Automation/TODO.md`
- `2_DragDrop_Tools/README.md`, `2_DragDrop_Tools/TODO.md`
- `3_Sync_Mobile_Drive/README.md`, `3_Sync_Mobile_Drive/TODO.md`, `3_Sync_Mobile_Drive/device_config.json`
- `3_Sync_Mobile_Drive/IPHONE_WINDOWS.md` (setup iPhone/Windows + strategia Files vs Foto)
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

**Ultima modifica**: 2026-03-18 (merge: Phone Mode workflow + setup multi-PC)
**Status**: permanente (modificare solo se cambiano fondamentali)
