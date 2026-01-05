# 1_LLM_Automation - Media Archive

## Scopo
Quest’area contiene script e workflow “assistiti” (LLM/Agente) per casi non deterministici: fix date/metadati, naming, deduzioni contestuali e gestione eccezioni.

Regola pratica:
- se l’utente può farlo in drag & drop -> sta in `2_DragDrop_Tools/`
- se serve logica/euristiche/report -> sta qui

## Struttura
```
1_LLM_Automation/
  README.md
  TODO.md

  Scripts/
    Fix-MediaDates.ps1
    Fix-MediaDates-Batch.ps1
    Force-DateToMax.ps1
    Force-DateFromReference.ps1
    Audit-GalleryDates.ps1

  Maintenance/
    Process-DayMarkerFolders.ps1
    Rename-ServiceFoldersToUnderscore.ps1
    Remove-EmptyFolders.ps1
    Fix-Orphans.ps1

  Analysis/
    (report e strumenti di analisi)

  Documentation/
    REGOLE_ORGANIZZAZIONE_MEDIA.md
```

## Principi fondamentali

### Date (fonti di verità)
Priorità consigliata:
1. GPS DateTime (se presente)
2. EXIF DateTimeOriginal / CreateDate / MediaCreateDate (se ragionevoli)
3. LastWriteTime (solo se coerente con l’anno del contesto)
4. Deduzione contestuale (cartella, altri file, eventi)
5. Input manuale utente

### Strategia “MAX date” (fine intervallo)
Quando un file è “fuori range” (anno sbagliato / outlier):
- non usare mediana
- forzare alla **fine dell’intervallo** (MAX) per preservare la cronologia visuale in galleria

### Cartelle di servizio (trasparenti)
Cartelle tipiche (legacy + canonical):
- `_mobile` (alias: `Mobile`) -> subset privato/di lavoro
- `_gallery` (alias: `Gallery`) -> subset visibile
- `Drive`, `MERGE`, `RAW` -> cartelle tecniche (non danno mai nome)

## Workflow consigliati

### 1) Marker folders `1day/Nday` (prima di tutto)
Quando esistono cartelle `1day`, `1day_2`, `4day`, `4day_2`, ecc.:
- eseguire `Maintenance/Process-DayMarkerFolders.ps1`
- lo script:
  - corregge date/metadati in base alla logica `1day` / `Nday`
  - sposta i contenuti fuori dalla cartella marker
  - elimina la cartella marker

### 2) Audit `_gallery` (prima della sync)
Per evitare file che finiscono “oggi” in galleria:
- eseguire `Scripts/Audit-GalleryDates.ps1`
- se ci sono `ERROR_NO_METADATA_DATE`, correggere con:
  - `2_DragDrop_Tools/MetadataTools/FIX_DATE_FROM_FILENAME.bat` (quando la data è nel filename)
  - oppure fix manuale (date forced a fine intervallo)

### 3) Fix avanzati per eventi
- `Scripts/Force-DateToMax.ps1`: trova range valido e forza outlier alla MAX
- `Scripts/Force-DateFromReference.ps1`: single-day fix usando un file reference

## Dipendenze
Richieste in PATH:
- `exiftool`
- `ffmpeg` / `ffprobe`

## Dopo ogni modifica importante
1. aggiornare `1_LLM_Automation/TODO.md`
2. aggiornare i README delle aree coinvolte
3. salvare report in `1_LLM_Automation/Analysis/` (no “pollution” nell’archivio)
