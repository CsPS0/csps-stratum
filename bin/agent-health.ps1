<#
.SYNOPSIS
    Read-only health check for the Claude Code and Antigravity configs on the desktop.

.DESCRIPTION
    Compares the live agent configs with what csps-stratum expects and reports drift.
    It never changes a config file. The only thing it writes is the report file
    (skipped with -WhatIf).

    Checks:
      - ~/.claude/settings.json: deny and ask rules, deniedMcpServers and the guard hook
        match strata/30-dev/ai/claude-settings.json; no Roblox hooks (Roblox Studio
        updates re-add them).
      - ~/.claude.json: Roblox_Studio and dart are not at user scope.
      - Antigravity: remote control off, sandbox on, non-workspace access not enabled,
        the permission preset, the trusted workspaces, the .ssh deny rules (app and CLI),
        no relative file rules, the disabled plugins (from
        strata/30-dev/ai/antigravity.yaml) and the MCP server list.
      - ~/.agents/ENV.md is identical to hosts/desktop/ENV.md (line endings ignored).

    Exit codes: 0 = all OK, 1 = differences found, 2 = a file could not be read.

.PARAMETER ReportDir
    Folder for the dated report file. Default: ~/agent-config-backup/health.

.EXAMPLE
    pwsh -NoProfile -File bin/agent-health.ps1
.EXAMPLE
    pwsh -NoProfile -File bin/agent-health.ps1 -WhatIf   # report to the console only
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ReportDir = (Join-Path $HOME 'agent-config-backup\health')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$aiDir = Join-Path $repoRoot 'strata\30-dev\ai'

# Expected Antigravity values that have no machine-readable snapshot in the repo.
$expectedTrusted = @(
    'D:\REPOS',
    'D:\REPOS\Neumann-Survival-Week\HORROR-GAME'
)
$expectedAgyMcp = @('github', 'serena', 'trello', 'vercel')
$sshPath = (Join-Path $HOME '.ssh') -replace '\\', '/'
$expectedSshRules = @("read_file($sshPath)", "write_file($sshPath)")

$lines = [System.Collections.Generic.List[string]]::new()
$script:diffs = 0
$script:readErrors = 0

function Add-Result([bool]$Ok, [string]$Text) {
    if ($Ok) { $lines.Add("[OK]   $Text") } else { $lines.Add("[DIFF] $Text"); $script:diffs++ }
}

function Read-Json([string]$Path) {
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { $lines.Add("[ERR]  cannot read $Path : $($_.Exception.Message)"); $script:readErrors++; return $null }
}

# Compares two string lists; a <placeholder> in the expected list matches a connector UUID.
function Compare-RuleList([string]$Name, [string[]]$Expected, [string[]]$Actual) {
    $uuid = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
    $remaining = [System.Collections.Generic.List[string]]::new()
    $Actual | ForEach-Object { $remaining.Add($_) }
    $missing = @()
    foreach ($e in $Expected) {
        $pattern = '^' + (([regex]::Escape($e)) -replace '<[^>]+>', $uuid) + '$'
        $hit = $remaining | Where-Object { $_ -match $pattern } | Select-Object -First 1
        if ($null -ne $hit) { [void]$remaining.Remove($hit) } else { $missing += $e }
    }
    $ok = ($missing.Count -eq 0 -and $remaining.Count -eq 0)
    $detail = "$($Actual.Count) of $($Expected.Count) expected"
    if ($missing) { $detail += "; missing: $($missing -join ', ')" }
    if ($remaining.Count) { $detail += "; extra: $($remaining -join ', ')" }
    Add-Result $ok "$Name ($detail)"
}

function Compare-Set([string]$Name, [string[]]$Expected, [string[]]$Actual) {
    $missing = $Expected | Where-Object { $_ -notin $Actual }
    $extra = $Actual | Where-Object { $_ -notin $Expected }
    $detail = ($Actual -join ', ')
    if ($missing) { $detail += "; missing: $($missing -join ', ')" }
    if ($extra) { $detail += "; extra: $($extra -join ', ')" }
    Add-Result (-not $missing -and -not $extra) "$Name ($detail)"
}

$lines.Add("agent-health $(Get-Date -Format 'yyyy-MM-dd HH:mm') on $env:COMPUTERNAME")

