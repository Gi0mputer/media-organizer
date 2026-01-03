# Progetto: Sincronizzazione Mobile & Drive

## Principio Fondamentale

**Cartelle di servizio `Mobile` e `Drive` = Subset selettivo del media archive**

Queste cartelle speciali marcano quali file devono essere sincronizzati su dispositivi/cloud con spazio limitato.

## Struttura Filesystem

### Organizzazione Base

```
D:\
├── 2019\                    # Cartella anno
│   ├── file1.jpg           # File liberi dell'anno
│   ├── Mobile\             # ← Cartella servizio (file per telefono)
│   ├── Drive\              # ← Cartella servizio (file per cloud)
│   ├── Lucca\              # Sottocartella evento
│   │   ├── foto.jpg
│   │   └── Mobile\         # ← Subset Lucca per telefono
│   └── SpagnaCalaLevado\
│       ├── video.mp4
│       └── Drive\          # ← Subset Spagna per cloud
│
├── 2020\
│   └── Mobile\
│
└── Family\                  # Cartella extra-anno (tematica persistente)
    ├── foto_famiglia.jpg
    └── Mobile\
```

### Regole Strutturali

1. **Cartelle principali**: Anno (2019, 2020) + Tematiche extra-anno (Family, Projects, etc.)
2. **File liberi**: Possono esistere direttamente dentro cartelle anno/tema
3. **Sottocartelle**: Raggruppano file correlati per argomento/evento
4. **Cartelle servizio**: `Mobile` e `Drive` possono esistere a QUALSIASI LIVELLO

**IMPORTANTE**: `Mobile` e `Drive` sono **trasparenti** per il naming dei file.
- File in `D:\2019\Lucca\Mobile\foto.jpg` → Nome: `20191103_Lucca.jpg` (NON `Mobile`!)

## Sistema di Sincronizzazione

### Destinazione Mobile (Telefono)

**Percorso base**: `Telefono:\DCIM\SSD\`

**Logica**: Ricrea la struttura ad albero, collassando le cartelle `Mobile`

**Esempio mapping**:
```
Sorgente                          → Destinazione
─────────────────────────────────────────────────────────
D:\2019\Mobile\foto.jpg           → DCIM\SSD\2019\foto.jpg
D:\2019\Lucca\Mobile\video.mp4    → DCIM\SSD\2019\Lucca\video.mp4
D:\2020\Mobile\snap.jpg           → DCIM\SSD\2020\snap.jpg
D:\Family\Mobile\ritratto.jpg     → DCIM\SSD\Family\ritratto.jpg
```

**Nota**: La cartella `Mobile` viene "collassata" - i file vanno nella cartella padre replicata.

### Destinazione Drive (Google Drive)

**Percorso base**: `GoogleDrive:\MediaArchive\`

**Logica**: Identica a Mobile, ma per il cloud

**Esempio mapping**:
```
D:\2019\SpagnaCalaLevado\Drive\panorama.jpg → GoogleDrive:\MediaArchive\2019\SpagnaCalaLevado\panorama.jpg
```

## Algoritmo di Sincronizzazione

### Prima Esecuzione (Setup Iniziale)

```
1. Scansiona TUTTO il filesystem sorgente (D:\, E:\, etc.)
2. Trova TUTTE le cartelle chiamate "Mobile" o "Drive"
3. Per ogni cartella trovata:
   a. Estrai il percorso relativo (es: 2019\Lucca)
   b. Crea la struttura nella destinazione (DCIM\SSD\2019\Lucca)
   c. Copia TUTTI i file da Mobile/Drive → destinazione
4. Salva snapshot dello stato (hash/timestamp per ogni file)
```

### Esecuzioni Successive (Sync Incrementale)

```
1. Scansiona cartelle Mobile/Drive nel sorgente
2. Confronta con snapshot precedente
3. Per ogni cartella Mobile/Drive:
   
   AGGIUNGI:
   - File nuovi presenti in Mobile/Drive ma non in destinazione
   
   RIMUOVI:
   - File in destinazione ma non più in Mobile/Drive
   - Cartelle vuote
   
   AGGIORNA:
   - File modificati (diverso timestamp/size/hash)
   
