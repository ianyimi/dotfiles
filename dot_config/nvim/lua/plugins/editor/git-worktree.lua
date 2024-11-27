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
				local new_path = normalize_path(metadata.path)
				vim.api.nvim_set_current_dir(new_path)
				if oil_ok then
					oil.open(new_path)
				elseif mini_files_ok then
					mini_files.open(new_path)
				end
				print("Updated Directory: " .. new_path)
			end
		end)

		return {
			update_on_change = true,
			clearjumps_on_change = true,
		}
	end,
}
