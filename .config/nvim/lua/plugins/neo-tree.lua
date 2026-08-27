return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    keys = {
      -- Override LazyVim defaults to always use cwd instead of git root
      {
        "<leader>fe",
        function()
          require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
        end,
        desc = "Explorer NeoTree (cwd)",
      },
      { "<leader>e", "<leader>fe", desc = "Explorer NeoTree (cwd)", remap = true },
    },
    opts = {
      filesystem = {
        filtered_items = {
          visible = true, -- When true, hidden files are dimmed out rather than completely hidden
          hide_dotfiles = false,
          hide_gitignored = true,
        },
      },
    },
  },
}