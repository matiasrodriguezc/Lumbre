#!/usr/bin/env python3
"""Exporta design/system/tokens.json como variables de Figma.

Genera dos caminos de importación desde la misma fuente:

1. variables/*.tokens.json: un archivo por colección y modo, en el formato de Design Tokens (DTCG)
   que usa la importación nativa de Figma (panel Variables > Importar).
2. plugin/: un plugin de desarrollo ("Lumbre tokens") que crea o actualiza las colecciones, los modos,
   las variables (con alcance, descripción y sintaxis de código), los estilos de texto y los de efecto.
   Es el camino recomendado: no depende de la versión del importador y se puede volver a correr.

    python3 design/figma/generar_variables.py          # regenera todo
    python3 design/figma/generar_variables.py --check  # falla si lo generado no coincide con tokens.json

Nunca edites a mano lo generado: cambiá tokens.json y volvé a correr este script.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
TOKENS = ROOT / "design" / "system" / "tokens.json"
OUT_VARS = HERE / "variables"
OUT_PLUGIN = HERE / "plugin"

# Modos del tema: el gris es el default (primer modo de la colección).
THEME_MODES = [("light", "Gris"), ("dark", "Grafito")]
PLATFORM_MODES = ["iOS", "Android"]

# Grupo de cada color en Figma (el nombre de la variable queda "grupo/token", igual que el token de CSS).
COLOR_GROUPS = {
    "neuron": "marca", "gray": "marca", "graphite": "marca", "bone": "marca", "spark": "marca",
    "bg": "superficie", "surface": "superficie", "surface-alt": "superficie", "scrim": "superficie",
    "ink": "texto", "ink-muted": "texto", "info-text": "texto", "accent-text": "texto", "pro-text": "texto",
    "border": "borde", "border-strong": "borde", "focus-ring": "borde",
    "accent": "accion", "on-accent": "accion", "accent-soft": "accion", "pro": "accion", "on-pro": "accion",
    "success": "estado", "warning": "estado", "danger": "estado",
}

# Dónde se puede usar cada color en Figma. Codifica las reglas de design/system/README.md:
# el rosa nunca es texto ni relleno de marco (solo formas: núcleo, punto, estrella).
FILLS = ["FRAME_FILL", "SHAPE_FILL"]
INK = ["TEXT_FILL", "SHAPE_FILL", "STROKE_COLOR"]
COLOR_SCOPES = {
    "neuron": ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL", "STROKE_COLOR"],
    "gray": FILLS, "graphite": FILLS,
    "bone": ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL", "STROKE_COLOR"],
    "spark": ["SHAPE_FILL", "EFFECT_COLOR"],
    "bg": FILLS, "surface": FILLS, "surface-alt": FILLS + ["STROKE_COLOR"], "scrim": FILLS,
    "ink": INK, "ink-muted": INK, "info-text": INK, "accent-text": ["TEXT_FILL"], "pro-text": ["TEXT_FILL"],
    "border": ["STROKE_COLOR", "SHAPE_FILL"], "border-strong": ["STROKE_COLOR", "SHAPE_FILL"], "focus-ring": ["STROKE_COLOR"],
    "accent": FILLS, "on-accent": INK, "accent-soft": FILLS, "pro": FILLS, "on-pro": INK,
    "success": INK, "warning": INK, "danger": INK,
}

# Nombre en el código de iOS (Palette en LumbreDesign).
def swift_name(token: str) -> str:
    head, *rest = token.split("-")
    return head + "".join(p.capitalize() for p in rest)


def parse_color(value: str) -> dict:
    value = value.strip()
    m = re.fullmatch(r"#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?", value)
    if m:
        h = m.group(1)
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
        a = int(m.group(2), 16) / 255 if m.group(2) else 1.0
        return {"r": r, "g": g, "b": b, "a": a}
    m = re.fullmatch(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)", value)
    if m:
        r, g, b = (int(m.group(i)) / 255 for i in (1, 2, 3))
        return {"r": r, "g": g, "b": b, "a": float(m.group(4) or 1)}
    raise ValueError(f"Color que no sé leer: {value}")


def hex_of(c: dict) -> str:
    h = "#" + "".join(f"{round(c[k] * 255):02X}" for k in "rgb")
    return h + (f"{round(c['a'] * 255):02X}" if c["a"] < 1 else "")


def parse_shadows(value: str) -> list[dict]:
    if value.strip() == "none":
        return []
    out = []
    for part in re.split(r",(?![^(]*\))", value):
        m = re.fullmatch(r"\s*(-?[\d.]+)(?:px)?\s+(-?[\d.]+)(?:px)?\s+([\d.]+)(?:px)?\s+(rgba?\([^)]*\)|#[0-9a-fA-F]+)\s*", part)
        if not m:
            raise ValueError(f"Sombra que no sé leer: {part}")
        out.append({"x": float(m.group(1)), "y": float(m.group(2)), "blur": float(m.group(3)), "color": parse_color(m.group(4))})
    return out


def px(value: str) -> float:
    return float(value.replace("px", ""))


def load_model() -> dict:
    t = json.loads(TOKENS.read_text(encoding="utf-8"))
    colors = []
    for tok in t["color"]["tokens"]:
        v = tok["value"]
        name = tok["name"]
        entry = {
            "name": f"{COLOR_GROUPS[name]}/{name}",
            "token": name,
            "description": tok.get("usage", ""),
            "scopes": COLOR_SCOPES[name],
            "web": f"var(--{name})",
            "ios": f"Palette.{swift_name(name)}",
        }
        if isinstance(v, dict):
            entry["values"] = {mode: parse_color(v[key]) for key, mode in THEME_MODES}
        elif isinstance(v, str) and v.startswith("{"):
            target = v.strip("{}")
            entry["alias"] = f"{COLOR_GROUPS[target]}/{target}"
        else:
            c = parse_color(v)
            entry["values"] = {mode: c for _, mode in THEME_MODES}
        colors.append(entry)

    floats = []
    for tok in t["spacing"]["tokens"]:
        floats.append({"collection": "Espaciado", "name": f"espacio/{tok['name']}", "token": tok["name"], "value": px(tok["value"]),
                       "description": tok.get("usage", ""), "scopes": ["GAP", "WIDTH_HEIGHT"],
                       "web": f"var(--{tok['name']})", "ios": f"Space.s{tok['name'].split('-')[1]}"})
    for tok in t["radius"]["tokens"]:
        floats.append({"collection": "Espaciado", "name": f"radio/{tok['name']}", "token": tok["name"], "value": px(tok["value"]),
                       "description": tok.get("usage", ""), "scopes": ["CORNER_RADIUS"],
                       "web": f"var(--{tok['name']})", "ios": f"Radius.{tok['name'].split('-')[1]}"})

    # Tipografía: modos iOS y Android. Android usa Roboto Flex y body a 16 sp (ver tokens.json, uso de body).
    type_vars = []
    text_styles = []
    families = {
        "display": {"iOS": "Fraunces", "Android": "Fraunces"},
        "text": {"iOS": "SF Pro Text", "Android": "Roboto Flex"},
    }
    for fam, per_mode in families.items():
        type_vars.append({"name": f"familia/{fam}", "type": "STRING", "values": per_mode, "scopes": ["FONT_FAMILY"],
                          "description": "Fraunces solo para marca y títulos de 20 pt o más." if fam == "display" else "Fuente del sistema para todo lo demás."})
    for group in t["type"]["groups"]:
        for st in group["styles"]:
            size, line = px(st["fontSize"]), px(st["lineHeight"])
            android_size, android_line = (16.0, 24.0) if st["name"] == "body" else (size, line)
            for prop, vals, scope in (("tamano", (size, android_size), "FONT_SIZE"), ("interlineado", (line, android_line), "LINE_HEIGHT")):
                type_vars.append({"name": f"texto/{st['name']}/{prop}", "type": "FLOAT", "scopes": [scope],
                                  "values": {"iOS": vals[0], "Android": vals[1]}, "description": st.get("usage", "")})
            ls = st.get("letterSpacing")
            ls_pct = float(ls.replace("em", "")) * 100 if ls else 0.0
            for mode in PLATFORM_MODES:
                fam_key = group["family"]
                family = families[fam_key][mode]
                weight = st["fontWeight"]
                text_styles.append({
                    "name": f"{mode}/{st['name']}",
                    "family": family,
                    "style": font_style(family, weight),
                    "size": size if mode == "iOS" else android_size,
                    "lineHeight": line if mode == "iOS" else android_line,
                    "letterSpacing": ls_pct,
                    "description": st.get("usage", "") + (f" Muestra: {st['sample']}" if st.get("sample") else ""),
                    "tabular": st["name"] == "counter",
                })

    effects = []
    for tok in t["shadow"]["tokens"]:
        for key, mode in THEME_MODES:
            raw = tok["value"][key] if isinstance(tok["value"], dict) else tok["value"]
            shadows = parse_shadows(raw)
            if shadows:
                effects.append({"name": f"{tok['name']}/{mode}", "shadows": shadows, "description": tok.get("usage", "")})

    return {"colors": colors, "floats": floats, "typeVars": type_vars, "textStyles": text_styles, "effects": effects}


def font_style(family: str, weight: int) -> str:
    names = {400: "Regular", 500: "Medium", 600: "Semibold", 700: "Bold"}
    style = names[weight]
    # Fraunces y Roboto Flex en Google Fonts escriben "SemiBold"; SF Pro, "Semibold".
    if family in ("Fraunces", "Roboto Flex") and weight == 600:
        style = "SemiBold"
    return style


# ---------- DTCG ----------

def dtcg_color(c: dict) -> dict:
    return {"colorSpace": "srgb", "components": [round(c["r"], 5), round(c["g"], 5), round(c["b"], 5)],
            "alpha": round(c["a"], 4), "hex": hex_of(c)[:7]}


def nest(tree: dict, path: str, leaf: dict) -> None:
    parts = path.split("/")
    for p in parts[:-1]:
        tree = tree.setdefault(p, {})
    tree[parts[-1]] = leaf


def build_dtcg(model: dict) -> dict[str, dict]:
    files: dict[str, dict] = {}
    for _, mode in THEME_MODES:
        tree: dict = {}
        for c in model["colors"]:
            value = "{" + c["alias"].replace("/", ".") + "}" if "alias" in c else dtcg_color(c["values"][mode])
            nest(tree, c["name"], {"$type": "color", "$value": value, "$description": c["description"],
                                   "$extensions": {"com.figma.scopes": c["scopes"],
                                                   "com.figma.codeSyntax": {"WEB": c["web"], "iOS": c["ios"]}}})
        files[f"Color.{mode}.tokens.json"] = tree
    tree = {}
    for f in model["floats"]:
        nest(tree, f["name"], {"$type": "number", "$value": f["value"], "$description": f["description"],
                               "$extensions": {"com.figma.scopes": f["scopes"],
                                               "com.figma.codeSyntax": {"WEB": f["web"], "iOS": f["ios"]}}})
    files["Espaciado.Valor.tokens.json"] = tree
    for mode in PLATFORM_MODES:
        tree = {}
        for v in model["typeVars"]:
            typ = "string" if v["type"] == "STRING" else "number"
            nest(tree, v["name"], {"$type": typ, "$value": v["values"][mode], "$description": v["description"],
                                   "$extensions": {"com.figma.scopes": v["scopes"]}})
        files[f"Tipografia.{mode}.tokens.json"] = tree
    return files


# ---------- Plugin ----------

PLUGIN_CODE = r"""// Lumbre tokens: crea o actualiza las variables y estilos de Lumbre en este archivo de Figma.
// Generado por design/figma/generar_variables.py desde design/system/tokens.json. No editar a mano.
const DATA = __DATA__;

