return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "volar",
          "ts_ls",
          "eslint",
        },
        automatic_installation = true,
      })
      
      local lspconfig = require("lspconfig")
      
      -- Common on_attach function
      local on_attach = function(client, bufnr)
        -- Disable formatting for both ESLint and ts_ls to let Prettier handle it
        if client.name == "eslint" or client.name == "ts_ls" then
          client.server_capabilities.documentFormattingProvider = false
        end
      end

      -- TypeScript/JavaScript
      lspconfig.ts_ls.setup({
        on_attach = on_attach,
        filetypes = {
          "javascript",
          "javascriptreact",
          "typescript",
          "typescriptreact",
        },
      })

      -- Vue
      lspconfig.volar.setup({
        filetypes = { "vue" },
        init_options = {
          vue = {
            hybridMode = false,
          },
        },
      })

      -- ESLint
      lspconfig.eslint.setup({
        on_attach = on_attach,
      })
    end,
  },
}