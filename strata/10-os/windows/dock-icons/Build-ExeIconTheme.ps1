<#
.SYNOPSIS
    Builds an icon theme that swaps the icons built into program files (title bars, Alt+Tab,
    Task Manager, Explorer) for the monochrome dock icons.

.DESCRIPTION
    For each line of exe-icons.map, finds the program's first icon group (the one Windows shows
    as "the" app icon), and compiles a resource-only DLL that holds the replacement .ico under
    the same group name. A theme.ini maps each program to its DLL. Windhawk's
    icon-resource-redirect mod then loads icons from the DLL instead of the program; anything
    the DLL doesn't contain still comes from the original file.

    Needs rc.exe (Windows SDK) and link.exe (MSVC build tools). -Register adds the theme folder
    to the mod's "Theme paths" setting; that needs an elevated session. Supports -WhatIf.

.EXAMPLE
    .\Build-ExeIconTheme.ps1 -WhatIf
    .\Build-ExeIconTheme.ps1
    .\Build-ExeIconTheme.ps1 -Register      # elevated
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$IconDir = (Join-Path $HOME '.config\csps-stratum\icons\dock'),
    # Outside AppData on purpose (see Set-DockIcons.ps1)
    [string]$OutDir = (Join-Path $HOME '.config\csps-stratum\icons\exe-theme'),
    [switch]$Register
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class IconGroups {
    delegate bool EnumResNameProc(IntPtr h, IntPtr type, IntPtr name, IntPtr param);
    [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr LoadLibraryExW(string file, IntPtr reserved, uint flags);
    [DllImport("kernel32")] static extern bool FreeLibrary(IntPtr h);
    [DllImport("kernel32", CharSet = CharSet.Unicode)]
    static extern bool EnumResourceNamesW(IntPtr h, IntPtr type, EnumResNameProc cb, IntPtr param);
    // First RT_GROUP_ICON name in enumeration order (= icon index 0), or null.
    public static string First(string file) {
        IntPtr h = LoadLibraryExW(file, IntPtr.Zero, 0x22); // AS_DATAFILE | AS_IMAGE_RESOURCE
        if (h == IntPtr.Zero) return null;
        string first = null;
        EnumResourceNamesW(h, (IntPtr)14, (m, t, n, p) => {
            long v = n.ToInt64();
            first = (v >> 16) == 0 ? v.ToString() : Marshal.PtrToStringUni(n);
            return false;
        }, IntPtr.Zero);
        FreeLibrary(h);
        return first;
    }
}
'@

function Find-Tool([string]$name, [string[]]$globs) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $hit = $globs | ForEach-Object { Get-ChildItem -Path $_ -ErrorAction SilentlyContinue } |
        Sort-Object FullName | Select-Object -Last 1
    if (-not $hit) { throw "$name not found; install the Windows SDK and MSVC build tools" }
    $hit.FullName
}

$pf86 = ${env:ProgramFiles(x86)}
$rc = Find-Tool 'rc.exe' @("$pf86\Windows Kits\10\bin\*\x64\rc.exe")
$link = Find-Tool 'link.exe' @("$pf86\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\link.exe",
                               "$env:ProgramFiles\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\link.exe")

$map = Get-Content -Path (Join-Path $PSScriptRoot 'exe-icons.map') |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    ForEach-Object { $exe, $icon = $_ -split '\|'; [pscustomobject]@{ Exe = $exe; Icon = $icon } }

$work = Join-Path ([IO.Path]::GetTempPath()) "exe-icon-theme-$PID"
$ini = [Collections.Generic.List[string]]::new()
$ini.Add('[redirections]')

