#!/usr/bin/env python3
"""Build the "OLED Monochrome" Visual Studio 2026 theme as a .vsix.

Visual Studio 2026's tinted themes (Cool Slate, Juicy Plum, ...) are small .pkgdef files that
override a handful of colour tokens on top of the Dark theme. This writes one the same way.

    python vstheme.py decode FILE.pkgdef         # print the tokens in a theme pkgdef
    python vstheme.py selftest FILE.pkgdef       # decode + re-encode, must be byte-identical
    python vstheme.py build OUT.vsix             # write the OLED Monochrome theme extension

Data blob layout (one per registry key): uint32 total length, uint32 version (11),
uint32 category count; per category a GUID (little-endian bytes) and uint32 entry count;
per entry uint32 name length, ASCII name, then background and foreground, each a type
byte (0 = unset, 1 = RGBA) followed by 4 bytes R,G,B,A when set.
"""
import re
import struct
import sys
import uuid
import zipfile

THEME_ID = "{6a1c2e4f-3b5d-4f7a-9c1e-0d2b4a6c8e10}"
THEME_NAME = "OLED Monochrome"
DARK_ID = "{1ded0138-47ce-435e-84ef-9ec1f439b749}"
VERSION = "1.0.0"

SHELL = "73708ded-2d56-4aad-b8eb-73b20d3f4bff"
SHELL_INTERNAL = "5af241b7-5627-4d12-bfb1-2b67d11127d7"

# Same 17 tokens Cool Slate overrides, in the same order. RRGGBBAA.
TOKENS = {
    "Shell": (SHELL, [
        ("AccentFillDefault", "B4B6B8FF"),
        ("AccentFillSecondary", "B4B6B8E5"),
        ("AccentFillTertiary", "B4B6B8CC"),
        ("SolidBackgroundFillTertiary", "000000FF"),
        ("SolidBackgroundFillQuaternary", "1A1A1AFF"),
        ("SurfaceBackgroundFillDefault", "111111FF"),
        ("TextFillSecondary", "FFFFFFCC"),
    ]),
    "ShellInternal": (SHELL_INTERNAL, [
        ("EnvironmentBackground", "000000FF"),
        ("EnvironmentBody", "000000FF"),
        ("EnvironmentBorder", "686B6FFF"),
        ("EnvironmentHeader", "000000FF"),
        ("EnvironmentHeaderInactive", "000000FF"),
        ("EnvironmentIndicator", "686B6F60"),
        ("EnvironmentLayeredBackground", "0000004D"),
        ("EnvironmentLogo", "E6E6E6FF"),
        ("EnvironmentTab", "000000FF"),
        ("EnvironmentTabInactive", "000000FF"),
    ]),
}


def decode_blob(data):
    total, ver, ncat = struct.unpack_from("<III", data, 0)
    assert total == len(data), f"length header {total} != {len(data)}"
    off, cats = 12, []
    for _ in range(ncat):
        guid = str(uuid.UUID(bytes_le=data[off:off + 16])); off += 16
        n, = struct.unpack_from("<I", data, off); off += 4
        entries = []
        for _ in range(n):
            ln, = struct.unpack_from("<I", data, off); off += 4
            name = data[off:off + ln].decode("ascii"); off += ln
            sides = []
            for _ in range(2):
                t = data[off]; off += 1
                if t:
                    sides.append((t, data[off:off + 4].hex().upper())); off += 4
                else:
                    sides.append(None)
            entries.append((name, sides[0], sides[1]))
        cats.append((guid, entries))
    assert off == len(data), "trailing bytes"
    return ver, cats


def encode_blob(ver, cats):
    body = bytearray(struct.pack("<I", len(cats)))
    for guid, entries in cats:
        body += uuid.UUID(guid).bytes_le + struct.pack("<I", len(entries))
        for name, bg, fg in entries:
            raw = name.encode("ascii")
            body += struct.pack("<I", len(raw)) + raw
            for side in (bg, fg):
                if side:
                    body += bytes([side[0]]) + bytes.fromhex(side[1])
                else:
                    body += b"\x00"
    head = struct.pack("<II", 8 + len(body), ver)
    return head + bytes(body)


def parse_pkgdef(text):
    for m in re.finditer(r'\[([^\]]+)\]\s*"Data"=hex:([0-9a-fA-F,\\\s]+)', text):
        yield m.group(1), bytes(int(b, 16) for b in re.findall(r"[0-9a-fA-F]{2}", m.group(2)))


def pkgdef_data_line(blob):
    return '"Data"=hex:' + ",".join(f"{b:02x}" for b in blob)


def build_pkgdef():
    lines = [
        f"[$RootKey$\\Themes\\{THEME_ID}]",
        f'@="{THEME_NAME}"',
        f'"Name"="{THEME_NAME}"',
        f'"FallbackId"="{DARK_ID}"',
        "",
    ]
    for key, (guid, entries) in TOKENS.items():
        cats = [(guid, [(n, (1, v), None) for n, v in entries])]
        lines += [f"[$RootKey$\\Themes\\{THEME_ID}\\{key}]", pkgdef_data_line(encode_blob(11, cats)), ""]
    return "\r\n".join(lines)


MANIFEST = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Id="csps.OledMonochrome.VisualStudio" Version="{VERSION}" Language="en-US" Publisher="csps" />
    <DisplayName>{THEME_NAME}</DisplayName>
    <Description xml:space="preserve">Black and grey tinted theme on top of Dark, matching the KDE OLED Monochrome desktop. Editor syntax colours are unchanged.</Description>
    <Tags>theme</Tags>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Community" Version="[18.0, 19.0)">
      <ProductArchitecture>amd64</ProductArchitecture>
    </InstallationTarget>
  </Installation>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.VsPackage" d:Source="File" Path="OledMonochrome.pkgdef" />
  </Assets>
</PackageManifest>
"""

CONTENT_TYPES = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="vsixmanifest" ContentType="text/xml" />
  <Default Extension="pkgdef" ContentType="text/plain" />
  <Default Extension="json" ContentType="application/json" />
</Types>
"""


def main():
    cmd, path = sys.argv[1], sys.argv[2]
    if cmd in ("decode", "selftest"):
        text = open(path, encoding="utf-8-sig").read()
        ok = True
        for key, blob in parse_pkgdef(text):
            ver, cats = decode_blob(blob)
            print(f"[{key}] version {ver}")
            for guid, entries in cats:
                print(f"  category {guid}")
                for name, bg, fg in entries:
                    print(f"    {name}: bg={bg and bg[1]} fg={fg and fg[1]}")
            if cmd == "selftest":
                same = encode_blob(ver, cats) == blob
                ok &= same
                print(f"  re-encode identical: {same}")
        sys.exit(0 if ok else 1)
    if cmd == "build":
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("[Content_Types].xml", CONTENT_TYPES)
            z.writestr("extension.vsixmanifest", MANIFEST)
            z.writestr("OledMonochrome.pkgdef", build_pkgdef())
        print(path)
        return
    sys.exit(f"unknown command {cmd}")


if __name__ == "__main__":
    main()
