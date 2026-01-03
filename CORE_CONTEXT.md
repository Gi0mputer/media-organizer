# 🎯 CORE CONTEXT - Media Archive Project (LEGGI SEMPRE ALL'INIZIO)

> **ISTRUZIONI PER LLM**: Questo documento contiene le informazioni permanenti e i punti cardine del progetto Media Archive Management. DEVE essere letto all'inizio di OGNI nuova chat prima di iniziare qualsiasi lavoro. Contiene path hardcoded, struttura archivio, e regole fondamentali che non cambiano.

---

## 📂 SISTEMA FILE - HARDCODED PATHS

### Hard Disk (FISSI)

```
E:\ - Recent SSD
  - Anno: 2024 → presente
  - Cartelle: 2024\, 2025\, etc.
  
D:\ - Old SSD  
  - Anno: Pre-2024 (fino 2023 incluso)
  - Cartelle: 2018 e pre\, 2019\, 2020\, 2021\, 2022\, 2023\

⚠️ IMPORTANTE: Old e Recent NON hanno MAI intersezione temporale
```

### Telefono (FISSO)

```
Device: Google Pixel 8

Path base:
PC\Pixel 8\Memoria condivisa interna\DCIM\SSD\

Nota: Questo path NON cambia, è hardcoded nel sistema
```

### Progetto Scripts

```
Base: c:\Users\ASUS\Desktop\Batchs\

Struttura:
├── 1_LLM_Automation\      - Script assistiti da LLM
├── 2_DragDrop_Tools\      - Tool drag & drop utente
└── 3_Sync_Mobile_Drive\   - Sync telefono/cloud
```

---

## 🏗️ STRUTTURA ARCHIVIO MEDIA

### Organizzazione Cartelle

```
D:\ o E:\
├── 2019\                   ← Cartella anno
│   ├── file.jpg           ← File liberi
│   ├── Mobile\            ← Cartella SERVIZIO (subset per telefono)
│   ├── Drive\             ← Cartella SERVIZIO (subset per cloud)
│   │
│   ├── Lucca\             ← Sottocartella EVENTO
│   │   ├── foto.jpg
│   │   └── Mobile\        ← Subset Lucca per telefono
│   │
│   └── SpagnaCalaLevado\
│       ├── video.mp4
│       ├── Mobile\
│       └── MERGE\         ← Cartella SERVIZIO (non dà nome!)
│
├── 2020\
├── 2021\
│
└── Family\                ← Cartella EXTRA-ANNO (tematica persistente)
    └── Mobile\
```

### Regole Cartelle SERVIZIO (CRITICO!)

**Cartelle servizio comuni**:
- `Mobile\` - File per telefono
- `Drive\` - File per cloud
- `MERGE\` - Video temporanei merge
- `RAW\` - File raw non processati

**REGOLA FONDAMENTALE**: 
- Queste cartelle sono **TRASPARENTI** per il naming dei file
- NON danno MAI il nome ai file
- I file appartengono logicamente alla **cartella padre**

**Esempi**:
```
D:\2019\Lucca\Mobile\foto.jpg  → Nome: 20191103_Lucca.jpg (NON Mobile!)
D:\2019\SpagnaCalaLevado\MERGE\video.mp4 → 20190814_SpagnaCalaLevado_1.mp4
```

---

## 📝 NAMING CONVENTION (STANDARD)

### Formato File Standard

```
YYYYMMDD_NomeDescrittivo_N.ext

Dove:
- YYYYMMDD: Data evento (8 cifre)
- NomeDescrittivo: Nome evento/contenuto
- N: Numero sequenziale (1, 2, 3, 10... NON 001, 002)
- ext: Estensione originale

⚠️ NUMERO OMESSO se file unico per quella data+nome
```

### Esempi Corretti

```
✓ 20190814_SpagnaCalaLevado.jpg          (file unico)
✓ 20190814_SpagnaCalaLevado_1.jpg        (primo di serie)
✓ 20190814_SpagnaCalaLevado_2.jpg        (secondo)
✓ 20190814_SpagnaCalaLevado_10.jpg       (decimo)

