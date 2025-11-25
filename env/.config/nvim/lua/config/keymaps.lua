local map = vim.keymap.set

-- General
map('n', '<leader>o', ':update<CR> :source<CR>')
map('n', '<leader>w', ':write<CR>')
map('n', '<leader>q', ':quit<CR>')

-- Navigation
map({'n', 'v', 'x'}, 'H', ':bprevious<CR>')
map({'n', 'v', 'x'}, 'L', ':bnext<CR>')
map('n', '<leader>ff', ':Pick files<CR>')
map('n', '<leader>fb', ':Pick buffers<CR>')
map('n', '<leader>fh', ':Pick help<CR>')
map('n', '<leader>e', ':Oil<CR>')
map('n', '<leader>km', ':e ~/.config/nvim/lua/config/keymaps.lua<CR>')

-- Copy/Cut with computer clipboard
map({ 'n', 'v', 'x' }, '<leader>y', '"+y<CR>')
map({ 'n', 'v', 'x' }, '<leader>d', '"+d<CR>')

-- LSP
map('n', '<leader>lf', vim.lsp.buf.format)
map('n', 'gca', vim.lsp.buf.code_action)
map('n', 'gd', vim.diagnostic.open_float)

-- Git
map('n', '<leader>lg', ':LazyGit<CR>')

-- surround:
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
map('n', '<leader>bx', ':bd<CR>')