const THEME_MODES = ["Gris", "Grafito"];
const PLATFORM_MODES = ["iOS", "Android"];
const report = { created: 0, updated: 0, textStyles: 0, effectStyles: 0, missingFonts: [] };

async function collection(name, modes) {
  const all = await figma.variables.getLocalVariableCollectionsAsync();
  let c = all.find((x) => x.name === name);
  if (!c) c = figma.variables.createVariableCollection(name);
  const ids = {};
  modes.forEach((mode, i) => {
    let m = c.modes.find((x) => x.name === mode);
    if (!m && i === 0) { c.renameMode(c.modes[0].modeId, mode); m = c.modes[0]; }
    if (!m) { const id = c.addMode(mode); m = { modeId: id, name: mode }; }
    ids[mode] = m.modeId;
  });
  return { c, ids };
}

async function variable(name, coll, type) {
  const all = await figma.variables.getLocalVariablesAsync(type);
  let v = all.find((x) => x.name === name && x.variableCollectionId === coll.id);
  if (v) { report.updated++; return v; }
  report.created++;
  return figma.variables.createVariable(name, coll, type);
}

function codeSyntax(v, item) {
  if (item.web) v.setVariableCodeSyntax("WEB", item.web);
  if (item.ios) v.setVariableCodeSyntax("iOS", item.ios);
}

