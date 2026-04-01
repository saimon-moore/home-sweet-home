-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- This file contains installation and configuration of plugins outside of MINI.
-- They significantly improve user experience in a way not yet possible with MINI.
-- These are mostly plugins that provide programming language specific behavior.
--
-- Use this file to install and configure other such plugins.

-- Make concise helpers for installing/adding plugins in two stages
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later
local now_if_args = _G.Config.now_if_args

-- Tree-sitter ================================================================

-- Tree-sitter is a tool for fast incremental parsing. It converts text into
-- a hierarchical structure (called tree) that can be used to implement advanced
-- and/or more precise actions: syntax highlighting, textobjects, indent, etc.
--
-- Tree-sitter support is built into Neovim (see `:h treesitter`). However, it
-- requires two extra pieces that don't come with Neovim directly:
-- - Language parsers: programs that convert text into trees. Some are built-in
--   (like for Lua), 'nvim-treesitter' provides many others.
--   NOTE: It requires third party software to build and install parsers.
--   See the link for more info in "Requirements" section of the MiniMax README.
-- - Query files: definitions of how to extract information from trees in
--   a useful manner (see `:h treesitter-query`). 'nvim-treesitter' also provides
--   these, while 'nvim-treesitter-textobjects' provides the ones for Neovim
--   textobjects (see `:h text-objects`, `:h MiniAi.gen_spec.treesitter()`).
--
-- Add these plugins now if file (and not 'mini.starter') is shown after startup.
--
-- Troubleshooting:
-- - Run `:checkhealth vim.treesitter nvim-treesitter` to see potential issues.
-- - In case of errors related to queries for Neovim bundled parsers (like `lua`,
--   `vimdoc`, `markdown`, etc.), manually install them via 'nvim-treesitter'
--   with `:TSInstall <language>`. Be sure to have necessary system dependencies
--   (see MiniMax README section for software requirements).
now_if_args(function()
  add({
    source = "nvim-treesitter/nvim-treesitter",
    -- Update tree-sitter parser after plugin is updated
    hooks = {
      post_checkout = function()
        vim.cmd("TSUpdate")
      end,
    },
  })
  add({
    source = "nvim-treesitter/nvim-treesitter-textobjects",
    -- Use `main` branch since `master` branch is frozen, yet still default
    -- It is needed for compatibility with 'nvim-treesitter' `main` branch
    checkout = "main",
  })

  -- Define languages which will have parsers installed and auto enabled
  -- After changing this, restart Neovim once to install necessary parsers. Wait
  -- for the installation to finish before opening a file for added language(s).
  local languages = {
    -- These are already pre-installed with Neovim. Used as an example.
    "lua",
    "vimdoc",
    "markdown",
    "scala",
    "go",
    "gosum",
    "gomod",
    "gotmpl",
    "gowork",
    "graphql",
    "hocon",
    "html",
    "http",
    "ruby",
    "embedded_template", -- for ERB files
    "java",
    "cmake",
    "rust",
    "json",
    "yaml",
    "sql",
    "terraform",
    "toml",
    "xml",
    "zsh",
    "css",
    "csv",
    "bash",
    "diff",
    "ebnf",
    "gitignore",
    "git_config",
    -- Add here more languages with which you want to use tree-sitter
    -- To see available languages:
    -- - Execute `:=require('nvim-treesitter').get_available()`
    -- - Visit 'SUPPORTED_LANGUAGES.md' file at
    --   https://github.com/nvim-treesitter/nvim-treesitter/blob/main
  }
  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then
    require("nvim-treesitter").install(to_install)
  end

  -- Enable tree-sitter after opening a file for a target language
  local filetypes = {}
  for _, lang in ipairs(languages) do
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      table.insert(filetypes, ft)
    end
  end
  local ts_start = function(ev)
    vim.treesitter.start(ev.buf)
  end
  _G.Config.new_autocmd("FileType", filetypes, ts_start, "Start tree-sitter")
end)

-- Language servers ===========================================================

