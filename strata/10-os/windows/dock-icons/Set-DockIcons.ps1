<#
.SYNOPSIS
    Points pinned taskbar (and optionally Start menu) shortcuts at monochrome .ico files.

.DESCRIPTION
    Reads icons.map and sets each pinned shortcut's IconLocation to <IconDir>\<icon>.ico.
    With -IncludeStartMenu, Start menu shortcuts that launch the same program (or have the
    same name) get the same icon; the all-users Start menu needs an elevated session.
    Every changed shortcut is first copied to a timestamped backup folder together with a
    manifest of its original path. Supports -WhatIf. Use -Restore <backup folder> to undo.

.EXAMPLE
    .\Set-DockIcons.ps1 -WhatIf
    .\Set-DockIcons.ps1 -IncludeStartMenu
    .\Set-DockIcons.ps1 -Restore "$HOME\.config\csps-stratum\backups\taskbar-pins-20261121-130041"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # Outside AppData on purpose: files a packaged app (e.g. an MSIX terminal) creates under
    # AppData get redirected into its private package store, where Explorer can't see them.
    [string]$IconDir = (Join-Path $HOME '.config\csps-stratum\icons\dock'),
    [switch]$IncludeStartMenu,
    [string]$Restore
)

$ErrorActionPreference = 'Stop'
$pinDir = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'

if ($Restore) {
    $manifest = Join-Path $Restore 'manifest.csv'
    $items = if (Test-Path $manifest) { Import-Csv $manifest } else {
        # backups made before the manifest existed only held taskbar pins
        Get-ChildItem -Path $Restore -Filter '*.lnk' | ForEach-Object { [pscustomobject]@{ Backup = $_.Name; Original = Join-Path $pinDir $_.Name } }
    }
    foreach ($i in $items) {
        if ($PSCmdlet.ShouldProcess($i.Original, 'Restore shortcut')) {
            Copy-Item -LiteralPath (Join-Path $Restore $i.Backup) -Destination $i.Original -Force
            Write-Host "  [RESTORE] $($i.Original)"
        }
    }
    return
}

# Icon files are named after the icon, not the app: Windows caches icons by path,
# so a new icon needs a new file name to show up.
$map = Get-Content -Path (Join-Path $PSScriptRoot 'icons.map') |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    ForEach-Object { $name, $icon = $_ -split '\|'; [pscustomobject]@{ Name = $name; Icon = $icon } }

$shell = New-Object -ComObject WScript.Shell
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')

$startLinks = @()
if ($IncludeStartMenu) {
    $roots = @(Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs')
    if ($isAdmin) { $roots += Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs' }
    else { Write-Host '  [INFO] not elevated: skipping the all-users Start menu' }
    $startLinks = foreach ($r in $roots) {
        Get-ChildItem -LiteralPath $r -Recurse -Filter '*.lnk' -ErrorAction SilentlyContinue |
            ForEach-Object { [pscustomobject]@{ Path = $_.FullName; Name = $_.BaseName; Target = $shell.CreateShortcut($_.FullName).TargetPath } }
    }
}

# Windows renames pinned shortcuts whenever it rewrites a pin ("Brave (10).lnk"), so match on the
# name without that " (n)" suffix; map names may also use * (e.g. "JetBrains Rider*" for its version).
$pins = Get-ChildItem -LiteralPath $pinDir -Filter '*.lnk' |
    ForEach-Object { [pscustomobject]@{ Path = $_.FullName; Name = ($_.BaseName -replace ' \(\d+\)$', '') } }

# Collect every shortcut to change: the taskbar pin plus matching Start menu entries
$jobs = foreach ($entry in $map) {
    $pin = ($pins | Where-Object { $_.Name -like $entry.Name } | Select-Object -First 1).Path
    $ico = Join-Path $IconDir "$($entry.Icon).ico"
    if (-not $pin) { Write-Host "  [SKIP] $($entry.Name) (not pinned)"; continue }
    if (-not (Test-Path -LiteralPath $ico)) { Write-Host "  [SKIP] $($entry.Name) (no icon)"; continue }
    [pscustomobject]@{ Label = $entry.Name; Path = $pin; Icon = $ico }
    $target = $shell.CreateShortcut($pin).TargetPath
    foreach ($s in $startLinks) {
        if (($target -and $s.Target -eq $target) -or $s.Name -like $entry.Name) {
            [pscustomobject]@{ Label = "$($entry.Name) (Start: $($s.Name))"; Path = $s.Path; Icon = $ico }
        }
    }
}

$backup = Join-Path $HOME ".config\csps-stratum\backups\taskbar-pins-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$manifest = @()
$n = 0
foreach ($j in $jobs) {
    if ($PSCmdlet.ShouldProcess($j.Label, "Set icon to $($j.Icon)")) {
        if (-not (Test-Path $backup)) { New-Item -ItemType Directory -Path $backup -Force | Out-Null }
        $n++
        $copy = '{0:D3}-{1}' -f $n, (Split-Path $j.Path -Leaf)
        Copy-Item -LiteralPath $j.Path -Destination (Join-Path $backup $copy)
        $manifest += [pscustomobject]@{ Backup = $copy; Original = $j.Path }
        $lnk = $shell.CreateShortcut($j.Path)
        $lnk.IconLocation = "$($j.Icon),0"
        $lnk.Save()
        Write-Host "  [SET] $($j.Label)"
    }
}
if ($manifest) {
    $manifest | Export-Csv (Join-Path $backup 'manifest.csv') -NoTypeInformation
    Write-Host "Backup: $backup"
}