// Si falta la fuente, prueba la familia hermana y después Inter (y lo avisa al cerrar).
const ALTERNATES = { "SF Pro Text": ["SF Pro"], "Roboto Flex": ["Roboto"], "Fraunces": [] };
async function loadFont(family, style) {
  const styles = (s) => [s, s.replace("SemiBold", "Semibold"), s.replace("Semibold", "SemiBold"), s.replace(/Semi ?[Bb]old/, "Semi Bold")];
  for (const fam of [family, ...(ALTERNATES[family] || [])]) {
    for (const st of [...new Set(styles(style))]) {
      try { await figma.loadFontAsync({ family: fam, style: st }); if (fam !== family) report.missingFonts.push(family + " (se usó " + fam + ")"); return { family: fam, style: st }; }
      catch (e) { /* sigue probando */ }
    }
  }
  report.missingFonts.push(family + " " + style + " (se usó Inter)");
  for (const st of [...new Set(styles(style))]) {
    try { await figma.loadFontAsync({ family: "Inter", style: st }); return { family: "Inter", style: st }; } catch (e) { /* sigue */ }
  }
  await figma.loadFontAsync({ family: "Inter", style: "Regular" });
  return { family: "Inter", style: "Regular" };
}

async function run() {
  // Color: modos Gris (default) y Grafito.
  const color = await collection("Color", THEME_MODES);
  const byName = {};
  for (const item of DATA.colors.filter((x) => !x.alias)) {
    const v = await variable(item.name, color.c, "COLOR");
    for (const mode of THEME_MODES) v.setValueForMode(color.ids[mode], item.values[mode]);
    v.description = item.description; v.scopes = item.scopes; codeSyntax(v, item);
    byName[item.name] = v;
  }
  for (const item of DATA.colors.filter((x) => x.alias)) {
    const v = await variable(item.name, color.c, "COLOR");
    const target = byName[item.alias];
    for (const mode of THEME_MODES) v.setValueForMode(color.ids[mode], figma.variables.createVariableAlias(target));
    v.description = item.description; v.scopes = item.scopes; codeSyntax(v, item);
  }

  // Espaciado y radios: un solo modo.
  const space = await collection("Espaciado", ["Valor"]);
  for (const item of DATA.floats) {
    const v = await variable(item.name, space.c, "FLOAT");
    v.setValueForMode(space.ids["Valor"], item.value);
    v.description = item.description; v.scopes = item.scopes; codeSyntax(v, item);
  }

  // Tipografía: modos iOS y Android.
  const type = await collection("Tipografía", PLATFORM_MODES);
  for (const item of DATA.typeVars) {
    const v = await variable(item.name, type.c, item.type);
    for (const mode of PLATFORM_MODES) v.setValueForMode(type.ids[mode], item.values[mode]);
    v.description = item.description; v.scopes = item.scopes;
  }

  // Estilos de texto, uno por plataforma (iOS/… y Android/…).
  const textStyles = await figma.getLocalTextStylesAsync();
  for (const s of DATA.textStyles) {
    const font = await loadFont(s.family, s.style);
    let st = textStyles.find((x) => x.name === s.name);
    if (!st) { st = figma.createTextStyle(); st.name = s.name; }
    st.fontName = font;
    st.fontSize = s.size;
    st.lineHeight = { unit: "PIXELS", value: s.lineHeight };
    st.letterSpacing = { unit: "PERCENT", value: s.letterSpacing };
    st.description = s.description;
    report.textStyles++;
  }

  // Estilos de efecto: glow-spark y elev-card por tema.
  const effectStyles = await figma.getLocalEffectStylesAsync();
  for (const e of DATA.effects) {
    let st = effectStyles.find((x) => x.name === e.name);
    if (!st) { st = figma.createEffectStyle(); st.name = e.name; }
    st.effects = e.shadows.map((s) => ({
      type: "DROP_SHADOW", color: s.color, offset: { x: s.x, y: s.y }, radius: s.blur, spread: 0,
      visible: true, blendMode: "NORMAL", showShadowBehindNode: false,
    }));
    st.description = e.description;
    report.effectStyles++;
  }
}

