local map = function(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { desc = desc })
end
local wk = require('which-key')

-- Group names shown by which-key when a prefix is pressed
wk.add({
	{ '<leader>b', group = 'buffer' },
	{ '<leader>f', group = 'find' },
	{ '<leader>k', group = 'keymaps' },
	{ '<leader>l', group = 'lsp / lazygit' },
	{ '<leader>n', group = 'nx' },
	{ '<leader>t', group = 'tools' },
})

-- General
map('n', '<leader>o', ':update<CR> :source<CR>', 'Save and source file')
map('n', '<leader>w', ':write<CR>', 'Write file')
map('n', '<leader>q', ':quit<CR>', 'Quit window')
map('n', '<leader>?', function() wk.show({ global = false }) end, 'Buffer-local keymaps')

-- Navigation
map({'n', 'v', 'x'}, 'H', ':bprevious<CR>', 'Previous buffer')
map({'n', 'v', 'x'}, 'L', ':bnext<CR>', 'Next buffer')
map('n', '<leader>ff', ':Pick files<CR>', 'Find files')
map('n', '<leader>fb', ':Pick buffers<CR>', 'Find buffers')
map('n', '<leader>fh', ':Pick help<CR>', 'Find help')
map('n', '<leader>e', ':NvimTreeToggle<CR>', 'Toggle file tree')
map('n', '<leader>s', ':NvimTreeFocus<CR>', 'Focus file tree')
map('n', '<leader>km', ':e ~/.config/nvim/lua/config/keymaps.lua<CR>', 'Edit keymaps file')
map('n', '<leader>kk', function() wk.show({ global = true }) end, 'Show all keymaps')
map('n', '<leader>tg', ':te esc-caps-swap<CR><bclose>', 'Swap Esc and Caps Lock')

-- Copy/Cut with computer clipboard
map({ 'n', 'v', 'x' }, '<leader>y', '"+y<CR>', 'Yank to system clipboard')
map({ 'n', 'v', 'x' }, '<leader>d', '"+d<CR>', 'Cut to system clipboard')

-- LSP
map('n', '<leader>lf', vim.lsp.buf.format, 'Format buffer')
map('n', 'gca', vim.lsp.buf.code_action, 'Code action')
map('n', 'ge', vim.diagnostic.open_float, 'Show diagnostic')
map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')

-- NX (nrwl)
map('n', '<leader>nx', '<cmd>Telescope nx actions<CR>', 'Nx actions')

-- Git
map('n', '<leader>lg', ':LazyGit<CR>', 'LazyGit')

-- surround (nvim-surround describes its own keymaps, so which-key lists them after ys/ds/cs):
--  Old text                    Command         New text
--------------------------------------------------------------------------------
--    surr*ound_words             ysiw)           (surround_words)
--    surr*ound_words             ysiw(           ( surround_words )
--    *make strings               ys$"            "make strings"
--    [delete ar*ound me!]        ds]             delete around me!
--    remove <b>HTML t*ags</b>    dst             remove HTML tags
--    'change quot*es'            cs'"            "change quotes"
--    <b>or tag* types</b>        csth1<CR>       <h1>or tag types</h1>
--    delete(functi*on calls)     dsf             function calls

-- buffers:
map('n', '<leader>bx', ':bd<CR>', 'Close buffer')
