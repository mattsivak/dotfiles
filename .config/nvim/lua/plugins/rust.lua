return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Use the rustup-managed rust-analyzer instead of Mason's 44M copy.
        -- Installed via `rustup component add rust-analyzer`, so it tracks the
        -- active toolchain automatically.
        --
        -- `mason = false` is what makes LazyVim call vim.lsp.enable() directly
        -- instead of deferring to mason-lspconfig's automatic_enable, which
        -- only enables servers Mason itself installed.
        rust_analyzer = {
          mason = false,
          cmd = { vim.fn.expand("~/.cargo/bin/rust-analyzer") },
        },
      },
    },
  },
}
