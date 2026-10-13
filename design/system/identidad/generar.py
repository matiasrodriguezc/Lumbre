"""Genera la identidad neuronal de Lumbre: logo, ícono, sinapsis, red e ilustraciones.

Uso (requiere shapely 2, fonttools, uharfbuzz y pillow):
    python3 -m venv /tmp/lumbre-venv && /tmp/lumbre-venv/bin/pip install shapely fonttools uharfbuzz pillow
    /tmp/lumbre-venv/bin/python design/system/identidad/generar.py

Escribe los SVG en design/system/logo/ y design/system/identidad/, los PNG del ícono
en design/system/logo/exportes/ y en el AppIcon de iOS, y arma design/system/identidad.html
a partir de identidad/plantilla.html. El wordmark sale en curvas desde la Fraunces
variable empaquetada en LumbreDesign, así que los SVG no dependen de la fuente instalada.

Todas las formas siguen el mismo lenguaje: "facetado orgánico". Ramas que se
afinan, uniones redondeadas y un contorno simplificado en segmentos rectos.
"""
import math
import random
import re
from pathlib import Path

from shapely.affinity import affine_transform
from shapely.geometry import LineString, MultiPolygon, Point, Polygon
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parent.parent  # design/system
REPO = ROOT.parent.parent
LOGO = ROOT / "logo"
OUT = ROOT / "identidad"
EXPORTS = LOGO / "exportes"
FONT = REPO / "ios/Packages/LumbreDesign/Sources/LumbreDesign/Resources/Fraunces.ttf"
IOS_ICON = REPO / "ios/Lumbre/Resources/Assets.xcassets/AppIcon.appiconset"
SWIFT_OUT = REPO / "ios/Packages/LumbreDesign/Sources/LumbreDesign/Generated/NeuralArt.generated.swift"

NEURON, GRAY, GRAPHITE, BONE, SPARK = "#0E0E10", "#E3E3DF", "#2A2A2C", "#EDEDE8", "#FF3EA5"
# Roles de ilustración sobre tokens existentes; el fallback es el tema oscuro.
ILLU_STYLE = ("<style>.n-dormant{fill:var(--surface-alt,#D5D5D0)}.n-link{fill:var(--border,#C6C6C0)}"
              ".n-active{fill:var(--ink,#0E0E10)}.n-impulse{fill:var(--info-text,#3A3A3E)}"
              ".n-spark{fill:var(--spark,#FF3EA5)}.n-trace{fill:none;stroke:var(--border-strong,#76767A);"
              "stroke-width:1.5;stroke-dasharray:2 5;stroke-linecap:round}"
              ".n-cut{fill:none;stroke:var(--border-strong,#76767A);stroke-width:2.5;stroke-linecap:round}</style>")
STAR = "M12 1 Q12 12 23 12 Q12 12 12 23 Q12 12 1 12 Q12 12 12 1Z"  # la chispa, 24×24


# ---------- geometría ----------

