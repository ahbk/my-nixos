require('nvim-tree').setup()
require('leap').add_default_mappings()
require("lsp")

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

vim.keymap.set('n', '<F2>', require('nvim-tree.api').tree.open)

vim.o.number = true
vim.o.wildmenu = true
vim.o.wildmode = 'longest:full,full'
vim.o.termguicolors = true
vim.cmd.colorscheme('habamax')

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
