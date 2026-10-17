#!/usr/bin/env python3
"""Junta los SVG de la identidad neuronal en un solo archivo JS para los mockups de design/.

Los mockups son HTML sueltos que se abren con file://, donde no se puede hacer fetch de los SVG.
Este script los lee de su fuente (design/system/identidad, design/system/logo, identidad.html y los
íconos de pestaña de iOS), les saca el <style> embebido y el tamaño fijo, y los escribe en arte.js.
En el HTML: <span data-art="sinapsis-completa"></span>. Los colores salen de las clases de rol
(n-dormant, n-link, n-active, n-impulse, n-spark) que define components/bundle.css, así que
siguen al tema gris o grafito.

No dibuja nada: para cambiar una forma, editá design/system/identidad/generar.py, regenerá y
volvé a correr este script.

    python3 design/shared/arte.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SYSTEM = ROOT / "design" / "system"
OUT = Path(__file__).with_name("arte.js")


def clean(svg: str, role_fill: dict | None = None) -> str:
    svg = re.sub(r"<style>.*?</style>", "", svg, flags=re.S)
    svg = re.sub(r"<\?xml.*?\?>", "", svg)
    head = re.match(r"<svg[^>]*>", svg).group(0)
    new_head = re.sub(r'\s(width|height)="[^"]*"', "", head)
    if "aria-hidden" not in new_head:
        new_head = new_head.replace("<svg", '<svg aria-hidden="true" focusable="false"', 1)
    svg = svg.replace(head, new_head, 1)
    for color, cls in (role_fill or {}).items():
        svg = svg.replace(f'fill="{color}"', f'class="{cls}"')
    if role_fill:
        # Trazos sin color propio: son la neurona (tinta del tema).
        svg = re.sub(r"<path (?![^>]*\b(?:class|fill)=)", '<path class="n-active" ', svg)
    return svg.strip()


def first_svg_after(html: str, marker: str) -> str:
    i = html.index(marker)
    start = html.index("<svg", i)
    end = html.index("</svg>", start) + len("</svg>")
    return html[start:end]


def main() -> None:
    ident = (SYSTEM / "identidad.html").read_text(encoding="utf-8")
    spark_card = (SYSTEM / "components" / "SparkCard" / "preview.html").read_text(encoding="utf-8")
    tabs = ROOT / "ios" / "Lumbre" / "Resources" / "Assets.xcassets"
    ink = {"#0E0E10": "n-active", "#FF3EA5": "n-spark", "#000": "n-active"}

    art = {
        # Símbolo y marca
        "marca": clean((SYSTEM / "logo" / "lumbre-mark.svg").read_text(), {"#0E0E10": "n-active"}),
        "marca-nucleo": clean(first_svg_after(ident, 'class="hero__mark"')),
        "marca-compacta": clean((SYSTEM / "logo" / "lumbre-mark-compacto.svg").read_text(), {"#0E0E10": "n-active"}),
        "icono-app": clean((SYSTEM / "logo" / "lumbre-app-icon.svg").read_text()),
        "wordmark": clean((SYSTEM / "logo" / "lumbre-wordmark.svg").read_text(), ink),
        # Sinapsis: terminales (conector chico) y neuronas enteras (chispa, reveal, compartir)
        "sinapsis": clean((SYSTEM / "identidad" / "sinapsis.svg").read_text()),
        "sinapsis-completa": clean(first_svg_after(spark_card, 'class="ch-pair"')),
        # Red de fondo
        "red-horizontal": clean((SYSTEM / "identidad" / "red-horizontal.svg").read_text()),
        "red-vertical": clean((SYSTEM / "identidad" / "red-vertical.svg").read_text()),
        "red-encabezado": clean(first_svg_after(ident, 'class="today__head"')),
        "red-historia": clean(first_svg_after(ident, 'class="share"')),
        "red-splash": clean(first_svg_after(ident, 'class="splash"')),
        # Pulso (axón) para destilar y encender
        "axon": clean(first_svg_after(ident, 'class="loader"')),
        # Estados vacíos
        "estado-red-vacia": clean((SYSTEM / "identidad" / "estado-boveda-vacia.svg").read_text()),
        "estado-sin-chispa": clean((SYSTEM / "identidad" / "estado-sin-chispa.svg").read_text()),
        "estado-sin-circuitos": clean((SYSTEM / "identidad" / "estado-sin-circuitos.svg").read_text()),
        "estado-sin-conexion": clean((SYSTEM / "identidad" / "estado-sin-conexion.svg").read_text()),
        # Pestañas (plantillas de iOS: se pintan con currentColor)
        "tab-hoy": clean((tabs / "tab-hoy.imageset" / "tab-hoy.svg").read_text()).replace('fill="#000"', 'fill="currentColor"'),
        "tab-red": clean((tabs / "tab-red.imageset" / "tab-red.svg").read_text()).replace('fill="#000"', 'fill="currentColor"'),
        "tab-circuitos": clean((tabs / "tab-circuitos.imageset" / "tab-circuitos.svg").read_text()).replace('fill="#000"', 'fill="currentColor"'),
    }

    js = [
        "/* Generado por design/shared/arte.py desde design/system. No editar a mano. */",
        "window.LUMBRE_ARTE = " + json.dumps(art, ensure_ascii=False, indent=0) + ";",
        "window.arte = function (name) { return window.LUMBRE_ARTE[name] || ''; };",
        "window.pintarArte = function (root) {",
        "  (root || document).querySelectorAll('[data-art]').forEach(function (el) {",
        "    if (!el.firstElementChild) el.innerHTML = window.arte(el.dataset.art);",
        "  });",
        "};",
        "document.addEventListener('DOMContentLoaded', function () { window.pintarArte(); });",
    ]
    OUT.write_text("\n".join(js) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {len(art)} piezas, {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