def taper(points, w0, w1, res=8):
    """Rama a lo largo de una polilínea: ancho w0 en la base y w1 en la punta."""
    acc = [0.0]
    for a, b in zip(points, points[1:]):
        acc.append(acc[-1] + math.dist(a, b))
    total = acc[-1] or 1
    width = lambda d: w0 + (w1 - w0) * d / total
    parts = [Point(points[0]).buffer(w0 / 2, res)]
    for i, (a, b) in enumerate(zip(points, points[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n, dx / n
        ha, hb = width(acc[i]) / 2, width(acc[i + 1]) / 2
        parts.append(Polygon([(a[0] + nx * ha, a[1] + ny * ha), (b[0] + nx * hb, b[1] + ny * hb),
                              (b[0] - nx * hb, b[1] - ny * hb), (a[0] - nx * ha, a[1] - ny * ha)]))
        parts.append(Point(b).buffer(hb, res))
    return unary_union(parts)


def soma(center, radii, rot=0.0):
    """Cuerpo de la neurona: polígono irregular con un radio por vértice."""
    k = len(radii)
    return Polygon([(center[0] + r * math.cos(rot + i * 2 * math.pi / k),
                     center[1] + r * math.sin(rot + i * 2 * math.pi / k)) for i, r in enumerate(radii)])


def organic(parts, fillet, facet):
    """Une las partes, redondea las uniones y facetea el contorno."""
    g = unary_union(parts)
    return g.buffer(fillet, 6).buffer(-fillet, 6).simplify(facet)


def path_d(geom, tx=0.0, ty=0.0, s=1.0):
    polys = geom.geoms if isinstance(geom, MultiPolygon) else [geom]
    out = []
    for p in polys:
        for ring in [p.exterior, *p.interiors]:
            pts = list(ring.coords)[:-1]
            out.append("M" + " L".join(f"{(x + tx) * s:.1f} {(y + ty) * s:.1f}" for x, y in pts) + "Z")
    return " ".join(out)


def fit(geom, box, pad):
    """Transformación que centra geom en un cuadro (w, h) con padding."""
    minx, miny, maxx, maxy = geom.bounds
    w, h = box
    s = min((w - 2 * pad) / (maxx - minx), (h - 2 * pad) / (maxy - miny))
    tx = (w / s - (maxx - minx)) / 2 - minx
    ty = (h / s - (maxy - miny)) / 2 - miny
    return tx, ty, s


# ---------- formas de marca ----------

def neuron_long():
    """La neurona del logo: soma a la izquierda, axón largo y tres terminales."""
    c = (66, 70)
    parts = [
        soma(c, [27, 25, 28, 24, 27, 25, 23, 26]),
        taper([(56, 54), (40, 36), (22, 26)], 20, 7),
        taper([(40, 36), (38, 18)], 9, 5),
        taper([(46, 72), (24, 76), (6, 70)], 20, 7),
        taper([(56, 88), (42, 108), (34, 124)], 20, 7),
        taper([(74, 50), (82, 30), (78, 12)], 18, 7),
        taper([(78, 90), (88, 112), (100, 124)], 16, 6),
        taper([(86, 70), (120, 62), (158, 66), (192, 60)], 18, 11),
        taper([(192, 60), (208, 42), (214, 26)], 11, 6),
        taper([(192, 60), (214, 60), (230, 54)], 11, 6),
        taper([(192, 60), (206, 78), (218, 92)], 11, 6),
    ]
    return organic(parts, 5, 1.6), c


def neuron_compact():
    """Variante para el ícono: el axón se curva hacia abajo para llenar el cuadrado."""
    c = (38, 40)
    parts = [
        soma(c, [15, 13.5, 15.5, 13, 15, 14, 12.5, 14.5], rot=0.3),
        taper([(32, 31), (23, 19), (12, 13)], 10, 3.6),
        taper([(23, 19), (22, 7)], 5, 2.8),
        taper([(27, 41), (15, 43), (4, 38)], 10, 3.6),
        taper([(31, 50), (22, 62), (18, 75)], 10, 3.6),
        taper([(22, 62), (9, 66)], 4.5, 2.6),
        taper([(43, 29), (48, 17), (46, 5)], 9, 3.4),
        taper([(48, 47), (60, 55), (68, 66), (72, 77)], 9.5, 6.5),
        taper([(72, 77), (70, 89), (65, 96)], 6, 3.2),
        taper([(72, 77), (83, 87), (93, 90)], 6, 3.2),
        taper([(72, 77), (86, 74), (96, 68)], 6, 3.2),
    ]
    return organic(parts, 2.6, 0.75), c


def synapse():
    """Dos terminales que se enfrentan; en el hueco salta la chispa. Caja 120×40."""
    def side(sign):
        x = lambda v: v if sign > 0 else 120 - v
        knobs = [(46, 9), (49, 20), (46, 31)]
        parts = [taper([(x(0), 20), (x(18), 19), (x(33), 20)], 5.5, 5)]
        for kx, ky in knobs:
            parts += [taper([(x(33), 20), (x(kx - 2), ky)], 4.2, 3.2), Point(x(kx), ky).buffer(3.6, 8)]
        return organic(parts, 1.6, 0.4)
    return side(1), side(-1)


def small_neuron(rng, c, r):
    parts = [soma(c, [r * rng.uniform(0.85, 1.15) for _ in range(7)], rot=rng.uniform(0, 6))]
    base = rng.uniform(0, 2 * math.pi)
    for i in range(rng.randint(3, 4)):
        a = base + i * 2 * math.pi / 4 + rng.uniform(-0.4, 0.4)
        L = r * rng.uniform(1.7, 2.6)
        bend = rng.uniform(-0.35, 0.35)
        p0 = (c[0] + math.cos(a) * r * 0.6, c[1] + math.sin(a) * r * 0.6)
        p1 = (c[0] + math.cos(a + bend / 2) * L * 0.6, c[1] + math.sin(a + bend / 2) * L * 0.6)
        p2 = (c[0] + math.cos(a + bend) * L, c[1] + math.sin(a + bend) * L)
        parts.append(taper([p0, p1, p2], r * 1.05, max(1.3, r * 0.32)))
    return organic(parts, r * 0.35, r * 0.1)


def hero_neuron(rng, c, r, end, fork=True):
    """Neurona protagonista: dendritas hacia atrás y axón hasta `end`, con terminal en tres botones."""
    a0 = math.atan2(end[1] - c[1], end[0] - c[0])
    parts = [soma(c, [r * rng.uniform(0.9, 1.1) for _ in range(8)], rot=rng.uniform(0, 1))]
    for k, da in enumerate([-1.25, -0.45, 0.45, 1.25]):
        a = a0 + math.pi + da + rng.uniform(-0.15, 0.15)
        L = r * rng.uniform(2.1, 2.7)
        bend = rng.uniform(-0.3, 0.3)
        p0 = (c[0] + math.cos(a) * r * 0.5, c[1] + math.sin(a) * r * 0.5)
        p1 = (c[0] + math.cos(a + bend / 2) * L * 0.6, c[1] + math.sin(a + bend / 2) * L * 0.6)
        p2 = (c[0] + math.cos(a + bend) * L, c[1] + math.sin(a + bend) * L)
        parts.append(taper([p0, p1, p2], r * 0.95, r * 0.32))
        if k in (0, 3):
            b = a + (0.7 if k == 0 else -0.7)
            parts.append(taper([p1, (p1[0] + math.cos(b) * L * 0.45, p1[1] + math.sin(b) * L * 0.45)], r * 0.45, r * 0.26))
    d = math.dist(c, end)
    nx, ny = -(end[1] - c[1]) / d, (end[0] - c[0]) / d
    mid = ((c[0] + end[0]) / 2 + nx * d * 0.06, (c[1] + end[1]) / 2 + ny * d * 0.06)
    parts.append(taper([c, mid, end], r * 0.6, r * 0.42))
    if fork:
        for da in (-0.75, 0, 0.75):
            a = a0 + da
            k = (end[0] + math.cos(a) * r * 0.85, end[1] + math.sin(a) * r * 0.85)
            parts += [taper([end, k], r * 0.36, r * 0.3), Point(k).buffer(r * 0.3, 8)]
    return organic(parts, r * 0.22, r * 0.05)


def link(rng, a, b, w0, w1):
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    d = math.dist(a, b)
    nx, ny = -(b[1] - a[1]) / d, (b[0] - a[0]) / d
    off = rng.uniform(-0.12, 0.12) * d
    return taper([a, (mx + nx * off, my + ny * off), b], w0, w1)


def network(w, h, min_dist, seed, r=(4.5, 7.5), active=None, keep_out=None):
    """Red de neuronas dormidas unidas a sus vecinas. active=((x,y),(x,y)) agrega dos
    neuronas encendidas cuyos axones se encuentran en el medio (la sinapsis)."""
    rng = random.Random(seed)
    pts = []
    for _ in range(4000):
        p = (rng.uniform(-20, w + 20), rng.uniform(-20, h + 20))
        if keep_out and any(Point(p).within(k) for k in keep_out):
            continue
        if all(math.dist(p, q) >= min_dist for q in pts) and \
                (not active or all(math.dist(p, q) >= min_dist * 0.9 for q in active)):
            pts.append(p)
    nodes = [small_neuron(rng, p, rng.uniform(*r)) for p in pts]
    edges, seen = [], set()
    for i, p in enumerate(pts):
        near = sorted(range(len(pts)), key=lambda j: math.dist(p, pts[j]))[1:3]
        for j in near:
            key = tuple(sorted((i, j)))
            if key not in seen and math.dist(p, pts[j]) < min_dist * 1.8:
                seen.add(key)
                edges.append(link(rng, p, pts[j], 3.2, 1.8))
    dormant = unary_union(nodes)
    links = unary_union(edges).difference(dormant)
    lit = None
    if active:
        (a, b), mid = active, ((active[0][0] + active[1][0]) / 2, (active[0][1] + active[1][1]) / 2)
        R = r[1] * 1.6
        gap = 26 + R * 0.85
        da = math.dist(a, mid)
        ea = (mid[0] - (mid[0] - a[0]) * gap / da, mid[1] - (mid[1] - a[1]) * gap / da)
        eb = (mid[0] - (mid[0] - b[0]) * gap / da, mid[1] - (mid[1] - b[1]) * gap / da)
        lit = unary_union([hero_neuron(rng, a, R, ea), hero_neuron(rng, b, R, eb)])
        links = links.difference(lit.buffer(8))
        dormant = dormant.difference(lit.buffer(8))
        return dormant, links, lit, mid
    return dormant, links, None, None


# ---------- wordmark ----------

def wordmark(text, size, x0, y0, tracking=-0.01):
    """"Lumbre." en curvas: Fraunces 600, SOFT 100, WONK 1, opsz al tamaño (como el CSS del sistema).
    Devuelve [(path, índice del carácter)] con la línea de base en y0, y el ancho total."""
    from io import BytesIO

    import uharfbuzz as hb
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    inst = instancer.instantiateVariableFont(
        TTFont(FONT), {"wght": 600, "SOFT": 100, "WONK": 1, "opsz": min(144, max(9, size))})
    data = BytesIO()
    inst.save(data)
    font = hb.Font(hb.Face(data.getvalue()))
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf, {"kern": True, "liga": True})
    upem = inst["head"].unitsPerEm
    s, track = size / upem, tracking * upem
    glyphs, order = inst.getGlyphSet(), inst.getGlyphOrder()
    out, pen_x = [], 0.0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        pen = SVGPathPen(glyphs)
        glyphs[order[info.codepoint]].draw(
            TransformPen(pen, (s, 0, 0, -s, x0 + (pen_x + pos.x_offset) * s, y0 - pos.y_offset * s)))
        out.append((pen.getCommands(), info.cluster))
        pen_x += pos.x_advance + track
    return out, (pen_x - track) * s


def wordmark_svg(glyphs, ink):
    """El punto final es `spark`; el resto, `ink`."""
    last = max(c for _, c in glyphs)
    return "".join(f'<path d="{d}" fill="{SPARK if c == last else ink}"/>' for d, c in glyphs)


# ---------- PNG ----------

def rgba(hex_color, alpha=255):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def raster(size, layers, bg=None, ss=4):
    """Rasteriza [(geometría en px finales, color)] con supersampling. bg=None deja fondo transparente."""
    from PIL import Image, ImageDraw
    big = size * ss
    img = Image.new("RGBA", (big, big), bg or (0, 0, 0, 0))
    for geom, color in layers:
        mask = Image.new("L", (big, big), 0)
        draw = ImageDraw.Draw(mask)
        for p in (geom.geoms if isinstance(geom, MultiPolygon) else [geom]):
            draw.polygon([(x * ss, y * ss) for x, y in p.exterior.coords], fill=255)
            for ring in p.interiors:
                draw.polygon([(x * ss, y * ss) for x, y in ring.coords], fill=0)
        img.paste(Image.new("RGBA", (big, big), color), (0, 0), mask)
    return img.resize((size, size), Image.LANCZOS)


def save_png(img, path, opaque=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    (img.convert("RGB") if opaque else img).save(path, optimize=True)
    print("escrito", path.relative_to(REPO))


def export_icons(comp_g, comp_c):
    """iOS 1024 (gris, dark, tinted) y Android adaptive (foreground y monochrome por densidad)."""
    import json

    from shapely.affinity import affine_transform

    def placed(scale, dx, dy):
        m = [scale, 0, 0, scale, dx, dy]
        neuron = affine_transform(comp_g, m)
        nucleus = affine_transform(Point(comp_c).buffer(5.4, 16), m)
        return neuron, nucleus

    # iOS: la neurona ocupa el 78% del cuadrado, igual que lumbre-app-icon.svg.
    minx, miny, maxx, maxy = comp_g.bounds
    k = 1024 * 0.78 / max(maxx - minx, maxy - miny)
    neuron, nucleus = placed(k, 512 - (minx + maxx) / 2 * k, 512 - (miny + maxy) / 2 * k)
    ios = EXPORTS / "ios"
    icons = {
        "AppIcon-light.png": (raster(1024, [(neuron, rgba(NEURON)), (nucleus, rgba(SPARK))], rgba(GRAY)), True),
        "AppIcon-dark.png": (raster(1024, [(neuron, rgba(BONE)), (nucleus, rgba(SPARK))]), False),
        "AppIcon-tinted.png": (raster(1024, [(neuron.difference(nucleus), rgba("#FFFFFF"))], rgba("#000000")), True),
    }
    for name, (img, opaque) in icons.items():
        save_png(img, ios / name, opaque)
        save_png(img, IOS_ICON / name, opaque)
    images = [{"filename": "AppIcon-light.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    for look in ("dark", "tinted"):
        images.append({"appearances": [{"appearance": "luminosity", "value": look}],
                       "filename": f"AppIcon-{look}.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"})
    (IOS_ICON / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    # Android: lienzo de 108dp; todo el dibujo entra en el círculo seguro de 66dp (radio 33).
    cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
    reach = max(math.dist((cx, cy), pt) for p in (comp_g.geoms if isinstance(comp_g, MultiPolygon) else [comp_g])
                for pt in p.exterior.coords)
    res = EXPORTS / "android/res"
    for density, px in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        k = px / 108 * 32 / reach
        neuron, nucleus = placed(k, px / 2 - cx * k, px / 2 - cy * k)
        save_png(raster(px, [(neuron, rgba(NEURON)), (nucleus, rgba(SPARK))]), res / f"mipmap-{density}/ic_launcher_foreground.png")
        save_png(raster(px, [(neuron.difference(nucleus), rgba("#FFFFFF"))]), res / f"mipmap-{density}/ic_launcher_monochrome.png")
    (res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        '</adaptive-icon>\n')
    (res / "values").mkdir(parents=True, exist_ok=True)
    (res / "values/ic_launcher_background.xml").write_text(
        f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">{GRAY}</color>\n</resources>\n')
    # Ícono de Google Play: 512 a sangre, con la misma proporción que iOS.
    k = 512 * 0.78 / max(maxx - minx, maxy - miny)
    neuron, nucleus = placed(k, 256 - cx * k, 256 - cy * k)
    save_png(raster(512, [(neuron, rgba(NEURON)), (nucleus, rgba(SPARK))], rgba(GRAY)), EXPORTS / "android/playstore-512.png", True)


# ---------- Swift ----------

def moved(g, tx, ty, s):
    """La misma transformación que path_d(g, tx, ty, s), pero sobre la geometría."""
    return affine_transform(g, [s, 0, 0, s, tx * s, ty * s])


def rings(g):
    for p in (g.geoms if isinstance(g, MultiPolygon) else [g]):
        if not p.is_empty:
            yield from [p.exterior, *p.interiors]


def write_swift(art, extras):
    """Vuelca las formas a LumbreDesign para que la app dibuje exactamente lo mismo que el sistema."""
    out = ["// Generado por design/system/identidad/generar.py. No editar a mano.", "",
           "import CoreGraphics", "", "extension NeuralArt {"]
    for name, (w, h, layers) in art.items():
        out.append(f"    static let {name} = NeuralArt(width: {w:g}, height: {h:g}, layers: [")
        for role, g in layers:
            rs = ["[" + ", ".join(f"{x:.1f}, {y:.1f}" for x, y in list(r.coords)[:-1]) + "]" for r in rings(g)]
            out.append(f"        NeuralLayer(.{role}, [{', '.join(rs)}]),")
        out.append("    ])")
    out.append("}")
    out.append("")
    out.append("enum NeuralAnchors {")
    out += [f"    static let {k} = {v}" for k, v in extras.items()]
    out.append("}")
    SWIFT_OUT.write_text("\n".join(out) + "\n")
    print("escrito", SWIFT_OUT.relative_to(REPO), f"({SWIFT_OUT.stat().st_size // 1024} KB)")


# ---------- íconos de pestañas ----------

def tab_icons():
    """Íconos de pestaña en el mismo facetado, más gruesos para leerse a 25pt. Lienzo de 100."""
    hoy = organic([
        soma((40, 40), [13, 11.5, 13.5, 11.5, 12.5, 12, 11, 12.5], rot=0.3),
        taper([(35, 31), (18, 10)], 12, 8), taper([(29, 42), (4, 38)], 12, 8),
        taper([(34, 51), (18, 74)], 12, 8), taper([(46, 29), (52, 4)], 11, 8),
        taper([(48, 48), (64, 62), (74, 82)], 11, 9),
        taper([(74, 82), (70, 97)], 9, 8), taper([(74, 82), (94, 92)], 9, 8),
    ], 3.5, 0.8)
    nodes = [(20, 30, 11), (72, 18, 10), (84, 64, 12), (38, 82, 11), (52, 48, 9)]
    edges = [(0, 4), (4, 1), (4, 2), (4, 3), (0, 3), (1, 2)]
    red = organic([Point(x, y).buffer(r, 10) for x, y, r in nodes]
                  + [taper([nodes[a][:2], nodes[b][:2]], 8, 6) for a, b in edges], 2.5, 0.8)
    ring = [(28, 26, 12), (76, 30, 10), (72, 76, 12), (24, 72, 10)]
    circuito = organic([Point(x, y).buffer(r, 10) for x, y, r in ring]
                       + [taper([ring[i][:2], ring[(i + 1) % 4][:2]], 8, 7) for i in range(4)]
                       + [taper([(72, 76), (92, 94)], 7, 6), Point(94, 96).buffer(5, 8)], 2.5, 0.8)
    return {"tab-hoy": hoy, "tab-red": red, "tab-circuitos": circuito}


def export_tab_icons():
    """Imagesets vectoriales y de plantilla en el catálogo de la app (25×25 pt, como un SF Symbol en la barra)."""
    import json
    assets = REPO / "ios/Lumbre/Resources/Assets.xcassets"
    previews = {}
    for name, g in tab_icons().items():
        tx, ty, s = fit(g, (25, 25), 0.5)
        d = path_d(g, tx, ty, s)
        folder = assets / f"{name}.imageset"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{name}.svg").write_text(svg(25, 25, f'<path d="{d}" fill="#000"/>'))
        (folder / "Contents.json").write_text(json.dumps({
            "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
        }, indent=2) + "\n")
        print("escrito", (folder / f"{name}.svg").relative_to(REPO))
        tx, ty, s = fit(g, (100, 100), 4)
        previews[name] = svg(100, 100, f'<path class="n-active" d="{path_d(g, tx, ty, s)}"/>')
    return previews


# ---------- previews del sistema ----------

def write_previews(frag):
    """Previews de componentes en design/system/components/ (mismo formato que los existentes)."""
    comp = ROOT / "components"
    head = ('<!doctype html><html data-theme="light"><head><link rel="stylesheet" href="../../tokens.css">'
            '<link rel="stylesheet" href="../bundle.css"><meta charset="utf-8"><title>{t}</title></head><body>\n')
    syn = frag["synapse"].replace("<svg ", '<svg class="ch-syn" aria-hidden="true" ', 1)
    syn_full = frag["synapse-full"].replace("<svg ", '<svg class="ch-syn-full" aria-hidden="true" ', 1)
    syn_off = frag["synapse-off"].replace("<svg ", '<svg class="ch-syn" aria-hidden="true" ', 1)
    pages = {
        "SparkCard": ('<!-- @dsCard group="Contenido" height=440 -->', (
            '<div class="ch-pad"><article class="ch-spark">\n'
            '<div class="ch-pair"><div><span>Medios</span><b>Formato podcast</b></div><div class="r"><span>Historia</span><b>Ruinas romanas</b></div></div>\n'
            f'{syn_full}\n'
            '<h3>Podcast × ruinas</h3>\n'
            '<p>Grabá cada episodio en un sitio histórico distinto y dejá que el lugar marque el tema. El sonido ambiente es parte del guion.</p>\n'
            '<div class="ch-spark__actions"><button class="ch-btn ch-btn--primary">Guardar idea</button>'
            '<button class="ch-btn ch-btn--secondary">Planificar</button><button class="ch-btn ch-btn--ghost">No me sirve</button></div>\n'
            '</article></div>')),
        "SparkMeter": ('<!-- @dsCard group="Contenido" height=180 -->', (
            '<div class="ch-pad ch-col">'
            f'<div class="ch-mline">{frag["mini-lit"]}<div><b>1 chispa para encender</b><span>Se recarga mañana a las 08:00</span></div>'
            f'<div class="x" aria-label="1 de 3 neuronas para la próxima extra">{frag["mini"]}{frag["mini-dim"]}{frag["mini-dim"]}</div></div>'
            f'<div class="ch-mline">{frag["mini-dim"]}<div><b>Usaste las chispas de hoy</b><span>Guardá 2 neuronas para ganar 1 extra</span></div></div>'
            '</div>')),
        "ConceptCard": ('<!-- @dsCard group="Contenido" height=260 -->', (
            '<div class="ch-pad"><ol class="ch-axon">'
            f'<li>{frag["mini"]}<div><span>Ingeniería</span><b>Separación ciclónica</b><p>Un flujo en espiral separa partículas por fuerza centrífuga, sin filtro.</p><span>De un artículo · hace 2 días</span></div></li>'
            f'<li>{frag["mini"]}<div><span>Marketing</span><b>Escasez intencional</b><p>Limitar la oferta sube el valor percibido y la atención de quien la recibe.</p><span>Nota de voz · hoy</span></div></li>'
            '</ol></div>')),
        "Synapse": ('<!-- @dsCard group="Identidad" height=120 -->', (
            '<div class="ch-pad" style="align-items:center;gap:var(--space-8)">'
            f'<div class="ch-col"><span class="ch-lbl">Encendida</span>{syn.replace("ch-syn", "ch-syn ch-syn--lg")}</div>'
            f'<div class="ch-col"><span class="ch-lbl">En espera</span>{syn_off.replace("ch-syn", "ch-syn ch-syn--lg")}</div>'
            '</div>')),
        "ImpulseLoader": ('<!-- @dsCard group="Identidad" height=120 -->', (
            f'<div class="ch-pad"><div class="ch-pulse" role="status">{frag["axon"]}<span>Destilando…</span></div></div>')),
        "NeuralIllustration": ('<!-- @dsCard group="Identidad" height=260 -->', (
            '<div class="ch-pad">'
            f'<div class="ch-empty">{frag["empty-vault"]}<b>Todavía no hay neuronas</b>'
            '<span>Guardá una frase, un link o una nota de voz para tener material que combinar.</span></div>'
            f'<div class="ch-empty">{frag["empty-spark"]}<b>Hoy no encontramos un buen par</b>'
            '<span>Guardá neuronas de otros temas. Las conexiones entre mundos distintos dan las mejores chispas.</span></div>'
            f'<div class="ch-empty">{frag["empty-offline"]}<b>Sin conexión</b><span>Revisá tu conexión y probá de nuevo.</span></div>'
            f'<div class="ch-empty">{frag["empty-circuits"]}<b>Todavía no hay circuitos</b>'
            '<span>Un circuito junta las ideas que querés llevar adelante.</span></div>'
            '</div>')),
        "LumbreMark": ('<!-- @dsCard group="Identidad" height=180 -->', (
            '<div class="ch-pad" style="align-items:center;gap:var(--space-8)">'
            f'<div class="ch-mark" style="width:220px">{frag["mark"]}</div>'
            f'<div class="ch-mark" style="width:110px">{frag["mark-compact"]}</div>'
            '</div>')),
    }
    icon = lambda k: frag[k].replace('class="n-active"', 'fill="currentColor"')
    perfil = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">'
              '<path d="M15.5 21v-3c2.4-.5 3.8-2.4 3.8-5 0-4.2-3.2-7.5-7.4-7.5C7.7 5.5 4.6 8.6 4.6 12.5c0 1.9.8 3.6 2 4.8V21"/>'
              '<circle cx="11.8" cy="11.6" r="1.6" fill="currentColor" stroke="none"/><path d="M11.8 11.6 9 9.2M11.8 11.6l3-2M11.8 11.6l.4 3.2"/></svg>')
    plus = '<svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 5v14M5 12h14"/></svg>'
    items = (f'<span class="ch-nav__i is-on">{icon("tab-hoy")}Hoy</span><span class="ch-nav__i">{icon("tab-red")}Red</span>'
             f'<span class="ch-nav__i">{icon("tab-circuitos")}Circuitos</span><span class="ch-nav__i">{perfil}Perfil</span>')
    stage = '<div class="ch-stage"><div class="ch-stage__bg"><div></div><div></div><div></div></div><div class="ch-float">'
    pages["NavBar"] = ('<!-- @dsCard group="Navegación" height=400 -->', (
        '<div class="ch-pad ch-col">\n<p class="ch-lbl">iOS: tab bar flotante de Liquid Glass + botón Capturar separado</p>\n'
        f'{stage}<nav class="ch-nav">{items}</nav><span class="ch-add">{plus}</span></div></div>\n'
        '<p class="ch-lbl" style="margin-top:8px">Android: barra flotante (M3 Expressive) + FAB separado</p>\n'
        f'{stage}<nav class="ch-nav ch-nav--md">{items}</nav><span class="ch-add ch-add--md">{plus}</span></div></div>\n</div>'))
    for name, (card, body) in pages.items():
        (comp / name).mkdir(exist_ok=True)
        write(comp / name / "preview.html", card + "\n" + head.format(t=name) + body + "</body></html>\n")


# ---------- SVG ----------

def svg(w, h, body, extra=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:g} {h:g}" width="{w:g}" height="{h:g}">{extra}{body}</svg>'


def star(cx, cy, size, cls="n-spark", fill=None):
    s = size / 24
    paint = f'fill="{fill}"' if fill else f'class="{cls}"'
    return f'<path {paint} transform="translate({cx - size / 2:.1f},{cy - size / 2:.1f}) scale({s:.3f})" d="{STAR}"/>'


def write(path, text):
    path.write_text(text)
    print("escrito", path.relative_to(ROOT.parent.parent))


def main():
    OUT.mkdir(exist_ok=True)
    long_g, long_c = neuron_long()
    comp_g, comp_c = neuron_compact()
    frag, art, extras = {}, {}, {}

    # Símbolo largo (logo) y compacto (ícono), sueltos.
    tx, ty, s = fit(long_g, (242, 131), 6)
    long_d = path_d(long_g, tx, ty, s)
    long_nucleus = ((long_c[0] + tx) * s, (long_c[1] + ty) * s)
    art["markLong"] = (242, 131, [("active", moved(long_g, tx, ty, s))])
    extras["markLongNucleus"] = f"CGPoint(x: {long_nucleus[0]:.1f}, y: {long_nucleus[1]:.1f})"
    write(LOGO / "lumbre-mark.svg", svg(242, 131, f'<path d="{long_d}" fill="{NEURON}"/>'))
    tx, ty, s = fit(comp_g, (100, 100), 4)
    comp_d = path_d(comp_g, tx, ty, s)
    comp_nucleus = ((comp_c[0] + tx) * s, (comp_c[1] + ty) * s)
    art["markCompact"] = (100, 100, [("active", moved(comp_g, tx, ty, s))])
    extras["markCompactNucleus"] = f"CGPoint(x: {comp_nucleus[0]:.1f}, y: {comp_nucleus[1]:.1f})"
    write(LOGO / "lumbre-mark-compacto.svg", svg(100, 100, f'<path d="{comp_d}" fill="{NEURON}"/>'))

    # Ícono de app: compacto negro al 78% sobre gris, núcleo spark. Monocromo para tinted y Android.
    k, off = 7.98, 113
    icon_body = (f'<rect width="1024" height="1024" fill="{GRAY}"/><g transform="translate({off},{off}) scale({k})">'
                 f'<path d="{comp_d}" fill="{NEURON}"/>'
                 f'<circle cx="{comp_nucleus[0]:.1f}" cy="{comp_nucleus[1]:.1f}" r="5.2" fill="{SPARK}"/></g>')
    write(LOGO / "lumbre-app-icon.svg", svg(1024, 1024, icon_body))
    write(LOGO / "lumbre-app-icon-mono.svg", svg(1024, 1024,
          f'<g transform="translate({off},{off}) scale({k})"><path d="{comp_d}" fill="#000"/></g>'))
    frag["icon"] = svg(1024, 1024, icon_body)

    # Wordmark: neurona + "Lumbre." en curvas.
    wm_glyphs, wm_width = wordmark("Lumbre.", 150, 405, 282)
    lw = round(405 + wm_width + 60)

    def lockup(bg, ink):
        return svg(lw, 460, f'<rect width="{lw}" height="460" fill="{bg}"/>'
                   f'<g transform="translate(50,141) scale(1.35)"><path d="{long_d}" fill="{ink}"/></g>'
                   + wordmark_svg(wm_glyphs, ink))

    solo, width = wordmark("Lumbre.", 100, 8, 100)
    write(LOGO / "lumbre-wordmark.svg", svg(round(width + 16), 128, wordmark_svg(solo, NEURON)))
    export_icons(comp_g, comp_c)
    write(LOGO / "lumbre-logo-dark.svg", lockup(GRAPHITE, BONE))
    write(LOGO / "lumbre-logo-light.svg", lockup(GRAY, NEURON))
    frag["lockup-dark"], frag["lockup-light"] = lockup(GRAPHITE, BONE), lockup(GRAY, NEURON)
    frag["mark"] = svg(242, 131, f'<path class="n-active" d="{long_d}"/>')
    frag["mark-compact"] = svg(100, 100, f'<path class="n-active" d="{comp_d}"/>')
    nuc = f'<circle class="n-spark" cx="{comp_nucleus[0]:.1f}" cy="{comp_nucleus[1]:.1f}" r="7"/>'
    frag["mini"] = svg(100, 100, f'<path class="n-active" d="{comp_d}"/>').replace("<svg ", '<svg class="mini" ', 1)
    frag["mini-lit"] = svg(100, 100, f'<path class="n-active" d="{comp_d}"/>{nuc}').replace("<svg ", '<svg class="mini" ', 1)
    frag["mini-dim"] = frag["mini"].replace('class="mini"', 'class="mini mini-dim"', 1)
    frag["mark-nucleus"] = svg(242, 131, f'<path class="n-active" d="{long_d}"/>'
                               f'<circle class="n-spark" cx="{long_nucleus[0]:.1f}" cy="{long_nucleus[1]:.1f}" r="8"/>')

    # Sinapsis: el conector de la chispa.
    sl, sr = synapse()
    syn = (f'<path class="n-active syn-l" d="{path_d(sl)}"/><path class="n-active syn-r" d="{path_d(sr)}"/>'
           + star(60, 20, 17, cls="n-spark syn-star"))
    write(OUT / "sinapsis.svg", svg(120, 40, syn, ILLU_STYLE))
    frag["synapse"] = svg(120, 40, syn)
    art["synapseLeft"], art["synapseRight"] = (120, 40, [("active", sl)]), (120, 40, [("active", sr)])
    # Sinapsis completa: dos neuronas enteras, simétricas, para los lugares grandes (la chispa, el reveal, compartir).
    # Las dos son el símbolo de la marca, enfrentadas: el axón de cada una apunta al hueco del medio.
    lx0, ly0, lx1, ly1 = long_g.bounds
    k_full = min(112 / (lx1 - lx0), 76 / (ly1 - ly0))
    full_l = affine_transform(long_g, [k_full, 0, 0, k_full, 2 - lx0 * k_full, 40 - (ly0 + ly1) / 2 * k_full])
    full_r = affine_transform(full_l, [-1, 0, 0, 1, 240, 0])
    art["synapseFullLeft"], art["synapseFullRight"] = (240, 80, [("active", full_l)]), (240, 80, [("active", full_r)])
    frag["synapse-full"] = svg(240, 80, f'<path class="n-active" d="{path_d(full_l)}"/><path class="n-active" d="{path_d(full_r)}"/>'
                                        + star(120, 40, 22))
    # Axón para el pulso de carga ("Destilando…"): el impulso viaja por la línea central.
    axon_line = [(6, 12), (40, 9), (80, 14), (114, 11)]
    axon = organic([taper(axon_line, 5, 4), Point(6, 12).buffer(4.5, 8), Point(114, 11).buffer(4.5, 8)], 1, 0.3)
    frag["axon"] = svg(120, 24, f'<path class="n-dormant" d="{path_d(axon)}"/>'
                       '<circle class="n-impulse" r="3.4"><animateMotion dur="1.2s" repeatCount="indefinite" '
                       'keyPoints="0;1" keyTimes="0;1" calcMode="spline" keySplines="0.45 0 0.55 1" '
                       'path="M6 12 L40 9 L80 14 L114 11"/></circle>')
    art["axon"] = (120, 24, [("dormant", axon)])
    extras["axonPath"] = "[" + ", ".join(f"CGPoint(x: {x}, y: {y})" for x, y in axon_line) + "]"
    frag["synapse-off"] = svg(120, 40, f'<path class="n-active" d="{path_d(sl)}"/><path class="n-active" d="{path_d(sr)}"/>')

    # Red horizontal (hero, onboarding) y vertical (splash, tarjeta para compartir).
    def net_svg(w, h, name=None, **kw):
        dormant, links, lit, mid = network(w, h, **kw)
        if name:
            art[name] = (w, h, [("link", links.simplify(1.2)), ("dormant", dormant.simplify(1.2))])
        body = f'<path class="n-link" d="{path_d(links)}"/><path class="n-dormant" d="{path_d(dormant)}"/>'
        if lit is not None:
            body += f'<path class="n-active" d="{path_d(lit)}"/>' + star(mid[0], mid[1], 26)
        return svg(w, h, body)

    frag["net-wide"] = net_svg(1200, 420, min_dist=110, seed=7, r=(8, 12), active=((560, 330), (940, 300)))
    # La red completa (splash, onboarding) y la de la tarjeta para compartir, con lugar abajo para el texto.
    frag["net-tall"] = net_svg(1080, 1920, name="networkTall", min_dist=210, seed=3, r=(15, 22))
    frag["net-share"] = net_svg(1080, 1920, min_dist=210, seed=3, r=(15, 22),
                                keep_out=[Polygon([(60, 900), (1020, 900), (1020, 1860), (60, 1860)])])
    frag["net-quiet"] = net_svg(390, 220, name="networkQuiet", min_dist=64, seed=11, r=(5, 8))
    write(OUT / "red-horizontal.svg", frag["net-wide"].replace(">", ">" + ILLU_STYLE, 1))
    write(OUT / "red-vertical.svg", frag["net-tall"].replace(">", ">" + ILLU_STYLE, 1))

    # Estados vacíos: 240×150.
    rng = random.Random(5)
    tx, ty, s = fit(comp_g, (100, 100), 0)
    ghosts = "".join(f'<circle class="n-dormant" cx="{x}" cy="{y}" r="{r}"/>' for x, y, r in
                     [(40, 40, 5), (200, 36, 6), (32, 118, 4), (206, 116, 5), (178, 16, 3), (62, 134, 3)])
    ghost_g = unary_union([Point(x, y).buffer(r, 12) for x, y, r in
                           [(40, 40, 5), (200, 36, 6), (32, 118, 4), (206, 116, 5), (178, 16, 3), (62, 134, 3)]])
    art["emptyVault"] = (240, 150, [("dormant", ghost_g),
                                    ("active", affine_transform(moved(comp_g, tx, ty, s), [0.84, 0, 0, 0.84, 78, 33]))])
    frag["empty-vault"] = svg(240, 150, ghosts + f'<g transform="translate(78,33) scale(0.84)">'
                                                 f'<path class="n-active" d="{path_d(comp_g, tx, ty, s)}"/></g>')

    a = hero_neuron(rng, (42, 74), 13, (96, 70))
    b = hero_neuron(rng, (198, 78), 13, (144, 82))
    frag["empty-spark"] = svg(240, 150, f'<path class="n-active" d="{path_d(a)}"/><path class="n-active" d="{path_d(b)}"/>'
                                         '<path class="n-trace" d="M110 75 L130 77"/>')
    dots = unary_union([Point(110 + i * 6.7, 75 + i * 0.67).buffer(1.1, 8) for i in range(4)])
    art["beforeSpark"] = (240, 150, [("active", unary_union([a, b])), ("trace", dots)])

    cut_l = hero_neuron(rng, (44, 78), 13, (108, 70), fork=False)
    cut_r = organic([taper([(132, 70), (164, 76), (190, 72)], 5.4, 5), taper([(190, 72), (202, 62)], 4.6, 4),
                     taper([(190, 72), (205, 74)], 4.6, 4), taper([(190, 72), (201, 84)], 4.6, 4),
                     Point(202, 62).buffer(3.9), Point(205, 74).buffer(3.9), Point(201, 84).buffer(3.9)], 1.2, 0.5)
    frag["empty-offline"] = svg(240, 150, f'<path class="n-active" d="{path_d(cut_l)}"/>'
                                          f'<path class="n-dormant" d="{path_d(cut_r)}"/>'
                                          '<path class="n-cut" d="M114 65 L126 77 M114 77 L126 65"/>')
    cross = unary_union([LineString([(114, 65), (126, 77)]).buffer(1.25), LineString([(114, 77), (126, 65)]).buffer(1.25)])
    art["offline"] = (240, 150, [("active", cut_l), ("dormant", cut_r), ("trace", cross)])
    # Sin circuitos: tres neuronas; dos conexiones hechas y la tercera todavía punteada.
    na, nb, nc = (58, 48), (182, 52), (120, 116)
    tri = organic([small_neuron(rng, na, 11), small_neuron(rng, nb, 11), small_neuron(rng, nc, 11),
                   taper([na, (120, 44), nb], 4.4, 3.2), taper([nb, (156, 90), nc], 4.4, 3.2)], 1.4, 0.5)
    gap = unary_union([Point(na[0] + (nc[0] - na[0]) * t, na[1] + (nc[1] - na[1]) * t).buffer(1.2, 8)
                       for t in (0.3, 0.4, 0.5, 0.6, 0.7)])
    frag["empty-circuits"] = svg(240, 150, f'<path class="n-active" d="{path_d(tri)}"/><path class="n-trace" '
                                           f'd="M{na[0] + (nc[0] - na[0]) * 0.25:.1f} {na[1] + (nc[1] - na[1]) * 0.25:.1f} '
                                           f'L{na[0] + (nc[0] - na[0]) * 0.75:.1f} {na[1] + (nc[1] - na[1]) * 0.75:.1f}"/>')
    art["emptyCircuits"] = (240, 150, [("active", tri), ("trace", gap)])

    for key, name in [("empty-circuits", "estado-sin-circuitos"), ("empty-vault", "estado-boveda-vacia"), ("empty-spark", "estado-sin-chispa"),
                      ("empty-offline", "estado-sin-conexion")]:
        write(OUT / f"{name}.svg", frag[key].replace(">", ">" + ILLU_STYLE, 1))

    write_swift(art, extras)
    for name, preview in export_tab_icons().items():
        frag[name] = preview
    write_previews(frag)

    # Página de identidad.
    page = (OUT / "plantilla.html").read_text()
    page = re.sub(r"\{\{([a-z-]+)\}\}", lambda m: frag[m.group(1)], page)
    write(ROOT / "identidad.html", page)


if __name__ == "__main__":
    main()
