#!/usr/bin/env python3
"""Convert an editor colour theme (VS Code or Zed JSON) to monochrome.

Every #RGB / #RGBA / #RRGGBB / #RRGGBBAA value becomes the grey with the same perceived
brightness (relative luminance), alpha kept. The --base colour (the theme's main
background) is then mapped to pure black and the main text colour (--fg) to --fg-to, so
the result matches an OLED black desktop while keeping the theme's brightness steps.

    python bin/greyscale-theme.py IN.json OUT.json --name "OLED Monochrome" --base "#16191d" --fg "#abb2bf"

--keep leaves matching parts in colour (globs over "/"-joined key paths), e.g. syntax and
git colours: --keep tokenColors --keep "colors/gitDecoration.*". Each editor's README
has the exact command used for its theme.

Comments in the input (JSONC) are not supported; strip them first.
"""
import argparse
import fnmatch
import json
import re

HEX = re.compile(r"^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")


def to_linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def to_srgb(y):
    v = 12.92 * y if y <= 0.0031308 else 1.055 * y ** (1 / 2.4) - 0.055
    return v * 255


def grey_value(r, g, b):
    y = 0.2126 * to_linear(r) + 0.7152 * to_linear(g) + 0.0722 * to_linear(b)
    return to_srgb(y)


def parse(h):
    h = h[1:]
    if len(h) in (3, 4):
        h = "".join(ch * 2 for ch in h)
    rgb = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    alpha = h[6:8] if len(h) == 8 else ""
    return rgb, alpha


def make_converter(base, fg, fg_to):
    black = grey_value(*parse(base)[0])
    # scale so the theme's main text colour lands on fg_to; brighter colours clip at white
    scale = grey_value(*parse(fg_to)[0]) / (grey_value(*parse(fg)[0]) - black)

    def convert(value):
        if not isinstance(value, str) or not HEX.match(value):
            return value
        rgb, alpha = parse(value)
        v = (grey_value(*rgb) - black) * scale
        v = round(min(max(v, 0), 255))
        return "#{0:02x}{0:02x}{0:02x}{1}".format(v, alpha)

    return convert


def walk(node, convert, keep, path=""):
    # keep: glob patterns of "/"-joined key paths whose colours stay as they are
    if path and any(fnmatch.fnmatchcase(path, k) for k in keep):
        return node
    if isinstance(node, dict):
        return {k: walk(v, convert, keep, f"{path}/{k}" if path else k) for k, v in node.items()}
    if isinstance(node, list):
        return [walk(v, convert, keep, f"{path}/{i}" if path else str(i)) for i, v in enumerate(node)]
    return convert(node)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--name", required=True, help="new theme name")
    ap.add_argument("--base", required=True, help="main background colour, becomes #000000")
    ap.add_argument("--fg", required=True, help="main text colour of the input theme")
    ap.add_argument("--fg-to", default="#e6e6e6", help="grey the main text becomes (default #e6e6e6)")
    ap.add_argument("--keep", action="append", default=[], metavar="GLOB",
                    help='key path to leave in colour, e.g. "tokenColors" or "colors/gitDecoration.*" (repeatable)')
    args = ap.parse_args()

    with open(args.src, encoding="utf-8-sig") as f:
        theme = json.load(f)
    theme = walk(theme, make_converter(args.base, args.fg, args.fg_to), args.keep)

    # VS Code themes carry a top-level name; Zed theme families list themes[].name
    if "themes" in theme:
        theme["name"] = args.name
        for t in theme["themes"]:
            t["name"] = args.name
    else:
        theme["name"] = args.name

    with open(args.dst, "w", encoding="utf-8", newline="\n") as f:
        json.dump(theme, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
