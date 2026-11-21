#!/usr/bin/env python3
"""Pack this folder's theme extension into a .vsix without needing Node or vsce.

    python pack-vsix.py [OUT.vsix]
    code-insiders --profile CsPS --install-extension OUT.vsix
"""
import json
import pathlib
import sys
import zipfile

here = pathlib.Path(__file__).resolve().parent
pkg = json.loads((here / "package.json").read_text(encoding="utf-8"))
out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else here / f"{pkg['name']}-{pkg['version']}.vsix"

content_types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/>
  <Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
"""

manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="{pkg['name']}" Version="{pkg['version']}" Publisher="{pkg['publisher']}"/>
    <DisplayName>{pkg['displayName']}</DisplayName>
    <Description xml:space="preserve">{pkg['description']}</Description>
    <Categories>Themes</Categories>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{pkg['engines']['vscode']}"/>
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
</PackageManifest>
"""

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", content_types)
    z.writestr("extension.vsixmanifest", manifest)
    z.write(here / "package.json", "extension/package.json")
    for f in sorted((here / "themes").glob("*.json")):
        z.write(f, f"extension/themes/{f.name}")
print(out)
