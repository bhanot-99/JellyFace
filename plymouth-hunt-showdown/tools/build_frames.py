#!/usr/bin/env python3
"""Resize + edge-feather the Hunt: Showdown frames so Plymouth never scales at runtime.

usage: build_frames.py <src-frames-dir> [out-dir] [width] [height]
"""
import sys, pathlib
from PIL import Image, ImageChops
import numpy as np

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "frames")
W = int(sys.argv[3]) if len(sys.argv) > 3 else 1280
H = int(sys.argv[4]) if len(sys.argv) > 4 else 720
out.mkdir(parents=True, exist_ok=True)

# soft vignette so the frame blends into the black background on larger screens
fx = np.minimum(np.arange(W), np.arange(W)[::-1]) / (W * 0.12)
fy = np.minimum(np.arange(H), np.arange(H)[::-1]) / (H * 0.12)
mask = np.clip(np.minimum.outer(fy, fx), 0, 1)

files = sorted(src.glob("ezgif-frame-*.png"))
for i, f in enumerate(files):
    im = Image.open(f).convert("L").resize((W, H), Image.LANCZOS)
    a = (np.asarray(im, dtype=np.float32) * mask).astype(np.uint8)
    Image.fromarray(a, "L").save(out / f"frame-{i:03d}.png", optimize=True)
print(len(files), "frames ->", out)
