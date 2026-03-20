# TODO — Media Archive Management

> Aggiornato: 2026-03-19
> Consegne utente riordinate + task list in step stabili.

---

## Consegne attive (da utente)

- **Fix date + nomi su D:\\** — tutte le cartelle anno da 2016 a 2023, formato standard `YYYYMMDD_NomeDescrittivo_N.ext`

---

## Task list: Fix D:\ (step successivi)

### Step 1 — Ricognizione D:\
- [ ] Listare anni presenti in D:\
- [ ] Per ogni anno: contare cartelle e stimare entità lavoro
- [ ] Identificare se ci sono già cartelle con naming corretto da saltare

### Step 2 — Fix anno per anno (inizia da D:\2016 o il più vecchio)
Per ogni anno:
- [ ] Scan EXIF: `exiftool -r -DateTimeOriginal -FileName "D:\ANNO\"`
- [ ] Identifica outlier (anni sbagliati / date fuori range evento)
- [ ] Fix outlier con `Force-DateToMax.ps1` o `Force-DateFromReference.ps1`
- [ ] Rinomina file nel formato standard
- [ ] Verifica finale + commit

### Step 3 — File ._  macOS (da fare su tutti i dischi)
- [ ] Scan D:\ per file `._*` (resource fork macOS)
- [ ] Eliminarli (stessa logica usata su E:\Snow)

### Step 4 — Verifica file WhatsApp su D:\
- [ ] Identifica JPG `IMG-YYYYMMDD-WA*` e video `VID-YYYYMMDD-WA*` con date errate
- [ ] Fix con stesso approccio usato su E:\Snow

---

## Backlog (non urgente)

### MemoryManage — cartelle foglia più pesanti
- [x] Script `Create-MemoryManage.ps1` creato — 2026-03-19
- [x] `D:\MemoryManage\` creata con 20 junction (top pesante: STUBAI2k21 28GB) — 2026-03-20
- [ ] `E:\MemoryManage\` — da creare quando E:\ è montato (rieseguire con `-Execute`)

### LLM Automation
- [ ] `Quarantine-AnomalousDates.ps1` — sposta file con anno sbagliato in `_DATE_ISSUES\` per review manuale
- [ ] `Batch Month Fix Workflow` — fix batch per mese dopo quarantena
- [ ] `Verify-MetadataAlignment.ps1` — verifica EXIF vs filesystem timestamps (post-resize/copy)
- [ ] `Uniform-SingleDayDates.ps1` — forza tutti i file di una cartella a una data singola

### DragDrop Tools
- [ ] `Verify-MetadataAlignment.bat` — wrapper per lo script sopra
- [ ] `Batch-Merge-Videos.bat` — merge video stessa cartella con pre-standardizzazione
- [ ] `Convert-HEIC-to-JPG.bat` — converte foto iPhone HEIC → JPG preservando EXIF

### Sync iPhone
- [ ] Sync bidirezionale intelligente (rilevare spostamenti su iPhone e replicarli su PC)
- [ ] Script download `DCIM/Camera` → Inbox PC per smistamento manuale

---

## Completato

- [x] Paradigma phone-first: `_mobile`/`_gallery` aboliti, root evento = phone-worthy, `_pc\` = solo PC — 2026-03-16
- [x] Phone Mode workflow: `Enable-PhoneMode.ps1`, `Restore-PCMode.ps1`, `Import-PhoneChanges.ps1` — 2026-03-17
- [x] Primo sync iPhone: 1093 file trasferiti, history salvata in `E:\_sys\` — 2026-03-17
- [x] `Flatten-NestedPc.ps1`: collassa `_pc` annidati — 81 cartelle, 842 item — 2026-03-17
- [x] BAT `-DeltaOnly` per Phone Mode (E:\ e D:\) — 2026-03-17
- [x] Fix E:\Snow: 66 file `._ ` eliminati, 95 JPG WA fixati, 56 video WA fixati — 2026-03-19
- [x] `Process-DayMarkerFolders.ps1`: gestione cartelle `1day`/`Nday` — 2026-01-05
- [x] `Force-DateToMax.ps1` + `Force-DateFromReference.ps1` — 2026-01-03
- [x] `Reorganize-PhonePc.ps1`: migrazione al paradigma phone-first — 2026-03-16
- [x] `Migrate-Insta360.ps1`: centralizzazione raw in `E:\Insta360\` — 2026-03-16
- [x] `STANDARDIZE_VIDEO.bat`, `REPAIR_VIDEO.bat`, `Video-Health-Diagnostics.ps1` — 2026-01-03
- [x] Fix naming: formato `YYYYMMDD_NomeDescrittivo_N.ext`, no zero-padding — 2026-01-03
