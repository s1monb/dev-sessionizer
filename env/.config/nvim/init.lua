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


require 'mini.pick'.setup()
require 'mason'.setup()
require 'mini.pairs'.setup()
require 'nvim-surround'.setup()
require 'nvim-tree'.setup({
	filters = {
		dotfiles = false,
		custom = { '^.git$' }
	},
	git = {
		ignore = false
	}
})
require 'blink.cmp'.setup({
	fuzzy = {
		implementation = 'lua'
	}
})
require 'telescope'.setup({})
require 'nx'.setup({
	nx_cmd_root = 'npx nx',
})

require 'telescope'.load_extension('nx')


vim.lsp.enable({ 'lua_ls', 'rust_analyzer', 'tinymist', 'marksman', 'ts_ls' })

vim.cmd('colorscheme gruvbox')
vim.cmd(':hi statusline guibg=NONE')

require('config.keymaps')
