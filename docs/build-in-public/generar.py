"""Arma plantilla-visual.html desde plantilla-visual.src.html y chispas-del-dia.md.

Uso: python3 docs/build-in-public/generar.py
"""
import json
import re
from pathlib import Path

HERE = Path(__file__).parent
md = (HERE / "chispas-del-dia.md").read_text(encoding="utf-8")

chispas = []
for block in re.split(r"^## \d+\. ", md, flags=re.M)[1:]:
    clash = block.splitlines()[0].strip()
    n1 = re.search(r"\*\*Neurona 1\*\* · ([^:]+): (.+)", block)
    n2 = re.search(r"\*\*Neurona 2\*\* · ([^:]+): (.+)", block)
    ch = re.search(r"\*\*Chispa: (.+?)\.\*\* (.+)", block)
    chispas.append({
        "clash": clash,
        "da": n1.group(1), "ia": n1.group(2).strip(),
        "db": n2.group(1), "ib": n2.group(2).strip(),
        "title": ch.group(1), "body": ch.group(2).strip(),
    })

assert len(chispas) == 20, len(chispas)
src = (HERE / "plantilla-visual.src.html").read_text(encoding="utf-8")
out = src.replace("/*CHISPAS*/[]", json.dumps(chispas, ensure_ascii=False, indent=1))
(HERE / "plantilla-visual.html").write_text(out, encoding="utf-8")
print(f"plantilla-visual.html con {len(chispas)} chispas")
