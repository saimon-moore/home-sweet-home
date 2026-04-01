-- ┌─────────────────────┐
-- │ cssls configuration │
-- └─────────────────────┘
--
-- CSS language server configuration
-- Source: https://github.com/microsoft/vscode-langservers-extracted
--
-- This file configures the CSS language server for CSS, SCSS, and Less files.
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.

return {
  on_attach = function(client, buf_id)
    -- CSS LSP provides formatting, diagnostics, completions, and hover
  end,
  settings = {
    css = {
      validate = true,
      lint = {
        unknownAtRules = "ignore", -- Don't warn about custom CSS properties/at-rules
      },
    },
    scss = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
      },
    },
    less = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
      },
    },
  },
}