# --- Claude Code ---------------------------------------------------------------
$snap = Read-Json (Join-Path $aiDir 'claude-settings.json')
$live = Read-Json (Join-Path $HOME '.claude\settings.json')
if ($snap -and $live) {
    Compare-RuleList 'Claude deny rules' $snap.permissions.deny $live.permissions.deny
    Compare-RuleList 'Claude ask rules' $snap.permissions.ask $live.permissions.ask
    Compare-Set 'Claude deniedMcpServers' @($snap.deniedMcpServers.serverName) @($live.deniedMcpServers.serverName)

    $hookCommands = foreach ($evt in $live.hooks.PSObject.Properties) {
        foreach ($m in $evt.Value) { foreach ($h in $m.hooks) { [pscustomobject]@{ Event = $evt.Name; Matcher = $m.matcher; Command = $h.command } } }
    }
    $guard = $hookCommands | Where-Object { $_.Event -eq 'PreToolUse' -and $_.Matcher -eq 'Bash|PowerShell' -and $_.Command -match 'guard-destructive\.ps1' }
    $guardFile = Join-Path $HOME '.claude\hooks\guard-destructive.ps1'
    Add-Result ([bool]$guard -and (Test-Path -LiteralPath $guardFile)) "Claude guard hook (settings entry: $([bool]$guard), script file: $(Test-Path -LiteralPath $guardFile))"

    $roblox = @($hookCommands | Where-Object { $_.Command -match '(?i)roblox' -or $_.Matcher -match '(?i)roblox' })
    Add-Result ($roblox.Count -eq 0) "No Roblox hooks in ~/.claude/settings.json (found: $($roblox.Count)$(if ($roblox) { ' in ' + (($roblox.Event | Select-Object -Unique) -join ', ') }))"
}

$claudeJson = Read-Json (Join-Path $HOME '.claude.json')
if ($claudeJson) {
    $userMcp = @($claudeJson.mcpServers.PSObject.Properties.Name)
    $bad = @($userMcp | Where-Object { $_ -in 'Roblox_Studio', 'dart' })
    Add-Result ($bad.Count -eq 0) "No Roblox_Studio or dart at user scope (user scope: $($userMcp -join ', '))"
}

# --- Antigravity ---------------------------------------------------------------
$agyCfg = Read-Json (Join-Path $HOME '.gemini\config\config.json')
if ($agyCfg) {
    $us = $agyCfg.userSettings
    Add-Result ($us.remoteControlEnabled -eq $false) "Antigravity remote control off (remoteControlEnabled: $($us.remoteControlEnabled))"
    Add-Result ($us.enableTerminalSandbox -eq $true) "Antigravity app sandbox on (enableTerminalSandbox: $($us.enableTerminalSandbox))"
    $missingAppSsh = @($expectedSshRules | Where-Object { $_ -notin @($us.globalPermissionGrants.deny) })
    Add-Result ($missingAppSsh.Count -eq 0) "Antigravity app .ssh deny rules with drive letter$(if ($missingAppSsh) { '; missing: ' + ($missingAppSsh -join ', ') })"

    $yaml = Get-Content -LiteralPath (Join-Path $aiDir 'antigravity.yaml') -Raw
    # Stored values seen in config.json; the docs don't list them, so only observed ones are mapped.
    $presetValues = @{
        'Auto'    = 'AGENT_PERMISSION_PRESET_AUTO'
        'Default' = 'AGENT_PERMISSION_PRESET_DEFAULT'
    }
    if ($yaml -match '(?m)^\s*preset:\s*"([^"]+)"') {
        $presetName = $Matches[1]
        $presetWanted = $presetValues[$presetName]
        $presetNote = if ($presetWanted) { '' } else { " (no known stored value for '$presetName' yet)" }
        Add-Result ($null -ne $presetWanted -and $us.permissionPreset -eq $presetWanted) "Antigravity permission preset is $presetName (permissionPreset: $($us.permissionPreset))$presetNote"
    } else {
        $lines.Add('[ERR]  preset not found in antigravity.yaml'); $script:readErrors++
    }

    if ($yaml -match 'disabled_plugins:\s*\[([^\]]*)\]') {
        $expectedOff = @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ })
        $actualOff = @($agyCfg.plugins.PSObject.Properties | Where-Object { $_.Value.enabled -eq $false } | ForEach-Object { $_.Name })
        Compare-Set 'Antigravity disabled plugins' $expectedOff $actualOff
    } else {
        $lines.Add('[ERR]  disabled_plugins not found in antigravity.yaml'); $script:readErrors++
    }
}

