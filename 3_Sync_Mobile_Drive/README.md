# 3_Sync_Mobile_Drive — iPhone Sync

Workflow completo per sincronizzare contenuti tra PC (E:\, D:\) e iPhone tramite **SSD exFAT come navetta**.

---

## Paradigma "Phone Mode / PC Mode"

Il drive ha due stati:

| Modalita' | Struttura | Uso |
|---|---|---|
| **PC Mode** (default) | File negli eventi originali | Editing, organizzazione, accesso normale |
| **Phone Mode** | File spostati in `_iphone\` | Connetti SSD a iPhone e copia la cartella |

Tutti i file di sistema sono in `_sys\` sulla root del drive (non sporcano la root).

---

## Flusso Export (PC → iPhone)

```
1. PREVIEW_ENABLE_PHONE_MODE.bat    → vedi cosa verra' spostato
2. RUN_ENABLE_PHONE_MODE.bat        → attiva Phone Mode (move in _iphone\)
3. [manuale] copia _iphone\ su iPhone Files (via Files app + SSD)
4. RUN_RESTORE_PC_MODE.bat          → ripristina PC Mode, aggiorna history
```

**Dal secondo sync in poi** usa `-DeltaOnly`: porta solo i file nuovi/modificati dall'ultimo import.

File di sistema generati:
- `_sys\_iphone_manifest.json` — generato da Enable, letto da Restore
- `_sys\_iphone_history.json` — history cumulativa di tutti i trasferimenti

---

## Flusso Import (iPhone → PC)

```
1. [manuale] copia albero da iPhone Files dentro _iphone\ sul drive
             (sostituisce il contenuto precedente)
2. PREVIEW_IMPORT_PHONE_CHANGES.bat  → vedi le differenze
3. RUN_IMPORT_PHONE_CHANGES.bat      → applica le modifiche su PC
```

Logica di confronto (RelPath + Size + LastWrite):

| Stato in _iphone\ | Azione |
|---|---|
| Uguale alla history | Skip |
| Diverso dalla history | File modificato → aggiorna su PC |
| Non in history | Nuovo da iPhone → importa su PC |
| In history ma assente | Eliminato su iPhone → va in `Evento\_pc\_trash\` |

---

## Script

| Script | Descrizione |
|---|---|
| `Enable-PhoneMode.ps1` | Sposta file phone-worthy in `_iphone\`, salva manifest |
| `Restore-PCMode.ps1` | Rimette file al posto, aggiorna history |
| `Import-PhoneChanges.ps1` | Importa modifiche da `_iphone\` copiata da iPhone |
| `Fix-MbrPartitionType-ForExFAT.ps1` | Fix tipo partizione MBR per exFAT (iPhone mount) |
| `Check-ExternalDrive-ForiPhone.ps1` | Diagnostica drive esterno per iPhone |
| `Import-iCloudPhotos-ToInbox.ps1` | Importa foto da iCloud Photos in inbox |
| `Publish-Gallery-ToiCloudUploads.ps1` | Pubblica foto curate verso iCloud |

---

## Parametri Enable-PhoneMode.ps1

```powershell
# Preview (default)
.\Enable-PhoneMode.ps1 -DriveRoot E:\

# Esegui tutto
.\Enable-PhoneMode.ps1 -DriveRoot E:\ -Execute

# Solo delta (nuovi/modificati dall'ultimo sync)
.\Enable-PhoneMode.ps1 -DriveRoot E:\ -Execute -DeltaOnly

# Registra stato attuale come "gia' trasferito" (primo trasferimento manuale)
.\Enable-PhoneMode.ps1 -DriveRoot E:\ -SaveHistory
```

---

## File di sistema (in _sys\)

- `_iphone_history.json` — dizionario RelPath → {Size, LastWrite, SyncDate}. Persiste tra i cicli.
- `_iphone_manifest.json` — creato da Enable, eliminato da Restore. Presente solo durante Phone Mode.

---

## Note

- I file in `_pc\` non vengono mai inclusi in Phone Mode.
- `E:\Insta360\` e' esclusa (raw vault, non va su iPhone).
- La cartella `_iphone\` sul drive e' temporanea: dopo la copia su iPhone, Restore la rimuove.
- `_sys\` e' in `$SystemSkip`: non viene mai inclusa in Phone Mode.
