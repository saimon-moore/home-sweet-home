-- ┌─────────────────────┐
-- │ gopls configuration │
-- └─────────────────────┘
--
-- Go language server configuration
-- Source: https://github.com/golang/tools/tree/master/gopls
--
-- This file configures the gopls language server for Go development.
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.

return {
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  on_attach = function(client, buf_id)
    -- Use this function to define buffer-local mappings and behavior that depend
    -- on attached client or only makes sense if there is language server attached.
  end,

  settings = {
    gopls = {
      -- Enable additional analyses
      analyses = {
        unusedparams = true,
        shadow = true,
        unusedvariable = true,
        useany = true,
      },

      -- Use staticcheck for additional linting
      staticcheck = true,

      -- Use gofumpt for stricter formatting
      gofumpt = true,

      -- Enable inlay hints for better code understanding
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },

      -- Customize code lenses
      codelenses = {
        gc_details = true,
        generate = true,
        regenerate_cgo = true,
        tidy = true,
        upgrade_dependency = true,
        vendor = true,
      },

      -- Semantic tokens for better syntax highlighting
      semanticTokens = true,

      -- Enable template file support
      templateExtensions = { 'tmpl', 'gotmpl', 'gohtml', 'gotxt' },
    },
  },
}