✗ 20190814_SpagnaCalaLevado_001.jpg      (NO zero-padding)
✗ 20190814_Mobile_1.jpg                  (NO nome da cartella servizio)
```

### Come Determinare Nome

**Priorità**:
1. Nome descrittivo manuale (es: "BaldoBibo", "cucinaconsasso") → **MANTIENI SEMPRE**
2. Nome prima sottocartella sotto anno (es: `2019\Lucca\` → "Lucca")
3. Per file in root anno → "Media", "Video", "Photo" (generico)

**Regola percorso**:
- Solo la **PRIMA** sottocartella sotto anno dà il nome
- Sottocartelle di servizio (Mobile, MERGE, etc.) → **IGNORA**

---

## 📅 DATE MANAGEMENT - REGOLE CRITICHE

### Fonti di Verità (in ORDINE)

1. **GPS DateTime** (massima affidabilità - se presente usa SEMPRE questo)
2. **EXIF DateTimeOriginal** (se ragionevole e coerente)
3. **LastWriteTime** (se anno coerente con cartella)
4. **Deduzione contestuale** (folder name, altri file correlati)
5. **Input manuale utente** (ultima risorsa)

### Strategia Fix Date ANOMALE

**Problema**: File con date sbagliate (anno diverso, mesi fuori range, etc.)

**Soluzione adottata**: **MAX DATE (fine intervallo)** NON mediana!

**Perché MAX e non MEDIAN?**
- Mediana spezza cronologia in mezzo all'evento
- MAX posiziona file anomali **alla fine** dell'evento
- Preserva ordine visuale in galleria

**Esempio**:
```
Cartella: Spagna 2019
Range GPS validi: 12/08/2019 → 20/08/2019
File anomali: Date 2020, 2025, o sbagliate

Soluzione:
✓ Forza TUTTI a: 20/08/2019 (MAX, fine intervallo)
✗ NON usare: 16/08/2019 (mediana - spezza in mezzo)

Risultato: File anomali appaiono cronologicamente alla FINE della vacanza
```

### Metadata da Aggiornare

**Per FOTO** (.jpg, .jpeg, .png):
```
exiftool -DateTimeOriginal="YYYY:MM:DD HH:MM:SS"
         -CreateDate="YYYY:MM:DD HH:MM:SS"
         -ModifyDate="YYYY:MM:DD HH:MM:SS"
```

**Per VIDEO** (.mp4, .mov):
```
exiftool -CreateDate="YYYY:MM:DD HH:MM:SS"
         -ModifyDate="YYYY:MM:DD HH:MM:SS"
         -TrackCreateDate="YYYY:MM:DD HH:MM:SS"
         -MediaCreateDate="YYYY:MM:DD HH:MM:SS"
```

**Filesystem timestamps**:
```powershell
$file.CreationTime = [DateTime]"YYYY-MM-DD HH:MM:SS"
$file.LastWriteTime = [DateTime]"YYYY-MM-DD HH:MM:SS"
```

---

## 🔧 VIDEO PROCESSING - STANDARD

### Formato Target Archivio

```
Container: MP4
Video Codec: H.264 (libx264 o h264_nvenc se GPU)
Audio Codec: AAC 128kbps
Resolution: Max 1080p (preserva aspect ratio)
FPS: 30fps (standard)
Pixel Format: yuv420p (compatibilità massima)
```

### Compression Settings

**Standard** (compatibilità LosslessCut merge):
```
Codec: H.264
CRF: 23 (qualità)
Resolution: 1080p
FPS: 30
```

**Max Compression** (archivio long-term):
```
Codec: HEVC (h.265)
CQ: 24 (NVENC) o CRF: 23 (software)
Resolution: 1080p
FPS: 30
```

### GPU Encoding (Se disponibile)

```
Hardware: NVIDIA GPU con NVENC
Encoder: h264_nvenc o hevc_nvenc
Preset: p4 o p5
Full pipeline: -hwaccel cuda -hwaccel_output_format cuda
Scale: scale_cuda (GPU) invece di scale (CPU)
```

---

## 📱 MOBILE SYNC - MAPPING

### Logica PC ↔ Telefono

**PC → Telefono** (Collapse cartelle Mobile):
```
D:\2019\Mobile\foto.jpg              → DCIM\SSD\2019\foto.jpg
D:\2019\Lucca\Mobile\video.mp4       → DCIM\SSD\2019\Lucca\video.mp4
E:\2020\Family\Mobile\pic.jpg        → DCIM\SSD\2020\Family\pic.jpg
```

**Telefono → PC** (Expand a Mobile):
```
DCIM\SSD\2019\foto.jpg               → D:\2019\Mobile\foto.jpg
DCIM\SSD\2019\Lucca\video.mp4        → D:\2019\Lucca\Mobile\video.mp4
DCIM\SSD\Family\pic.jpg              → D:\Family\Mobile\ o E:\Family\Mobile\
```

**Unificazione Old + Recent**: 
- Su telefono DCIM\SSD\ contiene cartelle da ENTRAMBI i dischi
- Nessuna distinzione visibile su telefono tra Old e Recent
- Script deve sapere reinstradarle correttamente quando sync inverso

---

## 🔄 WORKFLOW & BEST PRACTICES

### Prima di Modifiche Batch

1. **LEGGI** `REGOLE_ORGANIZZAZIONE_MEDIA.md`
2. **CONTROLLA** README e TODO dell'area pertinente
3. **USA** WhatIf/Preview mode
4. **TEST** su cartella singola/sample
5. **VERIFICA** risultato prima batch completo

### Dopo Implementazione Feature

1. **TESTA** su file reali (D:\ o E:\)
2. **AGGIORNA** TODO.md (sposta in Completed)
3. **AGGIORNA** README.md se cambia behavior
4. **DOCUMENTA** problemi risolti (Lessons Learned)

### Gestione Errori

- **NON assumere** path - verificare sempre
- **NON modificare** file senza backup/preview
- **NON eliminare** senza log dettagliato
- **SEMPRE** preservare timestamp originali
- **SEMPRE** preservare metadata EXIF/GPS

---

## 📚 DOCUMENTI DA MANTENERE AGGIORNATI

### Obbligatori (Aggiorna SEMPRE)

```
1_LLM_Automation/
├── README.md                    ← Aggiorna dopo nuove feature/fix
├── TODO.md                      ← Sposta completed, aggiungi nuovi
└── Documentation/
    └── REGOLE_ORGANIZZAZIONE_MEDIA.md  ← Aggiungi nuove regole

