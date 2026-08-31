-- Markdown task-list helpers.
--
-- Toggling is column-independent on purpose: the cursor is almost never on the
-- checkbox when you decide a task is done, and render-markdown replaces `[ ]`
-- with a glyph, so aiming at it is guesswork anyway.

local M = {}

-- `- [ ] task`, `* [x] task`, `+ [X] task`, `1. [ ] task`, any indent.
-- Captured: everything up to and including the opening bracket, then the mark.
local ITEM = "^(%s*[-*+]%s+%[)([^%]])(%])"
local ORDERED = "^(%s*%d+[.)]%s+%[)([^%]])(%])"

---@param line string
---@return string? prefix, string? mark, string? suffix
local function split(line)
	local prefix, mark, suffix = line:match(ITEM)
	if prefix then
		return prefix, mark, suffix
	end
	return line:match(ORDERED)
end

--- Is `line` a markdown task-list item?
---@param line string
---@return boolean
function M.is_task(line)
	return split(line) ~= nil
end

--- Rewrite one task-list line.
---@param line string
---@param want boolean|nil `true` check, `false` uncheck, `nil` flip
---@return string? rewritten `nil` when the line is not a task item, or already in the wanted state
local function rewrite(line, want)
	local prefix, mark, suffix = split(line)
	if not prefix then
		return nil
	end
	local checked = mark ~= " "
	local target = want == nil and not checked or want
	if target == checked then
		return nil
	end
	local rest = line:sub(#prefix + #mark + #suffix + 1)
	return prefix .. (target and "x" or " ") .. suffix .. rest
end

--- Toggle the task checkbox on every line in `srow`..`erow` (1-indexed, inclusive).
---
--- With more than one line, the whole range is driven to a single state rather
--- than flipped line by line: mixed selections check everything, a fully checked
--- selection unchecks. That makes a repeated keypress on a visual block do
--- something predictable instead of inverting the range each time.
---@param srow integer
---@param erow integer
---@param bufnr integer?
function M.toggle(srow, erow, bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, srow - 1, erow, false)

	local want ---@type boolean?
	if #lines > 1 then
		local tasks, checked = 0, 0
		for _, line in ipairs(lines) do
			local prefix, mark = split(line)
			if prefix then
				tasks = tasks + 1
				if mark ~= " " then
					checked = checked + 1
				end
			end
		end
		if tasks == 0 then
			vim.notify("No task list items in selection", vim.log.levels.WARN)
			return
		end
		want = checked < tasks
	end

	local changed = 0
	for i, line in ipairs(lines) do
		local new = rewrite(line, want)
		if new then
			-- One call per line: a single set_lines over the range would rewrite
			-- untouched lines too, which discards their extmarks and forces
			-- render-markdown to re-render the whole span.
			vim.api.nvim_buf_set_lines(bufnr, srow + i - 2, srow + i - 1, false, { new })
			changed = changed + 1
		end
	end

	if changed == 0 and #lines == 1 then
		vim.notify("Not a task list item", vim.log.levels.WARN)
	end
end

--- Toggle the task on the cursor line, from any column.
---@param bufnr integer?
function M.toggle_current(bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	M.toggle(row, row, bufnr)
end

--- Toggle every task in the last visual selection.
---@param bufnr integer?
function M.toggle_selection(bufnr)
	local srow = vim.fn.line("v")
	local erow = vim.fn.line(".")
	if srow > erow then
		srow, erow = erow, srow
	end
	M.toggle(srow, erow, bufnr)
end

return M
