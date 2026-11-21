<#
.SYNOPSIS
    Builds menubar.exe (Visual C++ build tools) and installs it with menubar.ini next to YASB's config.

.DESCRIPTION
    -Autostart also adds it to the current user's startup programs (HKCU Run "MenuBar").
    The running copy is stopped before it is replaced and started again afterwards.

.EXAMPLE
    .\Build-MenuBar.ps1 -WhatIf
    .\Build-MenuBar.ps1 -Autostart
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$OutDir = (Join-Path $HOME '.config\yasb\menubar'),
    [switch]$Autostart
)

$ErrorActionPreference = 'Stop'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = & $vswhere -latest -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual C++ build tools not found (install the "Desktop development with C++" workload)' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$exe = Join-Path $OutDir 'menubar.exe'

if ($PSCmdlet.ShouldProcess($OutDir, 'Build and install menubar.exe and menubar.ini')) {
    $obj = Join-Path ([IO.Path]::GetTempPath()) "menubar-build-$PID"
    New-Item -ItemType Directory -Path $obj, $OutDir -Force | Out-Null
    $src = Join-Path $PSScriptRoot 'menubar.cpp'
    $tmpExe = Join-Path $obj 'menubar.exe'
    cmd /c "`"$vcvars`" >nul && cl /nologo /O2 /EHsc /W3 /utf-8 /DUNICODE /D_UNICODE /Fo`"$obj\\`" `"$src`" /Fe:`"$tmpExe`" /link /SUBSYSTEM:WINDOWS"
    if ($LASTEXITCODE) { throw 'build failed' }
    Get-Process menubar -ErrorAction SilentlyContinue | Where-Object Path -eq $exe | Stop-Process
    Start-Sleep -Milliseconds 300
    Copy-Item $tmpExe $exe -Force
    Copy-Item (Join-Path $PSScriptRoot 'menubar.ini') $OutDir -Force
    Remove-Item $obj -Recurse -Force
    Start-Process $exe
    Write-Host "Installed and started $exe"
}

if ($Autostart -and $PSCmdlet.ShouldProcess('HKCU Run\MenuBar', "Start $exe at sign-in")) {
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name MenuBar -Value "`"$exe`""
}
