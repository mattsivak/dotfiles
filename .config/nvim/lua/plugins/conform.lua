return {
  "stevearc/conform.nvim",
  dependencies = { "mason.nvim" },
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    formatters_by_ft = {
      javascript = { "prettier", "eslint_d", stop_after_first = true },
      typescript = { "prettier", "eslint_d", stop_after_first = true },
      javascriptreact = { "prettier", "eslint_d", stop_after_first = true },
      typescriptreact = { "prettier", "eslint_d", stop_after_first = true },
      vue = { "prettier", "eslint_d", stop_after_first = true },
      json = { "prettier" },
      jsonc = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      scss = { "prettier" },
    },
    formatters = {
      prettier = {
        -- Let prettier use its config files instead of hardcoding args
      },
    },
  },
}
