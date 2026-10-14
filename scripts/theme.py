#!/usr/bin/env python3
"""JellyFace wallpaper-driven theming.

Reads the current COSMIC wallpaper, picks the best matching palette from the palette packs in
Color_Palette/*.txt, and writes it as the shell's colour scheme (scheme.json). The shell reloads that file live.

  theme.py apply [PALETTE]     apply the best match for the current wallpaper (or force palette number/name)
  theme.py match [IMAGE]       show the best matches for the wallpaper (or IMAGE) without applying anything
  theme.py list                list all palettes
  theme.py tint [0-6]          how strongly palette colours show (default 3; 1 = palette exactly as written)
  theme.py soft [0-1]          background lightness 0-2 (default 0.7; 0 = near-black backgrounds)
  theme.py system on|off       also theme COSMIC itself (Files, Terminal, Settings, panel) from the palette (default on)
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
import subprocess
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

DEFAULT_SOFT = 0.7  # 0 = backgrounds as dark as the palette's Deepest swatch, 1 = one full tonal step lighter, up to 2
DEFAULT_TINT = 3.0  # palettes in the pack are near-greys (chroma 0.5-7); this makes their hue visible
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


def lab_to_rgb(lab):
    L, a, b = lab
    fy = (L + 16) / 116
    fx, fz = fy + a / 500, fy - b / 200

    def finv(t):
        return t ** 3 if t ** 3 > 0.008856 else (t - 16 / 116) / 7.787

    x, y, z = finv(fx) * 0.95047, finv(fy), finv(fz) * 1.08883
    lin = (3.2404542 * x - 1.5371385 * y - 0.4985314 * z, -0.9692660 * x + 1.8760108 * y + 0.0415560 * z,
           0.0556434 * x - 0.2040259 * y + 1.0572252 * z)

    def gamma(v):
        v = max(0.0, min(1.0, v))
        return 255 * (12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055)

    return tuple(gamma(v) for v in lin)


def boost(rgb, k):
    """Scale the colour strength (chroma) by k, keeping hue and lightness."""
    L, a, b = rgb_to_lab(rgb)
    return lab_to_rgb((L, a * k, b * k))


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
    """Make fg lighter (on a dark background) until it reaches the contrast ratio, keeping its hue and colour strength
    as far as the sRGB gamut allows."""
    L, a, b = rgb_to_lab(fg)
    for lightness in range(int(L), 101):
        c = lab_to_rgb((lightness, a, b))
        if contrast(c, bg) >= ratio:
            return c
    return (255, 255, 255)


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
    try:
        good.insert(0, original_grey())
    except (OSError, ValueError, KeyError):
        pass
    return good


def original_grey():
    """The grey scheme JellyFace shipped with (config/scheme.json). Applied exactly: no tint, no softness."""
    path = os.path.join(ROOT, "config", "scheme.json")
    c = json.load(open(path))["colours"]
    rgb = [hex_to_rgb(c[k]) for k in ("background", "surfaceContainerHigh", "surfaceContainerHighest", "outline", "primary")]
    return {"num": 0, "name": "Original Grey", "family": "Original", "rgb": rgb, "lab": [rgb_to_lab(x) for x in rgb],
            "exact": path, "pack": "built-in"}


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
def build_scheme(p, tint=DEFAULT_TINT, soft=DEFAULT_SOFT):
    if p.get("exact"):  # the original grey is applied exactly as written
        scheme = json.load(open(p["exact"]))
        scheme["name"] = p["name"]
        return scheme
    sw = [boost(c, tint) for c in p["rgb"]]
    # soften: slide every swatch part of the way to the next lighter one (Highlight stays), so the background is a
    # tinted mid-dark instead of near-black
    def along(t):  # the colour t steps along the palette's ladder (Deepest=0 ... Highlight=4)
        t = min(t, 4.0)
        lo = int(t)
        return mix(sw[lo], sw[min(lo + 1, 4)], t - lo)

    sw = [along(i + soft) for i in range(5)]
    d, b, m, s, h = sw  # background, panel, border, secondary text, highlight
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


def update_cosmic_theme():
    """Also theme COSMIC itself (Files, Terminal, Settings, panel...) from the same scheme. Never fatal."""
    if not read_state().get("system", True):
        return
    script = os.path.join(ROOT, "scripts", "cosmic-theme.sh")
    tool = os.path.join(ROOT, "tools", "cosmic-theme", "target", "release", "jellyface-cosmic-theme")
    if not os.path.exists(tool):
        return
    try:
        subprocess.run([script, "apply"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=30, check=True)
    except Exception as e:
        print(f"theme: could not update COSMIC's theme: {getattr(e, 'stderr', b'') or e}", file=sys.stderr)


def sync_greeter():
    """Keep the login screen (greeter/) in step with the theme and wallpaper. Does nothing unless it is installed."""
    data = "/var/lib/jellyface-greeter/data"
    if os.access(data, os.W_OK):
        subprocess.run([os.path.join(ROOT, "greeter", "stage.sh"), data], capture_output=True, timeout=30, check=False)


def write_scheme(scheme):
    """Returns False (and touches nothing) when the shell already shows exactly this scheme."""
    text = json.dumps(scheme, indent=1)
    try:
        if open(SCHEME, encoding="utf-8").read() == text:
            return False
    except OSError:
        pass
    os.makedirs(os.path.dirname(SCHEME), exist_ok=True)
    # written in place (not renamed over) so the shell's file watcher keeps following the same file; one write() so the
    # shell never sees a half-written file
    with open(SCHEME, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())
    update_cosmic_theme()
    sync_greeter()
    return True


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
    if str(key).lower() in ("0", "000", "grey", "gray", "original", "original grey"):
        key = "0"
    for p in palettes:
        if str(p["num"]) == (str(key).lstrip("0") or "0") or str(p["num"]).zfill(3) == str(key) or p["name"].lower() == str(key).lower():
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
    tint, soft = read_state().get("tint", DEFAULT_TINT), read_state().get("soft", DEFAULT_SOFT)
    changed = write_scheme(build_scheme(p, tint, soft))
    write_state(palette=p["num"], name=p["name"], family=p["family"], source=source, reason=reason, applied=time.strftime("%F %T"), wallpaper_key=repr(wallpaper_key()))
    extra = "exact (tint and softness do not apply)" if p.get("exact") else f"tint {tint:g}, softness {soft:g}"
    print(f"applied [{p['num']:03d}] {p['name']} ({p['family']}), {extra} -- {reason}" + ("" if changed else " (already showing)"))


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


def set_param(key, val, lo, hi, default, doc):
    st = read_state()
    if val is None:
        print(f"{key}: {st.get(key, default):g}  ({doc})")
        return
    try:
        k = float(val)
    except ValueError:
        raise SystemExit(f"usage: theme.py {key} [{lo:g}-{hi:g}]")
    if not lo <= k <= hi:
        raise SystemExit(f"{key} must be between {lo:g} and {hi:g}")
    write_state(**{key: k})
    st = read_state()
    if st.get("palette"):
        apply_palette(find_palette(load_palettes(), st["palette"]), st.get("source", ""), st.get("reason", ""))


def cmd_tint(val=None):
    set_param("tint", val, 0, 6, DEFAULT_TINT, "how strongly the palette's colour shows: 0 greyscale, 1 as written, 3 default")


def cmd_soft(val=None):
    set_param("soft", val, 0, 2, DEFAULT_SOFT, "background lightness: 0 near-black, 1 one tonal step lighter, 2 two steps")


def cmd_system(val=None):
    st = read_state()
    script = os.path.join(ROOT, "scripts", "cosmic-theme.sh")
    if val is None:
        print(f"COSMIC system theme: {'on' if st.get('system', True) else 'off'}")
        subprocess.run([script, "status"])
        return
    if val not in ("on", "off"):
        raise SystemExit("usage: theme.py system on|off")
    write_state(system=(val == "on"))
    if val == "on":
        subprocess.run([script, "apply"], check=False)
    else:
        subprocess.run([script, "reset"], check=False)


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
    import fcntl
    # one watcher only, and it ends with whoever started it: a killed supervisor used to leave watchers behind, each of
    # them polling and re-applying the theme
    lock = open(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "jellyface-theme.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return
    parent = os.getppid()
    last = None
    try:  # the wallpaper this palette was chosen for: nothing to redo (and no colour flash) if it is still the same
        st = read_state()
        if st.get("mode", "auto") == "auto" and st.get("wallpaper_key") == repr(wallpaper_key()):
            last = wallpaper_key()
    except Exception:
        pass
    while os.getppid() == parent:
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
    {"apply": cmd_apply, "system": cmd_system, "tint": cmd_tint, "soft": cmd_soft, "match": cmd_match, "list": cmd_list, "auto": cmd_auto, "watch": cmd_watch, "status": cmd_status}.get(
        cmd, lambda *a: sys.exit(f"unknown command '{cmd}' (try --help)"))(*args)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
