#!/usr/bin/env python3
"""Copy de Lumbre: valida copy.json y lo vuelca al String Catalog de iOS y a strings.xml de Android.

    python3 design/copy/copy.py validar                 # claves únicas, placeholders iguales en es y en
    python3 design/copy/copy.py xcstrings               # → design/copy/build/ios/Localizable.xcstrings
    python3 design/copy/copy.py xcstrings --out ios/Lumbre/Resources/Localizable.xcstrings
                                                        #   (mezcla: conserva claves y traducciones que ya estén)
    python3 design/copy/copy.py android                 # → design/copy/build/android/values{,-en}/strings.xml
    python3 design/copy/copy.py android --out android/app/src/main/res
    python3 design/copy/copy.py revisar-ios             # compara copy.json con los literales de los .swift
    python3 design/copy/copy.py csv                     # → design/copy/build/copy.csv (para revisar en una planilla)
    python3 design/copy/copy.py formatear               # reescribe copy.json con un texto por línea
    python3 design/copy/copy.py todo                    # validar + xcstrings + android + csv (a build/)

Reglas del archivo: ver design/copy/README.md. Solo librería estándar (Python 3.9+).
"""
from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape as xml_escape

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = HERE / "copy.json"
BUILD = HERE / "build"
LANGS = ("es", "en")

SPEC = re.compile(r"%(?:(\d+)\$)?(lld|ld|d|@|s|f)")
INFLECT = re.compile(r"\^\[(.*?)\]\(inflect: true\)")


# ---------- Carga y validación ----------

def load() -> dict:
    return json.loads(SOURCE.read_text(encoding="utf-8"))


def entries(data: dict):
    for screen in data["screens"]:
        for e in screen["strings"]:
            yield screen, e


def spec_types(text: str) -> list[str]:
    """Tipos de los argumentos en orden de posición: ['int', 'obj', ...]."""
    found = []
    auto = 0
    for m in SPEC.finditer(text.replace("%%", "")):
        pos = int(m.group(1)) if m.group(1) else (auto := auto + 1)
        kind = "obj" if m.group(2) in ("@", "s") else ("float" if m.group(2) == "f" else "int")
        found.append((pos, kind))
    return [k for _, k in sorted(found)]


def is_ios(e: dict) -> bool:
    return e.get("platform") != "android"


def is_android(e: dict) -> bool:
    return e.get("platform") != "ios"


def validate(data: dict) -> list[str]:
    errors = []
    ids, keys = {}, {}
    for screen, e in entries(data):
        sid = e.get("id", "?")
        for field in ("id", "es", "en"):
            if not e.get(field):
                errors.append(f"{sid}: falta '{field}'")
        if sid in ids:
            errors.append(f"{sid}: id repetido")
        ids[sid] = screen["id"]
        if not sid.startswith(screen["id"] + "."):
            errors.append(f"{sid}: el id tiene que empezar con '{screen['id']}.'")
        if not re.fullmatch(r"[a-z0-9_]+(\.[a-z0-9_]+)+", sid):
            errors.append(f"{sid}: id con caracteres inválidos (minúsculas, números, _ y .)")
        if is_ios(e):
            if e["es"] in keys:
                errors.append(f"{sid}: el texto es igual al de {keys[e['es']]} (en iOS la clave es el texto: dejá uno solo, en 'comun' si se repite)")
            keys[e["es"]] = sid
        if spec_types(e["es"]) != spec_types(e["en"]):
            errors.append(f"{sid}: placeholders distintos entre es y en")
        for lang in LANGS:
            override = e.get("android", {}).get(lang)
            if override and spec_types(override) != spec_types(e[lang]):
                errors.append(f"{sid}: el reemplazo de Android ({lang}) cambia los placeholders")
            plural = e.get("plural", {}).get(lang)
            if plural and set(plural) - {"zero", "one", "two", "few", "many", "other"}:
                errors.append(f"{sid}: plural con cantidades inválidas")
            if plural and "other" not in plural:
                errors.append(f"{sid}: plural sin 'other'")
            text = e.get(lang, "")
            if "  " in text or text != text.lstrip():
                errors.append(f"{sid} ({lang}): espacios de más")
        if e.get("status", "app") not in ("app", "nuevo"):
            errors.append(f"{sid}: status tiene que ser 'app' o 'nuevo'")
        if e.get("platform") not in (None, "ios", "android"):
            errors.append(f"{sid}: platform tiene que ser 'ios' o 'android'")
    return errors


