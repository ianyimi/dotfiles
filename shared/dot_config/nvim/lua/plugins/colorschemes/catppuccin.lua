---@type Huez.ThemeConfig
local M = {
	styles = { "mocha" },
	set_theme = function(theme)
		---@type catppuccin.Config

		local config = {
			flavour = "mocha",  -- Set this explicitly
			transparent_background = true,
			highlight_overrides = {
				all = function(colors)
					vim.api.nvim_set_hl(0, "ColorColumn", { ctermbg = "NONE" })
					return {
						CurSearch = { bg = colors.lavender },
						IncSearch = { bg = colors.sapphire },
						CursorLineNr = { fg = colors.blue, style = { "bold" } },
						DashboardFooter = { fg = colors.sky },
						TreesitterContextBottom = { style = {} },
						WinSeparator = { fg = colors.overlay0, style = { "bold" } },
						["@markup.italic"] = { fg = colors.blue, style = { "italic" } },
						["@markup.strong"] = { fg = colors.blue, style = { "bold" } },
						Headline = { style = { "bold" } },
						Headline1 = { fg = colors.blue, style = { "bold" } },
						Headline2 = { fg = colors.pink, style = { "bold" } },
						Headline3 = { fg = colors.lavender, style = { "bold" } },
						Headline4 = { fg = colors.green, style = { "bold" } },
						Headline5 = { fg = colors.peach, style = { "bold" } },
						Headline6 = { fg = colors.flamingo, style = { "bold" } },
						rainbow1 = { fg = colors.blue, style = { "bold" } },
						rainbow2 = { fg = colors.pink, style = { "bold" } },
						rainbow3 = { fg = colors.lavender, style = { "bold" } },
						rainbow4 = { fg = colors.green, style = { "bold" } },
						rainbow5 = { fg = colors.peach, style = { "bold" } },
						rainbow6 = { fg = colors.flamingo, style = { "bold" } },
					}
				end,
			},
			color_overrides = {
				mocha = {
					-- Core accents (semantic roles, not literal matches)
					rosewater = "#FCD116", -- bright, punchy highlight (your gold)
					flamingo  = "#CE1126", -- vibrant warning/error (your red)
					pink      = "#ff5ca7", -- support (added warm pink)
					mauve     = "#d16aff", -- keyword, function (custom purple)
					red       = "#ff4f4f", -- softer than bold red, for diff/remove
					maroon    = "#b53030", -- dark tone for diagnostics
					peach     = "#f38b30", -- subtle warm orange
					yellow    = "#ffe666", -- softer yellow for less critical UI
					green     = "#006B3F", -- your base green, used for success/info
					teal      = "#2ba88f", -- adjusted complement to your green
					sky       = "#69d3e0", -- info & light context
					sapphire  = "#3f9dbf", -- complement to sky
					blue      = "#3f7fff", -- primary links/headers
					lavender  = "#a09fff", -- selection/focus borders

					-- Text colors
					text      = "#E0E0E0", -- bright readable text
					subtext1  = "#bfbfbf", -- softer text
					subtext0  = "#9a9a9a", -- even dimmer

					-- Overlay layers (for UI hierarchy)
					overlay2  = "#777777",
					overlay1  = "#5f5f5f",
					overlay0  = "#4a4a4a",

					-- Surface layers (panels, splits, UI)
					surface2  = "#363636",
					surface1  = "#2a2a2a",
					surface0  = "#1a1a1a",

					-- Base layers (backgrounds)
					base      = "#000000", -- your pure black background
					mantle    = "#0a0a0a", -- slightly lifted bg
					crust     = "#141414", -- dark framing bg
				},
				macchiato = {
					rosewater = "#F5B8AB",
					flamingo = "#F29D9D",
					pink = "#AD6FF7",
					mauve = "#FF8F40",
					red = "#E66767",
					maroon = "#EB788B",
					peach = "#FAB770",
					yellow = "#FACA64",
					green = "#70CF67",
					teal = "#4CD4BD",
					sky = "#61BDFF",
					sapphire = "#4BA8FA",
					blue = "#00BFFF",
					lavender = "#00BBCC",
					text = "#C1C9E6",
					subtext1 = "#A3AAC2",
					subtext0 = "#8E94AB",
					overlay2 = "#7D8296",
					overlay1 = "#676B80",
					overlay0 = "#464957",
					surface2 = "#3A3D4A",
					surface1 = "#2F313D",
					surface0 = "#1D1E29",
					base = "#0b0b12",
					mantle = "#11111a",
					crust = "#191926",
				},
			},
			integrations = {
				telescope = {
					enabled = true,
					style = "nvchad",
				},
				cmp = true,
				gitsigns = true,
				notify = true,
				which_key = true,
				indent_blankline = {
					enabled = true,
					colored_indent_levels = false,
				},
				native_lsp = {
					enabled = true,
					virtual_text = {
						errors = { "italic" },
						hints = { "italic" },
						warnings = { "italic" },
						information = { "italic" },
					},
					underlines = {
						errors = { "underline" },
						hints = { "underline" },
						warnings = { "underline" },
						information = { "underline" },
					},
					inlay_hints = {
						background = true,
					},
				},
				treesitter = true,
				dashboard = true,
			},
		}

		-- Apply Catppuccin setup
		require("catppuccin").setup(config)
		
		-- Force the colorscheme to apply
		vim.cmd("colorscheme catppuccin-mocha")
		
		-- Debug info
		vim.notify("Applied custom Catppuccin colors", vim.log.levels.INFO)
		
		return true
	end,
}

return M