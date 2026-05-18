# clangd direct includes

Enables to add direct includes to to C files trough clangd completion even if include file is already indirectly included.

### Usage

It registers as LSP and will offer direct include action under `code_actions`.

## Lazyvim
```lua
return {
    {
        "williamboman/mason.nvim",
        dependencies = {
            "williamboman/mason-lspconfig.nvim",
            "neovim/nvim-lspconfig",
            "hrsh7th/cmp-nvim-lsp",
            "FLeWz/clangd-direct-includes.nvim",
        },
        config = function()
            require("mason").setup({})
            require("clangd-direct-includes")

            vim.lsp.enable("clangd-direct-includes")

            require("lspconfig").clangd.setup({
                cmd = {
                    vim.fn.stdpath("data") .. "/mason/bin/clangd",
                    "--completion-style=detailed",
                },
            })
        end,
    },
}
```
