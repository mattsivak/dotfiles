return {
  {
    "folke/trouble.nvim",
    -- opts will be merged with the parent spec
  },
  {
    "mbbill/undotree",
    keys = {
      { "<leader>uu", "<cmd>UndotreeToggle<cr>", desc = "Toggle Undotree" },
    },
  },
  {
    "xiyaowong/transparent.nvim",
    lazy = false,
  },
}
