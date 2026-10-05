return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {},
  },
  {
    -- Only pulls in the mason registry when explicitly invoked.
    -- Previously this loaded at startup (~12ms) just to verify two
    -- already-installed tools on every launch.
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    cmd = { "MasonToolsInstall", "MasonToolsUpdate", "MasonToolsClean" },
    dependencies = { "mason.nvim" },
    opts = {
      ensure_installed = {
        "prettier",
      },
      run_on_start = false,
    },
  },
}