# ---------- iOS: String Catalog ----------

def build_xcstrings(data: dict, existing: dict | None = None) -> dict:
    catalog = existing or {"sourceLanguage": "es", "strings": {}, "version": "1.0"}
    catalog.setdefault("strings", {})
    for _, e in entries(data):
        if not is_ios(e):
            continue
        key = e["es"]
        item = catalog["strings"].get(key, {})
        comment = e.get("note", "").strip()
        item["comment"] = (comment + " " if comment else "") + f"[{e['id']}]"
        locs = item.setdefault("localizations", {})
        locs["en"] = {"stringUnit": {"state": "translated", "value": e["en"]}}
        catalog["strings"][key] = item
    return catalog


def dump_xcstrings(catalog: dict) -> str:
    # Mismo estilo que escribe Xcode: claves ordenadas y " : ".
    return json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : ")) + "\n"


# ---------- Android: strings.xml ----------

def android_format(text: str) -> str:
    """%lld → %d, %@ → %s; con más de un argumento, posicionales (%1$d)."""
    text = INFLECT.sub(r"\1", text)
    count = len(spec_types(text))
    auto = 0

    def repl(m):
        nonlocal auto
        kind = {"@": "s", "s": "s", "f": "f"}.get(m.group(2), "d")
        if m.group(1):
            return f"%{m.group(1)}${kind}"
        auto += 1
        return f"%{auto}${kind}" if count > 1 else f"%{kind}"

    return SPEC.sub(repl, text)


def android_escape(text: str) -> str:
    text = xml_escape(text)
    text = text.replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"').replace("\n", "\\n")
    if text[:1] in ("@", "?"):
        text = "\\" + text
    return text


def android_name(sid: str) -> str:
    return sid.replace(".", "_")


def build_android(data: dict, lang: str) -> str:
    lines = ['<?xml version="1.0" encoding="utf-8"?>',
             f"<!-- Generado por design/copy/copy.py desde design/copy/copy.json ({lang}). No editar a mano. -->",
             "<resources>"]
    for screen in data["screens"]:
        block = [e for e in screen["strings"] if is_android(e)]
        if not block:
            continue
        lines.append(f"    <!-- {screen['name']} -->")
        for e in block:
            name = android_name(e["id"])
            note = e.get("note")
            if note and lang == "es":
                lines.append(f"    <!-- {xml_escape(note).replace('--', '–')} -->")
            plural = e.get("plural", {}).get(lang)
            if plural:
                lines.append(f'    <plurals name="{name}">')
                for qty, text in plural.items():
                    lines.append(f'        <item quantity="{qty}">{android_escape(android_format(text))}</item>')
                lines.append("    </plurals>")
                continue
            text = e.get("android", {}).get(lang) or e[lang]
            fmt = android_format(text)
            attrs = ""
            if "%%" in text and not spec_types(text):
                attrs = ' formatted="false"'
                fmt = fmt.replace("%%", "%")
            if e["id"] in ("comun.pro", "comun.lumbre_pro") and lang == "es":
                attrs += ' translatable="false"'
            lines.append(f'    <string name="{name}"{attrs}>{android_escape(fmt)}</string>')
    lines.append("</resources>")
    return "\n".join(lines) + "\n"


# ---------- Revisión contra el código de iOS ----------