run().then(() => {
  const fonts = report.missingFonts.length ? ` Fuentes faltantes: ${[...new Set(report.missingFonts)].join(", ")}.` : "";
  figma.closePlugin(`Lumbre: ${report.created} variables nuevas, ${report.updated} actualizadas, ${report.textStyles} estilos de texto y ${report.effectStyles} de efecto.${fonts}`);
}).catch((e) => figma.closePlugin("Lumbre: no se pudo importar. " + (e && e.message ? e.message : e)));
"""

MANIFEST = {
    "name": "Lumbre tokens",
    "id": "lumbre-tokens-dev",
    "api": "1.0.0",
    "main": "code.js",
    "editorType": ["figma"],
    "documentAccess": "dynamic-page",
    "networkAccess": {"allowedDomains": ["none"]},
}


def build_plugin(model: dict) -> dict[str, str]:
    data = {
        "colors": [{k: v for k, v in c.items() if k != "token"} for c in model["colors"]],
        "floats": [{k: v for k, v in f.items() if k not in ("collection", "token")} for f in model["floats"]],
        "typeVars": model["typeVars"],
        "textStyles": model["textStyles"],
        "effects": model["effects"],
    }
    code = PLUGIN_CODE.replace("__DATA__", json.dumps(data, ensure_ascii=False, indent=1))
    return {"code.js": code, "manifest.json": json.dumps(MANIFEST, indent=2, ensure_ascii=False) + "\n"}


def main() -> int:
    check = "--check" in sys.argv
    model = load_model()
    outputs: dict[Path, str] = {}
    for name, tree in build_dtcg(model).items():
        outputs[OUT_VARS / name] = json.dumps(tree, ensure_ascii=False, indent=2) + "\n"
    for name, text in build_plugin(model).items():
        outputs[OUT_PLUGIN / name] = text

    stale = [p for p, text in outputs.items() if not p.exists() or p.read_text(encoding="utf-8") != text]
    if check:
        for p in stale:
            print(f"desactualizado: {p.relative_to(ROOT)}")
        return 1 if stale else 0
    for p, text in outputs.items():
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    n_colors = len(model["colors"])
    print(f"{n_colors} colores × 2 modos, {len(model['floats'])} medidas, {len(model['typeVars'])} variables de tipografía × 2 modos, "
          f"{len(model['textStyles'])} estilos de texto, {len(model['effects'])} de efecto. {len(stale)} archivos cambiaron.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
