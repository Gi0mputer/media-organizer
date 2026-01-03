# 📱 TODO - Chat Futura: Mobile Sync Implementation

## Contesto Sistema

### Architettura Media Archive

**Hard Disk PC**:
- `E:\` - Recent SSD (2024+)
- `D:\` - Old SSD (pre-2024, fino 2023)
- **Non hanno intersezione** temporale

**Struttura Cartelle**:
```
D:\ o E:\
├── 2019\
│   ├── file.jpg
│   ├── Mobile\           ← Cartella servizio
│   │   └── selected.jpg
│   └── Lucca\
│       ├── foto.jpg
│       └── Mobile\       ← Subset Lucca per telefono
│
├── 2020\
│   └── Drive\            ← Cartella servizio per cloud
│
└── Family\               ← Extra-anno
    └── Mobile\
```

**Cartelle Servizio** (`Mobile` e `Drive`):
- Possono esistere a QUALSIASI livello
- Sono **TRASPARENTI** per naming file
- `Mobile` = subset per telefono
- `Drive` = subset per cloud
- File dentro Mobile/Drive appartengono logicamente alla cartella padre

### Device Telefono

**Modello**: Google Pixel 8

**Path base telefono**:
```
PC\Pixel 8\Memoria condivisa interna\DCIM\SSD\
```

### Mapping PC ↔ Telefono

**Logica**: Collapse delle cartelle `Mobile`

**Esempi**:
```
PC (Source)                          → Telefono (Destination)
──────────────────────────────────────────────────────────────
D:\2019\Mobile\foto.jpg              → DCIM\SSD\2019\foto.jpg
D:\2019\Lucca\Mobile\video.mp4       → DCIM\SSD\2019\Lucca\video.mp4
D:\2020\Family\Mobile\ritratto.jpg   → DCIM\SSD\2020\Family\ritratto.jpg
D:\Family\Mobile\pic.jpg             → DCIM\SSD\Family\pic.jpg
```

**Note**:
- La cartella `Mobile` viene "rimossa" dal path
- I file vanno nella cartella padre replicata
- Old (D:\) e Recent (E:\) → **stesso SSD** sul telefono (unificati)

---

## 🎯 Obiettivo: Implementare 3 Modalità Sync

### Modalità 1: PC → Telefono (One-way Sync, Destructive)

**Descrizione**: 
- Sorgente verità: PC
- Allinea telefono a PC
- **Elimina** da telefono file/cartelle non presenti su PC

**Use Case**:
- Hai lavorato su PC eliminando/riorganizzando
- Vuoi riflettere le modifiche sul telefono
- Hai snellito la selezione Mobile su PC

**Comportamento**:
```
Se file in PC\Mobile\ → Copia/aggiorna su telefono
Se file su telefono ma NON in PC\Mobile\ → ELIMINA da telefono
Se cartella su telefono ma NON su PC → ELIMINA cartella da telefono
```

**Sicurezza**: 
- Preview mode obbligatorio
- Conferma utente prima eliminazione
- Log dettagliato

---

### Modalità 2: Telefono → PC (One-way Sync, Non-destructive)

**Descrizione**:
- Sorgente verità: Telefono
- Aggiungi nuovi file da telefono a PC
- **NON eliminare MAI** da PC

**Use Case**:
- Hai aggiunto foto/video da telefono nelle cartelle SSD
- Vuoi copiarle nelle corrispondenti cartelle Mobile su PC
- Vuoi mantenere tutto ciò che è su PC

**Comportamento**:
```
Se file nuovo su telefono → Copia in PC\Mobile\ corrispondente
Se file modificato su telefono → Aggiorna su PC
Se file su PC ma NON su telefono → IGNORA (mantieni su PC)
```

**Reverse Mapping**:
```
Telefono (Source)                    → PC (Destination)
──────────────────────────────────────────────────────────────
DCIM\SSD\2019\foto.jpg               → D:\2019\Mobile\foto.jpg
DCIM\SSD\2019\Lucca\video.mp4        → D:\2019\Lucca\Mobile\video.mp4
DCIM\SSD\Family\pic.jpg              → D:\Family\Mobile\pic.jpg (o E:\Family\Mobile\)
```

**Problema da risolvere**:
- Come sapere se `Family` è in D:\ o E:\?
- **Soluzione**: Scan entrambi dischi, usa cartella esistente
- Se non esiste → chiedi utente o crea in Recent (E:\)

---

### Modalità 3: Telefono → PC (Bidirectional Sync, Destructive)

**Descrizione**:
- Sorgente verità: Telefono
- Aggiungi nuovi file da telefono
- **Elimina** da PC file non presenti su telefono

**Use Case**:
- Hai snellito selezione da telefono
- Vuoi che anche PC rifletta la pulizia
- Hai eliminato file dalle cartelle SSD sul telefono

**Comportamento**:
```
Se file nuovo su telefono → Copia in PC\Mobile\
Se file modificato → Aggiorna su PC
Se file su PC\Mobile\ ma NON su telefono → ELIMINA da PC
Se cartella vuota su PC dopo eliminazioni → ELIMINA cartella
```

**Sicurezza**:
- **MOLTO pericoloso** se usato male
- Preview obbligatorio con lista eliminazioni
- Doppia conferma utente
- Backup raccomandato

---

## 🔧 Modalità Single-Disk (Da Approfondire)

### Problema

Se solo un disco connesso (es: solo E:\ Recent), come distinguere:
- Cartelle mancanti perché eliminate
- Cartelle mancanti perché su altro disco (D:\)

**Non possiamo assumere** la causa della mancanza.

### Strategia Proposta (Da Validare)

**Modalità Single-Disk**:
- **NON eliminare** cartelle direttamente sotto `DCIM\SSD\`
- Esempio: Se manca `DCIM\SSD\2020\` sul telefono
  - Potrebbe essere perché è solo su D:\ (non connesso)
  - NON eliminare automaticamente

**Comportamento**:
```
Cartelle root (2019, 2020, Family, etc.):
  - Non eliminare se mancanti su disco singolo
  
