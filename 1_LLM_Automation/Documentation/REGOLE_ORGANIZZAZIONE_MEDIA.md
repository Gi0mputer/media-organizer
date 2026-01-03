# Regole per Organizzazione Media Archive

## Filosofia Generale
Il media archive è troppo disordinato e vario per essere gestito da un programma completamente automatico. Richiede interpretazione caso per caso con linguaggio naturale e decisioni contestuali.

## Regole di Naming

### Formato Standard
`YYYYMMDD_DescrizioneContenuto_N.ext`

Dove:
- `YYYYMMDD`: Data dell'evento (8 cifre)
- `DescrizioneContenuto`: Nome descrittivo del contenuto
- `N`: Numero sequenziale (1, 2, 3...) **solo se serve**
- `.ext`: Estensione file (jpg, mp4, mov, etc.)

Regola: se per quella `YYYYMMDD_DescrizioneContenuto` esiste un solo file, **il numero va omesso**.

### Descrizione Contenuto - Regole di Priorità

1. **Se c'è un nome descrittivo scritto a mano** (es: "AlbyPizzeEnd", "SamuSteccato", "BaldoBibbo", "cucinaconsasso")
   → **PRESERVA** il nome originale come tag centrale
   → Esempio: `20191107_AlbyPizzeEnd_003.mp4`

2. **Se il file è in una cartella evento** (es: "Lucca", "SpagnaCalaLevado")
   → Usa il nome della cartella
   → Esempio: `20191103_Lucca_005.jpg`

3. **Se il nome è un codice random** (es: "XBDW6157", "FPFD8488", UUID)
   → Sostituisci con nome cartella o descrizione evento
   → Esempio: `20190905_MontaggiDrone_002.mp4`

## Regole per Date e Metadati

### Fonte di Verità per le Date (in ordine di priorità)

1. **Date GPS/EXIF** (se presenti e affidabili)
   → Massima priorità, specialmente per foto drone

2. **LastWriteTime del file** (se coerente con anno della cartella)
   → Se file in `D:\2019\...` ha LastWriteTime = 2019 → Usa quella
   → Se LastWriteTime = 2020/2025 in cartella 2019 → Ignora (data sbagliata)

3. **Data dalla cartella padre** (come fallback)
   → Usa anno della cartella (es: `D:\2019\...` → deve essere 2019)

### Gestione File con Date Sbagliate

**Problema**: File copiati da WhatsApp/Cloud hanno spesso date 2020/2025 invece di 2019

**Soluzione**: 
- Identificare data **MAX** (ultima data valida) degli altri file nella stessa cartella
- Assegnare quella data ai file "sospetti"
- **NON usare la mediana** → spezza la cronologia mettendo file forzati in mezzo

**Esempio**:
```
Cartella: D:\2019\Lucca
File validi: 2-7 Novembre 2019
File sospetti (2020): Assegna → 7 Novembre 2019 (data MAX)
```

### Aggiornamento Metadati

Per ogni file sistemato, aggiornare **TUTTI** i metadati:

**Foto (JPG/PNG)**:
- `DateTimeOriginal`
- `CreateDate`
- `ModifyDate`
- `File Creation Time`
- `File Modification Time`

**Video (MP4/MOV)**:
- Tutti i precedenti +
- `TrackCreateDate`
- `TrackModifyDate`
- `MediaCreateDate`
- `MediaModifyDate`

**Tool**: ExifTool

## Regole per Compressione Video

### Quando Comprimere
- Video drone 4K > 100 MB
- Video pre-2021 con bitrate eccessivi
- Video da uniformare per editing/merge

### Parametri Standard
```
Codec: HEVC (H.265)
Encoder: NVENC (GPU)
Risoluzione: 1920px lato lungo
Qualità: CQ 24
Preset: p4/p5
Frame rate: Mantieni originale
Audio: AAC 128k (se presente), altrimenti -an
```

### Comportamento
- **REPLACE**: Sostituisci originale con versione compressa
- **Backup**: Solo se richiesto esplicitamente (-Backup flag)
- **Verifica**: Controlla dimensione output > 100KB
- **Metadati**: Preserva CreationTime originale

