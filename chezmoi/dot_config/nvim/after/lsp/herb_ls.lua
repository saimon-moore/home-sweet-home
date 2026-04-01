-- ┌───────────────────────┐
-- │ herb_ls configuration │
-- └───────────────────────┘
--
-- ERB language server configuration
-- Source: https://github.com/itsnotyousef/herb
--
-- This file configures the herb_ls language server for ERB files.
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.

return {
  on_attach = function(client, buf_id)
    -- herb_ls provides diagnostics and potentially other LSP features for ERB
  end,
  settings = {},
}