-- Language Server Protocol (LSP) is a set of conventions that power creation of
-- language specific tools. It requires two parts:
-- - Server - program that performs language specific computations.
-- - Client - program that asks server for computations and shows results.
--
-- Here Neovim itself is a client (see `:h vim.lsp`). Language servers need to
-- be installed separately based on your OS, CLI tools, and preferences.
-- See note about 'mason.nvim' at the bottom of the file.
--
-- Neovim's team collects commonly used configurations for most language servers
-- inside 'neovim/nvim-lspconfig' plugin.
--
-- Add it now if file (and not 'mini.starter') is shown after startup.
now_if_args(function()
  add("neovim/nvim-lspconfig")
  add("b0o/schemastore.nvim") -- JSON schemas for jsonls

  -- Use `:h vim.lsp.enable()` to automatically enable language server based on
  -- the rules provided by 'nvim-lspconfig'.
  -- Use `:h vim.lsp.config()` or 'after/lsp/' directory to configure servers.
  -- Uncomment and tweak the following `vim.lsp.enable()` call to enable servers.
  vim.lsp.enable({
    'lua_ls',
    'herb_ls',     -- ERB
    'rubocop',
    'ruby_lsp',
    'golangci_lint_ls',
    'gopls',
    'harper_ls',
    'marksman',
    'jsonls',
    'cssls',       -- CSS
    'yamlls',      -- YAML
  })
end)

-- Formatting =================================================================

-- Programs dedicated to text formatting (a.k.a. formatters) are very useful.
-- Neovim has built-in tools for text formatting (see `:h gq` and `:h 'formatprg'`).
-- They can be used to configure external programs, but it might become tedious.
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup.
later(function()
  add("stevearc/conform.nvim")

  -- See also:
  -- - `:h Conform`
  -- - `:h conform-options`
  -- - `:h conform-formatters`
  require("conform").setup({
    default_format_opts = {
      -- Allow formatting from LSP server if no dedicated formatter is available
      lsp_format = "fallback",
    },
    -- Map of filetype to formatters
    -- Make sure that necessary CLI tool is available
    formatters_by_ft = {
      -- JSON and Markdown handled by their respective LSPs (jsonls, marksman)
      -- CSS handled by cssls LSP
      -- Go and gotmpl handled by gopls LSP
      -- ERB: erb_format as primary, herb_ls LSP as fallback
      typescript = { "dprint" },
      javascript = { "dprint" },
      typescriptreact = { "dprint" },
      javascriptreact = { "dprint" },
      toml = { "dprint" },
      dockerfile = { "dprint" },
      yaml = { "yamlfmt" },  -- Use yamlfmt as primary, yamlls LSP as fallback
      eruby = { "erb_format" },  -- ERB files: erb_format as primary, herb_ls LSP as fallback
    },
    formatters = {
      dprint = {
        command = "dprint",
        args = function(self, ctx)
          return {
            "fmt",
            "--stdin",
            ctx.filename,
            "--config",
            vim.fn.stdpath('config') .. '/dprint.json',
          }
        end,
        stdin = true,
      },
      erb_format = {
        command = "erb-format",
        args = { "--stdin" },
        stdin = true,
      },
    },
  })

  vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",
    callback = function(args)
      require("conform").format({ bufnr = args.buf })
    end,
  })
end)

-- Snippets ===================================================================

-- Although 'mini.snippets' provides functionality to manage snippet files, it
-- deliberately doesn't come with those.
--
-- The 'rafamadriz/friendly-snippets' is currently the largest collection of
-- snippet files. They are organized in 'snippets/' directory (mostly) per language.
-- 'mini.snippets' is designed to work with it as seamlessly as possible.
-- See `:h MiniSnippets.gen_loader.from_lang()`.
later(function()
  add("rafamadriz/friendly-snippets")
end)

-- Honorable mentions =========================================================

-- 'mason-org/mason.nvim' (a.k.a. "Mason") is a great tool (package manager) for
-- installing external language servers, formatters, and linters. It provides
-- a unified interface for installing, updating, and deleting such programs.
--
-- The caveat is that these programs will be set up to be mostly used inside Neovim.
-- If you need them to work elsewhere, consider using other package managers.
--
-- You can use it like so:

now_if_args(function()
  add("mason-org/mason.nvim")
  require("mason").setup()
end)