## Regole per Cartelle

### Struttura Anni
```
D:\[ANNO]\[EVENTO]\file.ext
E:\[ANNO]\[EVENTO]\file.ext
```

### Gestione File Sparsi
- File nella root (es: `D:\2019\file.mp4`) senza cartella evento:
  - Se nome descrittivo → Usa nome come tag
  - Se nome random → Usa "2019" o anno cartella
  - Numero sequenziale continua da file precedenti

## Casi Speciali

### File Duplicati
- File con nomi UUID da WhatsApp/Cloud: Spesso duplicati
- Controllare date e dimensioni
- **Regola**: Tenere originale (data più vecchia, qualità migliore)

### File in Sottocartelle MERGE
- Spesso video "processati" o merge temporanei
- Applicare stesse regole di naming
- Numerazione continua dalla cartella padre

### File Senza Audio
- Drone in modalità high-FPS spesso non registra audio
- Script deve rilevare assenza audio e usare `-an` invece di `-c:a aac`
- **NON** forzare encoding audio su stream vuoto

## Note Operative

### Script Esistenti
1. `Fix-MediaDates.ps1`: Fix singola cartella con data specifica
2. `Fix-MediaDates-Batch.ps1`: Batch multi-cartella (usa LastWriteTime)
3. `COMPRIMI_VIDEO_1080p_REPLACE.ps1`: Compressione GPU full-pipeline

### Workflow Tipico
1. Identifica cartella/anno da processare
2. Scansiona file → Identifica pattern
3. Decidi strategia date (GPS vs LastWriteTime vs Manual)
4. Applica naming rules
5. Comprimi video pesanti
6. Verifica metadati con ExifTool
7. Upload Google Photos → Controlla timeline

### Comandi Utili
```powershell
# Verifica date GPS
exiftool -GPSDateTime -DateTimeOriginal file.jpg

# Verifica metadati video
exiftool -CreateDate -MediaCreateDate file.mp4

# Trova file con date sbagliate in cartella 2019
Get-ChildItem "D:\2019" -Recurse | Where {$_.LastWriteTime.Year -ne 2019}

# Trova file più grandi in una cartella
Get-ChildItem "D:\2019\Lucca" -Recurse | Sort-Object Length -Descending | Select -First 10

# Calcola data MAX per file forzati
$files = Get-ChildItem ... | Where {$_.Year -eq 2019}
$maxDate = ($files | Sort LastWriteTime)[-1].LastWriteTime
```

## Lessons Learned

1. **Mediana vs Max**: NON usare mediana per date forzate → Usa MAX (ultima data valida)
2. **Nomi descrittivi**: SEMPRE preservare nomi scritti a mano
3. **Ricorsione**: Attenzione agli script con `-Recurse` su cartelle già processate
4. **Backup nomi**: Prima di rinominare in batch, salvare lista nomi originali
5. **Date WhatsApp**: File da WhatsApp/Cloud hanno spesso Marzo 2020 → Sempre sospetti

## REGOLA IMPORTANTE: Cartelle di Servizio

**Struttura percorsi**: Solo la PRIMA sottocartella sotto l'anno da il nome all'evento.

Esempio:
`
D:\2019\SpagnaCalaLevado\file.mp4        -> 20190814_SpagnaCalaLevado_1.mp4
D:\2019\SpagnaCalaLevado\Mobile\file.jpg -> 20190814_SpagnaCalaLevado_2.jpg (NON Mobile!)
D:\2019\SpagnaCalaLevado\MERGE\file.mp4  -> 20190814_SpagnaCalaLevado_3.mp4 (NON MERGE!)
`

**Sottocartelle di servizio comuni**:
- Mobile: File destinati al mobile/Instagram
- MERGE: Video merge temporanei
- RAW: File raw non processati
- Backup: Copie di backup
- Export: File esportati

**Regola**: Queste NON danno il nome ai file, usano sempre il nome della cartella padre (primo livello sotto anno)
