vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require('leap').add_default_mappings()
require("lsp")
require('window-picker').setup{}
require('mini.animate').setup()
require('toggleterm').setup { open_mapping='<leader>t' }
vim.g.neo_tree_remove_legacy_commands = 1

require('telescope').load_extension('fzf')
local telescope = require('telescope.builtin')
vim.keymap.set('n', '<leader>fg', telescope.live_grep, {})
vim.keymap.set('n', '<leader>fb', telescope.buffers, {})
vim.keymap.set('n', '<leader>fh', telescope.help_tags, {})
vim.keymap.set('n', '<Leader>ff', function() telescope.find_files({ hidden = true }) end)

vim.keymap.set('n', '<F2>', '<cmd>Neotree toggle<cr>')

vim.o.number = true
vim.o.wildmenu = true
vim.o.wildmode = 'longest:full,full'
vim.o.termguicolors = true
vim.cmd.colorscheme('kanagawa-dragon')
