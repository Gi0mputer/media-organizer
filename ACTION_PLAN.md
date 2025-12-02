# 🎯 PIANO D'AZIONE DETTAGLIATO - PULIZIA ARCHIVIO MEDIA

Generated: 2025-12-02 19:01

---

## 📊 ANALISI CARTELLE VECCHIE (E:\)

### **2018 e pre** (103.77 GB)
- **Files**: 1,468 (467 video, 808 foto)
- **Video formats**: .MOV (66 GB), .mp4 (30.5 GB)
- ⚠️ **WhatsApp**: 26 video + 119 foto
- ⚠️ **Merged/Cut files**: 12 (duplicati potenziali!)
- **Date Range**: SINGLE EVENT (1 day sampling) - ❌ Date inconsistenti!
- **Subfolders**: Mavic Pro (102 GB), 2016pre (1.6 GB)

### **2019** (16.54 GB)
- **Files**: 709 (305 video, 404 foto)
- **Video formats**: .mp4 (9.9 GB), .MOV (6.3 GB)
- ⚠️ **WhatsApp**: 1 foto
- **Date Range**: LONG PERIOD (72 days) - ✅ Cartella "random"
- **Top subfolders**: SangioCla (4.1 GB), GiteButei (2.7 GB), SPAGNA (2.5 GB)

### **2020** (7.72 GB)
- **Files**: 469 (196 video, 272 foto)
- **Video formats**: .mp4 (6.1 GB), .MOV (1.2 GB)
- ⚠️ **WhatsApp**: 45 video + 100 foto (307 MB totali!)
- **Date Range**: LONG PERIOD (72 days) - ✅ Cartella "random"
- **Top subfolders**: Covid (2.7 GB), Giulia (1.9 GB)

### **2021** (100.16 GB) 🔴
- **Files**: 2,511 (941 video, 1,564 foto)
- **Video formats**: solo .mp4 (95.8 GB)
- 🔴 **WhatsApp**: 398 video + 341 foto (2.2 GB!) - MASSIMO PROBLEMA
- **Date Range**: SINGLE EVENT (1 day sampling) - ❌ Date inconsistenti!
- **Top subfolders**: back (30 GB), STUBAI2k21 (28 GB), Giulia Roma Sardegna (24 GB)

---

## 🎯 PROBLEMI IDENTIFICATI

### **1. FILE WHATSAPP** 🔴 PRIORITÀ ALTA
| Anno | Video WA | Foto WA | Size Totale |
|------|----------|---------|-------------|
| 2018 e pre | 26 | 119 | **311 MB** |
| 2019 | 0 | 1 | 0.14 MB |
| 2020 | 45 | 100 | **307 MB** |
| 2021 | 398 | 341 | **2.2 GB** 🔴 |
| **TOTALE** | **469** | **561** | **~2.8 GB** |

**Azione**: Trovare originali e scartare copie WhatsApp

### **2. FILE MERGED/CUT** 🟡 DUPLICATI POTENZIALI
- **2018 e pre**: 12 file merged/cut trovati
- Pattern: `DJI_0001-0-12834-merged-1751836948831.mp4`
- **Azione**: Verificare se esistono originali non merged

### **3. DATE INCONSISTENTI** 🔴 PRIORITÀ MASSIMA
Problema rilevato: I file hanno CreationTime filesystem che NON riflette la data reale di acquisizione!

**Evidenza**:
- Sampling di 2018 e pre → range 2025-07-23 to 2025-07-23 ❌
- Sampling di 2021 → range 2025-07-23 to 2025-07-23 ❌

**Causa**: Probabilmente date modificate durante trasferimenti/conversioni

**Soluzione necessaria**: Usare EXIF/metadata interni, non filesystem dates!

### **4. FORMATI MISTI**
- 2018 e pre: .MOV (339 file, 66 GB) vs .mp4 (128 file, 30 GB)
- 2019: .MOV (101) + .mp4 (204)
- 2020: .MOV (24) + .mp4 (172)
- 2021: solo .mp4 ✅

**Azione**: Standardizzare tutto a .mp4 HEVC per uniformità

---

## 🛠️ STRUMENTI DA CREARE

### **FASE 1: DUPLICATI (1-2 settimane)**

#### **1.1 Smart Duplicate Finder** (CRITICO!)
```
Input: Cartella + opzioni
Output: Report duplicati con score

Features:
- Hash-based (SHA256) per identificare file identici
- Visual/Perceptual hash per video simili ma non identici
- Metadata comparison (durata, risoluzione) 
- Pattern matching WhatsApp (IMG-YYYYMMDD-WA####, VID-YYYYMMDD-WA####)
- Score system:
  * 100% = bit-identical
  * 90-99% = stesso contenuto, metadata diversi
  * 80-89% = visualmente simile
 
Decision logic:
- Se score >= 95% E uno è WhatsApp → SCARTA WhatsApp
- Se score >= 95% E uno è merged/cut → SCARTA merged, tieni originale
- Se score >= 80% ma < 95% → FLAG for manual review

Actions:
- DRY-RUN (default)
- DELETE (con conferma)
- MOVE to "Duplicates" folder
```

#### **1.2 WhatsApp Cleaner**
```
Narrow focus: Trova e gestisci solo file WhatsApp

Features:
- Scan per pattern WhatsApp
- Per ogni file WA, cerca originale con:
  * Stesso contenuto (hash)
  * Data simile (±7 giorni)
  * Dimensione simile (±10%)
- Report: "originale trovato" vs "solo WA"
- Action: DELETE solo se originale trovato
```

