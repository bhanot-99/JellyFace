#!/usr/bin/env python3
"""JellyFace frosted-glass look: translucent surfaces with the compositor blurring what is behind them.

  glass.py                 show the current setting
  glass.py on [OPACITY]    turn it on; OPACITY is how solid the surfaces are, 0.5-1.0 (default 0.9 = 10% transparent)
  glass.py off             solid surfaces, no blur
"""
import json
import os
import sys

CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "caelestia", "shell.json")


def load():
    try:
        return json.load(open(CONFIG))
    except (OSError, ValueError):
        return {}


def save(d):
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    tmp = CONFIG + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    os.replace(tmp, CONFIG)


def main(argv):
    d = load()
    t = d.setdefault("appearance", {}).setdefault("transparency", {})
    if not argv:
        on = t.get("enabled", False)
        print(f"glass: {'on' if on else 'off'}" + (f" (opacity {t.get('base', 0.85):g}, i.e. {round((1 - t.get('base', 0.85)) * 100)}% transparent)" if on else ""))
        return 0
    if argv[0] == "off":
        t["enabled"] = False
    elif argv[0] == "on":
        try:
            base = float(argv[1]) if len(argv) > 1 else 0.9
        except ValueError:
            sys.exit("usage: glass.py on [0.5-1.0]")
        if not 0.5 <= base <= 1.0:
            sys.exit("opacity must be between 0.5 and 1.0")
        t.update(enabled=True, base=base, layers=min(1.0, round(base - 0.05, 2)))
    else:
        sys.exit(__doc__)
    save(d)
    print(f"glass {argv[0]}" + (f" (opacity {t['base']:g})" if t.get("enabled") else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
