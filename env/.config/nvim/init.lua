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
	{ src = 'https://github.com/ellisonleao/gruvbox.nvim' },
	{ src = 'https://github.com/stevearc/oil.nvim' },
	{ src = 'https://github.com/echasnovski/mini.pairs' },
	{ src = 'https://github.com/echasnovski/mini.pick' },
	{ src = 'https://github.com/mason-org/mason.nvim' },
	{ src = 'https://github.com/neovim/nvim-lspconfig' },
	{ src = 'https://github.com/kdheepak/lazygit.nvim' },
	{ src = 'https://github.com/kylechui/nvim-surround' },
	{ src = 'https://github.com/saghen/blink.cmp', version = '1.*' },
})

require 'mini.pick'.setup()
require 'mason'.setup()
require 'mini.pairs'.setup()
require 'oil'.setup()
require 'nvim-surround'.setup()
require 'blink.cmp'.setup({
	fuzzy = {
		implementation = 'lua'
	}
})

vim.lsp.enable({ 'lua_ls', 'rust_analyzer', 'tinymist', 'marksman' })

vim.cmd('colorscheme gruvbox')
vim.cmd(':hi statusline guibg=NONE')

require('config.keymaps')