Sottocartelle/file dentro cartelle esistenti:
  - Applica logic sync normalmente
  - Se cartella esiste sia su disco che telefono → sync normale
```

**Alternative da considerare**:
1. Chiedere utente all'avvio: "Hai Old + Recent o solo uno?"
2. File di config che traccia quali dischi sono attivi
3. Metadata su telefono che indica sorgente originale (D: o E:)

**Decisione finale**: Da discutere in fase implementazione

---

## 📝 Implementation Tasks

### High Priority 🔴

- [x] **Sync-Mobile.ps1 - Core Script** (Implemented 2026-01-03)
  - Parametri: `-Mode [PC2Phone|Phone2PC|Phone2PCDelete]`
  - Parametri: `-SourceDisk [Both|Recent|Old]` (default: Both)
  - Scan cartelle Mobile su disco(i)
  - Build file list con mapping
  - Preview mode (WhatIf)
  - Execute mode con conferma

- [x] **Mapping Logic** (Implemented 2026-01-03)
  - PC → Telefono: Collapse Mobile/ dal path
  - Telefono → PC: Expand a Mobile/ nel path corretto
  - Gestione cartelle extra-anno (Family, etc.)
  - Auto-detect se cartella è in D:\ o E:\

- [x] **File Operations** (Implemented 2026-01-03)
  - Copy preservando timestamp
  - Update solo se hash diverso (evita re-copy inutili)
  - Delete con log dettagliato
  - Progress bar per grandi batch

### Medium Priority 🟡

- [x] **Safety Features** (Implemented 2026-01-03)
  - Snapshot stato pre-sync (per rollback)
  - Dry-run obbligatorio prima delete operations
  - Log tutte operazioni (copy, delete, update)
  - Backup opzionale prima sync destructive

- [x] **Single-Disk Mode** (Implemented 2026-01-03)
  - Detection automatica dischi connessi
  - Warning se solo 1 disco
  - Logic per non eliminare root folders
  - Config file per tracciare dischi attivi

- [ ] **Conflict Resolution**
  - File modificato su entrambi lati
  - Strategia: chiedi utente o timestamp più recente vince
  - Report conflitti per review manuale

### Low Priority 🟢

- [ ] **GUI Helper** (Nice to have)
  - Mostra preview alberatura pre/post sync
  - Checkbox per escludere file/cartelle
  - Visual indicator differenze

- [ ] **Statistics & Reports**
  - Spazio liberato
  - File copiati/aggiornati/eliminati
  - Velocità sync
  - Ultimo sync timestamp

---

## 🗂️ File di Configurazione

### Device Config (Proposta)

**File**: `3_Sync_Mobile_Drive\device_config.json`

```json
{
  "phone": {
    "model": "Google Pixel 8",
    "basePath": "PC\\Pixel 8\\Memoria condivisa interna\\DCIM\\SSD",
    "lastSync": "2026-01-03T13:00:00"
  },
  "disks": {
    "recent": {
      "path": "E:\\",
      "yearRange": "2024-present",
      "connected": true
    },
    "old": {
      "path": "D:\\",
      "yearRange": "pre-2024",
      "connected": true
    }
  },
  "syncSettings": {
    "defaultMode": "PC2Phone",
    "requireConfirmation": true,
    "enableBackup": true
  }
}
```

---

## ⚠️ Warnings & Edge Cases

### Old + Recent Unification

Telefono vede **unico** SSD con cartelle da entrambi dischi:
```
DCIM\SSD\
├── 2019\  (da D:\)
├── 2020\  (da D:\)
├── 2024\  (da E:\)
├── 2025\  (da E:\)
└── Family\ (potrebbe essere in D:\ o E:\)
```

**Implicazione**: Quando sync Telefono → PC, dobbiamo sapere dove reindirizzare.

### Cartelle Extra-Anno (Family, Projects, etc.)

- Possono esistere sia su D:\ che E:\
- Se su entrambi → errore (non dovrebbe succedere)
- Se su uno solo → usa quello
- Se su nessuno e file nuovo da telefono → crea in E:\ (Recent)

### Cartelle Mobile/Drive Multiple

Possibile avere:
```
D:\2019\Mobile\
D:\2019\Lucca\Mobile\
```

Entrambe mappano su telefono:
```
DCIM\SSD\2019\
DCIM\SSD\2019\Lucca\
```

**Corretto**: Nessun conflitto, path diversi.

---

## 📚 Documenti da Consultare

Prima di implementare, leggi:

1. **3_Sync_Mobile_Drive\README.md**
   - Spec progetto originale
   - Algoritmo sync (prima volta vs incrementale)

2. **1_LLM_Automation\Documentation\REGOLE_ORGANIZZAZIONE_MEDIA.md**
   - Cartelle servizio (Mobile, Drive)
   - Trasparenza naming

3. **3_Sync_Mobile_Drive\TODO.md**
   - Feature list completa

---

## 🚀 Come Iniziare (Chat Futura)

### Setup

1. Verifica Pixel 8 connesso e riconosciuto
2. Test path: `PC\Pixel 8\Memoria condivisa interna\DCIM\SSD`
3. Verifica dischi D:\ e E:\ disponibili
4. Scansiona sample cartelle Mobile per capire volume dati

### Implementazione Step-by-Step

**STEP 1**: Mapping logic (PC → Phone collapse)
**STEP 2**: Scan cartelle Mobile e build file list
**STEP 3**: Modalità 1 (PC → Phone) con WhatIf
**STEP 4**: Test su cartella singola
**STEP 5**: Modalità 2 e 3
**STEP 6**: Single-disk mode
**STEP 7**: Safety features (backup, rollback)

### Testing

Test su cartella **non critica** prima:
- Crea `E:\TEST_SYNC\Mobile\` con pochi file
- Sync → Telefono
- Verifica: `DCIM\SSD\TEST_SYNC\`
- Sync inverso
- Verifica eliminazioni funzionano

---

**Preparato**: 2026-01-03
**Per**: Chat futura #3 (dopo Advanced Date Fix)
**Priorità**: Medium-High (dopo fix date completato)
