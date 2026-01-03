# TODO - Sync Mobile & Drive

## Priority High 🔴

### Core Implementation

- [ ] **Sync-MobileArchive.ps1** ⭐
  - Implementare algoritmo sync completo
  - Features:
    - Scansione ricorsiva tutte cartelle `Mobile`
    - Mapping percorsi (D:\2019\Lucca\Mobile → Phone:\DCIM\SSD\2019\Lucca)
    - Sync incrementale (solo modifiche)
    - Gestione eliminazioni
  - Parametri: `-Source`, `-Destination`, `-WhatIf`, `-Force`
  
- [ ] **Sync-DriveArchive.ps1** ⭐
  - Clone di Sync-MobileArchive ma per Google Drive
  - Mapping: D:\ANNO\Evento\Drive → GoogleDrive:\MediaArchive\ANNO\Evento
  - Supporto API Google Drive (opzionale, o via filesystem montato)

### Safety Features

- [ ] **Snapshot System**
  - Salvare stato prima/dopo ogni sync
  - File: `.sync_snapshot.json` (hash, timestamp, dimensione per ogni file)
  - Permettere rollback se sync errato

- [ ] **Conflict Detection**
  - Rilevare se file modificato sia in source che destination
  - Report conflitti per review manuale
  - Strategia: Source always wins (one-way sync)

- [ ] **Dry-Run Mode**
  - `-WhatIf` che mostra TUTTO ciò che farà
  - Report dettagliato: file copiati, rimossi, aggiornati
  - Statistiche: spazio liberato/occupato

## Priority Medium 🟡

### Performance

- [ ] **Parallel Copy**
  - Copiare file in parallelo (Thread pool)
  - Massimo 4-8 thread simultanei
  - Progress bar aggregato

- [ ] **Resume Support**
  - Riprendere sync interrotto
  - Salvare stato intermedio
  - Skip file già copiati correttamente

- [ ] **Smart Sync Algorithm**
  - Comparare hash invece di solo timestamp/size
  - Rilevare file rinominati (stesso hash, nome diverso)
  - Skip re-copy di file identici

### Google Drive Integration

- [ ] **Google Drive API Support**
  - Upload diretto via API (più veloce di filesystem)
  - Autenticazione OAuth
  - Gestione quota/limiti rate
  
- [ ] **Sync Bidirectional (Futuro)**
  - Download da Drive → SSD se modificato
  - Gestione conflitti automatica
  - **Rischio**: Complessità alta, solo se davvero necessario

## Priority Low 🟢

### Monitoring & Reporting

- [ ] **Sync Statistics Dashboard**
  - Report HTML con statistiche sync
  - Grafico spazio occupato nel tempo
  - File più grandi, cartelle più popolate

- [ ] **Email Notifications**
  - Invia email al termine sync
  - Report errori/warnings
  - Integration SMTP

### Advanced Features

- [ ] **Selective Sync Rules**
  - Escludere file per estensione (`.tmp`, `.cache`)
  - Escludere cartelle specifiche
  - Filtrare per dimensione (es: solo file < 50MB su mobile)

- [ ] **Compression on Sync**
  - Opzione: comprimi video durante sync
  - Riduce ulteriormente spazio mobile
  - Mantiene originali su SSD

- [ ] **Auto-Sync on Schedule**
  - Task scheduler Windows
  - Sync automatico giornaliero/settimanale
  - Solo se dispositivo connesso

## Nice to Have 💡

### UI/UX

- [ ] **GUI Tool**
  - Interfaccia grafica per non-tecnici
  - Visualizza struttura cartelle Mobile
  - Preview sync prima di eseguire
  - Progress bar visuale

- [ ] **Mobile App Companion**
  - App Android per gestire subset
  - Scegliere cartelle da sincronizzare
  - Trigger sync da telefono

### Integration

- [ ] **iCloud Photos Sync**
  - Sync anche verso iCloud
  - Mantiene metadata EXIF
  - Alternativa a Google Drive

- [ ] **OneDrive Support**
  - Terza destinazione oltre Mobile/Drive
  - Stessa logica cartelle servizio (`OneDrive/`)

## Research & Planning 🔬

- [ ] **Test Performance**
  - Benchmark: filesystem copy vs Drive API vs rclone
  - Trovare bottleneck
  - Ottimizzare algoritmo

- [ ] **Conflict Resolution Strategies**
  - Studio approcci altri tool (Syncthing, rsync, rclone)
  - Definire policy chiara conflitti
  - Documentare edge cases

- [ ] **Metadata Preservation**
  - Verificare che sync preserva EXIF/timestamps
  - Test su vari formati (JPG, PNG, MP4, MOV)
  - Fix se Google Drive/Mobile corrompe metadata

## Completed ✅

- [x] Progetto documentato (README.md) - 2026-01-03
- [x] Definita struttura cartelle servizio (Mobile, Drive) - 2026-01-03
- [x] Specifiche algoritmo sync - 2026-01-03
- [x] Sync-Mobile.ps1 (PC↔Pixel, 3 modes) - 2026-01-03

---

**Note**: Questo è il progetto più complesso da implementare. Iniziare con versione base (copy one-way) e iterare.
