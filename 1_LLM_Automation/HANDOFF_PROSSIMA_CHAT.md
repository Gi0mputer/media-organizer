# 📋 HANDOFF - Prossima Chat Session

## Contesto Attuale

Progetto **Media Archive Management** organizzato e testato.

### Stato Lavoro Completato (2026-01-03)

✅ **Struttura progetto riorganizzata** in 3 macro-aree
✅ **40 script funzionanti** (.ps1 + .bat)
✅ **Documentazione pulita** (6 file essenziali)
✅ **Tutti gli strumenti testati** su archivio reale
✅ **1 bug fixato** (FPS threshold Video-Health-Diagnostics)
✅ **Scan completo archivio** eseguito per baseline

### Archivio Media

**Drives**:
- `E:\` - Recent SSD
- `D:\` - Old SSD

**Struttura**:
- Cartelle anno: 2019, 2020, 2021, etc.
- Cartelle tematiche: Family, Projects (extra-anno)
- File liberi in root anno
- Sottocartelle evento
- **Cartelle servizio** (`Mobile`, `Drive`) - NON danno nome ai file

**Formato standard file**: `YYYYMMDD_NomeEvento_N.ext`
- Numero omesso se file unico
- Numeri: _1, _2, _10 (NON _001)

---

## 🎯 PROSSIMO ARGOMENTO: Fix Date Avanzato

### Problema Identificato

**Mediana date crea discontinuità**: File forzati a metà intervallo spezzano cronologia in galleria.

**Soluzione adottata manualmente**: Usare **MAX date** (fine intervallo) invece di mediana.

### Esempio

Cartella `Spagna 2019`:
- Range GPS validi: 12/08/2019 → 20/08/2019
- File con date errate (2020, 2025, etc.)
- **Soluzione**: Forzare TUTTI a `20/08/2019` (fine intervallo)
- **Risultato**: File anomali appaiono alla fine dell'evento

### Casi d'Uso

#### CASO 1: Evento Singolo Giorno (SEMPLICE ✅)
Esempio: Gita 15/08/2019
- Range: 1 giorno
- Forza anomali a: 15/08/2019 23:59
- **Implementabile subito**

#### CASO 2: Vacanza Breve (SEMPLICE ✅)
Esempio: Weekend 12-14/08/2019
- Range: GPS auto-detect
- Forza anomali a: 14/08/2019 (MAX)
- **Implementabile subito**

#### CASO 3: Cartella Anno Intero (COMPLESSO ⚠️)
Esempio: `D:\2020` con file sparsi
- Range: Intero anno (troppo ampio)
- **Soluzione**: Quarantena → riorganizzazione manuale per mese → batch fix
- **Workflow**:
  1. Script trova file anomali → sposta in `_DATE_ISSUES\`
  2. Utente manualmente crea sottocartelle: `10_2020`, `02_2020`, etc.
  3. Script batch fix per sottocartella

#### CASO 4: Input Manuale/Visual (MEDIO 🟡)
- Utente drag & drop **file di riferimento** con data corretta
- Script estrae data da quel file
- Applica a tutti gli altri nella stessa cartella
- **Più comodo** di digitare data manualmente

---

## 📝 TODO per Prossima Chat

### Priority High 🔴

- [x] **Script: Force-DateToMax.ps1** (Implemented 2026-01-03)
  - Input: Cartella
  - Auto-detect range da GPS/EXIF
  - Calcola MAX date
  - Forza file anomali (conferma utente)
  - Use case: Vacanze brevi, eventi singoli

- [x] **Script: Force-DateFromReference.ps1** (Implemented 2026-01-03)
  - Input: File reference (drag & drop) + cartella
  - Estrai data da reference
  - Applica a tutti file nella cartella
  - Use case: Gite singolo giorno, eventi controllati

### Priority Medium 🟡

- [ ] **Script: Quarantine-AnomalousDates.ps1**
  - Scansiona cartella anno (es: 2020)
  - Trova file con anno diverso
  - Sposta in `_DATE_ISSUES\ANNO\`
  - Report per review utente manuale

- [ ] **Workflow: Batch Month Fix**
  - Dopo quarantena utente riorganizza per mese
  - Script batch applica date per sottocartella
  - Es: `_DATE_ISSUES\2020\10_2020\` → forza tutto a 31/10/2020

### Priority Low 🟢

- [ ] **GUI Tool: Visual Date Picker**
  - Mostra anteprima foto/video
  - Utente seleziona data corretta
  - Batch apply
  - Nice to have, non critico

---

## 🔧 Strumenti Esistenti da Usare

**Fix Date**:
- `Fix-MediaDates.ps1` - Singola cartella, interattivo
- `Fix-MediaDates-Batch.ps1` - Multi-cartella, LastWriteTime
- `Dates_Diagnostics.ps1` - Analisi metadata

**Comprimi/Standardizza**:
- `STANDARDIZE_VIDEO.bat` - Drag & drop, 1080p 30fps H.264
- `COMPRIMI_VIDEO_1080p_REPLACE.bat` - HEVC max compression
- `REPAIR_VIDEO.bat` - Fix corrupted metadata

**Analisi**:
- `Video-Health-Diagnostics.ps1` - Scan problemi video
- `Analyze-MediaArchive.ps1` - Overview archivio
- `SmartDuplicateFinder.ps1` - Trova duplicati

**Manutenzione**:
- `Remove-EmptyFolders.ps1` - Cleanup cartelle vuote

---

## 📚 Documenti Chiave da Consultare

1. **REGOLE_ORGANIZZAZIONE_MEDIA.md** ⭐
   - Naming conventions
   - Date management rules
   - MAX date vs median strategy
   - Cartelle servizio (Mobile, Drive)

2. **README.md** (per area)
   - LLM_Automation: Problemi risolti, workflow
   - DragDrop_Tools: Catalogo tool, best practices
   - Sync_Mobile_Drive: Spec progetto sync

3. **TODO.md** (per area)
   - Feature da implementare
   - Test results
   - Known issues

---

## 🚀 Come Iniziare Prossima Chat

### Cosa Dire

```
Ciao! Continuo il progetto Media Archive Management.

