# DOCS — Documentazione storica

> Cosa è stato fatto, perché, e come funziona.
> Aggiornato: 2026-03-19

---

## Architettura generale

Due SSD separati per periodo storico:
- `D:\` — archivio vecchio (fino 2023 incluso)
- `E:\` — archivio recente (2024+)

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

**Raw Insta360**: centralizzati fuori dagli eventi in `E:\Insta360\YYYYNomeEvento\` per non sporcare la struttura phone-first. Tool: `Migrate-Insta360.ps1`.

---

## Phone Mode — sync iPhone

**Problema**: iPhone su Windows non supporta sync filesystem diretta (no ADB). Le due vie sono:
- **iPhone Photos** (camera roll/album) → via iCloud Photos
- **iPhone Files** (filesystem) → via SSD esterno exFAT

**Soluzione adottata**: Phone Mode via SSD exFAT.

### Flusso Export (PC → iPhone)
1. `Enable-PhoneMode.ps1` — sposta i file phone-worthy (root di ogni evento) in `E:\_iphone\`, salva manifest JSON
2. [manuale] copia `_iphone\` su iPhone Files via SSD
3. `Restore-PCMode.ps1` — rimette tutto al posto, aggiorna `_iphone_history.json`

Dal secondo sync: `Enable-PhoneMode -DeltaOnly` porta solo i file nuovi (confronto con history).

### Flusso Import (iPhone → PC)
1. [manuale] copia albero da iPhone Files in `E:\_iphone\`
2. `Import-PhoneChanges.ps1` — applica delta: nuovo da iPhone → PC, modificato → aggiorna PC (vecchio in `_trash`), eliminato su iPhone → `_pc\_trash`

### File di sistema
Tutti in `E:\_sys\` (non sporca la root):
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

## Legacy rimosso

- `Sync-Mobile.ps1`, `Setup-ADB.ps1` — Android/ADB (Pixel 8), non più in uso
- `Sync-iPhoneFiles.ps1` — vecchio approccio staging iPhone
- Cartelle `_mobile`, `_gallery` — sostituite dal paradigma phone-first
