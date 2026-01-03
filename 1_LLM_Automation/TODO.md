# TODO - LLM Automation

## Priority High 🔴

### Date Fix Tools

- [ ] **Script: Uniform-SingleDayDates.ps1**
  - Forza tutti i file di una cartella a una singola data
  - Use case: Gita di un giorno, tutte foto stesso evento
  - Sicurezza: Solo se utente conferma esplicitamente data
  - Parametri: `-FolderPath`, `-TargetDate`, `-WhatIf`

- [ ] **Script: Verify-MetadataAlignment.ps1**
  - Verifica che EXIF, filesystem timestamps siano allineati
  - Use case: Dopo resize/copy, check se date sono coerenti
  - Report: File con mismatch tra DateTimeOriginal vs LastWriteTime
  - Auto-fix opzionale

### Intelligence Duplicati

- [ ] **Migliorare SmartDuplicateFinder**
  - Aggiungere fuzzy match sui nomi file (oltre a hash)
  - Rilevare video stesso contenuto ma risoluzione diversa
  - Suggerire quale versione tenere (migliore qualità/più vecchia data)

## Priority Medium 🟡

### Analysis Tools

- [ ] **Script: Analyze-TimelineGaps.ps1**
  - Trova "buchi" nella timeline (es: 2019 ha gen-mar, poi salta a nov)
  - Suggerisce cartelle/file che potrebbero essere fuori posto
  - Aiuta a capire dove mettere file orfani

- [ ] **Script: Analyze-FolderNamingPatterns.ps1**
  - Scansiona cartelle e trova pattern di naming incoerenti
  - Report: Cartelle con nomi simili ma struttura diversa
  - Suggerisce standardizzazione

### GPS Integration

- [ ] **Extract GPS Coordinates to Map**
  - Estrarre coordinate GPS da tutte le foto
  - Creare mappa interattiva eventi/viaggi
  - Usare per validare date (se foto in Italia ma dice data viaggio Spagna → sbagliata)

## Priority Low 🟢

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
  - Input: Path cartella, nomi file, dimensioni, pattern
  - Output: Confidenza su data proposta
  - Ridurre intervento manuale su casi semplici

## Ideas / Nice to Have 💡

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

## Completed ✅

- [x] Fix-MediaDates.ps1 - singola cartella
- [x] Fix-MediaDates-Batch.ps1 - batch multi-cartella
- [x] Regole naming standardizzate (YYYYMMDD_Nome_N.ext)
- [x] Gestione cartelle servizio (Mobile, Drive trasparenti)
- [x] Fix metadati PNG ridimensionati
- [x] Rimozione numero superfluo per file unici
- [x] Data MAX invece di mediana per file forzati
- [x] Documentazione regole REGOLE_ORGANIZZAZIONE_MEDIA.md
- [x] Remove-EmptyFolders.ps1
- [x] Analysis suite base (MediaArchive, OldMetadata, etc.)
- [x] Duplicate management base (SmartDuplicateFinder, WhatsApp cleaner)

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
- Sample: E:\2024\Attraversamento lago (9 videos, 3 images)
- WhatsApp files: 7 detected correctly
- No duplicates found (expected)
- Empty folders: 4 found (Mobile/Drive)

**Status: ALL TOOLS PRODUCTION READY** ?

## NEW: Advanced Date Fix Strategy (MAX vs Median)

### Context
**Problem Solved**: Median forcing creates visual discontinuity in gallery.
**Solution**: Use MAX date (end of range) for anomalous files.

### High Priority Implementation

- [x] **Force-DateToMax.ps1** (Implemented 2026-01-03)
  - Auto-detect date range from GPS/EXIF
  - Calculate MAX date from valid files
  - Force anomalous files to MAX (end of event)
  - Interactive confirmation
  - Use case: Short vacations, single events

- [x] **Force-DateFromReference.ps1** (Implemented 2026-01-03)
  - Drag & drop reference file with correct date
  - Extract date from reference
  - Apply to all files in folder
  - Easier than manual date input
  - Use case: Single day trips

### Medium Priority Workflows

- [ ] **Quarantine-AnomalousDates.ps1**
  - Scan year folders (e.g., 2020)
  - Find files with wrong year
  - Move to `_DATE_ISSUES\` for manual review (per-year)
  - Generate report
  - NOTE: Per cartelle anno intere (es: `D:\2020`), NON usare Force-DateToMax (range troppo ampio) → Quarantena prima

- [ ] **Batch Month Fix Workflow**
  - After quarantine, user organizes by month (10_2020, 02_2020, etc.)
  - Script batch applies dates per subfolder (o usa Force-DateFromReference su ogni sottocartella mese)
  - Force all to last day of month
  - Regola: se un mese ha un solo evento/giornata, si può anche forzare tutti a quella data (reference file)

### Strategy Rules (IMPORTANT!)

**MAX not Median**:
- Files with anomalous dates ? END of event
- Preserves visual chronology
- Example: Vacation 12/08 ? 20/08
  - Anomalous files ? 20/08 (not 16/08 median)

**Range Detection**:
- GPS dates = most reliable
- LastWriteTime if year matches folder
- Fall back to manual/reference file
 - Se il range rilevato è troppo ampio (tipico delle cartelle anno), fermati e usa Quarantine workflow
