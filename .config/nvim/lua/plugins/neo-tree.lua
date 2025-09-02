return {
  {
    "nvim-neo-tree/neo-tree.nvim",
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