#!/usr/bin/env python3
"""JellyFace wallpaper-driven theming.

Reads the current COSMIC wallpaper, picks the best matching palette from the palette packs in
Color_Palette/*.txt, and writes it as the shell's colour scheme (scheme.json). The shell reloads that file live.

  theme.py apply [PALETTE]     apply the best match for the current wallpaper (or force palette number/name)
  theme.py match [IMAGE]       show the best matches for the wallpaper (or IMAGE) without applying anything
  theme.py list                list all palettes
  theme.py auto on|off         follow the wallpaper automatically (on) or keep the current palette (off)
  theme.py watch               apply automatically whenever the wallpaper changes (used by `jellyface start`)
  theme.py status              what is applied and why

Needs python3-gi (GdkPixbuf) to read images; everything else is the standard library.
"""
import glob
import json
import math
import os
import re
import sys
import time

HOME = os.path.expanduser("~")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK_GLOB = os.path.join(ROOT, "Color_Palette", "*.txt")
CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
STATE_HOME = os.environ.get("XDG_STATE_HOME", os.path.join(HOME, ".local", "state"))
COSMIC_BG = os.path.join(CONFIG_HOME, "cosmic", "com.system76.CosmicBackground", "v1")
SCHEME = os.path.join(STATE_HOME, "caelestia", "scheme.json")
STATE = os.path.join(STATE_HOME, "jellyface", "theme.json")
IMAGE_EXT = (".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".tif", ".tiff")

SWATCHES = ["Deepest", "Dark Base", "Mid Tone", "Surface", "Highlight"]


# ----------------------------------------------------------------------------- colour maths
def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(c):
    return "".join(f"{max(0, min(255, int(round(v)))):02X}" for v in c)


def _lin(v):
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def rgb_to_lab(c):
    r, g, b = (_lin(v) for v in c)
    x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
    y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def luminance(c):
    r, g, b = (_lin(v) for v in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def ensure_contrast(fg, bg, ratio):
    """Lighten (on a dark background) or darken fg, keeping its hue, until it reaches the contrast ratio."""
    target = (255, 255, 255) if luminance(bg) < 0.5 else (0, 0, 0)
    for step in range(0, 101):
        c = mix(fg, target, step / 100.0)
        if contrast(c, bg) >= ratio:
            return c
    return target


# ----------------------------------------------------------------------------- palettes
def load_palettes():
    palettes = []
    for path in sorted(glob.glob(PACK_GLOB)):
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
        cur = None
        for line in lines:
            m = re.match(r"^\[(\d+)\]\s+(.+?)\s+\(family:\s*(.+?)\)\s*$", line)
            if m:
                cur = {"num": int(m.group(1)), "name": m.group(2).title(), "family": m.group(3), "sw": {}, "pack": os.path.basename(path)}
                palettes.append(cur)
                continue
            m = re.match(r"^\s+(Deepest|Dark Base|Mid Tone|Surface|Highlight)\s+HEX\s+#([0-9A-Fa-f]{6})", line)
            if m and cur is not None:
                cur["sw"][m.group(1)] = hex_to_rgb(m.group(2))
    good = []
    for p in palettes:
        if all(k in p["sw"] for k in SWATCHES):
            p["rgb"] = [p["sw"][k] for k in SWATCHES]
            p["lab"] = [rgb_to_lab(c) for c in p["rgb"]]
            good.append(p)
    return good


# ----------------------------------------------------------------------------- wallpaper
def current_wallpaper():
    """Returns ("image", path) or ("color", [rgb, ...]) or (None, None)."""
    cfg = os.path.join(COSMIC_BG, "all")
    try:
        if open(os.path.join(COSMIC_BG, "same-on-all")).read().strip() != "true":
            others = [p for p in glob.glob(os.path.join(COSMIC_BG, "*")) if os.path.basename(p) not in ("all", "same-on-all")]
            cfg = sorted(others)[0] if others else cfg
    except OSError:
        pass
    try:
        text = open(cfg, encoding="utf-8").read()
    except OSError:
        return None, None
    m = re.search(r'source:\s*Path\("([^"]+)"\)', text)
    if m:
        path = m.group(1)
        if os.path.isdir(path):
            files = sorted(f for f in os.listdir(path) if f.lower().endswith(IMAGE_EXT))
            path = os.path.join(path, files[0]) if files else None  # slideshow: COSMIC does not say which one is showing
        return ("image", path) if path and os.path.exists(path) else (None, None)
    colors = [tuple(float(x) * 255 for x in t) for t in re.findall(r"\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", text.split("source:", 1)[-1])]
    return ("color", colors) if colors else (None, None)


def image_pixels(path, size=64):
    import gi
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import GdkPixbuf
    pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, size, size, True)
    data, n, stride, w, h = pb.get_pixels(), pb.get_n_channels(), pb.get_rowstride(), pb.get_width(), pb.get_height()
    return [(data[y * stride + x * n], data[y * stride + x * n + 1], data[y * stride + x * n + 2]) for y in range(h) for x in range(w)]


def tonal_ramp(pixels, bins=5):
    """Mean Lab colour of the darkest 20%, next 20%, ... lightest 20% of the pixels."""
    labs = sorted((rgb_to_lab(p) for p in pixels), key=lambda c: c[0])
    n = len(labs)
    ramp = []
    for i in range(bins):
        chunk = labs[i * n // bins:(i + 1) * n // bins] or [labs[min(i * n // bins, n - 1)]]
        ramp.append(tuple(sum(c[k] for c in chunk) / len(chunk) for k in range(3)))
    return ramp


# ----------------------------------------------------------------------------- matching
WEIGHTS = [0.5, 0.8, 1.0, 1.0, 0.8]  # colour character matters most in the mid/upper tones


def score(ramp, palette):
    """Lower is better: hue/chroma difference along the tonal ramp, plus a small overall brightness term."""
    chroma = sum(w * math.hypot(r[1] - p[1], r[2] - p[2]) for w, r, p in zip(WEIGHTS, ramp, palette["lab"]))
    brightness = abs(sum(r[0] for r in ramp) / 5 - sum(p[0] for p in palette["lab"]) / 5)
    return chroma + 0.15 * brightness


def best_matches(ramp, palettes, top=5):
    return sorted(((score(ramp, p), p) for p in palettes), key=lambda t: (t[0], t[1]["num"]))[:top]


# ----------------------------------------------------------------------------- scheme
def build_scheme(p):
    d, b, m, s, h = p["rgb"]  # deepest, dark base, mid tone, surface, highlight
    text = ensure_contrast(h, d, 7.0)
    text_dim = ensure_contrast(s, d, 4.5)
    accent2 = ensure_contrast(mix(s, h, 0.5), d, 5.5)
    lowest = mix(d, (0, 0, 0), 0.25)
    container = mix(d, b, 0.5)
    c = {
        "background": d, "onBackground": text, "surface": d, "surfaceDim": lowest, "surfaceBright": b,
        "surfaceContainerLowest": lowest, "surfaceContainerLow": d, "surfaceContainer": container,
        "surfaceContainerHigh": b, "surfaceContainerHighest": m,
        "onSurface": text, "surfaceVariant": b, "onSurfaceVariant": text_dim,
        "inverseSurface": text, "inverseOnSurface": d, "outline": ensure_contrast(s, d, 3.0), "outlineVariant": m,
        "shadow": (0, 0, 0), "scrim": (0, 0, 0), "surfaceTint": text,
        "primary": text, "onPrimary": d, "primaryContainer": m, "onPrimaryContainer": text, "inversePrimary": m,
        "secondary": accent2, "onSecondary": d, "secondaryContainer": b, "onSecondaryContainer": text,
        "tertiary": text_dim, "onTertiary": d, "tertiaryContainer": m, "onTertiaryContainer": text,
        "error": hex_to_rgb("D98C8C"), "onError": d, "errorContainer": hex_to_rgb("5A3A3A"), "onErrorContainer": hex_to_rgb("F2C4C4"),
        "success": hex_to_rgb("9DBF9D"), "onSuccess": d, "successContainer": hex_to_rgb("3A4F3A"), "onSuccessContainer": hex_to_rgb("C8E2C8"),
        "primaryFixed": text, "primaryFixedDim": text_dim, "onPrimaryFixed": d, "onPrimaryFixedVariant": b,
        "secondaryFixed": accent2, "secondaryFixedDim": m, "onSecondaryFixed": d, "onSecondaryFixedVariant": b,
        "tertiaryFixed": text_dim, "tertiaryFixedDim": m, "onTertiaryFixed": d, "onTertiaryFixedVariant": b,
    }
    ramp = [d, b, m, s, text]
    for i in range(16):
        c[f"term{i}"] = hex_to_rgb("D98C8C") if i in (1, 9) else ramp[i % 5]
    return {"name": p["name"], "flavour": p["family"], "mode": "dark", "variant": "neutral",
            "colours": {k: rgb_to_hex(v) for k, v in c.items()}}


# ----------------------------------------------------------------------------- state
def read_state():
    try:
        return json.load(open(STATE))
    except (OSError, ValueError):
        return {}


def write_state(**kw):
    st = read_state()
    st.update(kw)
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    json.dump(st, open(tmp, "w"), indent=2)
    os.replace(tmp, STATE)


def write_scheme(scheme):
    os.makedirs(os.path.dirname(SCHEME), exist_ok=True)
    # written in place (not renamed over) so the shell's file watcher keeps following the same file
    with open(SCHEME, "w") as f:
        json.dump(scheme, f, indent=1)
        f.flush()
        os.fsync(f.fileno())


def wallpaper_ramp(image=None):
    if image:
        return tonal_ramp(image_pixels(image)), image
    kind, val = current_wallpaper()
    if kind == "image":
        return tonal_ramp(image_pixels(val)), val
    if kind == "color":
        return tonal_ramp(val), "solid colour"
    raise SystemExit("could not determine the current wallpaper")


def find_palette(palettes, key):
    for p in palettes:
        if str(p["num"]) == str(key).lstrip("0") or str(p["num"]).zfill(3) == str(key) or p["name"].lower() == str(key).lower():
            return p
    raise SystemExit(f"no palette '{key}' (see: theme.py list)")


# ----------------------------------------------------------------------------- commands
def cmd_match(image=None):
    palettes = load_palettes()
    ramp, src = wallpaper_ramp(image)
    print(f"wallpaper: {src}")
    for sc, p in best_matches(ramp, palettes):
        sw = " ".join("#" + rgb_to_hex(c) for c in p["rgb"])
        print(f"  [{p['num']:03d}] {p['name']:<22} {p['family']:<18} score {sc:6.1f}   {sw}")


def apply_palette(p, source, reason):
    write_scheme(build_scheme(p))
    write_state(palette=p["num"], name=p["name"], family=p["family"], source=source, reason=reason, applied=time.strftime("%F %T"))
    print(f"applied [{p['num']:03d}] {p['name']} ({p['family']}) -- {reason}")


def cmd_apply(key=None):
    palettes = load_palettes()
    if not palettes:
        raise SystemExit(f"no palettes found in {PACK_GLOB}")
    if key:
        p = find_palette(palettes, key)
        write_state(mode="manual")
        return apply_palette(p, "manual", "chosen by you; automatic theming is off (theme.py auto on to resume)")
    ramp, src = wallpaper_ramp()
    sc, p = best_matches(ramp, palettes, 1)[0]
    apply_palette(p, src, f"best match for {os.path.basename(str(src))} (score {sc:.1f})")


def cmd_list():
    for p in load_palettes():
        print(f"[{p['num']:03d}] {p['name']:<22} {p['family']:<18} " + " ".join("#" + rgb_to_hex(c) for c in p["rgb"]))


def cmd_auto(val):
    if val not in ("on", "off"):
        raise SystemExit("usage: theme.py auto on|off")
    write_state(mode="auto" if val == "on" else "manual")
    print(f"automatic theming {val}")
    if val == "on":
        cmd_apply()


def wallpaper_key():
    kind, val = current_wallpaper()
    stamp = lambda p: (p, os.path.getmtime(p)) if p and os.path.exists(p) else (p, 0)
    bg = os.path.join(COSMIC_BG, "all")
    return (stamp(val) if kind == "image" else (str(val), 0), stamp(bg)[1])


def cmd_watch():
    last = None
    while True:
        try:
            if read_state().get("mode", "auto") == "auto":
                key = wallpaper_key()
                if key != last:
                    time.sleep(1.0)  # let a freshly written wallpaper file settle
                    cmd_apply()
                    last = wallpaper_key()
            else:
                last = None
        except SystemExit as e:
            print(f"theme: {e}", file=sys.stderr)
        except Exception as e:  # never die: a bad image must not stop the watcher
            print(f"theme: {type(e).__name__}: {e}", file=sys.stderr)
            last = wallpaper_key() if last is None else last
        sys.stdout.flush()
        time.sleep(2.0)


def cmd_status():
    st = read_state()
    print(f"mode: {st.get('mode', 'auto')}")
    if st.get("name"):
        print(f"palette: [{st['palette']:03d}] {st['name']} ({st['family']})\nsource: {st['source']}\nwhy: {st['reason']}\napplied: {st['applied']}")
    else:
        print("nothing applied yet")


def main(argv):
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    cmd, args = argv[0], argv[1:]
    {"apply": cmd_apply, "match": cmd_match, "list": cmd_list, "auto": cmd_auto, "watch": cmd_watch, "status": cmd_status}.get(
        cmd, lambda *a: sys.exit(f"unknown command '{cmd}' (try --help)"))(*args)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
