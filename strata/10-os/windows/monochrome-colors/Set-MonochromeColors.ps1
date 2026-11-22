<#
.SYNOPSIS
    Applies the KDE "OLED Monochrome" greys to Windows-wide colours: the accent colour,
    the classic selection/link highlight, and the mouse pointer.

.DESCRIPTION
    - Accent (Settings > Personalization > Colors): a neutral grey palette around #686B6F.
      Dark-mode apps fill toggles and buttons with the light shade, so they turn light grey.
    - Classic Win32/Qt colours: selection highlight #686B6F with white text, menu highlight,
      link/hot-tracking colour. Applied live with SetSysColors and stored for the next sign-in.
    - Pointer: Bibata Modern Classic (black, as on the KDE laptop) once ..\cursors\Install-BibataCursors.ps1
      has installed it; otherwise the plain white Windows Default scheme.

    All values are per-user (HKCU), no elevation. Before changing anything the current values
    are saved to a JSON backup; -Restore <file> puts them back (values that didn't exist are
    removed again). Supports -WhatIf.

.EXAMPLE
    .\Set-MonochromeColors.ps1 -WhatIf
    .\Set-MonochromeColors.ps1
    .\Set-MonochromeColors.ps1 -Restore "$HOME\.config\csps-stratum\backups\colors-20261121-181500.json"
#>
#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param([string]$Restore)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class MonoNative {
    [DllImport("user32")] public static extern bool SetSysColors(int n, int[] elements, int[] colors);
    [DllImport("user32", CharSet = CharSet.Unicode)]
    public static extern bool SystemParametersInfoW(uint action, uint param, IntPtr pv, uint flags);
    [DllImport("user32", CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, string l, uint flags, uint ms, out IntPtr res);
}
'@

# 'RRGGBB' -> ABGR dword (accent registry format) / 'R G B' string (Control Panel\Colors)
function ConvertTo-Abgr([string]$hex, [int]$alpha = 0xFF) {
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16); $g = [Convert]::ToInt32($hex.Substring(2, 2), 16); $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
    [BitConverter]::ToInt32([byte[]]($r, $g, $b, $alpha), 0)
}
function ConvertTo-Argb([string]$hex, [int]$alpha) { [BitConverter]::ToInt32([byte[]](@([Convert]::FromHexString($hex))[2..0] + $alpha), 0) }
function ConvertTo-Rgb([string]$hex) { ([Convert]::FromHexString($hex) | ForEach-Object { $_ }) -join ' ' }

# Lightest -> darkest; Windows reads index 3 as the base accent.
$palette = 'D9DADB', 'B4B6B8', '8E9194', '686B6F', '4E5053', '35373A', '1E1F21', '686B6F'
$paletteBytes = [byte[]]($palette | ForEach-Object { [Convert]::FromHexString($_) + [byte]0 } | ForEach-Object { $_ })

# Pointer: Bibata Modern Classic (black, same as the KDE laptop) when ..\cursors\Install-BibataCursors.ps1
# has installed it, otherwise Windows' own white Aero scheme.
if (Test-Path (Join-Path $env:LOCALAPPDATA 'Cursors\Bibata-Modern-Classic\Pointer.cur')) {
    $cursorScheme = 'Bibata-Modern-Classic'
    $cursorDir = '%LOCALAPPDATA%\Cursors\Bibata-Modern-Classic'
    $cursors = [ordered]@{
        Arrow = 'Pointer.cur'; Help = 'Help.cur'; AppStarting = 'Work.ani'; Wait = 'Busy.ani'
        NWPen = 'Handwriting.cur'; No = 'Unavailable.cur'; SizeNS = 'Vert.cur'; SizeWE = 'Horz.cur'
        SizeNWSE = 'Dgn1.cur'; SizeNESW = 'Dgn2.cur'; SizeAll = 'Move.cur'; UpArrow = 'Alternate.cur'
        Hand = 'Link.cur'; Pin = 'Pin.cur'; Person = 'Person.cur'; Crosshair = 'Cross.cur'; IBeam = 'Text.cur'
    }
} else {
    $cursorScheme = 'Windows Default'
    $cursorDir = '%SystemRoot%\cursors'
    $cursors = [ordered]@{
        Arrow = 'aero_arrow.cur'; Help = 'aero_helpsel.cur'; AppStarting = 'aero_working.ani'; Wait = 'aero_busy.ani'
        NWPen = 'aero_pen.cur'; No = 'aero_unavail.cur'; SizeNS = 'aero_ns.cur'; SizeWE = 'aero_ew.cur'
        SizeNWSE = 'aero_nwse.cur'; SizeNESW = 'aero_nesw.cur'; SizeAll = 'aero_move.cur'; UpArrow = 'aero_up.cur'
        Hand = 'aero_link.cur'; Pin = 'aero_pin.cur'; Person = 'aero_person.cur'; Crosshair = ''; IBeam = ''
    }
}

# Key, value name, kind, data
$settings = [Collections.Generic.List[object]]::new()
function Add-Setting($key, $name, $kind, $data) { $settings.Add([pscustomobject]@{ Key = $key; Name = $name; Kind = $kind; Data = $data }) }

