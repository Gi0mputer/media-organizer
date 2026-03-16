# SETUP — Media Organizer

Guida per configurare l'ambiente su un nuovo PC.
Ultima revisione: 2026-03-12

---

## Requisiti di sistema

- Windows 10/11
- PowerShell 5.1+ (incluso in Windows) o PowerShell 7+
- **winget** (Windows Package Manager — incluso in Windows 11, scaricabile per Win 10)
- Git (per clonare/aggiornare il repo)

---

## 1. Clonare il repo

```powershell
git clone https://github.com/Gi0mputer/media-organizer.git
cd media-organizer
```

---

## 2. Installare le dipendenze

### Automatico (consigliato)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "Setup-Environment.ps1"
```

Lo script installa tutto via winget e verifica che i tool siano in PATH.

### Manuale (fallback)

| Tool | Comando winget | Uso nel progetto |
|---|---|---|
| ExifTool | `winget install OliverBetz.ExifTool` | Fix/lettura metadati EXIF |
| FFmpeg | `winget install Gyan.FFmpeg` | Compressione/conversione video |
| WinFsp | `winget install WinFsp.WinFsp` | FUSE layer per ifuse (iPhone) |
| libimobiledevice | `winget install libimobiledevice.libimobiledevice` | Comunicazione USB con iPhone |

> **Nota su ifuse:** `ifuse` permette di montare il filesystem iPhone come drive Windows.
> Richiede WinFsp installato **prima** di libimobiledevice.
> Dopo l'installazione, verifica con `ideviceinfo` collegando l'iPhone.

---

## 3. Configurazione per-PC (path locali)

I path dei drive (`E:\`, `D:\`) sono definiti in `CORE_CONTEXT.md` e possono differire tra PC.

Crea il file **`pc_config.local.json`** nella root del repo (è in `.gitignore`, non viene committato):

```json
{
  "RecentDrive": "E:\\",
  "OldDrive": "D:\\",
  "PCLabel": "PC-ASUS"
}
```

Adatta i valori al tuo sistema. Gli script che supportano questa config la leggono automaticamente; altrimenti i path di default sono `E:\` e `D:\`.

---

## 4. Verifica installazione

```powershell
# Verifica tool in PATH
exiftool -ver
ffmpeg -version
ffprobe -version
ideviceinfo --help
```

Se un comando non viene trovato dopo l'installazione, chiudi e riapri PowerShell (il PATH viene aggiornato).

---

## 5. iPhone — primo collegamento

1. Collega iPhone via USB
2. Sul telefono: **Consenti** l'accesso al dispositivo (popup "Vuoi consentire a questo dispositivo di accedere a foto e video?")
3. Per il pairing completo (necessario per ifuse): `idevicepair pair`
4. Sul telefono apparirà una richiesta di fiducia — **Fidati** del computer
5. Verifica: `ideviceinfo` deve mostrare le info del dispositivo

> Il pairing va ripetuto su ogni PC la prima volta.

---

## 6. Struttura attesa dei drive

```
E:\  = Recent SSD (2024+)    — cartelle: 2024\, 2025\, 2026\, ...
D:\  = Old SSD (fino al 2023) — cartelle: 2018\, 2019\, ..., 2023\, ...
```

Se i tuoi drive hanno lettere diverse, aggiornale in `pc_config.local.json`.

---

## Note per aggiornare l'ambiente

```powershell
# Aggiornare tutte le dipendenze installate via winget
winget upgrade OliverBetz.ExifTool
winget upgrade Gyan.FFmpeg
winget upgrade WinFsp.WinFsp
winget upgrade libimobiledevice.libimobiledevice
```
