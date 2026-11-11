#!/bin/zsh
# Doppio clic: salva tutte le modifiche su GitHub.
cd "$(dirname "$0")" || exit 1

echo "Hai cambiato la MAPPA in Studio? Prima fai: File > Save to File As > rustell.rbxlx (in questa cartella)."
echo "(Gli script in src/ non servono: quelli sono già qui.)"
read -k1 "?Premi un tasto quando sei pronto..."; echo ""

git add -A
if git diff --cached --quiet; then
  read -k1 "?Niente di nuovo da salvare. Premi un tasto."; exit 0
fi

git status --short
read "msg?Cosa hai cambiato? (Invio = messaggio automatico): "
[ -z "$msg" ] && msg="Aggiornamento $(date '+%d/%m/%Y %H:%M')"

git commit -m "$msg" && git pull --rebase && git push \
  && echo ">> Salvato su GitHub." \
  || echo ">> Qualcosa è andato storto (vedi sopra). Chiedi a Claude di sistemarlo."
read -k1 "?Premi un tasto per chiudere."