$accent = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
$dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
Add-Setting $accent 'AccentPalette' 'Binary' $paletteBytes
Add-Setting $accent 'AccentColorMenu' 'DWord' (ConvertTo-Abgr $palette[3])
Add-Setting $accent 'StartColorMenu' 'DWord' (ConvertTo-Abgr $palette[4])
Add-Setting $dwm 'AccentColor' 'DWord' (ConvertTo-Abgr $palette[3])
Add-Setting $dwm 'ColorizationColor' 'DWord' (ConvertTo-Argb $palette[3] 0xC4)
Add-Setting $dwm 'ColorizationAfterglow' 'DWord' (ConvertTo-Argb $palette[3] 0xC4)

$colors = 'HKCU:\Control Panel\Colors'
$sys = [ordered]@{ Hilight = @(13, '686B6F'); HilightText = @(14, 'FFFFFF'); HotTrackingColor = @(26, 'C8C8C8'); MenuHilight = @(29, '686B6F') }
foreach ($k in $sys.Keys) { Add-Setting $colors $k 'String' (ConvertTo-Rgb $sys[$k][1]) }

$cur = 'HKCU:\Control Panel\Cursors'
Add-Setting $cur '(default)' 'String' $cursorScheme
Add-Setting $cur 'Scheme Source' 'DWord' $(if ($cursorScheme -eq 'Windows Default') { 2 } else { 1 })
foreach ($k in $cursors.Keys) { Add-Setting $cur $k 'ExpandString' $(if ($cursors[$k]) { "$cursorDir\$($cursors[$k])" } else { '' }) }
Add-Setting 'HKCU:\Software\Microsoft\Accessibility' 'CursorType' 'DWord' 0

function Get-Current($key, $name) {
    $item = Get-Item -LiteralPath $key -ErrorAction SilentlyContinue
    if (-not $item -or -not ($item.GetValueNames() -contains $(if ($name -eq '(default)') { '' } else { $name }))) { return $null }
    $n = if ($name -eq '(default)') { '' } else { $name }
    [pscustomobject]@{ Kind = $item.GetValueKind($n).ToString(); Data = $item.GetValue($n, $null, 'DoNotExpandEnvironmentNames') }
}

function Write-Value($key, $name, $kind, $data) {
    if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
    if ($name -eq '(default)') { Set-Item -LiteralPath $key -Value $data; return }
    New-ItemProperty -LiteralPath $key -Name $name -PropertyType $kind -Value $data -Force | Out-Null
}

function Update-Live {
    # classic colours, pointer scheme, then tell apps the accent changed
    $live = Get-Item -LiteralPath $colors -ErrorAction SilentlyContinue
    $ids = @(); $vals = @()
    foreach ($k in $sys.Keys) {
        $v = if ($live) { $live.GetValue($k) }
        if ($v) { $p = $v -split ' '; $ids += $sys[$k][0]; $vals += [int]$p[0] + ([int]$p[1] -shl 8) + ([int]$p[2] -shl 16) }
    }
    if ($ids) { [void][MonoNative]::SetSysColors($ids.Count, $ids, $vals) }
    [void][MonoNative]::SystemParametersInfoW(0x57, 0, [IntPtr]::Zero, 3)  # SPI_SETCURSORS
    $r = [IntPtr]::Zero
    [void][MonoNative]::SendMessageTimeoutW([IntPtr]0xffff, 0x1A, [IntPtr]::Zero, 'ImmersiveColorSet', 2, 3000, [ref]$r)
}

if ($Restore) {
    foreach ($b in (Get-Content -Raw $Restore | ConvertFrom-Json)) {
        if (-not $PSCmdlet.ShouldProcess("$($b.Key)\$($b.Name)", 'Restore')) { continue }
        if ($null -eq $b.Kind) {
            if ($b.Name -ne '(default)') { Remove-ItemProperty -LiteralPath $b.Key -Name $b.Name -ErrorAction SilentlyContinue }
        } else {
            $data = if ($b.Kind -eq 'Binary') { [byte[]]$b.Data } else { $b.Data }
            Write-Value $b.Key $b.Name $b.Kind $data
        }
    }
    if (-not $WhatIfPreference) {
        # classic colours that didn't exist before fall back to Windows defaults at next sign-in
        Update-Live
        Write-Host "Restored from $Restore (classic colours fully revert after signing out and in)"
    }
    return
}

$backup = foreach ($s in $settings) {
    $c = Get-Current $s.Key $s.Name
    [pscustomobject]@{ Key = $s.Key; Name = $s.Name; Kind = $c.Kind; Data = $c.Data }
}

if ($PSCmdlet.ShouldProcess('accent, highlight and pointer colours', "Set $($settings.Count) values")) {
    $file = Join-Path $HOME ".config\csps-stratum\backups\colors-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
    $backup | ConvertTo-Json -Depth 3 | Set-Content -Path $file -Encoding utf8
    foreach ($s in $settings) { Write-Value $s.Key $s.Name $s.Kind $s.Data }
    Update-Live
    Write-Host "Applied. Backup: $file"
}
