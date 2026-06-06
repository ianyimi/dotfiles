return {
	"kylechui/nvim-surround",
	event = "VeryLazy",
	init = function()
		-- v4 API: Disable conflicting 'gr' mappings before plugin loads
		vim.g.nvim_surround_no_normal_mappings = true
	end,
	config = function()
		-- v4 API: setup() is only for configuration, not keymaps
		require("nvim-surround").setup({
			-- Configuration options only (none needed for basic setup)
		})
		
		-- Manually set up all the keymaps we want (avoiding 'gr' conflict)
		vim.keymap.set("n", "ys", "<Plug>(nvim-surround-normal)", {
			desc = "Add a surrounding pair around a motion",
		})
		vim.keymap.set("n", "yss", "<Plug>(nvim-surround-normal-cur)", {
			desc = "Add a surrounding pair around current line",
		})
		vim.keymap.set("n", "yS", "<Plug>(nvim-surround-normal-line)", {
			desc = "Add a surrounding pair around current line (linewise)",
		})
		vim.keymap.set("n", "ySS", "<Plug>(nvim-surround-normal-cur-line)", {
			desc = "Add a surrounding pair around current line (both ends)",
		})
		vim.keymap.set("x", "S", "<Plug>(nvim-surround-visual)", {
			desc = "Add a surrounding pair around visual selection",
		})
		vim.keymap.set("x", "gS", "<Plug>(nvim-surround-visual-line)", {
			desc = "Add a surrounding pair around visual selection (linewise)",
		})
		vim.keymap.set("n", "ds", "<Plug>(nvim-surround-delete)", {
			desc = "Delete a surrounding pair",
		})
		vim.keymap.set("n", "cs", "<Plug>(nvim-surround-change)", {
			desc = "Change a surrounding pair",
		})
		vim.keymap.set("n", "cS", "<Plug>(nvim-surround-change-line)", {
			desc = "Change a surrounding pair (linewise)",
		})
		-- IMPORTANT: Use 'gR' instead of 'gr' to avoid LSP conflict
		vim.keymap.set("n", "gR", "<Plug>(nvim-surround-replace)", {
			desc = "Replace a surrounding pair (avoids LSP 'gr' conflict)",
		})
		vim.keymap.set("n", "gRR", "<Plug>(nvim-surround-replace-line)", {
			desc = "Replace a surrounding pair (linewise)",
		})
		-- Insert mode mappings
		vim.keymap.set("i", "<C-g>s", "<Plug>(nvim-surround-insert)", {
			desc = "Add a surrounding pair (insert mode)",
		})
		vim.keymap.set("i", "<C-g>S", "<Plug>(nvim-surround-insert-line)", {
			desc = "Add a surrounding pair (insert mode, linewise)",
		})
	end,
}