4. Gestione cartelle:
   - Se nuova cartella Mobile/Drive → crea struttura in destinazione
   - Se cartella Mobile/Drive rimossa → elimina cartella in destinazione
   
5. Aggiorna snapshot
```

## Caratteristiche del Sistema

### Sicurezza

- ✅ **One-way sync**: Sorgente → Destinazione (mai il contrario)
- ✅ **Preview mode**: Mostra cosa farà prima di eseguire
- ✅ **Log dettagliato**: Traccia ogni operazione
- ⚠️ **Nessun backup automatico**: Se file rimosso da Mobile → eliminato da telefono

### Performance

- **Incremental sync**: Solo file modificati/nuovi (non ri-copia tutto)
- **Hash-based detection**: Rileva file duplicati/rinominati
- **Parallel copy**: Copia file in parallelo dove possibile

### Flessibilità

- Funziona con **qualsiasi** struttura di cartelle
- **Non richiede naming specifico** dei file
- **Agnostico** rispetto a date/metadati

## Casi d'Uso

### Scenario 1: Preparare foto per viaggio
```
1. Vai in D:\2019\SpagnaCalaLevado
2. Crea cartella "Mobile"
3. Copia dentro le 20 foto migliori
4. Esegui sync → Le foto appaiono nel telefono in SSD\2019\SpagnaCalaLevado
```

### Scenario 2: Backup selettivo su Drive
```
1. In D:\Family\Mobile → foto da tenere sempre nel telefono
2. In D:\Family\Drive → backup completo famiglia su cloud
3. Sync Mobile → Telefono ha poche foto selezionate
4. Sync Drive → Cloud ha archivio completo famiglia
```

### Scenario 3: Pulizia spazio telefono
```
1. Rimuovi file da D:\2019\Lucca\Mobile
2. Esegui sync → File eliminati automaticamente da telefono
3. Spazio liberato 🎉
```

## Implementazione

### Script PowerShell

**File**: `Sync-Mobile.ps1`
- Parametri: `-Mode [PC2Phone|Phone2PC|Phone2PCDelete]`, `-SourceDisk [Both|Recent|Old]`, `-ScanRoots`, `-WhatIf`, `-Execute`, `-ConfigPath`
- Config: `device_config.json` (path Pixel + dischi)
- Output: log in `3_Sync_Mobile_Drive\\Logs\\` + snapshot in `3_Sync_Mobile_Drive\\.state\\`

**File**: `Sync-DriveArchive.ps1`
- Come sopra, ma per Google Drive

### Workflow Tipico

```powershell
# Preview cosa farà
.\Sync-Mobile.ps1 -Mode PC2Phone -WhatIf

# Esegui sync
.\Sync-Mobile.ps1 -Mode PC2Phone -Execute

# Preview telefono -> PC (add-only)
.\Sync-Mobile.ps1 -Mode Phone2PC -WhatIf

# Esegui telefono -> PC (add-only)
.\Sync-Mobile.ps1 -Mode Phone2PC -Execute

# Statistiche
# Copiati: 15 file (245 MB)
# Rimossi: 3 file (12 MB)
# Aggiornati: 2 file (8 MB)
# Tempo: 12 secondi
```

## Vantaggi del Sistema

1. **Controllo granulare**: Scegli esattamente cosa va dove
2. **Nessuna duplicazione**: Stessa struttura logica, subset fisico
3. **Facile manutenzione**: Aggiungi/rimuovi da cartelle Mobile/Drive
4. **Spazio ottimizzato**: Solo contenuto selezionato su dispositivi limitati
5. **Sincronizzazione automatica**: Un comando per allineare tutto

## Limitazioni e Note

- ⚠️ Non gestisce conflitti (es: stesso file modificato in entrambi i lati)
- ⚠️ Eliminazione è permanente (nessun cestino/versioning)
- ℹ️ Richiede accesso diretto al filesystem destinazione (telefono via cavo USB o Google Drive montato)
- ℹ️ Google Drive sync può usare API ufficiale per migliori performance (opzionale)