def swift_literals(src: str):  # noqa: C901
    """Literales de una línea con las interpolaciones como {}. Saltea comentarios y bloques #Preview."""
    skip = []
    for m in re.finditer(r"#Preview\b", src):
        brace = src.find("{", m.end())
        if brace < 0:
            continue
        depth, i = 0, brace
        while i < len(src):
            c = src[i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        skip.append((m.start(), i))

    i, n = 0, len(src)
    while i < n:
        if src.startswith("//", i):
            i = src.find("\n", i)
            i = n if i < 0 else i
            continue
        if src.startswith('"""', i):
            end = src.find('"""', i + 3)
            i = n if end < 0 else end + 3
            continue
        if src[i] == '"':
            start = i
            text, i = read_literal(src, i + 1)
            if not any(a <= start <= b for a, b in skip):
                line = src.count("\n", 0, start) + 1
                before = src[max(0, start - 40):start].split("\n")[-1]
                yield line, text, before
            continue
        i += 1


def read_literal(src: str, i: int):
    out = []
    while i < len(src):
        c = src[i]
        if c == "\\" and i + 1 < len(src):
            nxt = src[i + 1]
            if nxt == "(":
                depth, j = 1, i + 2
                while j < len(src) and depth:
                    if src[j] == '"':
                        _, j = read_literal(src, j + 1)
                        continue
                    if src[j] == "(":
                        depth += 1
                    elif src[j] == ")":
                        depth -= 1
                    j += 1
                out.append("{}")
                i = j
                continue
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(nxt, nxt))
            i += 2
            continue
        if c == '"' or c == "\n":
            return "".join(out), i + 1
        out.append(c)
        i += 1
    return "".join(out), i


NOISE_LINE = re.compile(r"Logger|logger\.|print\(|Analytics\.|\.track\(|\.screen\(")
# Argumentos que nunca son copy: símbolos, assets, claves.
NOISE_BEFORE = re.compile(r"(systemImage|named|forKey|identifier|accessibilityIdentifier|suggestedFileName|bundle|subsystem|category|entry|trigger|tag|id):\s*$|(Image|Color|URL\(string|UTType|Notification\.Name)\(\s*$|@AppStorage\(\s*$|\[\s*$")


def looks_like_copy(text: str) -> bool:
    if not re.search(r"[A-Za-zÁÉÍÓÚáéíóúñÑ]{2}", text):
        return False
    if re.fullmatch(r"[a-z0-9_.\-/:]+", text):  # identificadores, símbolos, rutas
        return False
    if re.fullmatch(r"[A-Za-z]+[A-Z][A-Za-z]*", text) or re.fullmatch(r"X-[A-Za-z-]+", text):  # CamelCase y encabezados HTTP
        return False
    return " " in text or text[:1].isupper() or text[:1] in "¿¡"


# Literales que parecen copy pero no lo son (debug, encabezados HTTP, placeholders de carga, marca).
IGNORED = {
    "Lumbre", "Fraunces", "Volver a ver el onboarding", "Desarrollo", "Solo en Debug. El plan real lo cambia el webhook de RevenueCat.",
    "Se recarga mañana a las 8:00", "US$ 00,00", "US$ 0,00 por mes", "Fecha con un formato desconocido",
    "Content-Type", "Accept", "Authorization", "Bearer {}", "PGRST116", "Cache.store", "Cache-local.store",
}


def normalize(text: str) -> str:
    text = text.replace("%%", "%")
    return SPEC.sub("{}", text)


def review_ios(data: dict) -> int:
    roots = [ROOT / "ios" / "Lumbre"] + sorted((ROOT / "ios" / "Packages").glob("*/Sources"))
    found: dict[str, list[str]] = {}
    every: set[str] = set()
    for root in roots:
        for path in sorted(root.rglob("*.swift")):
            if "Mock" in path.name or "Preview" in path.name:
                continue
            src = path.read_text(encoding="utf-8")
            lines = src.splitlines()
            for line_no, text, before in swift_literals(src):
                every.add(normalize(text))
                if NOISE_LINE.search(lines[line_no - 1]) or NOISE_BEFORE.search(before) or not looks_like_copy(text):
                    continue
                found.setdefault(text, []).append(f"{path.relative_to(ROOT)}:{line_no}")

    copy_keys = {normalize(e["es"]): e for _, e in entries(data) if is_ios(e)}
    missing = {t: w for t, w in found.items() if normalize(t) not in copy_keys and normalize(t) not in IGNORED}
    stale = [e for k, e in copy_keys.items() if e.get("status", "app") == "app" and k not in every]

    print(f"Literales de interfaz en Swift: {len(found)}. En copy.json (iOS): {len(copy_keys)}.")
    if missing:
        print(f"\nEn el código y no en copy.json ({len(missing)}): sumalos o, si no son copy, ignoralos.")
        for t, where in sorted(missing.items(), key=lambda x: x[1][0]):
            print(f"  {where[0]}  {t!r}")
    if stale:
        print(f"\nEn copy.json (status app) y no en el código ({len(stale)}): cambió el texto en la app o es un String sin localizar.")
        for e in stale:
            print(f"  {e['id']}  {e['es']!r}")
    nuevos = [e for e in copy_keys.values() if e.get("status") == "nuevo" and normalize(e["es"]) in every]
    if nuevos:
        print(f"\nMarcados 'nuevo' que ya están en el código ({len(nuevos)}): pasalos a status app.")
        for e in nuevos:
            print(f"  {e['id']}")
    return 0


