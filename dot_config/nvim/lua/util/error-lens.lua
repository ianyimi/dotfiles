---@class lazyvim.util.error_lens
local M = {}

-- Convert hex color to RGB
---@param hex string Hex color like "#RRGGBB"
---@return number, number, number RGB values (0-255)
local function hex_to_rgb(hex)
	hex = hex:gsub("#", "")
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Convert RGB to hex color
---@param r number Red (0-255)
---@param g number Green (0-255)
---@param b number Blue (0-255)
---@return string Hex color like "#RRGGBB"
local function rgb_to_hex(r, g, b)
	return string.format("#%02x%02x%02x", math.floor(r), math.floor(g), math.floor(b))
end

-- Blend foreground color with background using alpha
---@param fg string Foreground hex color
---@param bg string Background hex color
---@param alpha number Opacity (0.0-1.0)
---@return string Blended hex color
local function alpha_blend(fg, bg, alpha)
	local fg_r, fg_g, fg_b = hex_to_rgb(fg)
	local bg_r, bg_g, bg_b = hex_to_rgb(bg)

	local r = fg_r * alpha + bg_r * (1 - alpha)
	local g = fg_g * alpha + bg_g * (1 - alpha)
	local b = fg_b * alpha + bg_b * (1 - alpha)

	return rgb_to_hex(r, g, b)
end

-- Get highlight color from a highlight group
---@param group string Highlight group name
---@param attr string Attribute to get (fg, bg, etc.)
---@return string|nil Hex color or nil if not found
local function get_hl_color(group, attr)
	local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
	if hl and hl[attr] then
		return string.format("#%06x", hl[attr])
	end
	return nil
end

-- Setup diagnostic line highlighting with theme colors
---@param opts? {opacity?: number} Configuration options
function M.setup(opts)
	opts = opts or {}
	local opacity = opts.opacity or 0.1 -- Default 10% opacity

	-- Function to apply diagnostic line highlights
	local function apply_diagnostic_highlights()
		-- Get background color from Normal highlight
		local bg = get_hl_color("Normal", "bg") or "#000000"

		-- Define diagnostic severity levels and their highlight groups
		local diagnostics = {
			{ severity = "Error", hl_source = "DiagnosticError" },
			{ severity = "Warn", hl_source = "DiagnosticWarn" },
			{ severity = "Info", hl_source = "DiagnosticInfo" },
			{ severity = "Hint", hl_source = "DiagnosticHint" },
		}

		-- Apply blended background for each diagnostic level
		for _, diag in ipairs(diagnostics) do
			local fg = get_hl_color(diag.hl_source, "fg")
			if fg then
				local blended = alpha_blend(fg, bg, opacity)
				local hl_name = "DiagnosticLine" .. diag.severity

				-- Create highlight group with blended background
				vim.api.nvim_set_hl(0, hl_name, { bg = blended })
			end
		end

		-- Configure vim.diagnostic to use our line highlights
		vim.diagnostic.config({
			virtual_text = true, -- Keep inline diagnostics
			signs = true,        -- Keep gutter signs
			underline = true,    -- Keep underlines
			update_in_insert = false,
			severity_sort = true,
			float = {
				border = "rounded",
				source = "always",
			},
			-- Apply line highlighting
			---@diagnostic disable-next-line: missing-fields
			linehl = {
				[vim.diagnostic.severity.ERROR] = "DiagnosticLineError",
				[vim.diagnostic.severity.WARN] = "DiagnosticLineWarn",
				[vim.diagnostic.severity.INFO] = "DiagnosticLineInfo",
				[vim.diagnostic.severity.HINT] = "DiagnosticLineHint",
			},
		})
	end

	-- Apply highlights immediately
	apply_diagnostic_highlights()

	-- Reapply when colorscheme changes
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("error_lens_colorscheme", { clear = true }),
		callback = function()
			-- Small delay to ensure colorscheme is fully loaded
			vim.defer_fn(apply_diagnostic_highlights, 50)
		end,
	})
end

-- Toggle diagnostic line highlighting on/off
function M.toggle()
	local current_config = vim.diagnostic.config()
	if current_config.linehl then
		-- Disable line highlighting
		vim.diagnostic.config({ linehl = nil })
		vim.notify("Error Lens: Disabled", vim.log.levels.INFO)
	else
		-- Re-enable by running setup again
		M.setup()
		vim.notify("Error Lens: Enabled", vim.log.levels.INFO)
	end
end

-- Update opacity dynamically
---@param opacity number New opacity value (0.0-1.0)
function M.set_opacity(opacity)
	M.setup({ opacity = opacity })
	vim.notify(string.format("Error Lens opacity: %.1f%%", opacity * 100), vim.log.levels.INFO)
end

return M
