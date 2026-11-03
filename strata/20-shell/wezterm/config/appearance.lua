local wezterm = require 'wezterm'
local module = {}

function module.apply_to_config(config)
  -- Auto Dark/Light Mode
  local function get_color_scheme()
    if wezterm.gui then
      local appearance = wezterm.gui.get_appearance()
      if appearance:find 'Dark' then
        return 'Gruber (base16)'
      else
        return 'Catppuccin Latte'
      end
    end
    return 'Gruber (base16)'
  end

  config.color_scheme = get_color_scheme()
  
  config.font = wezterm.font_with_fallback({
    { family = 'JetBrainsMono NF', harfbuzz_features = { 'calt', 'liga', 'clig' } },
    'JetBrains Mono NF',
    'JetBrains Mono',
  })
  config.font_size = 11.0

  -- Modern Cursor & Smoothness
  config.default_cursor_style = 'BlinkingBar'
  config.cursor_blink_rate = 600
  config.animation_fps = 60

  -- Padding & Spacing
  config.window_padding = {
    left = 15, right = 15, top = 10, bottom = 10,
  }
  config.enable_scroll_bar = true

  -- Colors
  config.colors = {
    cursor_bg = '#FFFFFF',
    cursor_fg = '#000000',
    cursor_border = '#FFFFFF',
    selection_fg = 'none',
    selection_bg = 'rgba(255, 221, 51, 0.3)',
    background = '#000000',
    visual_bell = '#333333',
    scrollbar_thumb = '#222222',
  }

  -- Background & Opacity
  config.window_background_opacity = 0.8
  config.text_background_opacity = 1.0
  config.inactive_pane_hsb = { saturation = 0.8, brightness = 0.5 }

  -- Window & UI
  config.window_decorations = "RESIZE"
  config.initial_cols = 120
  config.initial_rows = 30
  config.scrollback_lines = 10000
  config.show_tab_index_in_tab_bar = false

  -- Default Shell (PowerShell 7)
  config.default_prog = { 'pwsh.exe', '-NoLogo' }
  config.set_environment_variables = { SHELL = 'pwsh' }
end

return module