# ---------- Formato del archivo ----------

def dump_copy(data: dict) -> str:
    """Un objeto por texto en una línea, así los diffs y las revisiones son legibles."""
    out = ["{", '  "meta": ' + json.dumps(data["meta"], ensure_ascii=False, indent=2).replace("\n", "\n  ") + ",", '  "screens": [']
    for si, screen in enumerate(data["screens"]):
        head = {k: v for k, v in screen.items() if k != "strings"}
        out.append("    {")
        for k, v in head.items():
            out.append(f'      "{k}": {json.dumps(v, ensure_ascii=False)},')
        out.append('      "strings": [')
        for ei, e in enumerate(screen["strings"]):
            comma = "," if ei < len(screen["strings"]) - 1 else ""
            out.append("        " + json.dumps(e, ensure_ascii=False) + comma)
        out.append("      ]")
        out.append("    }" + ("," if si < len(data["screens"]) - 1 else ""))
    out.append("  ]")
    out.append("}")
    return "\n".join(out) + "\n"


def write_csv(data: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "pantalla", "es", "en", "android_es", "android_en", "plataforma", "estado", "nota"])
        for screen, e in entries(data):
            a = e.get("android", {})
            w.writerow([e["id"], screen["name"], e["es"], e["en"], a.get("es", ""), a.get("en", ""),
                        e.get("platform", "ambas"), e.get("status", "app"), e.get("note", "")])


# ---------- CLI ----------

def arg(name: str, default: Path) -> Path:
    if name in sys.argv:
        value = Path(sys.argv[sys.argv.index(name) + 1])
        return value if value.is_absolute() else Path.cwd() / value
    return default


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "validar"
    data = load()
    errors = validate(data)
    if errors:
        print("copy.json tiene errores:")
        for e in errors:
            print("  " + e)
        return 1
    total = sum(1 for _ in entries(data))
    nuevos = sum(1 for _, e in entries(data) if e.get("status") == "nuevo")

    if cmd == "validar":
        print(f"copy.json está bien: {total} textos en {len(data['screens'])} pantallas ({nuevos} nuevos, todavía no en el código).")
        return 0
    if cmd == "formatear":
        SOURCE.write_text(dump_copy(data), encoding="utf-8")
        print("copy.json reescrito.")
        return 0
    if cmd in ("xcstrings", "todo"):
        out = arg("--out", BUILD / "ios" / "Localizable.xcstrings") if cmd == "xcstrings" else BUILD / "ios" / "Localizable.xcstrings"
        existing = json.loads(out.read_text(encoding="utf-8")) if out.exists() and cmd == "xcstrings" and "--out" in sys.argv else None
        catalog = build_xcstrings(data, existing)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(dump_xcstrings(catalog), encoding="utf-8")
        print(f"{out}: {len(catalog['strings'])} claves.")
    if cmd in ("android", "todo"):
        res = arg("--out", BUILD / "android") if cmd == "android" else BUILD / "android"
        for lang, folder in (("es", "values"), ("en", "values-en")):
            path = res / folder / "strings.xml"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(build_android(data, lang), encoding="utf-8")
            print(f"{path}")
    if cmd in ("csv", "todo"):
        path = BUILD / "copy.csv"
        write_csv(data, path)
        print(f"{path}")
    if cmd == "revisar-ios":
        return review_ios(data)
    if cmd not in ("xcstrings", "android", "csv", "todo", "revisar-ios"):
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
