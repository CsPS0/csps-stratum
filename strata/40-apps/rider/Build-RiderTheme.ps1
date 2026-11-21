<#
.SYNOPSIS
    Builds the "OLED Monochrome" Rider theme plugin from the installed Rider's own theme files.

.DESCRIPTION
    - UI theme: Rider's bundled Islands Dark theme, turned into greys of the same brightness
      on a black background (bin/greyscale-theme.py). VCS, diff and file colours stay.
    - Editor scheme: Rider Islands Dark with its #191A1C backgrounds turned black and a grey
      selection and caret row. All syntax and VCS colours stay.
    The JetBrains source files are read from the Rider install each time, so the repo only
    holds plugin.xml and this script. The built jar goes to -OutDir (not committed).

    -Install copies the jar into Rider's per-user plugins folder; Rider must be closed. Then
    pick Settings > Appearance & Behavior > Appearance > Theme > "OLED Monochrome".
    Supports -WhatIf.

.EXAMPLE
    .\Build-RiderTheme.ps1 -WhatIf
    .\Build-RiderTheme.ps1 -Install
#>
#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RiderHome = (Get-ChildItem 'C:\Program Files\JetBrains' -Directory -Filter 'JetBrains Rider *' -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Name -replace '^JetBrains Rider ', '') } | Select-Object -Last 1 -ExpandProperty FullName),
    [string]$ConfigDir = (Get-ChildItem (Join-Path $env:APPDATA 'JetBrains') -Directory -Filter 'Rider20*' -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Name -replace '^Rider', '') } | Select-Object -Last 1 -ExpandProperty FullName),
    [string]$OutDir = (Join-Path $HOME '.config\csps-stratum\build\rider'),
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
if (-not $RiderHome) { throw 'Rider install not found; pass -RiderHome' }
Write-Host "Rider: $RiderHome"

function Read-JarEntry([string]$jar, [string]$entry) {
    $z = [IO.Compression.ZipFile]::OpenRead($jar)
    try {
        $e = $z.GetEntry($entry); if (-not $e) { throw "$entry not found in $jar" }
        $r = [IO.StreamReader]::new($e.Open()); try { $r.ReadToEnd() } finally { $r.Dispose() }
    } finally { $z.Dispose() }
}

$work = Join-Path ([IO.Path]::GetTempPath()) "rider-oled-$PID"
# temp files are always written, also under -WhatIf
$PSDefaultParameterValues['*:WhatIf'] = $false
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    # UI theme: Islands Dark, greyscale, keep VCS/diff/file colours
    $src = Join-Path $work 'islands.theme.json'
    Set-Content -Path $src -Encoding utf8NoBOM -Value (Read-JarEntry (Join-Path $RiderHome 'lib\intellij.platform.ide.impl.jar') 'themes/islands/ManyIslandsDark.theme.json')
    $theme = Join-Path $work 'oled-monochrome.theme.json'
    $keep = 'ui/FileColor', 'ui/Diff', 'ui/VersionControl' | ForEach-Object { '--keep', $_ }
    python -I (Join-Path $repo 'bin\greyscale-theme.py') $src $theme --name 'OLED Monochrome' --base '#191A1C' --fg '#D1D3D9' @keep
    if ($LASTEXITCODE) { throw 'greyscale-theme.py failed' }
    $t = Get-Content -Raw $theme
    if ($t -notmatch '"editorScheme": "Islands Dark"') { throw 'editorScheme line not found in Islands Dark theme' }
    $t = $t.Replace('"editorScheme": "Islands Dark"', '"editorScheme": "OLED Monochrome"').Replace('"author": "JetBrains"', '"author": "csps (based on JetBrains Islands Dark)"')
    Set-Content -Path $theme -Value $t -Encoding utf8NoBOM -NoNewline

    # Editor scheme: Rider Islands Dark on black
    $x = Read-JarEntry (Join-Path $RiderHome 'plugins\rider-theme-pack\lib\rider-theme-pack.jar') 'colorSchemes/RiderIslandsDark.xml'
    if ($x -notmatch '<scheme name="Rider Islands Dark"') { throw 'unexpected RiderIslandsDark.xml' }
    $x = $x.Replace('<scheme name="Rider Islands Dark"', '<scheme name="OLED Monochrome"')
    $x = [regex]::Replace($x, '(?i)"191a1c"', '"000000"')
    $x = [regex]::Replace($x, '(<option name="CARET_ROW_COLOR" value=")[0-9A-Fa-f]{6}', '${1}0D0D0D')
    $x = [regex]::Replace($x, '(<option name="SELECTION_BACKGROUND" value=")[0-9A-Fa-f]{6}', '${1}333333')
    $scheme = Join-Path $work 'OLEDMonochrome.xml'
    Set-Content -Path $scheme -Value $x -Encoding utf8NoBOM -NoNewline

    $PSDefaultParameterValues.Remove('*:WhatIf')
    $jar = Join-Path $OutDir 'oled-monochrome.jar'
    if ($PSCmdlet.ShouldProcess($jar, 'Build theme plugin')) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
        if (Test-Path $jar) { Remove-Item $jar }
        $z = [IO.Compression.ZipFile]::Open($jar, 'Create')
        try {
            foreach ($pair in @(@((Join-Path $PSScriptRoot 'plugin.xml'), 'META-INF/plugin.xml'),
                                @($theme, 'oled-monochrome.theme.json'),
                                @($scheme, 'colorSchemes/OLEDMonochrome.xml'))) {
                [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, $pair[0], $pair[1])
            }
        } finally { $z.Dispose() }
        Write-Host "  [BUILD] $jar"
    }

    if ($Install) {
        if (-not $ConfigDir) { throw 'Rider config folder not found; pass -ConfigDir' }
        if (Get-Process rider64 -ErrorAction SilentlyContinue) { throw 'Close Rider before installing' }
        $dest = Join-Path $ConfigDir 'plugins\oled-monochrome\lib\oled-monochrome.jar'
        if ($PSCmdlet.ShouldProcess($dest, 'Install theme plugin')) {
            New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
            Copy-Item -LiteralPath $jar -Destination $dest -Force
            Write-Host "  [INSTALL] $dest"
        }
    }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue -WhatIf:$false
}
