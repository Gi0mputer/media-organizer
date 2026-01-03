# 🚀 START HERE - Nuova Chat LLM

## Per LLM: Istruzioni Inizio Sessione

Quando inizi una nuova chat su questo progetto, segui SEMPRE questa sequenza:

### STEP 1: Leggi Context Permanente
```
File: CORE_CONTEXT.md
Contiene: Path hardcoded, regole fondamentali, struttura archivio
Obbligatorio: SÌ (SEMPRE)
```

### STEP 2: Identifica Argomento
Chiedi all'utente o leggi il suo primo messaggio per capire:
- Lavoro su date fix?
- Lavoro su sync mobile?
- Nuova feature?
- Bug fix?
- Test/analisi?

### STEP 3: Leggi Documentazione Specifica

**Se lavori su DATE FIX**:
→ `1_LLM_Automation/HANDOFF_PROSSIMA_CHAT.md`
→ `1_LLM_Automation/README.md`
→ `1_LLM_Automation/TODO.md`
→ `1_LLM_Automation/Documentation/REGOLE_ORGANIZZAZIONE_MEDIA.md`

**Se lavori su MOBILE SYNC**:
→ `3_Sync_Mobile_Drive/TODO_CHAT_FUTURA_SYNC.md`
→ `3_Sync_Mobile_Drive/README.md`
→ `3_Sync_Mobile_Drive/device_config.json`

**Se lavori su DRAG&DROP TOOLS**:
→ `2_DragDrop_Tools/README.md`
→ `2_DragDrop_Tools/TODO.md`

### STEP 4: Conferma Comprensione
Rispondi all'utente confermando:
- ✓ Ho letto CORE_CONTEXT.md
- ✓ Ho capito la struttura archivio
- ✓ So quali documenti consultare per questo task
- ✓ Sono pronto ad iniziare

---

## Per Utente: Come Iniziare Nuova Chat

### Chat su Advanced Date Fix
```
Continuo progetto Media Archive Management.

LEGGI: Desktop\Batchs\CORE_CONTEXT.md  
POI: Desktop\Batchs\1_LLM_Automation\HANDOFF_PROSSIMA_CHAT.md

OBIETTIVO: Implementa Advanced Date Fix (MAX strategy)
```

### Chat su Mobile Sync
```
Implemento Mobile Sync per progetto Media Archive.

LEGGI: Desktop\Batchs\CORE_CONTEXT.md
POI: Desktop\Batchs\3_Sync_Mobile_Drive\TODO_CHAT_FUTURA_SYNC.md

OBIETTIVO: Sync Pixel 8, 3 modalità
```

### Chat Generica/Manutenzione
```
Lavoro su progetto Media Archive Management.

LEGGI: Desktop\Batchs\CORE_CONTEXT.md

TASK: [descrivi cosa vuoi fare]
```

---

## Struttura Documenti Quick Reference

```
Desktop\Batchs\
│
├── CORE_CONTEXT.md              ← LEGGI SEMPRE (permanente)
├── START_HERE.md                ← Questo file (guida avvio)
│
├── 1_LLM_Automation\
│   ├── README.md                ← Overview area + problemi risolti
│   ├── TODO.md                  ← Feature da implementare
│   ├── HANDOFF_PROSSIMA_CHAT.md ← Next: Advanced Date Fix
│   └── Documentation\
│       └── REGOLE_ORGANIZZAZIONE_MEDIA.md  ← Regole complete
│
├── 2_DragDrop_Tools\
│   ├── README.md                ← Catalogo tool utente
│   └── TODO.md                  ← Nuovi tool da creare
│
└── 3_Sync_Mobile_Drive\
    ├── README.md                ← Spec sync progetto
    ├── TODO.md                  ← Feature sync base
    ├── TODO_CHAT_FUTURA_SYNC.md ← Spec complete 3 modalità
    └── device_config.json       ← Config Pixel 8 + dischi
```

---

**Quick Start per LLM**:
1. Leggi `CORE_CONTEXT.md`
2. Chiedi all'utente cosa deve fare
3. Leggi doc specifico
4. Inizia!
