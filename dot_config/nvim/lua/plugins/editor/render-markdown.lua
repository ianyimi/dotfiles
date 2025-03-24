return {
	'MeanderingProgrammer/render-markdown.nvim',
	enabled = true,
	-- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
	-- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
	dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
	init = function()
		-- Helper to get highlight color from current theme
		local function get_color(group, attr)
			local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
			if ok and hl[attr] then
				return string.format("#%06x", hl[attr])
			end
		end

		-- Text foreground (usually Normal fg)
		local fg = get_color("Normal", "fg") or "#ffffff"

		-- Headline background shades from various theme groups
		local bg_headlines = {
			get_color("CursorLine", "bg") or "#1e1e2e",
			get_color("Visual", "bg") or "#2e2e3e",
			get_color("Pmenu", "bg") or "#3e3e4e",
			get_color("StatusLine", "bg") or "#4e4e5e",
			get_color("LineNr", "bg") or "#5e5e6e",
			get_color("Folded", "bg") or "#6e6e7e",
		}

		-- Inline code colors (from String + Normal)
		local inline_fg = get_color("String", "fg") or "#00ff88"
		local inline_bg = get_color("Normal", "bg") or "#000000"

		-- Define Headline highlight groups
		for i = 1, 6 do
			vim.cmd(string.format("highlight Headline%dBg guifg=%s guibg=%s", i, fg, bg_headlines[i]))
			vim.cmd(string.format("highlight Headline%dFg cterm=bold gui=bold guifg=%s", i, bg_headlines[i]))
		end

		-- Inline code styling
		vim.cmd(string.format("highlight RenderMarkdownCodeInline guifg=%s guibg=%s", inline_fg, inline_bg))
	end,
	---@module 'render-markdown'
	opts = {
		bullet = {
			enabled = true,
		},
		checkbox = {
			enabled = true,
			position = "inline",
			unchecked = {
				icon = "   󰄱 ",
				highlight = "RenderMarkdownUnchecked",
				scope_highlight = nil,
			},
			checked = {
				icon = "   󰱒 ",
				highlight = "RenderMarkdownChecked",
				scope_highlight = nil,
			},
		},
		html = {
			enabled = true,
			comment = {
				conceal = false,
			},
		},
		code = {
			-- Force proper interpretation of code blocks with custom syntax
			enabled = true,
			inline = {
				conceal = true,
				highlight = "RenderMarkdownCodeInline",
			},
			left_pad = 2,
			block = {
				-- Prevent code blocks from interfering with heading detection
				format_leading = true,
				format_trailing = true,
				scope_highlight = nil,
			},
		},
		heading = {
			sign = false,
			-- Make headings more visible and consistent
			icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
			width = "block",
			min_width = 30
		},
		-- Add specific handling for Obsidian-style callouts
		callouts = {
			enabled = true,
		},
		injections = {
			markdown = {
				enabled = true,
				-- Custom TreeSitter query with more precise handling of code blocks
				query = [[
					;; Define special handling for anyblock code blocks
					((fenced_code_block
						(info_string) @_info
						(code_fence_content) @obsidian)
					(#match? @_info "^```anyblock")
					(#set! injection.language "markdown")
					(#set! injection.combined)
					(#set! injection.self))
					
					;; Same for dataview, dataviewjs, tasks, calendar-nav
					((fenced_code_block
						(info_string) @_info
						(code_fence_content) @obsidian)
					(#match? @_info "^```(dataview|dataviewjs|tasks|calendar-nav)")
					(#set! injection.language "markdown")
					(#set! injection.combined)
					(#set! injection.self))
				]],
			},
		},
		debug = true, -- Enable debug mode to see parsing issues in :messages
	},
}
