import math, os, sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
N = 100          # frames
W = 160          # low-res canvas (upscaled x4 -> 640)
SCALE = 4
os.makedirs(OUT, exist_ok=True)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
LEVELS = np.array([0, 85, 170, 255], dtype=np.uint8)
yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
cx = cy = W / 2
rng = np.random.default_rng(7)
noise = rng.random((W, W)).astype(np.float32)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def frame(i):
    t = i / N * 2 * math.pi
    # gaze wanders on a loop; blink around frames 72-84
    gx = 14 * math.sin(t) + 5 * math.sin(3 * t)
    gy = 8 * math.sin(2 * t + 1)
    b = (i - 78) / 6.0
    lid = 1 - math.exp(-b * b) if 0 <= i else 1          # 0 = shut, 1 = open
    open_h = 0.15 + 0.85 * lid

    # eyeball: wide ellipse, shaded toward edges
    ex, ey = (xx - cx) / 70, (yy - cy) / (48 * open_h)
    r = np.sqrt(ex ** 2 + ey ** 2)
    ball = r < 1
    lum = 0.95 - 0.55 * smooth(0.55, 1.0, r) + 0.05 * noise
    # veins
    lum -= 0.12 * (np.sin((xx * 0.9 + yy * 1.7) * 0.6 + noise * 2) > 0.93) * smooth(0.5, 1, r)

    # iris + pupil
    ix, iy = xx - (cx + gx), yy - (cy + gy * open_h)
    ir = np.sqrt(ix ** 2 + iy ** 2)
    pupil_r = 9 + 2.5 * math.sin(t * 2)
    iris = ir < 26
    lum = np.where(iris, 0.55 - 0.25 * smooth(12, 26, ir)
                   + 0.12 * np.sin(np.arctan2(iy, ix) * 14 + ir * 0.4), lum)
    lum = np.where(ir < 27, np.where(ir > 23, 0.15, lum), lum)  # limbal ring
    lum = np.where(ir < pupil_r, 0.02, lum)
    hl = np.sqrt((ix + 6) ** 2 + (iy + 7) ** 2) < 3
    lum = np.where(hl & (ir < 27), 1.0, lum)

    # background: dim noisy texture, brighter near eye
    bg = 0.10 + 0.18 * noise * smooth(110, 30, np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) * 0 + np.abs(xx - cx)) \
        + 0.06 * np.sin(yy * 0.35 + t * 3)
    lum = np.where(ball, lum, bg)
    # dark lid rim
    lum = np.where((r > 0.93) & (r < 1.0), 0.05, lum)

    # glitch: shifted row bands on a few frames
    if i % 23 in (0, 1, 2):
        for _ in range(3):
            y0 = int(rng.integers(0, W - 10)); h = int(rng.integers(2, 9))
            lum[y0:y0 + h] = np.roll(lum[y0:y0 + h], int(rng.integers(-12, 12)), axis=1)

    # ordered dither to 4 grey levels
    th = np.tile(BAYER, (W // 4, W // 4))
    q = np.clip(np.floor(np.clip(lum, 0, 1) * 3 + th), 0, 3).astype(int)
    img = Image.fromarray(LEVELS[q], "L").resize((W * SCALE, W * SCALE), Image.NEAREST)
    return img


for i in range(N):
    frame(i).convert("RGB").save(f"{OUT}/frame-{i:03d}.png", optimize=True)
print("wrote", N, "frames")
