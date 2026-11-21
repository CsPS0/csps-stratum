local wezterm = require 'wezterm'
local module = {}

function module.apply_to_config(config)
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

  -- OLED Monochrome palette (matches the laptop's KDE "OLED_Monochrome" scheme)
  config.colors = {
    background = '#000000',
    foreground = '#E6E6E6',
    cursor_bg = '#FFFFFF',
    cursor_fg = '#000000',
    cursor_border = '#FFFFFF',
    selection_bg = '#686B6F', -- KDE accent grey
    selection_fg = '#FFFFFF',
    visual_bell = '#333333',
    scrollbar_thumb = '#222222',
    split = '#282828',
    ansi = {
      '#1A1A1A', '#C8C8C8', '#E0E0E0', '#B0B0B0',
      '#F0F0F0', '#D6D6D6', '#B8B8B8', '#FFFFFF',
    },
    brights = {
      '#4D4D4D', '#DCDCDC', '#F5F5F5', '#C0C0C0',
      '#FFFFFF', '#EAEAEA', '#CCCCCC', '#FFFFFF',
    },
    tab_bar = {
      background = '#000000',
      new_tab = { bg_color = '#000000', fg_color = '#888888' },
      new_tab_hover = { bg_color = '#686B6F', fg_color = '#FFFFFF' },
    },
  }

  -- Solid true black, inactive panes desaturated and dimmed
  config.window_background_opacity = 1.0
  config.text_background_opacity = 1.0
  config.inactive_pane_hsb = { saturation = 0.0, brightness = 0.6 }

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