foreach ($m in $map) {
    $pattern = [Environment]::ExpandEnvironmentVariables($m.Exe)
    $exe = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    $ico = Join-Path $IconDir "$($m.Icon).ico"
    if (-not $exe) { Write-Host "  [SKIP] $($m.Exe) (not installed)"; continue }
    if (-not (Test-Path -LiteralPath $ico)) { Write-Host "  [SKIP] $($m.Exe) (no $($m.Icon).ico)"; continue }

    # Some apps (Electron, WinUI) set their window icon from a loose .ico file; redirect it to a copy
    if ($exe.Extension -eq '.ico') {
        $copy = "file.$($m.Icon).ico"
        $ini.Add("$($m.Exe)=$copy")
        if ($PSCmdlet.ShouldProcess($exe.Name, "Copy $copy")) {
            New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
            Copy-Item -LiteralPath $ico -Destination (Join-Path $OutDir $copy) -Force
            Write-Host "  [COPY] $copy ($($exe.FullName))"
        }
        continue
    }

    $group = [IconGroups]::First($exe.FullName)
    if (-not $group) { Write-Host "  [SKIP] $($m.Exe) (has no icon resource)"; continue }

    # DLL named after the program and icon, so a changed icon gets a new path (Windows caches icons by path)
    $dll = '{0}.{1}.dll' -f $exe.BaseName.ToLower().Replace(' ', '-'), $m.Icon
    $ini.Add("$($m.Exe)=$dll")
    if (-not $PSCmdlet.ShouldProcess("$($exe.Name) [$group]", "Build $dll")) { continue }

    New-Item -ItemType Directory -Path $work, $OutDir -Force | Out-Null
    # rc takes a bare word as a string name (quoting it would make the quotes part of the name)
    if ($group -notmatch '^(\d+|[A-Za-z_][A-Za-z0-9_]*)$') { Write-Host "  [SKIP] $($m.Exe) (icon name '$group' can't be written in .rc)"; continue }
    $base = Join-Path $work ([IO.Path]::GetFileNameWithoutExtension($dll))
    Set-Content -Path "$base.rc" -Value "$group ICON `"$($ico.Replace('\', '\\'))`"" -Encoding ascii
    & $rc /nologo /fo "$base.res" "$base.rc" | Out-Null
    if ($LASTEXITCODE) { throw "rc failed for $dll" }
    & $link /nologo /dll /noentry /machine:x64 "/out:$(Join-Path $OutDir $dll)" "$base.res" | Out-Null
    if ($LASTEXITCODE) { throw "link failed for $dll" }
    Write-Host "  [BUILD] $dll ($($exe.Name) icon $group)"
}

if ($PSCmdlet.ShouldProcess((Join-Path $OutDir 'theme.ini'), 'Write')) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    Set-Content -Path (Join-Path $OutDir 'theme.ini') -Value $ini -Encoding ascii
    Get-ChildItem -Path $OutDir -Filter '*.lib' | Remove-Item
    Get-ChildItem -Path $OutDir -Filter '*.exp' | Remove-Item
}
if (Test-Path $work) { Remove-Item -Recurse -Force $work }

if ($Register) {
    $key = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\icon-resource-redirect'
    $settings = Get-ItemProperty "$key\Settings"
    $i = 0
    while ($settings."themePaths[$i]" -and $settings."themePaths[$i]" -ne $OutDir) { $i++ }
    if ($settings."themePaths[$i]" -eq $OutDir) { Write-Host "  [OK] already registered as themePaths[$i]" }
    elseif ($PSCmdlet.ShouldProcess("themePaths[$i]", "Set to $OutDir")) {
        $bak = Join-Path $HOME ".config\csps-stratum\backups\icon-resource-redirect-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"
        New-Item -ItemType Directory -Path (Split-Path $bak) -Force | Out-Null
        reg export ($key -replace '^HKLM:', 'HKLM') $bak /y | Out-Null
        Set-ItemProperty "$key\Settings" -Name "themePaths[$i]" -Value $OutDir -Type String
        Set-ItemProperty $key -Name SettingsChangeTime -Value ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -Type DWord
        Write-Host "  [SET] themePaths[$i] (backup: $bak)"
    }
}
