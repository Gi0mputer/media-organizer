# TODO - LLM Automation

## Priority High

### Date Fix Tools

- [ ] **Script: Uniform-SingleDayDates.ps1**
  - Forza tutti i file di una cartella a una singola data
  - Use case: gita di un giorno, tutte foto stesso evento
  - Sicurezza: solo se utente conferma esplicitamente la data
  - Parametri: `-FolderPath`, `-TargetDate`, `-WhatIf`

- [ ] **Script: Rename-LegacyDayMarkers.ps1**
  - Rinomina ricorsivamente `sameday\` -> `1day\` (preview + execute)
  - Use case: standardizzare tag marker per day fix

- [ ] **Script: Verify-MetadataAlignment.ps1**
  - Verifica che EXIF e filesystem timestamps siano allineati
  - Use case: dopo resize/copy, check se date sono coerenti
  - Report: mismatch tra DateTimeOriginal / CreateDate / LastWriteTime
  - Auto-fix opzionale

### Intelligence Duplicati

- [ ] **Migliorare SmartDuplicateFinder**
  - Aggiungere fuzzy match sui nomi file (oltre a hash)
  - Rilevare video stesso contenuto ma risoluzione diversa
  - Suggerire quale versione tenere (migliore qualità / più vecchia data)

## Priority Medium

### Analysis Tools

- [ ] **Script: Analyze-TimelineGaps.ps1**
  - Trova "buchi" nella timeline (es: 2019 ha gen-mar, poi salta a nov)
  - Suggerisce cartelle/file che potrebbero essere fuori posto
  - Aiuta a capire dove mettere file orfani

- [ ] **Video-Health-Diagnostics.ps1 - Mobile subset mode**
  - Aggiungere filtro: scan solo dentro cartelle `_mobile\` (e/o per anno/evento)
  - Motivo: full scan su D:\+E:\ può essere molto lungo
  - Output: report separato per subset “telefono”

- [ ] **Script: Analyze-FolderNamingPatterns.ps1**
  - Scansiona cartelle e trova pattern di naming incoerenti
  - Report: cartelle con nomi simili ma struttura diversa
  - Suggerisce standardizzazione

### GPS Integration

- [ ] **Extract GPS Coordinates to Map**
  - Estrarre coordinate GPS da tutte le foto
  - Creare mappa interattiva eventi/viaggi
  - Usare per validare date (se foto in Italia ma dice data viaggio Spagna -> sbagliata)

## Priority Low

### Automation Enhancements

- [ ] **Auto-detect Event Names**
  - Analizzare file dentro cartella e suggerire nome evento
  - Usare cluster GPS, analisi testo OCR su foto, pattern date
  - Ridurre naming manuale

- [ ] **Batch Operations Log**
  - Salvare log dettagliato di ogni operazione batch
  - Permettere undo/rollback se qualcosa va storto
  - File: `.batch_history.json`

### Machine Learning (Futuro)

- [ ] **ML Model: Date Prediction**
  - Training su archivio esistente (corretto manualmente)
  - Input: path cartella, nomi file, dimensioni, pattern
  - Output: confidenza su data proposta
  - Ridurre intervento manuale su casi semplici

## Ideas / Nice to Have

### Metadata Enrichment

- [ ] Aggiungere tag automatici basati su:
  - Località GPS (città, paese)
  - Persone nelle foto (face recognition - opzionale)
  - Oggetti/scene (image recognition)

### Cross-Platform Sync

- [ ] Estendere fix date anche per:
  - Google Photos metadata (API)
  - iCloud Photos Library
  - Mantenere sync bidirezionale

### UI/UX

- [ ] **GUI Tool per Fix Date**
  - Interfaccia grafica per utenti non tecnici
  - Preview visivo modifiche
  - Drag & drop cartelle

## Completed

- [x] Fix-MediaDates.ps1 - singola cartella
- [x] Fix-MediaDates-Batch.ps1 - batch multi-cartella
- [x] Regole naming standardizzate (YYYYMMDD_Nome_N.ext)
- [x] Gestione cartelle servizio (Mobile/Drive trasparenti)
- [x] Fix metadati PNG ridimensionati
- [x] Rimozione numero superfluo per file unici
- [x] Data MAX invece di mediana per file forzati
- [x] Documentazione regole `REGOLE_ORGANIZZAZIONE_MEDIA.md`
- [x] Remove-EmptyFolders.ps1
- [x] Analysis suite base (MediaArchive, OldMetadata, ecc.)
- [x] Duplicate management base (SmartDuplicateFinder, WhatsApp cleaner)

- [x] **Process-DayMarkerFolders.ps1** - `1day/Nday` fix + move contenuti fuori + suffix `1day_2` - 2026-01-05
- [x] **Audit-GalleryDates.ps1** - audit `_gallery` (errori/fix candidates) - 2026-01-05
- [x] **Rename-ServiceFoldersToUnderscore.ps1** - `Mobile/Gallery/Trash` -> `_mobile/_gallery/_trash` - 2026-01-05

---

**Note**: Quando completi un task, spostalo in "Completed" con data e breve nota.

## Test Results - 2026-01-03

**All Tools Tested Successfully:**
- [x] Video-Health-Diagnostics.ps1 - Fixed FPS threshold (100000 vs 1000)
- [x] Fix-MediaDates.ps1 - GPS auto-detection working
- [x] REPAIR_VIDEO.ps1 - Detection logic validated
- [x] SmartDuplicateFinder.ps1 - Hash + WhatsApp patterns working
- [x] Analyze-MediaArchive.ps1 - Report generation OK
- [x] Remove-EmptyFolders.ps1 - Preview mode tested
- [x] STANDARDIZE_VIDEO_UNIVERSAL.ps1 - GPU detection OK

**Test Environment:**
- Sample: `E:\2024\Attraversamento lago` (9 video, 3 immagini)
- WhatsApp files: 7 detected correctly
- No duplicates found (expected)
- Empty folders: 4 found (Mobile/Drive)

**Status**: ALL TOOLS PRODUCTION READY ?

## Advanced Date Fix Strategy (MAX vs Median)

### Context
**Problem Solved**: la mediana crea discontinuità visiva in galleria.
**Solution**: usare MAX date (fine intervallo) per file anomali.

### High Priority Implementation

- [x] **Force-DateToMax.ps1** (Implemented 2026-01-03)
  - Auto-detect date range da GPS/EXIF
  - Calcola MAX date dai file validi
  - Forza gli outlier alla MAX (fine evento)
  - Conferma interattiva
  - Use case: vacanze/eventi brevi

- [x] **Force-DateFromReference.ps1** (Implemented 2026-01-03)
  - Drag & drop reference file con data corretta
  - Estrae data dal reference
  - Applica a tutti i file della cartella
  - Use case: eventi single-day

### Medium Priority Workflows

- [ ] **Quarantine-AnomalousDates.ps1**
  - Scan cartelle anno (es: `D:\2020`)
  - Trova file con anno sbagliato
  - Sposta in `_DATE_ISSUES\` per review manuale (per-year)
  - NOTE: su cartelle anno NON usare Force-DateToMax (range troppo ampio) -> quarantena prima

- [ ] **Batch Month Fix Workflow**
  - Dopo quarantena, organizzare per mese (10_2020, 02_2020, ecc.)
  - Script batch applica date per sottocartella (o usare Force-DateFromReference su ogni mese)
  - Regola: se un mese ha un solo evento/giornata, si può forzare tutto a quella data (reference file)

### Strategy Rules (IMPORTANT!)

**MAX, non mediana**:
- File con date anomale -> fine evento
- Preserva la cronologia visiva

**Range Detection**:
- GPS dates = più affidabile
- LastWriteTime se anno coerente con cartella
- Fallback a manual/reference file
  - Se il range rilevato è troppo ampio (tipico delle cartelle anno), fermati e usa Quarantine workflow
