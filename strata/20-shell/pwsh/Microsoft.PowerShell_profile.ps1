# Restore Oh My Posh
oh-my-posh init pwsh --config "$HOME\mytheme.omp.json" | Invoke-Expression

# WezTerm OSC 7 CWD tracking for PowerShell
if ($host.Name -match "ConsoleHost") {
    if (Test-Path Function:\prompt) {
        Rename-Item Function:\prompt WezTerm-Backup-Prompt -ErrorAction SilentlyContinue
    } else {
        function WezTerm-Backup-Prompt { "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) " }
    }

    function prompt {
        $path = $executionContext.SessionState.Path.CurrentLocation
        $pathUri = [uri]$path.ProviderPath
        # Send OSC 7 escape sequence
        Write-Host -NoNewline "`e]7;$pathUri`a"
        
        # Call the original prompt (Oh My Posh)
        WezTerm-Backup-Prompt
    }
}
