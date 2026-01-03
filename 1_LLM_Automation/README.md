# LLM Automation - Media Archive

## Scopo

Quest'area contiene **script e processi che richiedono interpretazione LLM/Agente** a causa della loro natura non deterministica e ricca di eccezioni.

Il focus principale è il **fix di date, metadati e nomi file**, che richiede:
- Interpretazione contestuale
- Decisioni basate su euristiche flessibili
- Gestione eccezioni caso per caso
- Linguaggio naturale per regole complesse

## ⚠️ IMPORTANTE: Regole di Lavoro per LLM

Quando lavori in quest'area:

1. **LEGGI SEMPRE** questo README prima di modifiche significative
2. **AGGIORNA TODO.md** dopo ogni implementazione/fix
3. **CONSULTA `Documentation/REGOLE_ORGANIZZAZIONE_MEDIA.md`** per regole naming e metadati
4. **NON introdurre problemi già risolti** - controlla documentazione esistente

## Struttura Cartelle

```
1_LLM_Automation/
├── README.md                    # ← Questo file
├── TODO.md                      # Task futuri
│
├── Scripts/                     # Fix date/metadati interattivi
│   ├── Fix-MediaDates.ps1             # Fix singola cartella con data specifica
│   ├── Fix-MediaDates-Batch.ps1       # Fix batch multi-cartella (usa LastWriteTime)
│   ├── Fix-WeirdDates.ps1             # Fix date anomale
│   └── Dates_Diagnostics.ps1          # Diagnostica problemi date
│
├── Analysis/                    # Analisi archivio per decisioni
│   ├── Analyze-MediaArchive.ps1       # Overview generale archivio
│   ├── Analyze-OldMetadata.ps1        # Trova file con metadati pre-2000
│   ├── Analyze-MisplacedFolders.ps1   # Trova cartelle fuori posto
│   ├── Analyze-AggregationOpportunities.ps1  # Suggerisce accorpamenti
│   └── Find-HighBitrate-DroneVideos.ps1      # Trova video 4K da comprimere
│
├── DuplicateManagement/         # Gestione duplicati complessa
│   ├── SmartDuplicateFinder.ps1       # Trova duplicati intelligenti
│   ├── DuplicateCleaner.ps1           # Pulisce duplicati dopo conferma
│   ├── WhatsAppFuzzyFinder.ps1        # Trova copie WhatsApp (fuzzy match)
│   └── Quarantine-WhatsApp.ps1        # Quarantena temporanea WhatsApp
│
├── Maintenance/                 # Manutenzione struttura
│   ├── Remove-EmptyFolders.ps1        # Rimuove cartelle vuote
│   ├── Fix-Orphans.ps1                # Trova file orfani senza contesto
│   ├── Restructure-Archive.ps1        # Riorganizza struttura anno
│   └── Generate-FolderMarkers.ps1     # Crea marker per categorizzazione
│
└── Documentation/               # Documentazione e regole
    ├── REGOLE_ORGANIZZAZIONE_MEDIA.md  # ★ REGOLE NAMING E METADATI
    ├── ACTION_PLAN.md                  # Piano azioni archivio
    ├── AGGREGATION_REPORT.md           # Report accorpamenti
    ├── ANALYSIS_REPORT.md              # Report analisi
    └── DUPLICATE_ANALYSIS_SUMMARY.md   # Summary duplicati
```

## Principi Fondamentali

### 1. Fix Date e Metadati

**Problema**: File con date sbagliate da:
- Copie WhatsApp/Cloud (data copia invece di originale)
- Resize/modifica foto (timestamp aggiornato)
- Import da dispositivi con data/ora sbagliata

**Approccio**:
1. Tentare auto-rilevamento (GPS EXIF, LastWriteTime coerente)
2. Se incerto → Chiedere conferma utente
3. Se pattern chiaro ma con eccezioni → Interpretazione LLM

**Fonti di verità (in ordine)**:
1. GPS DateTime (massima affidabilità)
2. EXIF DateTimeOriginal (se ragionevole)
3. LastWriteTime (se coerente con cartella anno)
4. Deduzione contestuale (cartella, nome file, altri file correlati)
5. Input manuale utente

### 2. Naming Files

**Formato standard**: `YYYYMMDD_NomeDescrittivo_N.ext`

