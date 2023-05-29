vim.g.mapleader = "'"
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

--require('neo-tree')
require('leap').add_default_mappings()
require("lsp")
require('window-picker').setup{}
require('mini.animate').setup()
vim.g.neo_tree_remove_legacy_commands = 1

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

vim.keymap.set('n', '<F2>', '<cmd>Neotree toggle<cr>')

vim.o.number = true
vim.o.wildmenu = true
vim.o.wildmode = 'longest:full,full'
vim.o.termguicolors = true
vim.cmd.colorscheme('habamax')
