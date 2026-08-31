-- Markdown buffer-local setup.
--
-- (This file used to stop the treesitter highlighter above 1500 lines and fall
-- back to Vim's regex syntax. That traded a real stall for unreadable specs:
-- `syntax/markdown.vim` sets `syn sync minlines=50`, so a fenced block longer
-- than the sync window lost its highlighting entirely below it -- verified with
-- `synstack()` returning nothing 200+ lines into a ```typescript fence. The real
-- cost was markdown's `conceal_lines` query directive, now stripped in
-- lua/plugins/editor/treesitter.lua. The highlighter is affordable at any size
-- now, so the gate and the fallback are both gone -- and nothing here has to
-- out-order Nvim's own ftplugin/markdown.lua any more.)

local md = require("util.markdown")
local map = function(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { buffer = true, silent = true, desc = desc })
end

-- Toggle the task checkbox on the cursor line from ANY column, or across a
-- visual selection. <C-Space> for the one-handed reflex, <leader>T for the
-- leader route.
--
-- <leader>T rather than <leader>tt: the `<leader>t` prefix already carries six
-- maps (to/tf/tl/te huez, tc ts-context, tp mini-pairs), and a bare `T` costs
-- one keystroke with no 'timeoutlen' wait. Free everywhere, including the
-- disabled specs that still hold capitals (B, D, Y, E, X, Z).
--
-- The `x` mapping reads the range while visual mode is still active -- Nvim
-- keeps it active for the duration of a Lua callback, so `line("v")` is valid
-- inside `toggle_selection` -- then drops back to normal mode.
for _, lhs in ipairs({ "<C-Space>", "<leader>T" }) do
	map("n", lhs, md.toggle_current, "Toggle task checkbox")
	map("x", lhs, function()
		md.toggle_selection()
		vim.cmd("normal! \27")
	end, "Toggle task checkboxes")
end
