#!/usr/bin/env bash
# Copia a web/ lo que sale del design system, para que el sitio se publique solo (sin depender de ../design).
# Correr desde la raíz del repo después de cambiar tokens, logos o la red: web/scripts/sync-assets.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
web="$root/web"
sys="$root/design/system"

{ echo "/* Copia de design/system/tokens.css (generado desde tokens.json). Para actualizarla: web/scripts/sync-assets.sh */"; cat "$sys/tokens.css"; } > "$web/assets/tokens.css"
cp "$sys/logo/lumbre-mark.svg" "$sys/logo/lumbre-wordmark.svg" "$sys/identidad/estado-sin-chispa.svg" "$web/assets/img/"
cp "$sys/logo/lumbre-app-icon.svg" "$web/favicon.svg"

python3 - "$sys" "$web" <<'PY'
import re, sys
from PIL import Image
sys_dir, web = sys.argv[1], sys.argv[2]
# La red del hero: toda dormida (la chispa de la página es la de la demo).
s = open(f"{sys_dir}/identidad/red-horizontal.svg").read()
s = re.sub(r'<path class="n-spark"[^>]*/>', "", s).replace('class="n-active"', 'class="n-dormant"')
open(f"{web}/assets/img/red-dormida.svg", "w").write(s)
icon = Image.open(f"{sys_dir}/logo/exportes/ios/AppIcon-light.png").convert("RGB")
icon.resize((180, 180), Image.LANCZOS).save(f"{web}/apple-touch-icon.png", optimize=True)
PY

# Fraunces para la web: peso 600 y SOFT 100 fijos, opsz y WONK variables, solo latín (~37 KB). Requiere fonttools.
tmp="$(mktemp -d)"
python3 - "$root/ios/Packages/LumbreDesign/Sources/LumbreDesign/Resources/Fraunces.ttf" "$tmp/fr.ttf" <<'PY'
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
instancer.instantiateVariableFont(TTFont(sys.argv[1]), {"wght": 600, "SOFT": 100}).save(sys.argv[2])
PY
python3 -m fontTools.subset "$tmp/fr.ttf" --unicodes="U+0020-007E,U+00A0-00FF,U+2013-2014,U+2018-201E,U+2026,U+00D7,U+2022,U+20AC" \
  --layout-features='*' --flavor=woff --output-file="$web/assets/fonts/fraunces-600-soft.woff"
cp "$root/ios/Packages/LumbreDesign/Sources/LumbreDesign/Resources/Fraunces-OFL.txt" "$web/assets/fonts/"
rm -rf "$tmp"

python3 "$web/scripts/og.py" "$root"
echo "Listo: web/assets actualizado."
