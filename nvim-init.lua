require("nvim-tree").setup()
vim.keymap.set('n', '<F2>', require("nvim-tree.api").tree.open)
