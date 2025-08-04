return {
  {
    "NickvanDyke/opencode.nvim",
    dependencies = {
      "folke/snacks.nvim",
    },
    ---@type opencode.Config
    opts = {
      auto_reload = true, -- Automatically reload buffers edited by opencode
      context = { -- Context to inject in prompts
        ["@file"] = function()
          return require("opencode.context").file()
        end,
        ["@files"] = function()
          return require("opencode.context").files()
        end,
        ["@cursor"] = function()
          return require("opencode.context").cursor_position()
        end,
        ["@selection"] = function()
          return require("opencode.context").visual_selection()
        end,
        ["@diagnostics"] = function()
          return require("opencode.context").diagnostics()
        end,
        ["@quickfix"] = function()
          return require("opencode.context").quickfix()
        end,
        ["@diff"] = function()
          return require("opencode.context").git_diff()
        end,
      },
    },
    -- stylua: ignore
    keys = {
      {
        '<leader>ao',
        function()
          require('snacks.terminal').toggle('opencode', { win = { position = 'right' } })
        end,
        desc = "Toggle opencode",
      },
      { '<leader>aa', function() require('opencode').ask() end, desc = 'Ask opencode', mode = { 'n', 'v' }, },
      { '<leader>aA', function() require('opencode').ask('@file ') end, desc = 'Ask opencode about current file', mode = { 'n', 'v' }, },
      { '<leader>ae', function() require('opencode').prompt('Explain @cursor and its context') end, desc = 'Explain code near cursor' },
      { '<leader>ar', function() require('opencode').prompt('Review @file for correctness and readability') end, desc = 'Review file', },
      { '<leader>af', function() require('opencode').prompt('Fix these @diagnostics') end, desc = 'Fix errors', },
      { '<leader>ao', function() require('opencode').prompt('Optimize @selection for performance and readability') end, desc = 'Optimize selection', mode = 'v', },
      { '<leader>ad', function() require('opencode').prompt('Add documentation comments for @selection') end, desc = 'Document selection', mode = 'v', },
      { '<leader>at', function() require('opencode').prompt('Add tests for @selection') end, desc = 'Test selection', mode = 'v', },
    },
  },
}