now(function()
  add("miikanissi/modus-themes.nvim")


  require("modus-themes").setup({
    line_nr_column_background = false,
    sign_column_background = false,
    hide_inactive_statusline = true,

    dim_inactive = false,
    styles = {
      comments = { italic = true },
      keywords = { italic = true },
      functions = {},
      variables = {},
    },
    on_colors = function(colors)
      colors.bg_sign = colors.bg_main
      colors.bg_linenr = colors.bg_main
    end,
    on_highlights = function(hl, colors)
      hl.CursorLine           = {
        bg = colors.bg_main
      }

      hl.CursorLineNr         = {
        fg = colors.magenta,
        bg = colors.bg_main,
        bold = true
      }
      -- MiniClue window
      hl.MiniClueBorder       = {
        fg = colors.border,
        bg = colors.bg_main,
      }

      hl.MiniClueSeparator    = {
        fg = colors.border,
        bg = colors.bg_main,
      }

      hl.MiniClueTitle        = {
        fg = colors.fg_main,
        bg = colors.bg_main,
        bold = true,
      }

      hl.MiniClueDescGroup    = {
        fg = colors.cyan,
        bg = colors.bg_main,
        bold = true,
      }

      hl.MiniClueDescSingle   = {
        fg = colors.fg_dim,
        bg = colors.bg_main,
      }

      hl.MiniClueNextKey      = {
        fg = colors.yellow,
        bg = colors.bg_main,
        bold = true,
      }

      hl.Pmenu                = { fg = colors.fg_main, bg = colors.bg_main }
      hl.PmenuSel             = { fg = colors.fg_main, bg = colors.bg_active, bold = true }
      hl.PmenuSbar            = { bg = colors.bg_main }
      hl.PmenuThumb           = { bg = colors.border }
      hl.PmenuKind            = { fg = colors.blue, bg = colors.bg_main }
      hl.PmenuKindSel         = { fg = colors.blue, bg = colors.bg_active, bold = true }

      hl.PmenuExtra           = { fg = colors.fg_dim, bg = colors.bg_main }
      hl.PmenuExtraSel        = { fg = colors.fg_dim, bg = colors.bg_active }

      hl.NormalFloat          = { fg = colors.fg_main, bg = colors.bg_main }
      hl.FloatBorder          = { fg = colors.border, bg = colors.bg_main }

      -- MiniPick window
      hl.MiniPickMatchCurrent = {
        fg = colors.fg_main,
        bg = colors.bg_active,
        bold = true
      }

      hl.MiniPickMatchRanges  = {
        fg = colors.cyan,
        bold = true
      }

      hl.MiniPickMatchMarked  = {
        fg = colors.yellow,
        bg = colors.bg_dim
      }

      hl.MiniPickPrompt       = {
        fg = colors.magenta,
        bold = true
      }
    end,
  })


  vim.cmd("color modus_vivendi")
end)


-- UI enhancements ========================================================================

