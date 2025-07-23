return {
	"MagicDuck/grug-far.nvim",
	opts = { headerMaxWidth = 80 },
	cmd = "GrugFar",
	keys = function()
		local grug = require("grug-far")
		return {
			{
				"<leader>fr",
				function()
					local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
					grug.open({
						transient = true,
						prefills = {
							filesFilter = ext and ext ~= "" and "*." .. ext or nil,
						},
					})
				end,
				mode = { "n", "v" },
				desc = "[F]ind and [R]eplace",
			},
			{
				"<leader>fR",
				function()
					local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
					grug.open({
						transient = true,
						prefills = {
							paths = vim.fn.expand("%")
						},
					})
				end,
				mode = { "n", "v" },
				desc = "[F]ind and [R]eplace (cwd)",
			},
			{
				"<leader>fc",
				function()
					local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
					grug.open({
						transient = true,
						prefills = {
							search = vim.fn.expand("<cword>")
						},
					})
				end,
				mode = { "n", "v" },
				desc = "[F]ind [C]urrent word",
			},
		}
	end,
}
