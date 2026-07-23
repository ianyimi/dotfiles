local colors = require("colors")
local settings = require("settings")

-- Aerospace mode indicator
-- This widget is controlled directly by aerospace via sketchybar --set commands
-- It shows when in non-main modes (e.g., service mode)
local aerospace_mode = sbar.add("item", "aerospace.mode", {
	position = "left",
	icon = {
		string = "",
		font = {
			style = settings.font.style_map["Bold"],
			size = 12.0,
		},
		color = colors.red,
		padding_left = 8,
		padding_right = 8,
	},
	label = { drawing = false },
	background = {
		color = colors.bg2,
		border_color = colors.red,
		border_width = 2,
	},
	padding_left = 5,
	padding_right = 5,
	drawing = false, -- Hidden by default (main mode)
})
