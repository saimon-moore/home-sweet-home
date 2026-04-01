-- ┌──────────────────────┐
-- │ yamlls configuration │
-- └──────────────────────┘
--
-- YAML language server configuration
-- Source: https://github.com/redhat-developer/yaml-language-server
--
-- This file configures the YAML language server for YAML files.
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.

return {
  on_attach = function(client, buf_id)
    -- YAML LSP provides formatting, diagnostics, completions, and schema validation
  end,
  settings = {
    yaml = {
      schemas = require('schemastore').yaml.schemas(),
      schemaStore = {
        -- Enable built-in schemaStore support
        enable = true,
        -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
        url = "",
      },
      format = {
        enable = true,
        singleQuote = false,
        bracketSpacing = true,
      },
      validate = true,
      hover = true,
      completion = true,
    },
  },
}
