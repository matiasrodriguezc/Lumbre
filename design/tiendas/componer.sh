#!/usr/bin/env bash
# Compone las 7 capturas de App Store (1320×2868) desde las pantallas crudas de crudas/<idioma>/ con plantilla.html.
#   design/tiendas/componer.sh          # español
#   design/tiendas/componer.sh en       # inglés
# Necesita Google Chrome. Salida: design/tiendas/capturas/<idioma>/0N.png
set -euo pipefail
cd "$(dirname "$0")"
LANG_SET="${1:-es}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p "capturas/$LANG_SET"
for n in 1 2 3 4 5 6 7; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --window-size=1320,2868 --virtual-time-budget=3000 \
    --screenshot="$PWD/capturas/$LANG_SET/0$n.png" "file://$PWD/plantilla.html?n=$n&lang=$LANG_SET" 2>/dev/null
  echo "capturas/$LANG_SET/0$n.png"
done
