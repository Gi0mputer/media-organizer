# TODO - Sync Mobile & Drive

## Priority High

### Core Implementation

- [x] **Sync-Mobile.ps1**
  - 3 modalità: `PC2Phone`, `Phone2PC`, `Phone2PCDelete`
  - Mapping (Pixel 8): base `PC\\Pixel 8\\Memoria condivisa interna\\SSD`
    - PC `_gallery`/`Gallery` -> dissolve nel parent (visibile in Google Foto)
    - PC `_mobile`/`Mobile` -> `...\\Mobile\\...` + `.nomedia` (nascosto in Google Foto)
  - Safety: preview/confirm/log + snapshot (delete su telefono/PC solo se già gestiti, salvo `-Force`)

- [ ] **Sync-DriveArchive.ps1**
  - Clone di Sync-Mobile ma per Google Drive
  - Mapping: `<disk>:\\ANNO\\Evento\\Drive` -> `GoogleDrive:\\MediaArchive\\ANNO\\Evento`
  - Supporto API Google Drive (opzionale, o via filesystem montato)

### Safety Features

- [x] **Snapshot System (size + lastWriteUtc)**
  - Stato per `PC2Phone`: `3_Sync_Mobile_Drive/.state/snapshot_pc2phone.json`
  - Usato per:
    - delete safe (non elimina file “phone-only” se non gestiti da snapshot, salvo `-Force`)
    - replace detection (stesso nome, contenuto diverso)
  - TODO futuro: aggiungere hash (PC-side) per rinomina/conflitti avanzati

- [ ] **Conflict Detection**
  - Rilevare se file modificato sia in source che destination
  - Report conflitti per review manuale
  - Strategia: definire policy chiara per mode

- [x] **Dry-Run Mode**
  - Default = preview (o `-WhatIf`): mostra piano + log senza modifiche
  - `-Execute` applica

## Priority Medium

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
  - Download da Drive -> SSD se modificato
  - Gestione conflitti automatica
  - **Rischio**: complessità alta, solo se davvero necessario

## Priority Low

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

## Nice to Have

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

## Research & Planning

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

## Completed

- [x] Progetto documentato (`README.md`) - 2026-01-03
- [x] Definita struttura cartelle servizio (Mobile, Drive) - 2026-01-03
- [x] Specifiche algoritmo sync - 2026-01-03
- [x] Sync-Mobile.ps1 (legacy: `Gallery\\*` -> `DCIM\\Camera` flat + inbox `E:\\Gallery\\`) - 2026-01-03
- [x] Sync-Mobile.ps1 - Update 2026-01-04 (legacy: guard date validation + DCIM delete safer) - 2026-01-04
- [x] Sync-Mobile.ps1 - Update 2026-01-05 (SSD root + `_gallery` dissolve + `_mobile` -> `Mobile\\` + `.nomedia` + fix MTP filename) - 2026-01-05
- [x] Cleanup-LegacyCamera.ps1 (delete sicura da `DCIM\\Camera` basata su log storici) - 2026-01-05

---

**Note**: Questo è il progetto più complesso da implementare. Iniziare con versione base (copy one-way) e iterare.
