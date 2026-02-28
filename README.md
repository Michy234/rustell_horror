# 🥖 Rustell Simulator — Il Re delle Rustelle

Un gioco su Roblox in cui devi sfamare gli NPC con le rustelle... prima che il Nonno si svegli.

---

## 🎮 Come si gioca

1. **Avvia la partita** dal menu principale premendo **GIOCA**
2. Nella mappa trovi una **brace** (braciere) e degli **NPC** affamati
3. **Cuoci le rustelle** sulla brace e **sfama gli NPC** prima che muoiano di fame
4. Hai **5 minuti** per sfamare tutti — se ci riesci, **vinci!**

---

## ⚠️ Attenzione al Nonno

Il **Nonno** dorme all'inizio della partita. Man mano che gli NPC vengono sfamati:

- Quando rimangono **2 NPC**, il Nonno si **sveglia** e diventa agitato
- Quando rimane **1 solo NPC** (o muori), il Nonno si **alza** e ti insegue → **GAME OVER**

La sequenza di game over include un urlo e un jumpscare — buona fortuna.

---

## 🔥 Meccaniche principali

| Azione | Dettaglio |
|---|---|
| **Cuocere** | Metti la rustella cruda sulla brace, aspetta ~10 secondi |
| **Bruciare** | Se la lasci troppo (~12 sec dopo cotta), brucia e penalizza la fame |
| **Sfamare** | Porta la rustella cotta a un NPC entro la distanza di interazione |
| **Pioggia** | Evento casuale che spegne la brace — rimettici il carbone! |
| **Cane** | Un cane ostile appare periodicamente e disturba il gioco |

---

## ⚙️ Impostazioni

Premi **IMPOSTAZIONI** dal menu o il tasto **I** durante il gioco per regolare:
- Volume audio / musica
- Difficoltà (velocità di fame degli NPC)
- Prima / Terza persona

---

## 👑 Comandi Admin

Disponibili solo per gli admin (`Michy234`, `Moltarobba`, `marco`):

- `:lose` — forza il game over
- `:win` — forza la vittoria
- `:reset` — resetta la partita
- `:nonno2` — sveglia il Nonno

---

## 🛠️ Setup progetto (Rojo)

```bash
# Builda il place
rojo build -o "NEW RUSTELL HORROR ROJO.rbxlx"

# Avvia il server di sync live
rojo serve
```

Apri il file `.rbxlx` in **Roblox Studio** e connettiti al server Rojo per il live sync.
Docs: [rojo.space/docs](https://rojo.space/docs)
