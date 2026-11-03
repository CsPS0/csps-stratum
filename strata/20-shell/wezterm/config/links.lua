local wezterm = require 'wezterm'
local module = {}

function module.apply_to_config(config)
  config.hyperlink_rules = wezterm.default_hyperlink_rules()
  
  -- JIRA tickets (e.g. PROJ-1234)
  table.insert(config.hyperlink_rules, {
    regex = [[\b[A-Z]+-\d+\b]],
    format = 'https://jira.yourcompany.com/browse/$0',
  })
  
  -- Git Hashes (7-40 hex chars)
  table.insert(config.hyperlink_rules, {
    regex = [[\b[0-9a-f]{7,40}\b]],
    format = 'https://github.com/search?q=$0&type=commits',
  })
end

return module
