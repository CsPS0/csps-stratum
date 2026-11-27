<#
.SYNOPSIS
    Sets the Windows lock screen picture, which the sign-in screen also shows, to a still of OLED
    Span (stills\contours-1920x1080.png by default). Saves the current picture first.
.DESCRIPTION
    Uses the Windows.System.UserProfile.LockScreen API, so it needs no administrator rights and
    changes only this user's lock screen. The WinRT calls work only in Windows PowerShell 5.1; from
    PowerShell 7 the script runs itself again under powershell.exe.
    The sign-in screen shows the lock picture unless "Show the lock screen background picture on the
    sign-in screen" is off (Settings > Personalization > Lock screen).
.EXAMPLE
    .\Set-LockScreen.ps1 -WhatIf
    .\Set-LockScreen.ps1
    .\Set-LockScreen.ps1 -Image "$HOME\.stratum_backups\lockscreen\lockscreen-<time>.png"   # undo
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Image = (Join-Path $PSScriptRoot 'stills\contours-1920x1080.png'),
    [string]$BackupDir = (Join-Path $HOME '.stratum_backups\lockscreen')
)
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    $argsList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Image', $Image, '-BackupDir', $BackupDir)
    if ($WhatIfPreference) { $argsList += '-WhatIf' }
    & powershell.exe @argsList
    exit $LASTEXITCODE
}

$Image = (Resolve-Path -LiteralPath $Image).Path

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]

function Wait-Operation($Operation, [Type]$ResultType) {
    $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    $task = $asTask.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $null = $task.Wait(-1)
    $task.Result
}

function Wait-Action($Action) {
    $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
    } | Select-Object -First 1
    $null = $asTask.Invoke($null, @($Action)).Wait(-1)
}

# Back up the current picture.
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $BackupDir "lockscreen-$stamp.png"
if ($PSCmdlet.ShouldProcess($backup, 'Save the current lock screen picture')) {
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    $current = [Windows.System.UserProfile.LockScreen]::GetImageStream()
    if ($current) {
        $in = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($current)
        $out = [System.IO.File]::Create($backup)
        try { $in.CopyTo($out) } finally { $out.Dispose(); $in.Dispose() }
        Write-Host "backup: $backup"
    }
}

if ($PSCmdlet.ShouldProcess($Image, 'Set as the lock screen picture')) {
    $file = Wait-Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Image)) ([Windows.Storage.StorageFile])
    Wait-Action ([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($file))
    Write-Host "lock screen picture: $Image"
}