### **FASE 2: STANDARDIZZAZIONE FORMATO (2-3 settimane)**

#### **2.1 Format Normalizer**
```
Obiettivo: Convertire tutto a formato standard

Standard target:
- Container: .mp4
- Video codec: H.264 (o HEVC se supportato)
- Resolution: max 1920x1080 (per file pre-2022)
- FPS: max 30fps (per file pre-2020)
- Audio: AAC, 128kbps

Features:
- Scan cartella
- Identifica file "over-spec":
  * Risoluzione > 1080p
  * FPS > 30
  * Codec non-standard
  * Container .MOV/.AVI
- Batch convert con ffmpeg
- PRESERVA metadata originali
- Opzione: sovrascrit ti o crea "_normalized"
```

### **FASE 3: METADATA E DATE (3-4 settimane) - PRIORITÀ MASSIMA!**

#### **3.1 Metadata Analyzer**
```
Features:
- Scan cartella ricorsivamente
- Per ogni file:
  * Estrai EXIF DateTimeOriginal
  * Estrai QuickTime:CreateDate
  * Estrai FileSystem dates
  * Compara e report discrepanze
- Identifica "tipo" di cartella:
  * Single Event (span <= 3 giorni)
  * Short Period (4-14 giorni)
  * Medium Period (15-60 giorni)
  * Long/Random (> 60 giorni)
```

#### **3.2 Date Fixer** (IL PIÙ COMPLESSO!)
```
Strategie per tipo di cartella:

A) SINGLE EVENT (es: "Gita Lago 2019-08-15")
   1. Analizza tutti i file
   2. Trova data "dominante" (moda statistica)
   3. Identifica outliers (file con date molto diverse)
   4. Opzioni:
      - Setta tutti alla data dominante
      - Setta outliers alla data dominante
      - Ridistribuisci nell'arco di 1 giorno (09:00-20:00)
   
B) SHORT/MEDIUM PERIOD (es: "Vacanza Spagna 2019-08-10 a 2019-08-20")
   1. Trova date min/max reali (da EXIF)
   2. Identifica "gap" (periodi senza foto)
   3. Ridistribuisci file uniformemente nell'intervallo
   4. Opzione: rispetta ordine alfabetico/filename
   
C) LONG/RANDOM (es: "Amici 2019")
   1. Usa EXIF se disponibile
   2. Se EXIF mancante:
      - Fallback a filename pattern (IMG_YYYYMMDD)
      - Fallback a subfolder name
      - Ultimo resort: FileSystem date
   3. VERIFICA che anno sia corretto
   4. NON modificare se anno corretto
   
D) SENZA METADATA (worst case)
   1. Tenta inferenza da:
      - Nome cartella parent
      - Pattern filename
      - File vicini nella cartella
   2. Flag per manual review
```

#### **3.3 Google Photos Sync Validator**
```
Pre-upload validation:
- Verifica che tutti i file abbiano:
  * Date EXIF coerenti
  * Anno corretto
  * Nessun timestamp "1970-01-01" o "futuristico"
- Report file problematici
```

---

## 📅 TIMELINE PROPOSTA

### **SETTIMANA 1-2: DUPLICATI**
- ✅ Crea Smart Duplicate Finder
- ✅ Crea WhatsApp Cleaner
- ✅ Test su 2021 (più problematico)
- ✅ Run su tutte le cartelle vecchie
- **Target risparmio**: ~3-5 GB

### **SETTIMANA 3-4: FORMATI**
- ✅ Crea Format Normalizer
- ✅ Test su subset (2020)
- ✅ Converti .MOV → .mp4
- ✅ Downscale 4K → 1080p dove necessario
- **Target risparmio**: ~20-30 GB

### **SETTIMANA 5-8: METADATA (LA PIÙ COMPLESSA)**
- ✅ Crea Metadata Analyzer
- ✅ Analizza tutte le cartelle
- ✅ Classifica per "tipo evento"
- ✅ Crea Date Fixer con strategie multiple
- ✅ Test su subset
- ✅ Manual review + fix
- ✅ Batch processing
- ✅ Validazione finale

### **SETTIMANA 9: VALIDAZIONE E BACKUP**
- ✅ Google Photos Sync Validator
- ✅ Test upload campione
- ✅ Backup finale pre-commit
- ✅ Commit changes

---

## 🚦 STEP IMMEDIATI (QUESTA SESSIONE)

1. **Creare Smart Duplicate Finder** con focus su:
   - Hash comparison
   - WhatsApp pattern detection
   - Report chiaro
   
2. **Test su cartella 2021** (più problematica per WhatsApp)

3. **Decidere strategia metadata** per cartelle specifiche:
   - 2018 e pre/Mavic Pro → ?
   - 2021/STUBAI2k21 → Single event?
   - 2019/SPAGNA → Short period?

---

## ❓ DOMANDE PER L'UTENTE

1. **Cartelle specifiche**: Puoi darmi esempi di:
   - Una cartella che dovrebbe essere "single event"?
   - Una cartella tipo "amici" (random)?
   
2. **Strategia conversione**: Per i file .MOV vecchi, preferisci:
   - Convertire TUTTI → .mp4
   - Solo quelli > 1080p
   - Lasciarli com'è

3. **Priorità**: Quale problema vuoi risolvere PRIMA?
   - Duplicati/WhatsApp?
   - Formati?
   - Metadata/Date?

---

**Vuoi che iniziamo a creare il Smart Duplicate Finder?** 🚀