$agyCli = Read-Json (Join-Path $HOME '.gemini\antigravity-cli\settings.json')
if ($agyCli) {
    Add-Result ($agyCli.enableTerminalSandbox -eq $true) "Antigravity CLI sandbox on (enableTerminalSandbox: $($agyCli.enableTerminalSandbox))"
    # agy drops allowNonWorkspaceAccess when it rewrites the file; absent means the default, false.
    Add-Result ($agyCli.allowNonWorkspaceAccess -ne $true) "Antigravity CLI non-workspace access off (allowNonWorkspaceAccess: $(if ($null -eq $agyCli.allowNonWorkspaceAccess) { 'absent = false' } else { $agyCli.allowNonWorkspaceAccess }))"
    Compare-Set 'Antigravity CLI trustedWorkspaces' $expectedTrusted @($agyCli.trustedWorkspaces)
    $missingSsh = @($expectedSshRules | Where-Object { $_ -notin @($agyCli.permissions.deny) })
    Add-Result ($missingSsh.Count -eq 0) "Antigravity CLI .ssh deny rules with drive letter$(if ($missingSsh) { '; missing: ' + ($missingSsh -join ', ') })"
}

# A read_file/write_file rule without a drive letter breaks the Windows terminal sandbox
# ("non-absolute file path"), and agy then reruns the command outside the sandbox.
# App rules (config.json globalPermissionGrants) are shared with the CLI, so check both.
$fileRules = @()
if ($agyCli) { $fileRules += @($agyCli.permissions.PSObject.Properties | ForEach-Object { $_.Value }) }
if ($agyCfg) { $fileRules += @($agyCfg.userSettings.globalPermissionGrants.PSObject.Properties | ForEach-Object { $_.Value }) }
$relative = @($fileRules | Where-Object { $_ -match '^(read_file|write_file)\((?![A-Za-z]:[\\/])[^)]*\)$' })
Add-Result ($relative.Count -eq 0) "Antigravity file rules all absolute (sandbox-safe)$(if ($relative) { '; relative: ' + ($relative -join ', ') })"

$agyMcp = Read-Json (Join-Path $HOME '.gemini\config\mcp_config.json')
if ($agyMcp) {
    Compare-Set 'Antigravity MCP servers' $expectedAgyMcp @($agyMcp.mcpServers.PSObject.Properties.Name)
}

# --- Shared rules ---------------------------------------------------------------
$envLive = Join-Path $HOME '.agents\ENV.md'
$envRepo = Join-Path $repoRoot 'hosts\desktop\ENV.md'
if ((Test-Path -LiteralPath $envLive) -and (Test-Path -LiteralPath $envRepo)) {
    $a = (Get-Content -LiteralPath $envLive -Raw) -replace "`r`n", "`n"
    $b = (Get-Content -LiteralPath $envRepo -Raw) -replace "`r`n", "`n"
    Add-Result ($a -ceq $b) '~/.agents/ENV.md identical to hosts/desktop/ENV.md'
} else {
    $lines.Add("[ERR]  ENV.md missing (live: $(Test-Path -LiteralPath $envLive), repo: $(Test-Path -LiteralPath $envRepo))"); $script:readErrors++
}

# --- Result ---------------------------------------------------------------------
$exitCode = if ($script:readErrors) { 2 } elseif ($script:diffs) { 1 } else { 0 }
$lines.Add($(switch ($exitCode) {
    0 { 'RESULT: OK' }
    1 { "RESULT: $($script:diffs) difference(s)" }
    2 { "RESULT: $($script:readErrors) read error(s), $($script:diffs) difference(s)" }
}))

$lines | ForEach-Object { Write-Output $_ }

$reportFile = Join-Path $ReportDir ("{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd'))
if ($PSCmdlet.ShouldProcess($reportFile, 'Write health report')) {
    New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
    $lines | Set-Content -LiteralPath $reportFile -Encoding utf8
    Write-Output "Report: $reportFile"
}

exit $exitCode
