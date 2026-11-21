local wezterm = require 'wezterm'
local module = {}

function module.apply_to_config(config)
  config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
  
  if not config.keys then config.keys = {} end

  local keys = {
    -- Leader key passthrough
    { key = 'a', mods = 'LEADER|CTRL', action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' } },

    { key = 'P', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateCommandPalette },
    { key = 'v', mods = 'LEADER', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = 's', mods = 'LEADER', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'z', mods = 'LEADER', action = wezterm.action.TogglePaneZoomState },
    { key = 'c', mods = 'LEADER', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
    { key = 'Enter', mods = 'LEADER', action = wezterm.action.ActivateCopyMode },
    { key = 'f', mods = 'CTRL|SHIFT', action = wezterm.action.Search 'CurrentSelectionOrEmptyString' },
    { key = 'x', mods = 'CTRL|SHIFT', action = wezterm.action.QuickSelect },
    { key = 's', mods = 'ALT', action = wezterm.action.ShowLauncherArgs { flags = 'WORKSPACES' } },
    { key = 'p', mods = 'CTRL', action = wezterm.action.QuickSelectArgs { label = 'Select file', patterns = { '[a-zA-Z]:\\\\(?:[^\\\\\\/:*?"<>|\\r\\n]+\\\\)*[^\\\\\\/:*?"<>|\\r\\n]*' } } },
    
    -- F1 Fix: Open current directory in explorer
    {
      key = 'F1',
      mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
        local cwd = pane:get_current_working_dir()
        if cwd then
          local path = cwd.file_path
          -- Windows esetén, ha az útvonal /C:/ formátumú, vágjuk le az elejéről a perjelet
          if path:match("^/[A-Za-z]:") then
            path = path:sub(2)
          end
          path = path:gsub("/", "\\")
          wezterm.background_child_process { 'explorer.exe', path }
        end
      end),
    },

    -- Smart Copy
    {
      key = 'c',
      mods = 'CTRL',
      action = wezterm.action_callback(function(window, pane)
        local has_selection = window:get_selection_text_for_pane(pane) ~= ''
        if has_selection then
          window:perform_action(wezterm.action.CopyTo 'ClipboardAndPrimarySelection', pane)
          window:perform_action(wezterm.action.ClearSelection, pane)
        else
          window:perform_action(wezterm.action.SendKey { key = 'c', mods = 'CTRL' }, pane)
        end
      end),
    },
    -- Smart Paste
    { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom 'Clipboard' },

    -- Dynamic Workspace Manager (Projects / Repos)
    -- Leader+w (Ctrl+Shift+W stays "close pane"). Base dir: $env:WEZTERM_PROJECTS_DIR,
    -- else the first non-empty of ~/Projects, D:/Projects, ~/source/repos.
    {
      key = 'w',
      mods = 'LEADER',
      action = wezterm.action_callback(function(window, pane)
        local success, stdout, stderr = wezterm.run_child_process {
          'pwsh', '-NoProfile', '-Command',
          '$baseDir = @($env:WEZTERM_PROJECTS_DIR, "$HOME/Projects", "D:/Projects", "$HOME/source/repos") | Where-Object { $_ -and (Get-ChildItem -Path $_ -Directory -ErrorAction SilentlyContinue) } | Select-Object -First 1; if ($baseDir) { (Get-ChildItem -Path $baseDir -Directory -Depth 1 -ErrorAction SilentlyContinue).FullName }'
        }
        
        local choices = {}
        if success then
          for line in stdout:gmatch("([^\r\n]+)") do
            local label = line:match("([^\\]+)$")
            if label then
              table.insert(choices, { label = label, id = line })
            end
          end
        end

        window:perform_action(
          wezterm.action.InputSelector {
            action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
              if id then
                inner_window:perform_action(
                  wezterm.action.SwitchToWorkspace {
                    name = label,
                    spawn = { cwd = id },
                  },
                  inner_pane
                )
              end
            end),
            title = 'Select Workspace',
            choices = choices,
          },
          pane
        )
      end),
    },

    -- Rapid Tab Switching
    { key = '1', mods = 'ALT', action = wezterm.action.ActivateTab(0) },
    { key = '2', mods = 'ALT', action = wezterm.action.ActivateTab(1) },
    { key = '3', mods = 'ALT', action = wezterm.action.ActivateTab(2) },
    { key = '4', mods = 'ALT', action = wezterm.action.ActivateTab(3) },
    { key = '5', mods = 'ALT', action = wezterm.action.ActivateTab(4) },
    { key = '6', mods = 'ALT', action = wezterm.action.ActivateTab(5) },
    { key = '7', mods = 'ALT', action = wezterm.action.ActivateTab(6) },
    { key = '8', mods = 'ALT', action = wezterm.action.ActivateTab(7) },
    { key = '9', mods = 'ALT', action = wezterm.action.ActivateTab(8) },

    -- Nav & Management
    { key = 'h', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Left' },
    { key = 'l', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Right' },
    { key = 'k', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Up' },
    { key = 'j', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Down' },
    { key = 't', mods = 'CTRL', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
    { key = 'Q', mods = 'CTRL|SHIFT', action = wezterm.action.CloseCurrentTab { confirm = false } },
    { key = 'w', mods = 'CTRL|SHIFT', action = wezterm.action.CloseCurrentPane { confirm = true } },
  }

  for _, k in ipairs(keys) do
    table.insert(config.keys, k)
  end

  config.mouse_bindings = {
    {
      event = { Down = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      action = wezterm.action.PasteFrom 'Clipboard',
    },
    {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'NONE',
      action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
    },
  }
end

return module
