return {
	"ThePrimeagen/git-worktree.nvim",
	opts = function()
		local worktree = require("git-worktree")
		-- Function to normalize paths to use backslashes
		local function normalize_path(path)
			local sep = package.config:sub(1, 1)
			if sep == "\\" then
				-- On Windows, replace '/' with '\'
				return path:gsub("/", "\\")
			else
				-- On Unix-like systems (macOS, Linux), return the path as-is
				return path
			end
		end
		worktree.on_tree_change(function(op, metadata)
			local oil_ok, oil = pcall(require, "oil")
			local mini_files_ok, mini_files = pcall(require, "mini.files")
			if op == worktree.Operations.Switch then
				-- Convert to absolute path - metadata.path is relative to git root
				local new_path = metadata.path
				-- If path is not absolute, make it absolute
				if not vim.startswith(new_path, "/") and not vim.startswith(new_path, "~") then
					-- Get the git toplevel directory
					local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
					if git_root and git_root ~= "" then
						-- Build absolute path relative to git root's parent
						local parent_dir = vim.fn.fnamemodify(git_root, ":h")
						new_path = parent_dir .. "/" .. new_path
					end
				end
				new_path = normalize_path(vim.fn.fnamemodify(new_path, ":p"))

				-- Use pcall to safely change directory
				local ok, err = pcall(vim.api.nvim_set_current_dir, new_path)
				if ok then
					if oil_ok then
						oil.open(new_path)
					elseif mini_files_ok then
						mini_files.open(new_path)
					end
					print("Updated Directory: " .. new_path)
				else
					vim.notify("Failed to change directory: " .. tostring(err), vim.log.levels.ERROR)
				end
			end
		end)

		return {
			update_on_change = true,
			clearjumps_on_change = true,
		}
	end,
}
