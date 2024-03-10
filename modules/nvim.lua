vim.o.number = true
vim.o.wildmenu = true
vim.o.wildmode = 'longest:full,full'
vim.o.termguicolors = true
vim.cmd.colorscheme('kanagawa-dragon')
vim.cmd([[
  cnoremap <expr> <Up> pumvisible() ? "\<C-p>" : "\<Up>"
  cnoremap <expr> <Down> pumvisible() ? "\<C-n>" : "\<Down>"
]])

-- nixpkgs: nvim-treesitter
-- https://github.com/nvim-treesitter/nvim-treesitter
require 'nvim-treesitter.configs'.setup {
  modules = {},
  sync_install = false,
  auto_install = false,
  ensure_installed = {},
  ignore_install = { "all" },
  indent = {
    enable = true,
    disable = { "nix" },
  },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
}

-- nixpkgs: nvim-neo-tree nvim-web-devicons
-- https://github.com/nvim-neo-tree/neo-tree.nvim
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.neo_tree_remove_legacy_commands = 1
vim.keymap.set('n', '<F2>', '<cmd>Neotree toggle<cr>')

-- nixpkgs: leap-nvim
-- https://github.com/ggandor/leap.nvim
require('leap').add_default_mappings()

-- nixpkgs: mini-nvim
-- https://github.com/echasnovski/mini.nvim
require('mini.animate').setup()

-- nixpkgs: toggleterm-nvim
-- https://github.com/akinsho/toggleterm.nvim
require('toggleterm').setup { open_mapping = '<leader>t' }

-- nixpkgs: telescope-nvim telescope-fzf-native-nvim
-- https://github.com/nvim-telescope/telescope.nvim
-- https://github.com/nvim-telescope/telescope.nvim?tab=readme-ov-file#pickers
require('telescope').load_extension('fzf')
local telescope = require('telescope.builtin')
vim.keymap.set('n', '<leader>pp', telescope.planets, {})
vim.keymap.set('n', '<leader>fg', telescope.live_grep, {})
vim.keymap.set('n', '<leader>fb', telescope.buffers, {})
vim.keymap.set('n', '<leader>fh', telescope.help_tags, {})
vim.keymap.set('n', '<Leader>ff', function() telescope.find_files({ hidden = true }) end)
vim.keymap.set('n', '<leader>fc', telescope.commands, {})
vim.keymap.set('n', '<leader>fm', telescope.man_pages, {})
vim.keymap.set('n', '<leader>fo', telescope.vim_options, {})
vim.keymap.set('n', '<leader>fk', telescope.keymaps, {})
vim.keymap.set('n', '<leader>fp', telescope.pickers, {})
vim.keymap.set('n', '<leader>fr', telescope.current_buffer_fuzzy_find, {})

vim.keymap.set('n', '<leader>gc', telescope.git_commits, {})
vim.keymap.set('n', '<leader>gb', telescope.git_bcommits, {})
vim.keymap.set('n', '<leader>gg', telescope.git_branches, {})

vim.keymap.set('n', '<leader>ld', telescope.diagnostics, {})



-- nixpkgs: nvim-lspconfig
-- https://github.com/neovim/nvim-lspconfig
local lspconfig = require('lspconfig')
lspconfig.nil_ls.setup {}
lspconfig.pyright.setup {}
lspconfig.tsserver.setup {}
lspconfig.svelte.setup {}
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#lua_ls
lspconfig.lua_ls.setup {
  on_init = function(client)
    local path = client.workspace_folders[1].name
    if not vim.loop.fs_stat(path..'/.luarc.json') and not vim.loop.fs_stat(path..'/.luarc.jsonc') then
      client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
        Lua = {
          runtime = {
            version = 'LuaJIT'
          },
          workspace = {
            checkThirdParty = false,
            library = {
              vim.env.VIMRUNTIME
            }
          }
        }
      })
    end
    return true
  end
}

vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<space>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})

-- nixpkgs: nvim-cmp cmp-nvim-lsp luasnip cmp_luasnip
-- https://github.com/neovim/nvim-lspconfig/wiki/Autocompletion
local capabilities = require("cmp_nvim_lsp").default_capabilities()

local servers = { 'nil_ls', 'svelte', 'pyright', 'tsserver' }
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    capabilities = capabilities,
  }
end

local luasnip = require 'luasnip'

local cmp = require 'cmp'
cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-u>'] = cmp.mapping.scroll_docs(-4), -- Up
    ['<C-d>'] = cmp.mapping.scroll_docs(4), -- Down
    -- C-b (back) C-f (forward) for snippet placeholder navigation.
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  }),
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  },
}
