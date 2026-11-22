<#
.SYNOPSIS
    Installs the Bibata Modern Classic cursors for the current user (no elevation).

.DESCRIPTION
    Copies the regular-size cursors from the official Windows release zip
    (Bibata-Modern-Classic-Windows.zip, https://github.com/ful1e5/Bibata_Cursor, GPL-3.0) into
    %LOCALAPPDATA%\Cursors\Bibata-Modern-Classic. The release's own install.inf writes to
    C:\Windows\Cursors and needs admin; Windows pointer schemes are per-user, so a per-user copy
    is enough. Set-MonochromeColors.ps1 then uses these cursors when the folder exists.
    The laptop (KDE) uses the same theme (cursorTheme=Bibata-Modern-Classic). Supports -WhatIf.

.EXAMPLE
    gh release download v2.0.7 -R ful1e5/Bibata_Cursor -p Bibata-Modern-Classic-Windows.zip -D $env:TEMP\bibata
    .\Install-BibataCursors.ps1 -Zip $env:TEMP\bibata\Bibata-Modern-Classic-Windows.zip
    ..\monochrome-colors\Set-MonochromeColors.ps1
#>
#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][string]$Zip,
    [ValidateSet('Regular', 'Large', 'Extra-Large')][string]$Size = 'Regular'
)

$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:LOCALAPPDATA 'Cursors\Bibata-Modern-Classic'
$work = Join-Path ([IO.Path]::GetTempPath()) "bibata-$([guid]::NewGuid().ToString('N'))"

try {
    Expand-Archive -LiteralPath $Zip -DestinationPath $work
    $src = Join-Path $work "Bibata-Modern-Classic-$Size-Windows"
    if (-not (Test-Path (Join-Path $src 'Pointer.cur'))) { throw "No $Size cursors in $Zip" }
    $files = Get-ChildItem $src -File | Where-Object Extension -in '.cur', '.ani'
    if ($PSCmdlet.ShouldProcess($dest, "Copy $($files.Count) $Size cursors")) {
        New-Item -ItemType Directory -Force $dest | Out-Null
        $files | Copy-Item -Destination $dest -Force
        Write-Host "  [INSTALL] $($files.Count) cursors -> $dest"
    }
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