2_DragDrop_Tools/
├── README.md                    ← Catalogo tool, problemi noti
└── TODO.md                      ← Feature utente richieste

3_Sync_Mobile_Drive/
├── README.md                    ← Spec sync, use cases
├── TODO.md                      ← Feature sync
└── device_config.json           ← Config dispositivi
```

### Documenti Handoff (Per cambio chat)

```
1_LLM_Automation/
├── HANDOFF_PROSSIMA_CHAT.md     ← Aggiorna quando cambi argomento
└── CORE_CONTEXT.md              ← Questo file (RARO modificare)

3_Sync_Mobile_Drive/
└── TODO_CHAT_FUTURA_SYNC.md     ← Spec complete sync (aggiorna se cambia)
```

---

## ⚠️ COSE DA NON FARE MAI

### File Operations

- ❌ NON eliminare file senza log + conferma
- ❌ NON modificare file senza testare su sample
- ❌ NON assumere path - sempre verificare esistenza
- ❌ NON perdere metadata originali (EXIF, GPS, timestamps)

### Naming

- ❌ NON usare zero-padding numeri (_001 → usa _1)
- ❌ NON usare nomi cartelle servizio (Mobile, MERGE, etc.)
- ❌ NON perdere nomi descrittivi manuali (BaldoBibo, etc.)

### Date

- ❌ NON usare mediana per date forzate (usa MAX)
- ❌ NON ignorare GPS date se disponibili
- ❌ NON forzare date senza conferma utente

### Struttura Progetto

- ❌ NON creare file .md in root progetto (usa Documentation/)
- ❌ NON lasciare script obsoleti senza spostare in _Legacy/
- ❌ NON dimenticare aggiornare TODO dopo implementazioni

---

## 🎯 CHECKLIST INIZIO NUOVA CHAT

Quando inizi una nuova chat su questo progetto:

- [ ] Leggi `CORE_CONTEXT.md` (questo file)
- [ ] Leggi `HANDOFF_PROSSIMA_CHAT.md` (se esiste)
- [ ] Leggi README dell'area su cui lavorerai
- [ ] Leggi TODO dell'area per capire feature richieste
- [ ] Verifica path D:\ e E:\ accessibili
- [ ] Se lavori su sync, verifica Pixel 8 connesso

---

## 🛠️ STRUMENTI CHIAVE DISPONIBILI

### Fix Date/Metadata
- `Fix-MediaDates.ps1` - Singola cartella, interattivo
- `Fix-MediaDates-Batch.ps1` - Multi-cartella automatico
- `Dates_Diagnostics.ps1` - Analisi problemi date

### Video Processing
- `STANDARDIZE_VIDEO.bat` - 1080p 30fps H.264 (drag & drop)
- `COMPRIMI_VIDEO_1080p_REPLACE.bat` - HEVC max compression
- `REPAIR_VIDEO.bat` - Fix metadata corrotti

### Analisi
- `Video-Health-Diagnostics.ps1` - Scan problemi video
- `Analyze-MediaArchive.ps1` - Overview archivio
- `SmartDuplicateFinder.ps1` - Duplicati

### Manutenzione
- `Remove-EmptyFolders.ps1` - Cleanup cartelle vuote

---

## 📞 DEPENDENCIES

### Software Richiesti

```
- ffmpeg (con NVENC support)
- ffprobe
- exiftool

Verifica installazione:
- ffmpeg -version
- ffprobe -version
- exiftool -ver

Path: Assumere in system PATH
```

### PowerShell

```
Versione: 5.1+ (Windows PowerShell)
Execution Policy: Bypass (per script)

Comando tipico:
powershell -ExecutionPolicy Bypass -File "script.ps1"
```

---

**Versione**: 1.0
**Ultima modifica**: 2026-01-03
**Status**: PERMANENTE (modificare solo se cambiano fondamentali)

---

> **NOTA PER LLM**: Dopo aver letto questo documento, conferma di aver compreso i punti chiave:
> 1. Path hardcoded E:\ (Recent) e D:\ (Old)
> 2. Cartelle servizio trasparenti (Mobile, Drive, MERGE)
> 3. Naming convention (YYYYMMDD_Nome_N.ext)
> 4. MAX date strategy (non median)
> 5. Mantenere aggiornati README e TODO
