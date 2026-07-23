return {
	"mbbill/undotree",
	event = "VeryLazy",
	keys = {
		{ "<leader>u", "<Cmd>UndotreeToggle<CR>", desc = "Undotree Toggle" }
	},
	config = function()
		vim.g.undotree_WindowLayout = 4
		vim.g.undotree_SplitWidth = 40
		vim.g.undotree_DiffpanelHeight = 15
		vim.g.undotree_SetFocusWhenToggle = 1
		vim.g.undotree_RelativeTimestamp = 0
		vim.g.undotree_DisabledFiletypes = { "env" }
	end
}