CONTESTO: Abbiamo strutturato progetto in 3 aree, testato tutti tool, 
fatto scan archivio. Ora voglio implementare Fix Date Avanzato.

OBIETTIVO: Fix date forzate usando MAX date (fine intervallo) invece 
di mediana, per evitare discontinuità in galleria.

LEGGI: 
- 1_LLM_Automation/HANDOFF_PROSSIMA_CHAT.md
- 1_LLM_Automation/Documentation/REGOLE_ORGANIZZAZIONE_MEDIA.md

IMPLEMENTA:
1. Force-DateToMax.ps1 (eventi brevi) [DONE - 2026-01-03]
2. Force-DateFromReference.ps1 (drag & drop reference file) [DONE - 2026-01-03]
3. Aggiorna TODO con workflow complessi (quarantena anni interi) [DONE - 2026-01-03]
```

### File da Aprire

- `1_LLM_Automation/HANDOFF_PROSSIMA_CHAT.md` (questo file)
- `1_LLM_Automation/README.md`
- `1_LLM_Automation/TODO.md`
- `1_LLM_Automation/Documentation/REGOLE_ORGANIZZAZIONE_MEDIA.md`

---

## 📊 Scan Archivio Risultati

**(Verrà popolato automaticamente al termine dello scan in corso)**

Report completo: `1_LLM_Automation/Analysis/VIDEO_HEALTH_REPORT_[timestamp].md`

---

## ⚠️ Note Importanti

1. **Cartelle Mobile/Drive** sono TRASPARENTI per naming
   - `D:\2019\Lucca\Mobile\foto.jpg` → `20191103_Lucca.jpg` (NON Mobile!)

2. **MAX date** è la strategia corretta
   - File anomali vanno a FINE evento, non in mezzo
   - Preserva cronologia visuale in galleria

3. **GPS date** ha priorità massima
   - Se esiste GPS → fidati
   - Se manca GPS → usa LastWriteTime coerente
   - Se tutto sospetto → chiedi conferma utente

4. **ExifTool required**
   - Tutti script metadata usano exiftool
   - Verifica sia in PATH

5. **TODO sempre aggiornato**
   - Dopo ogni implementazione: sposta in Completed
   - Aggiungi data + breve nota

---

**Data handoff**: 2026-01-03
**Token usati sessione precedente**: ~113k
**Stato**: READY per nuova chat ✅
