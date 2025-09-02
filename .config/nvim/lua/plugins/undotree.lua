return {
  {
    "mbbill/undotree",
    keys = {
      { "<leader>su", "<cmd>UndotreeToggle<cr>", desc = "Toggle Undotree" },
    },
    init = function()
      vim.g.undotree_WindowLayout = 3 -- tree on right, diff below
      vim.g.undotree_ShortIndicators = 1
      vim.g.undotree_SetFocusWhenToggle = 1
      vim.g.undotree_HelpLine = 0
    end,
  },
}
