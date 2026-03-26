# DOCS — Documentazione storica

> Cosa è stato fatto, perché, e come funziona.
> Aggiornato: 2026-03-20

---

## Architettura generale

Due SSD separati per periodo storico:
- `D:\` — archivio vecchio (fino 2023 incluso), quasi sempre `D:\`
- `{R}:\` — archivio recente (2024+), lettera variabile per PC/sessione (E:\, F:\, altro) — verificare `pc_config.local.json`

Nessuna intersezione temporale tra i due. Filesystem exFAT su entrambi per compatibilità iPhone.

Ogni anno contiene cartelle-evento. Ogni file segue il naming `YYYYMMDD_NomeDescrittivo_N.ext`.

---

## Paradigma phone-first (adottato 2026-03-16)

**Problema precedente**: cartelle `_mobile` e `_gallery` dentro ogni evento creavano ridondanza e confusione su cosa andasse sul telefono.

**Soluzione**: struttura semplificata —
```
EventFolder/        ← file phone-worthy (vanno su iPhone)
EventFolder/_pc/    ← tutto il resto (solo PC: raw, editing, duplicati, ecc.)
```

**Come è stato migrato**: `Reorganize-PhonePc.ps1` ha dissolto `_mobile`/`_gallery` nella cartella padre e spostato il resto in `_pc`.

**Raw Insta360**: centralizzati fuori dagli eventi in `{R}:\Insta360\YYYYNomeEvento\` per non sporcare la struttura phone-first. Tool: `Migrate-Insta360.ps1`.

---

## Phone Mode — sync iPhone

**Problema**: iPhone su Windows non supporta sync filesystem diretta (no ADB). Le due vie sono:
- **iPhone Photos** (camera roll/album) → via iCloud Photos
- **iPhone Files** (filesystem) → via SSD esterno exFAT

**Soluzione adottata**: Phone Mode via SSD exFAT.

### Flusso Export (PC → iPhone)
1. `Enable-PhoneMode.ps1` — sposta i file phone-worthy (root di ogni evento) in `{R}:\_iphone\`, salva manifest JSON
2. [manuale] copia `_iphone\` su iPhone Files via SSD
3. `Restore-PCMode.ps1` — rimette tutto al posto, aggiorna `_iphone_history.json`

Dal secondo sync: `Enable-PhoneMode -DeltaOnly` porta solo i file nuovi (confronto con history).

### Flusso Import (iPhone → PC)
1. [manuale] copia albero da iPhone Files in `{R}:\_iphone\`
2. `Import-PhoneChanges.ps1` — applica delta: nuovo da iPhone → PC, modificato → aggiorna PC (vecchio in `_trash`), eliminato su iPhone → `_pc\_trash`

### File di sistema
Tutti in `{R}:\_sys\` (non sporca la root):
- `_iphone_history.json` — history cumulativa trasferimenti (persiste tra cicli)
- `_iphone_manifest.json` — presente solo durante Phone Mode attiva

---

## Gestione date (strategia MAX)

**Problema**: i file con date anomale (es. foto del 2020 con data 2024) apparivano a metà evento nella galleria, rompendo la cronologia visiva.

**Soluzione**: forzare gli outlier alla **MAX date** (fine intervallo evento), non alla mediana. Gli outlier finiscono "in fondo" all'evento, non nel mezzo.

### Fonti di verità (ordine priorità)
1. GPS DateTime
2. EXIF/QuickTime (DateTimeOriginal / CreateDate / MediaCreateDate)
3. LastWriteTime (solo se coerente con anno/contesto)
4. Deduzione contestuale (cartella, altri file)
5. Input manuale

### Tool disponibili
- `Force-DateToMax.ps1` — auto-detect range da GPS/EXIF, forza outlier a MAX
- `Force-DateFromReference.ps1` — drag & drop file reference con data corretta, applica a tutta la cartella
- `Process-DayMarkerFolders.ps1` — gestisce cartelle `1day\` e `Nday\`: fix date + dissolve cartella marker

---

## Cartelle marker `1day` / `Nday`

Usate per segnalare che il contenuto appartiene a un singolo giorno o a un range breve.

- `1day\` → tutto stesso giorno, deduci data, allinea metadati, dissolvi cartella
- `Nday\` (es. `4day\`) → range breve, N è limite superiore per eccesso; rileva range reale, forza outlier a MAX, dissolvi

Tool: `Process-DayMarkerFolders.ps1` + wrapper `PROCESS_DAY_MARKERS.bat`.

---

## Fix file macOS `._` (2026-03-19)

**Problema**: iPhone Photos mostrava alcune foto con data "martedì" (= 2026-03-18) invece della data evento. Causa: file `._NomeFile` (resource fork macOS) presenti nell'archivio — Apple Photos li leggeva come file media con timestamp di sistema.

**Soluzione**: eliminare tutti i file `._*` che hanno una controparte reale. Eseguito su `E:\Snow`: 66 file eliminati.

**Regola generale**: prima di ogni sync iPhone, eseguire uno scan per file `._*`.

---

## Fix date WhatsApp / Google (2026-03-19)

**Problema**: JPG e video condivisi via WhatsApp/Google hanno spesso date EXIF errate o assenti. Il filename invece contiene la data corretta (`IMG-YYYYMMDD-WA*`, `VID-YYYYMMDD-WA*`, `YYYYMMDD_HHmmss_NNN.mp4`).

**Soluzione**:
- JPG: scrivere `DateTimeOriginal` + `CreateDate` da filename con exiftool
- Video MP4: scrivere 6 tag QuickTime espliciti (`QuickTime:CreateDate`, `ModifyDate`, `TrackCreateDate`, `TrackModifyDate`, `MediaCreateDate`, `MediaModifyDate`)

**Nota tecnica**: `-AllDates` fallisce su MP4 WhatsApp perché `IFD0:ModifyDate` contiene `0000:00:00` non parsabile. Non usare `-AllDates` su questi file — specificare i tag QuickTime uno per uno.

---

## Flatten _pc annidati (2026-03-17)

**Problema**: dopo la migrazione phone-first, alcune cartelle avevano `_pc\_pc\` annidati.

**Soluzione**: `Flatten-NestedPc.ps1` collassa ricorsivamente i `_pc` annidati nel `_pc` padre. Eseguito su E:\: 81 cartelle collassate, 842 item spostati.

---

## Fix date outlier D:\ e F:\ (2026-03-19 / 2026-03-20)

**Problema**: molti file media avevano date di filesystem errate:
- `1979-12-31` — epoch Unix (comune su Android/WhatsApp se il timestamp non viene propagato)
- `1601-01-01` — epoch Windows FILETIME (comune su exFAT dopo copia da certi dispositivi)
- Anni completamente sbagliati (es. foto 2021 con data 2024)

**Cartelle fixate su D:\**:
- `D:\2021Sardegna`, `D:\2021MotoConRiki` — outlier pushati a MAX range evento
- `D:\2022` — 47 file fixati da filename
- `D:\2023` — 72 file fixati da filename

**Cartelle fixate su {R}:\ (recent SSD, era F:\ in quella sessione)**:
- `F:\2024`: CapodannoBerlino (3 WA), Croazia (2 Screenshot), Laurea (2 IMG/WA) — 7 file
- `F:\2025`: arezzo (7), Como (9), FerrataAquile (5), GiroMotoDolomiti (5), SardegnaMoto (109 + 2 compose_video) — 133 file

**Strategia fix**:
1. Estrarre data dal filename con regex (WA, IMG_, VID_, PXL_, YYYYMMDD_, dji_fly_, Screenshot_, compose_video_ Unix ts)
2. Scrivere EXIF (`DateTimeOriginal`+`CreateDate` per foto, 6 tag QuickTime per video)
3. Aggiornare `LastWriteTime` filesystem
4. Fallback: MAX date della sottocartella (per file senza data nel nome)

**Pattern riconosciuti** (copertura ~99% dei file moderni):
- `IMG/VID-YYYYMMDD-WA*` — WhatsApp
- `IMG/VID_YYYYMMDD_HHMMSS` — Android camera
- `PXL_YYYYMMDD_HHMMSS` — Google Pixel (tutti i suffissi: `.MP`, `.NIGHT`, `.LS`, `~2`, `_exported_`)
- `YYYYMMDD_HHMMSS_NNN` — Insta360 / camera custom
- `dji_fly_YYYYMMDD_HHMMSS` — DJI drone
- `Screenshot_YYYY-MM-DD-HH-MM-SS` / `Screenshot_YYYYMMDD-HHMMSS` — Android
- `compose_video_UNIX_MS` — app video Android (timestamp Unix in millisecondi)

---

## MemoryManage (2026-03-20)

**Problema**: trovare velocemente le cartelle piu pesanti per fare pulizia senza dover navigare l'albero.

**Soluzione**: `1_LLM_Automation/Maintenance/Create-MemoryManage.ps1` crea junction points in `D:\MemoryManage\` e `E:\MemoryManage\` (o `F:\MemoryManage\`) puntando alle cartelle foglia piu pesanti.

**Stato**:
- `D:\MemoryManage\` — creata con 20 junction (top: STUBAI2k21 28GB, 2023Spagna 21GB)
- `{R}:\MemoryManage\` — da creare quando disco montato: `.\Create-MemoryManage.ps1 -Execute`

**Parametri**: `-TopN 20 -MinSizeMB 200 -Execute` (senza `-Execute` mostra solo preview).
Esclusioni: `_sys`, `_pc`, `_trash`, `MemoryManage`, `FOUND.000`, `System Volume Information`, `$RECYCLE.BIN`, `{R}:\Insta360`.

---

## Legacy rimosso

- `Sync-Mobile.ps1`, `Setup-ADB.ps1` — Android/ADB (Pixel 8), non più in uso
- `Sync-iPhoneFiles.ps1` — vecchio approccio staging iPhone
- Cartelle `_mobile`, `_gallery` — sostituite dal paradigma phone-first
