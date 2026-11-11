#!/bin/zsh
# Doppio clic: scarica le novità da GitHub e avvia Rojo. Lascia la finestra aperta mentre lavori.
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/.rokit/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v rokit >/dev/null; then
  echo "Manca rokit. Apri il Terminale e scrivi:  brew install rokit"
  read -k1 "?Premi un tasto per chiudere."; exit 1
fi

command -v rojo >/dev/null || rokit install || { read -k1 "?Installazione Rojo fallita. Premi un tasto."; exit 1; }

if [ ! -f "$HOME/Documents/Roblox/Plugins/RojoManagedPlugin.rbxm" ]; then
  rojo plugin install && echo ">> Plugin Rojo installato: RIAVVIA Roblox Studio."
fi

echo ">> Scarico le novità da GitHub..."
git pull || { read -k1 "?git pull fallito (vedi sopra). Premi un tasto."; exit 1; }

echo ""
echo ">> In Studio: apri il plugin Rojo e premi Connect."
echo ">> Per fermare: chiudi questa finestra. Per salvare su GitHub: doppio clic su Salva.command"
echo ""
rojo serve
