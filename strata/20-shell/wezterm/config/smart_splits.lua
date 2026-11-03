local wezterm = require 'wezterm'
local module = {}

local function is_vim(pane)
  local process_name = pane:get_foreground_process_name()
  if process_name then
    return process_name:find('n?vim') ~= nil
  end
  return false
end

local direction_keys = {
  h = 'Left',
  j = 'Down',
  k = 'Up',
  l = 'Right',
}

function module.apply_to_config(config)
  if not config.keys then config.keys = {} end

  for key, dir in pairs(direction_keys) do
    table.insert(config.keys, {
      key = key,
      mods = 'CTRL',
      action = wezterm.action_callback(function(window, pane)
        if is_vim(pane) then
          window:perform_action(
            wezterm.action.SendKey({ key = key, mods = 'CTRL' }),
            pane
          )
        else
          window:perform_action(wezterm.action.ActivatePaneDirection(dir), pane)
        end
      end),
    })
  end
end

return module
