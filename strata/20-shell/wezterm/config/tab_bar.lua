local wezterm = require 'wezterm'
local module = {}

local function get_process_icon(process_name)
  local icons = {
    ['nvim'] = '', ['vim'] = '', ['node'] = '󰎙', ['npm'] = '', ['git'] = '󰊢',
    ['bash'] = '', ['zsh'] = '', ['powershell'] = '', ['pwsh'] = '', ['cmd'] = '',
    ['ssh'] = '󰣀', ['python'] = '', ['docker'] = '󰡨', ['go'] = '', ['cargo'] = '󱘗',
    ['topgrade'] = '󰚰', ['antigravity'] = '󰠧',
  }
  return icons[process_name] or ''
end

function module.apply_to_config(config)
  config.use_fancy_tab_bar = false
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom = false
  config.tab_max_width = 32

  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
    local pane = tab.active_pane
    local process_name = pane.foreground_process_name:match("([^/\\]+)$") or "bash"
    local icon = get_process_icon(process_name:lower():gsub("%.exe$", ""))
    local title = " " .. icon .. " "
    local cwd = pane.current_working_dir
    if cwd then
      -- current_working_dir is a Url object (file_path) on newer builds, a string on older ones
      local path = type(cwd) == 'string' and cwd:gsub("^file://[^/]*", "") or cwd.file_path
      path = path:gsub("^/([A-Za-z]:)", "%1"):gsub("/", "\\")
      local home = wezterm.home_dir:gsub("/", "\\")
      if path:lower():gsub("\\$", "") == home:lower():gsub("\\$", "") then title = title .. "~"
      else title = title .. (path:gsub("\\$", ""):match("([^\\]+)$") or path) end
    else
      title = title .. (pane.title:gsub("^%d+: ", ""):gsub("^pwsh in ", ""):match("([^\\]+)$") or pane.title)
    end
    title = title:gsub("^%d+: ", ""):gsub("pwsh in ", "")

    if tab.is_active then
      return {
        { Background = { Color = '#686B6F' } },
        { Foreground = { Color = '#FFFFFF' } },
        { Text = ' ' .. title .. ' ' },
      }
    end
    return {
      { Background = { Color = hover and '#3A3C3E' or '#111111' } },
      { Foreground = { Color = hover and '#FFFFFF' or '#888888' } },
      { Text = ' ' .. title .. ' ' },
    }
  end)

  wezterm.on('update-right-status', function(window, pane)
    local cells = {}
    table.insert(cells, wezterm.strftime '󰃭 %Y-%m-%d 󱑎 %H:%M')
    table.insert(cells, '󱂬 ' .. window:active_workspace())
    for _, b in ipairs(wezterm.battery_info()) do
      table.insert(cells, string.format('󰁹 %.0f%%', b.state_of_charge * 100))
    end
    window:set_right_status(wezterm.format {
      { Foreground = { Color = '#CCCCCC' } },
      { Text = table.concat(cells, '  ') .. ' ' },
    })
  end)
end

return module
