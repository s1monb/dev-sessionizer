-- Disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.number = true
vim.opt.cursorcolumn = false
vim.opt.relativenumber = true
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.swapfile = false
vim.opt.termguicolors = true
vim.opt.undofile = true
vim.opt.incsearch = true
vim.opt.winborder = 'rounded'
vim.opt.signcolumn = 'yes'

vim.g.mapleader = ' '

vim.pack.add({
	{ src = 'https://github.com/ellisonleao/gruvbox.nvim', version = '5e0a460d8e0f7f669c158dedd5f9ae2bcac31437' },
	{ src = 'https://github.com/stevearc/oil.nvim', version = '01cb3a8ad7d5e8707041edc775af83dbf33838f4' },
	{ src = 'https://github.com/echasnovski/mini.pairs', version = 'b316e68f2d242d5bd010deaab645daa27ed86297' },
	{ src = 'https://github.com/echasnovski/mini.pick', version = 'b4351399db5043a781a32699a1bde60b747f711f' },
	{ src = 'https://github.com/mason-org/mason.nvim', version = '57e5a8addb8c71fb063ee4acda466c7cf6ad2800' },
	{ src = 'https://github.com/neovim/nvim-lspconfig', version = 'f1237a8b3c243608a7116fa1ad216c441d7c2264' },
	{ src = 'https://github.com/kdheepak/lazygit.nvim', version = '2305deed25bc61b866d5d39189e9105a45cf1cfb' },
	{ src = 'https://github.com/kylechui/nvim-surround', version = 'fcfa7e02323d57bfacc3a141f8a74498e1522064' },
	{ src = 'https://github.com/saghen/blink.cmp', version = '4b18c32adef2898f95cdef6192cbd5796c1a332d' },
	{ src = 'https://github.com/nvim-tree/nvim-tree.lua', version = 'ae16aab5fd1792b97758622b9fb53408ec804fd8' },
})

require 'mini.pick'.setup()
require 'mason'.setup()
require 'mini.pairs'.setup()
require 'oil'.setup()
require 'nvim-surround'.setup()
require 'nvim-tree'.setup()
require 'blink.cmp'.setup({
	fuzzy = {
		implementation = 'lua'
	}
})

vim.lsp.enable({ 'lua_ls', 'rust_analyzer', 'tinymist', 'marksman' })

vim.cmd('colorscheme gruvbox')
vim.cmd(':hi statusline guibg=NONE')

require('config.keymaps')
