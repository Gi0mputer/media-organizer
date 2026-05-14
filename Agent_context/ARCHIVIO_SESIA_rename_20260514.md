# Rinomina ARCHIVIO\SESIA — 2026-05-14

## Percorso base
`G:\Il mio Drive\ARCHIVIO\SESIA\`

## Obiettivo
Rinominare tutti i file video da nomi DJI/Google Drive grezzi (spesso con prefisso "Copia di Copia di") a nomi leggibili, univoci per prefisso-evento, ordinati cronologicamente per numero clip DJI.

---

## Convenzioni adottate

**Formato:** `[Prefisso]_[DDMMYY]_[N][suffisso].[ext]`

- `DDMMYY` = data di ripresa estratta dal nome file DJI
- `N` = numero progressivo globale per prefisso, ordinato per numero clip DJI (NNNN)
- Estensioni normalizzate in minuscolo (`.MP4` → `.mp4`, `.MOV` → `.mov`)
- Suffisso `a/b/c...` = crop/versioni diverse dello stesso clip
- Suffisso `_tag` = stesso clip in cartelle diverse (per identificare duplicati)

---

## Cartelle rinominate

### Video Gare — prefisso `SesiaRace`
Numerazione globale unica su 4 sottocartelle. Date: 08/05/26 e 09/05/26.

| Prefisso | Range | File | Cartella |
|----------|-------|------|----------|
| `SesiaRace_080526_` | 1–2 | 2 | Drone Solo Sermenza |
| `SesiaRace_090526_` | 1–58 | 65 | First Race, Nouria, Drone Solo Sermenza, Sermenza Kayakers |

**Dettaglio cartelle:**
- `First Race` → `SesiaRace_090526_1` … `15` (+ `7a/7b` per clip 0017)
- `Nouria` → `_16`, `_17`, `_23`, `_24`, `_25_nouria` … `_28_nouria`
- `Drone Solo Sermenza` → `_18`, `_19`, `_21`, `_22`, `_25_solo` … `_28_solo`, `_32`, `_33`, `_49`–`_53`
- `Sermenza Kayakers` → `_20`, `_29`–`_48`, `_52`, `_54`–`_58` (+ `35a/b`, `44a/b`)
- `Tom` → **lasciato invariato** (`TomSesiaVertical.MP4`)

**Clip condivisi tra Drone Solo Sermenza e Nouria** (0039, 0040, 0041, 0043):
stessa numerazione + tag `_solo` / `_nouria` per identificare duplicati.

---

### FPV Part 1 (gronda e sorba) — prefisso `FPV1GroSorb`
Data: 19/04/26. 27 file rinominati, 2 lasciati invariati.

| Range | Note |
|-------|------|
| `FPV1GroSorb_190426_1` | clip 0002, singolo |
| `FPV1GroSorb_190426_2` + `2a/b/c` | clip 0006, 3 crop |
| `FPV1GroSorb_190426_3` + `3a`–`3e` | clip 0007, 5 crop |
| `FPV1GroSorb_190426_4` + `4a/b` | clip 0009, 2 crop |
| `FPV1GroSorb_190426_5` + `5a/b` | clip 0011, 2 crop |
| `FPV1GroSorb_190426_6a/b` | clip 0012, .mov + .mp4 (stesso clip, formati diversi) |
| `FPV1GroSorb_190426_7`–`14` | clip 0013–0027, singoli |

**Lasciati invariati:** `IMG_2039.MOV`, `CE6B4AFD-53FF-4D84-8C8B-E7A03BAB5D64.mp4`

---

### FPV Part 2 (alpin x cori) — prefisso `FPV2Alpin`
Data: 02/05/26. 23 file rinominati.

| Range | Note |
|-------|------|
| `FPV2Alpin_020526_1`–`20` | clip 0040–0061 |
| `FPV2Alpin_020526_3a` | crop clip 0042 |
| `FPV2Alpin_020526_6a` | crop clip 0045 |
| `FPV2Alpin_020526_18a` | crop clip 0059 |

---

### ALPIN — lasciata invariata
File Pixel phone (PXL_*), foto e video misti. Da gestire separatamente.

---

## Totale file rinominati
| Sessione | File |
|----------|------|
| Sermenza Kayakers (prima passata Avata2) | 27 |
| Tutte Video Gare (re-rinomina + altre 3) | 67 |
| FPV Part 1 + FPV Part 2 | 50 |
| **Totale** | **144** |