-- Aerial - Code outline and structure navigator
later(function()
  add("stevearc/aerial.nvim")

  local mini_icons = require("mini.icons")

  -- Build icons table from mini.icons for the kinds we filter
  local aerial_icons = {}
  local kinds = {
    'Class', 'Constructor', 'Enum', 'Function', 'Interface', 'Module', 'Method', 'Struct'
  }

  for _, kind in ipairs(kinds) do
    local icon = mini_icons.get("lsp", kind:lower())
    aerial_icons[kind] = icon .. " "
  end

  -- Override function icon (the default one doesn't render well)
  aerial_icons['Function'] = '󰊕 '

  require("aerial").setup({
    filter_kind = kinds,
    layout = {
      min_width = 28,
      default_direction = 'left',
      placement = 'edge',
    },
    highlight_mode = 'last',
    highlight_on_jump = 1000,
    highlight_on_hover = true,
    highlight_closest = true,
    open_automatic = false,
    autojump = true,
    link_folds_to_tree = false,
    link_tree_to_folds = false,
    attach_mode = 'global',
    backends = { 'treesitter', 'lsp', 'markdown', 'man', 'asciidoc' },
    show_guides = true,
    guides = {
      mid_item = '├ ',
      last_item = '└ ',
      nested_top = '│ ',
      whitespace = '  ',
    },
    icons = aerial_icons,
    on_attach = function(bufnr)
      vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
      vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
    end,
  })
end)

-- Quicker.nvim - Enhanced quickfix window
later(function()
  add("stevearc/quicker.nvim")

  require("quicker").setup({
    -- Keymaps for the quickfix buffer
    keys = {
      {
        ">",
        function()
          require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
        end,
        desc = "Expand quickfix context",
      },
      {
        "<",
        function()
          require("quicker").collapse()
        end,
        desc = "Collapse quickfix context",
      },
    },

    -- Enable editing the quickfix like a normal buffer
    edit = {
      enabled = true,
      autosave = "unmodified",
    },

    -- Use treesitter and LSP for syntax highlighting
    highlight = {
      treesitter = true,
      lsp = true,
      load_buffers = false,
    },
  })

  -- Keybindings for quickfix/location list toggle are defined in plugin/20_keymaps.lua
  -- <Leader>eq -> Toggle quickfix
  -- <Leader>eQ -> Toggle location list
end)

-- Task runner =====================================================================

-- Overseer - Task runner for Makefile, mise, and other task systems
later(function()
  add("stevearc/overseer.nvim")

  require("overseer").setup({
    templates = { "builtin", "make", "mise" },
    task_list = {
      direction = "bottom",
      min_height = 15,
      max_height = 25,
      default_detail = 1,
      bindings = {
        ["?"] = "ShowHelp",
        ["g?"] = "ShowHelp",
        ["<CR>"] = "RunAction",
        ["<C-e>"] = "Edit",
        ["o"] = "Open",
        ["<C-v>"] = "OpenVsplit",
        ["<C-s>"] = "OpenSplit",
        ["<C-f>"] = "OpenFloat",
        ["<C-q>"] = "OpenQuickFix",
        ["p"] = "TogglePreview",
        ["<C-l>"] = "IncreaseDetail",
        ["<C-h>"] = "DecreaseDetail",
        ["L"] = "IncreaseAllDetail",
        ["H"] = "DecreaseAllDetail",
        ["["] = "DecreaseWidth",
        ["]"] = "IncreaseWidth",
        ["{"] = "PrevTask",
        ["}"] = "NextTask",
        ["<C-k>"] = "ScrollOutputUp",
        ["<C-j>"] = "ScrollOutputDown",
        ["q"] = "Close",
      },
    },
    -- Automatically detect tasks from Makefile and mise
    auto_detect_success_color = true,
    -- Integration with toggleterm
    strategy = {
      "toggleterm",
      direction = "horizontal",
      autos_croll = true,
      quit_on_exit = "success"
    },
    component_aliases = {
      default = {
        { "display_duration", detail_level = 2 },
        "on_output_summarize",
        "on_exit_set_status",
        "on_complete_notify",
        "on_complete_dispose",
      },
    },
  })
end)

-- Terminal management ================================================================

-- ToggleTerm - Better terminal management with floating windows
later(function()
  add("akinsho/toggleterm.nvim")

  require("toggleterm").setup({
    size = function(term)
      if term.direction == "horizontal" then
        return 15
      elseif term.direction == "vertical" then
        return vim.o.columns * 0.4
      end
    end,
    open_mapping = [[<C-/>]],
    hide_numbers = true,
    shade_terminals = true,
    start_in_insert = true,
    insert_mappings = true,
    terminal_mappings = true,
    persist_size = true,
    persist_mode = true,
    direction = 'float',
    close_on_exit = true,
    shell = vim.o.shell,
    float_opts = {
      border = 'curved',
      winblend = 0,
    },
  })

  -- Create a custom terminal for taskwarrior-tui
  local Terminal = require('toggleterm.terminal').Terminal
  local taskwarrior = Terminal:new({
    cmd = "taskwarrior-tui",
    direction = "float",
    float_opts = {
      border = "curved",
      width = math.floor(vim.o.columns * 0.9),
      height = math.floor(vim.o.lines * 0.9),
    },
    on_open = function(term)
      vim.cmd("startinsert!")
      -- Disable line numbers in the terminal
      vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
    end,
  })

  -- Function to toggle taskwarrior
  function _G.toggle_taskwarrior()
    taskwarrior:toggle()
  end

  -- Quick add task function
  function _G.quick_add_task()
    vim.ui.input({ prompt = "Task: " }, function(input)
      if input and input ~= "" then
        -- Pass input directly to shell without escaping
        -- User is responsible for proper quoting if needed
        vim.fn.system("task add " .. input)
        vim.notify("Task added: " .. input, vim.log.levels.INFO)
      end
    end)
  end
end)

-- Test runner ==============================================================================

-- vim-test - Run tests at the speed of thought
-- vim-dispatch - Async test execution with quickfix integration
later(function()
  add("tpope/vim-dispatch") -- Required for vim-test dispatch strategy
  add("vim-test/vim-test")

  -- Strategy: Use vim-dispatch to send test output to quickfix list
  -- This runs tests asynchronously and populates the quickfix window
  -- Use :copen to see results, :cn/:cp to navigate errors
  vim.g['test#strategy'] = 'dispatch'

  -- Language-specific runners
  vim.g['test#go#runner'] = 'gotest'     -- Go: use gotest runner
  vim.g['test#scala#runner'] = 'sbttest' -- Scala: use sbttest (coexists with nvim-metals)
  -- Ruby: Auto-detect between minitest/rspec based on project (no explicit config needed)
end)

-- Git integration ========================================================================

-- Neogit - Magit-like Git interface for Neovim
later(function()
  add({
    source = "NeogitOrg/neogit",
    depends = { "nvim-lua/plenary.nvim" },
  })

  require("neogit").setup({
    -- Quality-of-life improvements
    disable_hint = true, -- Remove hint text in status buffer
    disable_commit_confirmation = "auto",
    disable_insert_on_commit = true,
  })
end)

-- Markdown rendering ===================================================================

-- render-markdown.nvim - Inline markdown rendering with conceals
later(function()
  add("MeanderingProgrammer/render-markdown.nvim")

  require("render-markdown").setup({
    completion = { lsp = { enabled = true } },
    render_modes = true,
    indent = {
      enabled = false,
    },
    sign = {
      enabled = false,
    },
    dash = {
      enabled = true,
    },
    code = {
      enabled = true,
    },
    heading = {
      enabled = true,
      icons = { '■ ', '■■ ', '■■■ ', '■■■■ ', '■■■■■ ', '■■■■■■ ' },
      backgrounds = {},
      foregrounds = {
        'RenderMarkdownH1',
        'RenderMarkdownH2',
        'RenderMarkdownH3',
        'RenderMarkdownH4',
        'RenderMarkdownH5',
        'RenderMarkdownH6',
      },
      above = '▄',
      below = '▀',
    },
    link = {
      enabled = true,
    },
    bullet = {
      enabled = true,
      icons = { '•', '•', '•', '•' },
    },
    checkbox = {
      enabled = true,

      -- kept compatible with obsidian minimal theme checkboxes
      custom = {
        cancelled = { raw = '[-]', rendered = '󰜺 ', highlight = 'RenderMarkdownUnchecked' },
        incomplete = { raw = '[/]', rendered = '󰜺 ', highlight = 'RenderMarkdownUnchecked' },
        information = { raw = '[i]', rendered = '󰋼 ', highlight = 'RenderMarkdownBullet' },
        idea = { raw = '[I]', rendered = '󰛨 ' },
        event = { raw = '[e]', rendered = ' ' },
        forwarded = { raw = '[>]', rendered = '󰜴 ' },
        scheduled = { raw = '[<]', rendered = '󰜱 ' },
        important = { raw = '[!]', rendered = ' ' },
        quote = { raw = '["]', rendered = '󰉾 ' },
        star = { raw = '[*]', rendered = ' ' },
        question = { raw = '[?]', rendered = ' ' },
        pros = { raw = '[p]', rendered = '󰔓 ', highlight = 'RenderMarkdownBullet' },
        cons = { raw = '[c]', rendered = '󰔑 ', highlight = 'RenderMarkdownBullet' },
      },
    },
    latex = {
      enabled = true,
      render_modes = false,
      converter = 'latex2text',
      highlight = 'RenderMarkdownMath',
      top_pad = 0,
      bottom_pad = 0,
    },
  })
end)

-- Notes system ========================================================================

-- Helper functions for managing notes in ~/Documents/Notes
later(function()
  local notes_dir = vim.fn.expand("~/Documents/Notes")

  -- Ensure notes directory exists
  vim.fn.mkdir(notes_dir, "p")

  -- Open or create daily note (format: YYYY-MM-DD.md)
  _G.open_daily_note = function()
    local date = os.date("%Y-%m-%d")
    local note_path = notes_dir .. "/" .. date .. ".md"
    vim.cmd("edit " .. note_path)
  end

  -- Find notes using mini.pick
  _G.find_notes = function()
    local pick = require("mini.pick")
    pick.builtin.files({}, { source = { cwd = notes_dir } })
  end

  -- Grep in notes using mini.pick
  _G.grep_notes = function()
    local pick = require("mini.pick")
    pick.builtin.grep_live({}, { source = { cwd = notes_dir } })
  end
end)

-- Languages ============================================================================

later(function()
  add({ source = "scalameta/nvim-metals", depends = { 'mfussenegger/nvim-dap' } })

  -- Configure nvim-metals for Scala files
  local metals_augroup = vim.api.nvim_create_augroup('nvim-metals', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'scala', 'sbt', 'java' },
    group = metals_augroup,
    callback = function()
      local metals = require('metals')
      local metals_config = metals.bare_config()

      metals_config.settings = {
        showInferredType = false,
        superMethodLensesEnabled = true,
        showImplicitArguments = true,
        excludedPackages = { 'akka.actor.typed.javadsl', 'com.github.swagger.akka.javadsl' },
        serverVersion = 'latest.snapshot',
      }
      metals_config.init_options.statusBarProvider = 'on'

      metals_config.on_attach = function(client, bufnr)
        require('metals').setup_dap()

        if client.server_capabilities.codeLensProvider then
          vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'InsertLeave' }, {
            buffer = bufnr,
            callback = vim.lsp.codelens.refresh,
          })
        end
      end

      -- Initialize metals for this buffer
      metals.initialize_or_attach(metals_config)
    end,
  })
end)
