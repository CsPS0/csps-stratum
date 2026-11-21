<#
.SYNOPSIS
    Master Stratum Orchestration CLI for Windows (PowerShell 7+).

.DESCRIPTION
    Dispatches profile synchronizations, validation checks, and stratum deployments
    across workstation and portable environments.

.PARAMETER Command
    Action to perform: sync, check, status, list. Default is 'check'.

.PARAMETER Profile
    Target host profile name (e.g., 'desktop', 'laptop', 'mobile').

.PARAMETER DryRun
    Preview actions without applying changes (alias for -WhatIf).
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('sync', 'check', 'status', 'list', 'diff', 'doctor')]
    [string]$Command = 'check',

    [Parameter(Position = 1)]
    [Alias('Profile')]
    [string]$ProfileName = 'desktop',

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($DryRun) {
    # Writing to $PSBoundParameters does not enable WhatIf; the preference variable does.
    $WhatIfPreference = $true
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$hostsDir = Join-Path $repoRoot "hosts"

Write-Host ">>> csps-stratum CLI Orchestrator" -ForegroundColor Cyan
Write-Host "    Repository: $repoRoot"
Write-Host "    Action    : $Command"
Write-Host "    Profile   : $ProfileName"
Write-Host ""

switch ($Command) {
    'list' {
        Write-Host "Available Host Profiles:" -ForegroundColor White
        Get-ChildItem -Path $hostsDir -Directory | ForEach-Object {
            $hasPs = Test-Path (Join-Path $_.FullName "setup.ps1")
            $status = if ($hasPs) {
                "[Active Local Setup]"
            } else {
                "[Inventory & Specs]"
            }
            Write-Host "  - $($_.Name) $status" -ForegroundColor Green
        }
        Write-Host "`nAvailable Configuration Strata:" -ForegroundColor White
        Get-ChildItem -Path (Join-Path $repoRoot "strata") -Directory | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor Yellow
        }
    }

    'status' {
        Write-Host "System Status & Environment Check:" -ForegroundColor White
        $os = Get-CimInstance Win32_OperatingSystem
        Write-Host "  OS         : $($os.Caption) (Build $($os.BuildNumber))"
        Write-Host "  Machine    : $env:COMPUTERNAME"
        Write-Host "  User       : $env:USERNAME"
        Write-Host "  PowerShell : $($PSVersionTable.PSVersion)"

        # Check ADB device status if available
        $adb = Get-Command adb -ErrorAction SilentlyContinue
        if ($adb) {
            $devices = & $adb.Source devices | Where-Object { $_ -match "\tdevice" }
            if ($devices) {
                Write-Host "  Mobile ADB : $($devices.Count) connected Android device(s)" -ForegroundColor Green
            } else {
                Write-Host "  Mobile ADB : Daemon running (0 active devices)" -ForegroundColor Gray
            }
        }
    }

    'doctor' {
        Write-Host "Running csps-stratum Diagnostics..." -ForegroundColor White
        $checks = @(
            @{ Name = "Git CLI"; Check = { Get-Command git -ErrorAction SilentlyContinue } },
            @{ Name = "Git LFS"; Check = { Get-Command git-lfs -ErrorAction SilentlyContinue } },
            @{ Name = "PowerShell 7+"; Check = { $PSVersionTable.PSVersion.Major -ge 7 } },
            @{ Name = "WinGet Package Manager"; Check = { Get-Command winget -ErrorAction SilentlyContinue } },
            @{ Name = "Scoop Package Manager"; Check = { Get-Command scoop -ErrorAction SilentlyContinue } },
            @{ Name = "Topgrade CLI"; Check = { Get-Command topgrade -ErrorAction SilentlyContinue } },
            @{ Name = "Android ADB Bridge"; Check = { Get-Command adb -ErrorAction SilentlyContinue } }
        )

        $allOk = $true
        foreach ($c in $checks) {
            $res = & $c.Check
            if ($res) {
                Write-Host "  [PASS] $($c.Name)" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] $($c.Name) not found or not ready" -ForegroundColor Yellow
                $allOk = $false
            }
        }
        if ($allOk) {
            Write-Host "`nAll core prerequisites and mount targets are healthy!" -ForegroundColor Green
        }
    }

    'diff' {
        Write-Host "Auditing Configuration Drift (Live System vs Repository)..." -ForegroundColor White
        $driftPairs = @(
            @{ Name = "Git Config"; Live = (Join-Path $HOME ".gitconfig"); Repo = (Join-Path $repoRoot "strata\00-base\git\.gitconfig") },
            @{ Name = "Topgrade"; Live = (Join-Path $env:APPDATA "topgrade.toml"); Repo = (Join-Path $repoRoot "strata\10-os\windows\topgrade.toml") },
            @{ Name = "PowerShell Profile"; Live = (Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"); Repo = (Join-Path $repoRoot "strata\20-shell\pwsh\Microsoft.PowerShell_profile.ps1") },
            @{ Name = "Oh My Posh Theme"; Live = (Join-Path $HOME "mytheme.omp.json"); Repo = (Join-Path $repoRoot "strata\20-shell\oh-my-posh\mytheme.omp.json") },
            @{ Name = "Fastfetch Config"; Live = (Join-Path $HOME ".config\fastfetch\config.jsonc"); Repo = (Join-Path $repoRoot "strata\20-shell\fastfetch\config.jsonc") },
            @{ Name = "Zed Settings"; Live = (Join-Path $env:APPDATA "Zed\settings.json"); Repo = (Join-Path $repoRoot "strata\40-apps\zed\settings.json") }
        )

        $driftCount = 0
        foreach ($pair in $driftPairs) {
            if (-not (Test-Path $pair.Live)) {
                Write-Host "  [MISSING IN SYSTEM] $($pair.Name): $($pair.Live)" -ForegroundColor Yellow
                $driftCount++
                continue
            }
            if (-not (Test-Path $pair.Repo)) {
                Write-Host "  [MISSING IN REPO]   $($pair.Name): $($pair.Repo)" -ForegroundColor Yellow
                $driftCount++
                continue
            }

            $liveContent = Get-Content -Path $pair.Live -Raw
            $repoContent = Get-Content -Path $pair.Repo -Raw

            # Normalize CRLF / LF for comparison
            $liveNorm = $liveContent -replace "\r\n", "`n"
            $repoNorm = $repoContent -replace "\r\n", "`n"

            if ($liveNorm.Trim() -eq $repoNorm.Trim()) {
                Write-Host "  [IN SYNC]  $($pair.Name)" -ForegroundColor Green
            } else {
                Write-Host "  [DRIFTED]  $($pair.Name) differs from repository!" -ForegroundColor Yellow
                $driftCount++
            }
        }

        if ($driftCount -eq 0) {
            Write-Host "`nAll checked configurations are 100% in sync with the repository." -ForegroundColor Green
        } else {
            Write-Host "`n$driftCount configuration(s) differ or are missing. Run sync to synchronize." -ForegroundColor Yellow
        }
    }

    'check' {
        if ($ProfileName -eq 'mobile') {
            Write-Host "Mobile Profile: Hardware and software specifications tracked in hosts/mobile/" -ForegroundColor White
            $adb = Get-Command adb -ErrorAction SilentlyContinue
            if ($adb) {
                $devices = & $adb.Source devices | Where-Object { $_ -match "\tdevice" }
                Write-Host "  [INFO] Attached ADB target(s): $($devices.Count)" -ForegroundColor Cyan
            }
            return
        }

        $targetScript = Join-Path $hostsDir "$ProfileName\setup.ps1"
        if (-not (Test-Path $targetScript)) {
            Write-Error "Profile '$ProfileName' does not contain a setup.ps1 script at '$targetScript'."
        }
        Write-Host "Executing validation check for profile '$ProfileName'..." -ForegroundColor White
        & $targetScript -WhatIf
    }

    'sync' {
        if ($ProfileName -eq 'mobile') {
            Write-Host "Profile 'mobile' is an inventory and hardware profile. No automated script deployment required." -ForegroundColor Yellow
            return
        }

        $targetScript = Join-Path $hostsDir "$ProfileName\setup.ps1"
        if (-not (Test-Path $targetScript)) {
            Write-Error "Profile '$ProfileName' does not contain a setup.ps1 script at '$targetScript'."
        }

        if ($PSCmdlet.ShouldProcess("Profile '$ProfileName'", "Synchronize and deploy configurations")) {
            & $targetScript
        } else {
            & $targetScript -WhatIf
        }
    }
}
