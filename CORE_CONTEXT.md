# CORE CONTEXT - Media Archive Management (LEGGI SEMPRE ALL’INIZIO)

Questo documento contiene le regole permanenti del progetto: path hardcoded, struttura archivio, naming, gestione date e principi fondamentali. Va letto all’inizio di ogni chat.

---

## Paths hardcoded (setup specifico)

### Hard disk

> **ATTENZIONE — LETTERE DRIVE VARIABILI**
> La lettera del Recent SSD cambia a seconda del PC e della sessione (E:\, F:\, o altro).
> D:\ (Old SSD) e quasi sempre stabile.
> **Prima di ogni sessione: chiedere all'utente quale lettera ha il recent SSD, oppure leggere pc_config.local.json (campo RecentDrive).**
> Negli esempi di questo documento si usa {R} per indicare il Recent SSD.

```
{R}:\  = Recent SSD (2024+)   <- lettera variabile: E:\, F:\, o altro
  - Cartelle: 2024\, 2025\, 2026\, ...

D:\  = Old SSD (fino al 2023 incluso)  <- quasi sempre D:\
  - Cartelle: 2018\, 2019\, 2020\, 2021\, 2022\, 2023\, ...

IMPORTANTE: Old e Recent NON hanno mai intersezione temporale.

FileSystem (setup attuale): exFAT (compatibile iPhone).
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
3_Sync_Mobile_Drive\ = script iCloud/utility iPhone (flusso manuale via SSD)

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
{R}:\Insta360\YYYYNomeEvento\    (es: 2025KayakScoltenna, 2025Stubai, ...)
```
Tool: `1_LLM_Automation/Maintenance/Migrate-Insta360.ps1`

Regola fondamentale:
- le cartelle di servizio sono **trasparenti** per naming/contesto
- non danno mai il nome ai file: il nome deriva dalla cartella padre “evento”

Esempio:
```
{R}:\2025\Elba\clip.mp4        -> phone-worthy (va su iPhone)
{R}:\2025\Elba\_pc\raw.mp4     -> solo PC
{R}:\2025\Elba\MERGE\out.mp4   -> nome evento: Elba (NON MERGE)
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

## Flusso iPhone — regole chiave

### Paradigma attuale (2026-03-18)

Gli SSD sono **exFAT** → si collegano direttamente a iPhone via cavo/adattatore.
**Non c'è sync automatica.** Il trasferimento è manuale, cartella per cartella, quando serve.

```
[SSD collegato a PC]  →  correzione nomi + date EXIF  →  [SSD collegato a iPhone]
                                                          → copia cartella in iPhone Foto
```

Il PC serve solo per la fase di preparazione (fix nomi, fix date, selezione).
I file `_pc\` restano sul SSD e iPhone li ignora semplicemente (non li vede in Foto).

### Prerequisito critico prima di ogni trasferimento

**I file devono avere nome e data EXIF corretti**, altrimenti in iPhone Photos
finiscono sulla data di oggi invece che sulla data dell'evento.

Workflow di preparazione su PC (per ogni cartella/evento):
1. Verifica/correggi nomi → formato `YYYYMMDD_NomeDescrittivo_N.ext`
2. Verifica/correggi date EXIF → usare ExifTool (vedi sezione Date management)
3. Collega SSD a iPhone → copia la cartella in Foto

### `_pc\` — solo per chiarezza, non obbligatorio nel flusso

La cartella `_pc\` è una convenzione di comodità: indica file che non vuoi su iPhone.
Non serve gestirla in modo automatico — iPhone copia solo quello che gli porti esplicitamente.


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

**Ultima modifica**: 2026-03-18 (flusso SSD diretto iPhone — Phone Mode obsoleto)
**Status**: permanente (modificare solo se cambiano fondamentali)
