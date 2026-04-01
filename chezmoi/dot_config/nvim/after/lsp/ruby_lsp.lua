-- ┌────────────────────────┐
-- │ ruby_lsp configuration │
-- └────────────────────────┘
--
-- Ruby language server configuration
-- Source: https://github.com/Shopify/ruby-lsp
--
-- This file configures the ruby-lsp language server for Ruby development.
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.

return {
  on_attach = function(client, buf_id)
    -- Use this function to define buffer-local mappings and behavior that depend
    -- on attached client or only makes sense if there is language server attached.
  end,

  init_options = {
    experimentalFeaturesEnabled = true,
    enabledFeatures = {
      "codeActions",
      "diagnostics",
      "documentHighlights",
      "documentLink",
      "documentSymbols",
      "foldingRanges",
      "formatting",
      "hover",
      "inlayHint",
      "onTypeFormatting",
      "selectionRanges",
      "semanticHighlighting",
      "completion",
      "codeLens",
      "definition",
      "workspaceSymbol",
    },
  },

  settings = {
    rubyLsp = {
      formatter = "rufo",
      linters = { "rubocop" },
      enabledFeatures = {
        inlayHint = false,
      },
    },
  },
}