Dove:
- `YYYYMMDD`: Data evento (8 cifre)
- `NomeDescrittivo`: Nome evento/contenuto
- `N`: Numero sequenziale (1, 2, 3... NON 001, 002)
- Numero **omesso** se file unico per quella data+nome

**Regole naming**:
- Nome deriva da **prima sottocartella sotto anno** (es: `D:\2019\Lucca\file.jpg` → `Lucca`)
- Cartelle `Mobile` e `Drive` sono **trasparenti** (non danno nome ai file)
- Preservare sempre **nomi descrittivi scritti a mano** (es: "BaldoBibo", "AlbyPizzeEnd")
- Sostituire codici random (XBDW6157, UUID) con nomi significativi

### 3. Gestione Eccezioni

**Casi comuni**:
- **File 2020 in cartella 2019**: Forzare a data MAX (ultima valida) del 2019
- **File senza GPS/EXIF**: Usare data mediana o MAX degli altri file stessa cartella
- **Cartelle tematiche extra-anno** (Family, Projects): OK, non forzare anno
- **Sottocartelle servizio** (Mobile, MERGE, RAW, Drive): Usare nome cartella padre

## Workflow Tipico

### Scenario: Sistemare cartella evento

```powershell
# 1. Analizza stato attuale
.\Analysis\Dates_Diagnostics.ps1 -FolderPath "D:\2019\Lucca"

# 2. Tenta auto-fix (preview)
.\Scripts\Fix-MediaDates-Batch.ps1 -FolderPaths "D:\2019\Lucca" -WhatIf

# 3. Se date OK → esegui
.\Scripts\Fix-MediaDates-Batch.ps1 -FolderPaths "D:\2019\Lucca"

# 4. Se date sbagliate → fix manuale con data specifica
.\Scripts\Fix-MediaDates.ps1 -FolderPath "D:\2019\Lucca" -TargetDate "2019-11-03"
```

### Scenario: Pulizia duplicati

```powershell
# 1. Trova duplicati
.\DuplicateManagement\SmartDuplicateFinder.ps1 -Source "D:\2019"

# 2. Quarantena WhatsApp (sicuri)
.\DuplicateManagement\Quarantine-WhatsApp.ps1 -Source "D:\2019"

# 3. Review e pulizia manuale
```

## Problemi Risolti (History)

### ✅ Fix Metadati PNG Ridimensionati
**Problema**: Resize foto PNG perdeva metadati EXIF
**Soluzione**: Re-applicare DateTimeOriginal, CreateDate, ModifyDate + ripristino LastWriteTime
```powershell
exiftool -DateTimeOriginal="2019:08:14 12:00:00" -overwrite_original file.png
```

### ✅ Naming Cartelle Servizio
**Problema**: File in `Mobile/` e `MERGE/` prendevano nome dalla sottocartella
**Soluzione**: Cartelle servizio sono trasparenti, usano nome cartella padre
- `D:\2019\Lucca\Mobile\foto.jpg` → `20191103_Lucca.jpg` (NON `Mobile`)

### ✅ Numero File Superfluo
**Problema**: File unici avevano `_001` superfluo
**Soluzione**: Omettere numero se unico per data+nome, altrimenti `_1`, `_2`, `_10` (not 001)

### ✅ Date Forzate in Mezzo alla Timeline
**Problema**: Usare data mediana per file sospetti rompeva cronologia
**Soluzione**: Usare data **MAX** (ultima valida) così vanno alla fine

## Limitazioni Conosciute

- ⚠️ **Non gestisce video .insv Insta360** (formato proprietario, serve tool separato)
- ⚠️ **PNG hanno meno metadati di JPG** (alcuni tool non scrivono EXIF su PNG)
- ⚠️ **Conflitti merge Git** su documenti Markdown se edit simultanei
- ⚠️ **ExifTool richiesto** (non incluso, installare separatamente)

## Prossimi Passi

Vedi [TODO.md](./TODO.md) per task futuri.

---

## Documentation Folder

**REGOLE_ORGANIZZAZIONE_MEDIA.md**: ? Documento FONDAMENTALE con regole complete per naming, metadata fix, date management. **LEGGI SEMPRE prima di operazioni batch su archivio!**

Vecchi report (ACTION_PLAN, AGGREGATION_REPORT, etc.) eliminati - erano snapshot specifici obsoleti.

