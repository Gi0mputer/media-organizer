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

### Telefono (Google Pixel 8)
```
Base (root-level):
PC\Pixel 8\Memoria condivisa interna\SSD\

Legacy (solo cleanup one-time, non usare più per sync):
PC\Pixel 8\Memoria condivisa interna\DCIM\Camera\
```

### Progetto
```
Base: c:\Users\ASUS\Desktop\Batchs\

1_LLM_Automation\    = workflow assistiti / euristiche / report
2_DragDrop_Tools\    = tool drag & drop per uso quotidiano
3_Sync_Mobile_Drive\ = sync con Pixel 8 (+ futuro Drive)
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

## Sync (Pixel 8) - regole chiave

Paradigma attuale:
- `_gallery` su PC -> su telefono si “dissolve” nel parent (visibile in Google Foto)
- `_mobile` su PC -> su telefono diventa sottocartella `Mobile\...` con `.nomedia` (non visibile in Google Foto)
- non si copia più niente in `DCIM\Camera` (salvo cleanup legacy one-time)

Workflow consigliato (sempre):
1. Risolvi marker folders `1day/Nday`
2. Audit date `_gallery` (evita file che finiscono “oggi” in galleria)
3. Sync con Pixel 8

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

PowerShell:
- Windows PowerShell 5.1+
- quando serve: `powershell -NoProfile -ExecutionPolicy Bypass -File "script.ps1" ...`

---

**Ultima modifica**: 2026-01-05
**Status**: permanente (modificare solo se cambiano fondamentali)
