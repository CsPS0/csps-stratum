<#
.SYNOPSIS
    Builds menubar.exe (Visual C++ build tools) and installs it with menubar.ini next to YASB's config.

.DESCRIPTION
    -Autostart also registers a "MenuBar" sign-in scheduled task for the current user (needs an
    elevated prompt). A Run-key entry was used before, but Explorer skipped it at sign-in.
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
    if (-not $Autostart) { Start-Process $exe }   # with -Autostart the task starts it, un-elevated
    Write-Host "Installed $exe"
}

if ($Autostart -and $PSCmdlet.ShouldProcess('Scheduled task \MenuBar', "Start $exe at sign-in")) {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><LogonTrigger><Enabled>true</Enabled><UserId>$sid</UserId></LogonTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>$sid</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author"><Exec><Command>"$exe"</Command></Exec></Actions>
</Task>
"@
    $xmlFile = Join-Path ([IO.Path]::GetTempPath()) "menubar-task-$PID.xml"
    Set-Content -Path $xmlFile -Value $xml -Encoding Unicode
    schtasks /create /tn MenuBar /xml $xmlFile /f
    $failed = $LASTEXITCODE
    Remove-Item $xmlFile
    if ($failed) { throw 'creating the MenuBar task failed (run from an elevated prompt)' }
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name MenuBar -ErrorAction SilentlyContinue
    schtasks /run /tn MenuBar | Out-Null
    Write-Host 'MenuBar starts at sign-in (scheduled task \MenuBar)'
}
