return {
	{
		-- highlighting for chezmoi files template files
		"alker0/chezmoi.vim",
		init = function()
			vim.g["chezmoi#use_tmp_buffer"] = 1
			vim.g["chezmoi#source_dir_path"] = os.getenv("HOME") .. "/.local/share/chezmoi"
		end,
	},
	{
		"xvzc/chezmoi.nvim",
		opts = {
			edit = {
				watch = true,
				force = false,
			},
			notification = {
				on_open = true,
				on_apply = true,
				on_watch = false,
			},
			telescope = {
				select = { "<CR>", "<Tab>" },
			},
		},
		init = function()
			-- Guard: skip watch() for paths that are never chezmoi-managed
			local function should_watch(filepath)
				-- Paths inside .git, .agent, .claude, .omp, .pi, node_modules never get managed
				local unmanaged_dirs = { ".git", ".agent", ".claude", ".omp", ".pi", "node_modules" }
				for _, dir in ipairs(unmanaged_dirs) do
					if filepath:find(dir, 1, true) then
						return false
					end
				end
				return true
			end

			-- run chezmoi edit on file enter (with guard)
			vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
				group = vim.api.nvim_create_augroup("chezmoi_edit", { clear = true }),
				pattern = { os.getenv("HOME") .. "/.local/share/chezmoi/*" },
				callback = function(ev)
					if should_watch(ev.file) then
						vim.schedule(function()
							require("chezmoi.commands.__edit").watch(ev.buf)
						end)
					end
				end,
			})
		end,
	},
}
