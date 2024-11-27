return {
	"L3MON4D3/LuaSnip",
	lazy = true,
	build = (not LazyVim.is_win())
			and "echo 'NOTE: jsregexp is optional, so not a big deal if it fails to build'; make install_jsregexp"
			or nil,
	opts = function()
		require("luasnip").filetype_extend("typescript", { "javascript" })
		require("luasnip.loaders.from_vscode").lazy_load()
		return {
			history = true,
			delete_check_events = "TextChanged",
		}
	end
}
