local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

require('config.appearance').apply_to_config(config)
require('config.tab_bar').apply_to_config(config)
require('config.links').apply_to_config(config)
require('config.bindings').apply_to_config(config)

return config
