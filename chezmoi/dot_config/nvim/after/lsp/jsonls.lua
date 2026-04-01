-- ┌──────────────────────┐
-- │ jsonls configuration │
-- └──────────────────────┘
--
-- JSON language server configuration
-- Source: https://github.com/microsoft/vscode-langservers-extracted
--
-- This file configures the JSON language server for JSON/JSONC files.
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.

return {
  on_attach = function(client, buf_id)
    -- JSON LSP provides formatting, diagnostics, and validation
  end,
  settings = {
    json = {
      schemas = require('schemastore').json.schemas(),
      validate = { enable = true },
    },
  },
}
