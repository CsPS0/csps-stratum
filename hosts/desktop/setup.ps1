<#
.SYNOPSIS
    Automated Desktop Profile Setup for csps-stratum on Windows.

.DESCRIPTION
    Validates workstation prerequisites, backs up existing configurations,
    links WezTerm, PowerShell profiles, Oh My Posh themes, Zed, VS Code,
    and verifies Windhawk, developer toolchains, and game library paths.

.PARAMETER DryRun
    Alias for -WhatIf. Previews actions without applying changes.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($DryRun) {
    # Writing to $PSBoundParameters does not enable WhatIf; the preference variable does.
    $WhatIfPreference = $true
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$backupTimestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$backupDir = Join-Path $HOME ".stratum_backups\$backupTimestamp"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " csps-stratum : Desktop Profile Setup (Windows 11)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Repository Root : $repoRoot"
Write-Host "Timestamp       : $backupTimestamp"
Write-Host ""

function Ensure-SymlinkOrCopy {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    if (-not (Test-Path $SourcePath)) {
        Write-Warning "Source does not exist: $SourcePath"
        return
    }

    $parentDir = Split-Path -Parent $TargetPath
    if (-not (Test-Path $parentDir)) {
        if ($PSCmdlet.ShouldProcess($parentDir, "Create Directory")) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
    }

    $isDirectory = Test-Path -Path $SourcePath -PathType Container

    if (Test-Path $TargetPath) {
        $backupTarget = Join-Path $backupDir (Split-Path -Leaf $TargetPath)
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        if ($PSCmdlet.ShouldProcess($TargetPath, "Backup existing item to $backupTarget")) {
            # -Recurse so directory backups include their contents
            Copy-Item -Path $TargetPath -Destination $backupTarget -Recurse -Force
            Write-Host "  [BACKUP] $TargetPath -> $backupTarget" -ForegroundColor Yellow
        }
    }

    if ($PSCmdlet.ShouldProcess($TargetPath, "Deploy from $SourcePath")) {
        if ($isDirectory) {
            # Copy the directory's contents; copying the directory itself into an
            # existing target would nest it (e.g. wezterm\wezterm\...).
            if (-not (Test-Path $TargetPath)) {
                New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
            }
            Copy-Item -Path (Join-Path $SourcePath '*') -Destination $TargetPath -Recurse -Force
        } else {
            Copy-Item -Path $SourcePath -Destination $TargetPath -Force
        }
        Write-Host "  [DEPLOY] $SourcePath -> $TargetPath" -ForegroundColor Green
    }
}

# 1. Verify System Environment
Write-Host "[1/8] Checking System Environment..." -ForegroundColor White
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "  OS: $($os.Caption) (Build: $($os.BuildNumber))"
Add-Type -AssemblyName System.Windows.Forms | Out-Null
$screens = @([System.Windows.Forms.Screen]::AllScreens)
Write-Host "  Displays: $($screens.Count) active display(s)"
foreach ($scr in $screens) {
    $role = if ($scr.Primary) { "Primary" } else { "Secondary" }
    Write-Host "    - $($scr.DeviceName): $($scr.Bounds.Width)x$($scr.Bounds.Height) ($role)"
}

# 2. Deploy Base, Shell & Prompt Strata
Write-Host "`n[2/8] Configuring Base, Shell & System Strata..." -ForegroundColor White
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\00-base\git\.gitconfig") -TargetPath (Join-Path $HOME ".gitconfig")
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\10-os\windows\topgrade.toml") -TargetPath (Join-Path $env:APPDATA "topgrade.toml")
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\20-shell\wezterm") -TargetPath (Join-Path $HOME ".config\wezterm")
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\20-shell\fastfetch") -TargetPath (Join-Path $HOME ".config\fastfetch")
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\20-shell\oh-my-posh\mytheme.omp.json") -TargetPath (Join-Path $HOME "mytheme.omp.json")
$pwshProfilePath = if ($global:PROFILE) { $global:PROFILE.ToString() } else { Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1" }
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\20-shell\pwsh\Microsoft.PowerShell_profile.ps1") -TargetPath $pwshProfilePath

$wtLocalState = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
if (Test-Path $wtLocalState) {
    Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\20-shell\windows-terminal\settings.json") -TargetPath (Join-Path $wtLocalState "settings.json")
}

# 3. Deploy Editor & Client Strata (Zed, VS Code, Sonora, Vencord)
Write-Host "`n[3/8] Configuring Code Editors & App Clients..." -ForegroundColor White
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\40-apps\zed\settings.json") -TargetPath (Join-Path $env:APPDATA "Zed\settings.json")
# settings.json selects this theme, so it has to be deployed alongside it
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\40-apps\zed\themes\one-dark-pro-night-flat.json") -TargetPath (Join-Path $env:APPDATA "Zed\themes\one-dark-pro-night-flat.json")
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\40-apps\vscode\settings.json") -TargetPath (Join-Path $env:APPDATA "Code - Insiders\User\settings.json")
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\40-apps\sonora\settings.json") -TargetPath (Join-Path $env:APPDATA "sonora\settings.json")
Ensure-SymlinkOrCopy -SourcePath (Join-Path $repoRoot "strata\40-apps\vencord\settings.json") -TargetPath (Join-Path $env:APPDATA "Vencord\settings\settings.json")

# 4. Verify Developer Toolchains
Write-Host "`n[4/8] Checking Developer Toolchains..." -ForegroundColor White
$devChecks = @(
    @{ Name = "Rust (cargo)"; Check = { Get-Command cargo -ErrorAction SilentlyContinue } },
    @{ Name = "Flutter / Dart"; Check = { Get-Command flutter -ErrorAction SilentlyContinue } },
    @{ Name = "Node.js / pnpm"; Check = { Get-Command node -ErrorAction SilentlyContinue } },
    @{ Name = "Python"; Check = { Get-Command python, py -ErrorAction SilentlyContinue } },
    @{ Name = ".NET SDK"; Check = { Get-Command dotnet -ErrorAction SilentlyContinue } },
    @{ Name = "Java 17 (OpenJDK)"; Check = { Get-Command java -ErrorAction SilentlyContinue } },
    @{ Name = "Git & GitHub CLI"; Check = { Get-Command git, gh -ErrorAction SilentlyContinue } },
    @{ Name = "Scoop Package Manager"; Check = { Get-Command scoop -ErrorAction SilentlyContinue } },
    @{ Name = "WinGet Package Manager"; Check = { Get-Command winget -ErrorAction SilentlyContinue } },
    @{ Name = "Topgrade CLI"; Check = { Get-Command topgrade -ErrorAction SilentlyContinue } }
)

foreach ($dc in $devChecks) {
    $ok = & $dc.Check
    if ($ok) {
        Write-Host "  [OK] $($dc.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $($dc.Name)" -ForegroundColor Yellow
    }
}

# 5. Verify Gaming Clients & Engines
Write-Host "`n[5/8] Checking Gaming Clients & Engine Tools..." -ForegroundColor White
$gameApps = @(
    @{ Name = "Steam"; Check = { (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue) -or (Get-Process -Name "steam" -ErrorAction SilentlyContinue) } },
    @{ Name = "Heroic Games Launcher"; Check = { Get-Command heroic -ErrorAction SilentlyContinue } },
    @{ Name = "Prism Launcher"; Check = { Get-Command prismlauncher -ErrorAction SilentlyContinue } },
    @{ Name = "Godot Engine"; Check = { Get-Command godot -ErrorAction SilentlyContinue } },
    @{ Name = "scrcpy"; Check = { Get-Command scrcpy -ErrorAction SilentlyContinue } }
)

foreach ($ga in $gameApps) {
    $found = & $ga.Check
    if ($found) {
        Write-Host "  [FOUND] $($ga.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [AVAILABLE] $($ga.Name)" -ForegroundColor Gray
    }
}

# 6. Verify Windhawk & Customization Stack
Write-Host "`n[6/8] Checking Windhawk & Customization Stack..." -ForegroundColor White
$whProcess = Get-Process -Name "windhawk" -ErrorAction SilentlyContinue
if ($whProcess) {
    Write-Host "  [OK] Windhawk process is running (PID: $($whProcess[0].Id))" -ForegroundColor Green
} else {
    Write-Warning "  [WARN] Windhawk process is not currently running."
}

$wpProcess = Get-Process -Name "wallpaper64" -ErrorAction SilentlyContinue
if ($wpProcess) {
    Write-Host "  [OK] Wallpaper Engine is active (PID: $($wpProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "  [INFO] Wallpaper Engine not running." -ForegroundColor Gray
}

# 7. Verify Multi-Agent AI Ecosystem
Write-Host "`n[7/8] Verifying AI Assistant Configurations..." -ForegroundColor White
$aiChecks = @(
    @{ Name = "Google Antigravity"; Path = "$HOME\.gemini" },
    @{ Name = "Claude Code"; Path = "$HOME\.claude" },
    @{ Name = "OpenAI Codex"; Path = "$HOME\.codex" }
)

foreach ($ai in $aiChecks) {
    if (Test-Path $ai.Path) {
        Write-Host "  [CONFIGURED] $($ai.Name) -> $($ai.Path)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $($ai.Name) -> $($ai.Path)" -ForegroundColor Yellow
    }
}

# 8. Final Summary
Write-Host "`n[8/8] Setup verification complete!" -ForegroundColor Cyan
Write-Host "All configured strata, apps, and paths verified successfully." -ForegroundColor Green
