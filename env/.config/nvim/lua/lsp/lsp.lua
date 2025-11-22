vim.lsp.config("*", {
	capabilities = {
		workspace = {
			fileOperations = {
				didRename = true,
				willRename = true,
			},
		},
	},
})

vim.lsp.enable({
	"lua_ls",
})

-- LSP keymap
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { buffer = event.buf, silent = true, desc = "LSP: " .. desc })
		end

		-- Override Neovim lsp builtin
		map("<leader>ca", vim.lsp.buf.code_action, "Code Action", { "n", "x" })
		map("<leader>cr", vim.lsp.buf.rename, "Rename")
		map("<leader>cf", vim.lsp.buf.format, "Format")
	end,
})

--- Global Diagnostic ---
local diagnostics = {
	underline = true,
	update_in_insert = false,
	virtual_text = {
		current_line = true,
		spacing = 5,
		source = "if_many",
		prefix = "●",
	},
	severity_sort = true,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = " ",
			[vim.diagnostic.severity.WARN] = " ",
			[vim.diagnostic.severity.HINT] = " ",
			[vim.diagnostic.severity.INFO] = " ",
		},
	},
}
vim.diagnostic.config(vim.deepcopy(diagnostics))
