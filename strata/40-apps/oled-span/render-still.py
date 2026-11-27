#!/usr/bin/env python3
"""Renders one still frame of OLED Span's contours style to a PNG, for screens that only take a
picture (lock screens, the login screen, splash screens).

A NumPy port of the contours branch of the shader in wallpaper-engine-web/index.html: the same
simplex noise, four octaves, 14 levels and every fifth line brighter. No browser or GPU needed.
Needs numpy and Pillow.

    python render-still.py [--width 1920] [--height 1080] [--time 43200] [--size 1.0] out.png
"""
import argparse

import numpy as np
from PIL import Image


def mod289(x):
    return x - np.floor(x * (1.0 / 289.0)) * 289.0


def permute(x):
    return mod289(((x * 34.0) + 10.0) * x)


def snoise(vx, vy, vz):
    """3D simplex noise by Ian McEwan and Stefan Gustavson (Ashima Arts), MIT licence; one value
    per element of the input arrays."""
    c_x, c_y = 1.0 / 6.0, 1.0 / 3.0
    s = (vx + vy + vz) * c_y
    ix, iy, iz = np.floor(vx + s), np.floor(vy + s), np.floor(vz + s)
    t = (ix + iy + iz) * c_x
    x0x, x0y, x0z = vx - ix + t, vy - iy + t, vz - iz + t
    # g = step(x0.yzx, x0.xyz); l = 1 - g
    gx, gy, gz = (x0x >= x0y) * 1.0, (x0y >= x0z) * 1.0, (x0z >= x0x) * 1.0
    lx, ly, lz = 1.0 - gx, 1.0 - gy, 1.0 - gz
    i1x, i1y, i1z = np.minimum(gx, lz), np.minimum(gy, lx), np.minimum(gz, ly)
    i2x, i2y, i2z = np.maximum(gx, lz), np.maximum(gy, lx), np.maximum(gz, ly)
    x1 = (x0x - i1x + c_x, x0y - i1y + c_x, x0z - i1z + c_x)
    x2 = (x0x - i2x + c_y, x0y - i2y + c_y, x0z - i2z + c_y)
    x3 = (x0x - 0.5, x0y - 0.5, x0z - 0.5)
    x0 = (x0x, x0y, x0z)
    ix, iy, iz = mod289(ix), mod289(iy), mod289(iz)

    def corner(ox, oy, oz):
        return permute(permute(permute(iz + oz) + iy + oy) + ix + ox)

    ps = [corner(0.0, 0.0, 0.0), corner(i1x, i1y, i1z), corner(i2x, i2y, i2z), corner(1.0, 1.0, 1.0)]
    n_ = 0.142857142857
    nsx, nsy, nsz = n_ * 2.0 - 0.0, n_ * 0.5 - 1.0, n_ * 1.0 - 0.0
    total = 0.0
    for p, x in zip(ps, (x0, x1, x2, x3)):
        j = p - 49.0 * np.floor(p * nsz * nsz)
        x_ = np.floor(j * nsz)
        y_ = np.floor(j - 7.0 * x_)
        gxv = x_ * nsx + nsy
        gyv = y_ * nsx + nsy
        h = 1.0 - np.abs(gxv) - np.abs(gyv)
        sx = np.floor(gxv) * 2.0 + 1.0
        sy = np.floor(gyv) * 2.0 + 1.0
        sh = -((h <= 0.0) * 1.0)
        ax = gxv + sx * sh
        ay = gyv + sy * sh
        norm = 1.79284291400159 - 0.85373472095314 * (ax * ax + ay * ay + h * h)
        ax, ay, az = ax * norm, ay * norm, h * norm
        m = np.maximum(0.5 - (x[0] * x[0] + x[1] * x[1] + x[2] * x[2]), 0.0)
        m = m * m
        total = total + m * m * (ax * x[0] + ay * x[1] + az * x[2])
    return 105.0 * total


def fbm(x, y, z):
    s, a = 0.0, 0.5
    for _ in range(4):
        s = s + a * snoise(x, y, z)
        x, y, z, a = x * 2.03, y * 2.03, z * 1.5, a * 0.5
    return s


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def render(width, height, seconds, size):
    col, row = np.meshgrid(np.arange(width) + 0.5, np.arange(height) + 0.5)
    px, py = col / (900.0 * size), row / (900.0 * size)
    lv = fbm(px, py, np.full_like(px, seconds * 0.02)) * 14.0
    idx = np.floor(lv + 0.5)
    d = np.abs(lv - idx)
    # fwidth(): the change of lv to the next pixel across and down
    w = np.abs(np.diff(lv, axis=1, append=lv[:, -1:])) + np.abs(np.diff(lv, axis=0, append=lv[-1:, :]))
    w = np.maximum(w, 1e-6)
    major = np.mod(idx, 5.0) < 0.5
    line = 1.0 - smoothstep(0.0, w * np.where(major, 1.6, 1.0), d)
    c = line * np.where(major, 0.55, 0.24)
    c = c + (np.random.default_rng(7).random(c.shape) - 0.5) / 255.0  # dither against banding
    return Image.fromarray(np.clip(np.round(np.maximum(c, 0.0) * 255.0), 0, 255).astype(np.uint8), "L")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--width", type=int, default=1920)
    ap.add_argument("--height", type=int, default=1080)
    ap.add_argument("--time", type=float, default=43200.0, help="seconds into the day (the pattern's position)")
    ap.add_argument("--size", type=float, default=1.0, help="pattern size, like the wallpaper's Size setting")
    a = ap.parse_args()
    render(a.width, a.height, a.time, a.size).convert("RGB").save(a.out, optimize=True)
    print(f"wrote {a.out} ({a.width}x{a.height})")


if __name__ == "__main__":
    main()
