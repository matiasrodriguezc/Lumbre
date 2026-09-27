#!/usr/bin/env python3
"""Genera los tokens de LumbreDesign desde design/system/tokens.json.

Salida:
- Colors.xcassets con una variante clara y una oscura por token.
- Tokens.generated.swift con colores, espaciado, radios, sombras y estilos display.

Uso: python3 ios/scripts/generate_tokens.py
"""
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOKENS = ROOT / "design/system/tokens.json"
PACKAGE = ROOT / "ios/Packages/LumbreDesign/Sources/LumbreDesign"
ASSETS = PACKAGE / "Resources/Colors.xcassets"
SWIFT = PACKAGE / "Generated/Tokens.generated.swift"

HEADER = "// Generado por ios/scripts/generate_tokens.py desde design/system/tokens.json. No editar a mano.\n"


def camel(name):
    head, *rest = re.split(r"[-_]", name)
    return head + "".join(part.capitalize() for part in rest)


def px(value):
    return float(value.replace("px", ""))


def parse_color(value):
    """Devuelve (r, g, b, a) en 0–1 desde #RRGGBB o rgba()."""
    value = value.strip()
    if value.startswith("#"):
        h = value[1:]
        return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (1.0,)
    m = re.match(r"rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)", value)
    if not m:
        raise ValueError("Color no soportado: " + value)
    r, g, b, a = m.groups()
    return (int(r) / 255, int(g) / 255, int(b) / 255, float(a))


def resolve_colors(tokens):
    raw = {t["name"]: t["value"] for t in tokens}

    def resolve(value, theme):
        if isinstance(value, dict):
            value = value[theme]
        ref = re.fullmatch(r"\{(.+)\}", value)
        return resolve(raw[ref.group(1)], theme) if ref else value

    return {
        name: {theme: parse_color(resolve(value, theme)) for theme in ("light", "dark")}
        for name, value in raw.items()
    }


def colorset(rgba_by_theme):
    def entry(rgba):
        r, g, b, a = rgba
        return {
            "color-space": "srgb",
            "components": {
                "red": "%.3f" % r, "green": "%.3f" % g, "blue": "%.3f" % b, "alpha": "%.3f" % a,
            },
        }

    return {
        "colors": [
            {"color": entry(rgba_by_theme["light"]), "idiom": "universal"},
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "color": entry(rgba_by_theme["dark"]),
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }


def parse_shadow_layers(value):
    if value == "none":
        return []
    layers = []
    for part in re.split(r",\s*(?![^()]*\))", value):
        m = re.match(r"\s*(-?\d+)(?:px)?\s+(-?\d+)(?:px)?\s+(\d+)(?:px)?\s+(rgba\(.+\))", part)
        if not m:
            raise ValueError("Sombra no soportada: " + part)
        x, y, blur, color = m.groups()
        layers.append((float(x), float(y), float(blur), parse_color(color)))
    return layers


def swift_layers(layers):
    items = []
    for x, y, blur, (r, g, b, a) in layers:
        items.append(
            "ShadowLayer(color: Color(.sRGB, red: %.3f, green: %.3f, blue: %.3f, opacity: %.2f), "
            "radius: %g, x: %g, y: %g)" % (r, g, b, a, blur / 2, x, y)
        )
    return "[" + ", ".join(items) + "]"


def main():
    data = json.loads(TOKENS.read_text(encoding="utf-8"))
    colors = resolve_colors(data["color"]["tokens"])

    if ASSETS.exists():
        shutil.rmtree(ASSETS)
    ASSETS.mkdir(parents=True)
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    for name, rgba in colors.items():
        folder = ASSETS / (name + ".colorset")
        folder.mkdir()
        (folder / "Contents.json").write_text(json.dumps(colorset(rgba), indent=2) + "\n")

    usage = {t["name"]: t.get("usage", "") for t in data["color"]["tokens"]}
    lines = [HEADER, "import SwiftUI", "", "/// Colores de marca y semánticos. Cambian solos entre el tema claro y el oscuro.",
             "public enum Palette {"]
    for name in colors:
        lines.append("    /// " + usage[name])
        lines.append('    public static let %s = Color("%s", bundle: .module)' % (camel(name), name))
    lines.append("}")
    lines.append("")
    lines.append("/// Nombres de los colores en el catálogo, para UIKit.")
    lines.append("public enum PaletteName {")
    for name in colors:
        lines.append('    public static let %s = "%s"' % (camel(name), name))
    lines.append("}")

    lines += ["", "/// Grilla de 4 pt.", "public enum Space {"]
    for t in data["spacing"]["tokens"]:
        lines.append("    public static let s%s: CGFloat = %g" % (t["name"].split("-")[1], px(t["value"])))
    lines.append("}")

    lines += ["", "public enum Radius {"]
    for t in data["radius"]["tokens"]:
        lines.append("    public static let %s: CGFloat = %g" % (t["name"].split("-")[1], px(t["value"])))
    lines.append("}")

    lines += ["", "public enum ShadowToken: Sendable {"]
    shadows = data["shadow"]["tokens"]
    for t in shadows:
        lines.append("    case %s" % camel(t["name"]))
    lines += ["", "    public func layers(for scheme: ColorScheme) -> [ShadowLayer] {", "        switch (self, scheme) {"]
    for t in shadows:
        for theme, scheme in (("dark", ".dark"), ("light", ".light")):
            layers = parse_shadow_layers(t["value"][theme])
            lines.append("        case (.%s, %s): return %s" % (camel(t["name"]), scheme, swift_layers(layers)))
    lines += ["        default: return []", "        }", "    }", "}"]

    display = next(g for g in data["type"]["groups"] if g["name"].startswith("Display"))
    lines += ["", "/// Estilos de marca en Fraunces. Solo para 20 pt o más.", "public enum DisplayStyle: CaseIterable, Sendable {"]
    for s in display["styles"]:
        lines.append("    case %s" % camel(s["name"]))
    for prop, key in (("size", "fontSize"), ("lineHeight", "lineHeight")):
        lines += ["", "    public var %s: CGFloat {" % prop, "        switch self {"]
        for s in display["styles"]:
            lines.append("        case .%s: return %g" % (camel(s["name"]), px(s[key])))
        lines += ["        }", "    }"]
    lines += ["", "    public var weight: CGFloat {", "        switch self {"]
    for s in display["styles"]:
        lines.append("        case .%s: return %d" % (camel(s["name"]), s["fontWeight"]))
    lines += ["        }", "    }", "}", ""]

    SWIFT.parent.mkdir(parents=True, exist_ok=True)
    SWIFT.write_text("\n".join(lines), encoding="utf-8")
    print("Generados %d colores en %s" % (len(colors), ASSETS.relative_to(ROOT)))
    print("Generado %s" % SWIFT.relative_to(ROOT))


if __name__ == "__main__":
    main()
