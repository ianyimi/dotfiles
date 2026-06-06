return {
	"neovim/nvim-lspconfig",
	dependencies = {
		"mason-org/mason.nvim",
		"mason-org/mason-lspconfig.nvim",
		"hrsh7th/cmp-nvim-lsp",
		"j-hui/fidget.nvim",
		"luckasRanarison/tailwind-tools.nvim",
		"onsails/lspkind-nvim",
		"hrsh7th/nvim-cmp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-cmdline",
		"saadparwaiz1/cmp_luasnip",
		"L3MON4D3/LuaSnip",
		"rafamadriz/friendly-snippets",
		"dmmulroy/ts-error-translator.nvim",
	},
	config = function()
		-- Setup fidget for LSP progress notifications
		require("fidget").setup({
		notification = {
			override_vim_notify = true,
		},
	})

	-- Mirror all notifications into :messages so they are copyable
	local __orig_notify = vim.notify
	vim.notify = function(msg, level, opts)
		-- push content to :messages using echomsg so it persists in history
		local function echomsg_line(line)
			-- use :echomsg with a quoted string to handle special chars
			vim.cmd("silent! echomsg " .. vim.fn.string(tostring(line)))
		end
		if type(msg) == "table" then
			for _, line in ipairs(msg) do echomsg_line(line) end
		else
			for _, line in ipairs(vim.split(tostring(msg), "\n", { plain = true })) do echomsg_line(line) end
		end
		return __orig_notify(msg, level, opts)
	end

	-- Also mirror LSP $/progress messages into :messages without altering Fidget
	local __orig_progress = vim.lsp.handlers["$/progress"]
	vim.lsp.handlers["$/progress"] = function(err, result, ctx, config)
		pcall(function()
			if result and type(result.value) == "table" then
				local v = result.value
				local msg = v.message or v.title or v.kind
				if msg and msg ~= "" then
					vim.cmd("silent! echomsg " .. vim.fn.string("[LSP] " .. msg))
				end
			end
		end)
		return __orig_progress and __orig_progress(err, result, ctx, config)
	end

	-- Priority order for hover results when multiple LSPs respond (e.g. tailwindcss + vtsls).
	-- Higher priority client "wins" when both have content.
	-- We render the popup ourselves to guarantee treesitter syntax highlighting on
	-- fenced code blocks (CSS in tailwindcss hover, TS in vtsls JSDoc, etc.).
	-- API refs:
	--   vim.lsp.buf_request_all          https://neovim.io/doc/user/lsp.html
	--   vim.lsp.util.open_floating_preview
	--   vim.lsp.util.convert_input_to_markdown_lines
	local hover_priority = { "tailwindcss", "vtsls", "ts_ls", "eslint" }
	local function smart_hover()
		local bufnr = vim.api.nvim_get_current_buf()
		local params = vim.lsp.util.make_position_params(0, "utf-16")

		vim.lsp.buf_request_all(bufnr, "textDocument/hover", params, function(results)
			local best_client, best_result, best_rank = nil, nil, math.huge

			for client_id, response in pairs(results) do
				local res = response.result
				if res and res.contents then
					local c = res.contents
					local has_content = false
					if type(c) == "string" then
						has_content = c ~= ""
					elseif type(c) == "table" then
						has_content = (c.value and c.value ~= "") or #c > 0
					end

					if has_content then
						local client = vim.lsp.get_client_by_id(client_id)
						local rank = math.huge
						if client then
							for i, name in ipairs(hover_priority) do
								if client.name == name then rank = i; break end
							end
						end
						if rank < best_rank then
							best_rank, best_client, best_result = rank, client, res
						end
					end
				end
			end

			if not best_result then
				vim.notify("No hover information available", vim.log.levels.INFO)
				return
			end

			-- Stash the raw response globally so we can inspect it with
			-- :lua print(vim.inspect(_G.__last_hover_result))
			-- Helpful for diagnosing unwrap failures without polluting :messages on
			-- every hover.
			_G.__last_hover_result = best_result

			-- Decide the popup syntax. The goal: avoid markdown rendering whenever the
			-- content is effectively a single block of code in one language, because
			-- markdown rendering leaves the ```lang fence delimiters visible (vim's
			-- default markdown ftplugin doesn't conceal them and render-markdown.nvim
			-- is disabled on this popup to avoid re-triggering the nvim-treesitter
			-- predicate bug).
			--
			-- Three cases:
			--  1. MarkedString with `language` (tailwindcss CSS) → render as that language.
			--  2. MarkupContent whose body is exactly ONE fenced code block (vtsls type-
			--     only hovers like "(parameter) children: ReactNode") → unwrap the
			--     fence, render as the inner language. Looks clean like case 1.
			--  3. Anything else (prose, mixed prose+code) → render as markdown and set
			--     conceallevel on the buffer so fence delimiters are at least hidden.
			local contents = best_result.contents
			local lines, syntax

			-- Try to unwrap content that's only a single fenced code block.
			-- Returns (language, code_lines) if the input is exactly one fenced block
			-- (after stripping blank lines around it). Otherwise nil.
			-- Line-based instead of regex-based so CRLF, trailing whitespace, info-string
			-- attributes (```ts {1,2}), and language aliases don't break detection.
			local function unwrap_single_fence(text)
				if type(text) ~= "string" or text == "" then return nil end
				local raw_lines = vim.split(text, "\n", { plain = true })
				-- Strip CR (handle CRLF) and trim leading/trailing blank lines
				local lines = {}
				for _, l in ipairs(raw_lines) do
					table.insert(lines, (l:gsub("\r$", "")))
				end
				while #lines > 0 and lines[1]:match("^%s*$") do table.remove(lines, 1) end
				while #lines > 0 and lines[#lines]:match("^%s*$") do table.remove(lines) end
				if #lines < 2 then return nil end

				-- First line must be ```<lang>[anything]. Capture just the language word.
				local lang = lines[1]:match("^%s*```([%w_%-%.]+)")
				if not lang then return nil end
				-- Last line must be a bare ``` (maybe with trailing whitespace)
				if not lines[#lines]:match("^%s*```%s*$") then return nil end
				-- No interior fence lines (would mean multiple blocks)
				for i = 2, #lines - 1 do
					if lines[i]:match("^%s*```") then return nil end
				end

				-- Extract the body (everything between the two fences)
				local body = {}
				for i = 2, #lines - 1 do table.insert(body, lines[i]) end
				return lang, body
			end

			-- Extract the raw markdown body regardless of which LSP shape we got.
			-- LSP allows hover.contents to be: MarkedString (string or {language,value}),
			-- MarkedString[] (legacy), or MarkupContent ({kind,value}). vtsls in practice
			-- returns a bare string — not a table — so we have to handle that case too.
			local raw_md = nil
			if type(contents) == "string" then
				raw_md = contents
			elseif type(contents) == "table" then
				if contents.language and contents.value then
					-- MarkedString object — already a single language. Skip markdown
					-- entirely; render as that language. (tailwindcss CSS case.)
					lines = vim.split(contents.value, "\n", { plain = true })
					syntax = contents.language
				elseif contents.kind and contents.value then
					-- MarkupContent — plain markdown body.
					raw_md = contents.value
				elseif vim.islist(contents) then
					-- MarkedString[] — join into markdown, treating bare strings as
					-- prose and {language,value} entries as fenced code blocks.
					local parts = {}
					for _, item in ipairs(contents) do
						if type(item) == "string" then
							table.insert(parts, item)
						elseif type(item) == "table" and item.language and item.value then
							table.insert(parts, "```" .. item.language .. "\n" .. item.value .. "\n```")
						end
					end
					raw_md = table.concat(parts, "\n\n")
				end
			end

			-- If we extracted a markdown body, try to unwrap a single-fence case before
			-- falling back to markdown rendering. This catches the common vtsls shape
			-- (a bare string that's just ```typescript\n...\n```) so type-only hovers
			-- like `(parameter) children: ReactNode` render as clean TypeScript with no
			-- markdown wrapper visible — same look as the tailwindcss CSS hover.
			if raw_md and not syntax then
				local lang, code_lines = unwrap_single_fence(raw_md)
				if lang then
					lines = code_lines
					syntax = lang
				else
					lines = vim.split(raw_md, "\n", { plain = true })
					syntax = "markdown"
				end
			end

			-- Last-resort fallback (shouldn't normally hit)
			if not lines then
				-- Build markdown lines manually (Noice's convert_input_to_markdown_lines
				-- override returns pre-styled text without raw fences).
				lines = { tostring(contents) }
				syntax = "markdown"
			end

			while #lines > 0 and lines[1] == "" do table.remove(lines, 1) end
			while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
			if #lines == 0 then
				vim.notify("No hover information available", vim.log.levels.INFO)
				return
			end

			local float_bufnr, float_winid = vim.lsp.util.open_floating_preview(lines, syntax, {
				border = "rounded",
				max_width = 100,
				max_height = 30,
				focus_id = "smart_hover",
				wrap = true,
			})

			if float_bufnr and vim.api.nvim_buf_is_valid(float_bufnr) then
				-- Disable render-markdown.nvim on this popup. It runs on markdown buffers
				-- and was the path through which the broken predicate kept re-triggering.
				vim.b[float_bufnr].render_markdown_enabled = false
				pcall(function() require("render-markdown").buf_disable(float_bufnr) end)

				-- IMPORTANT: open_floating_preview() only runs its full markdown stylization
				-- pipeline (filetype, conceallevel, treesitter.start) when do_stylize is true,
				-- which requires both `syntax == 'markdown'` AND `vim.g.syntax_on ~= nil`.
				-- Modern treesitter-only configs don't run `:syntax on`, so vim.g.syntax_on
				-- is nil, do_stylize is false, and the popup ends up with just
				-- `vim.bo.syntax = 'markdown'` set — not filetype. Without filetype, the
				-- ftplugin doesn't run, conceal isn't enabled, and ```typescript fences
				-- stay visible.
				-- See: $VIMRUNTIME/lua/vim/lsp/util.lua, search for `do_stylize`.
				-- We replicate the stylization manually:
				if syntax == "markdown" then
					-- Set filetype (not just syntax) so the markdown ftplugin runs and
					-- treesitter properly hooks the buffer.
					vim.bo[float_bufnr].filetype = "markdown"
					if float_winid and vim.api.nvim_win_is_valid(float_winid) then
						-- conceallevel=2 hides text with `conceal ""` directive; the default
						-- markdown highlights.scm conceals fenced_code_block_delimiter +
						-- info_string, so ```typescript and closing ``` lines disappear.
						vim.wo[float_winid].conceallevel = 2
						-- Empty string = conceal even on the cursor line (matches what
						-- open_floating_preview's do_stylize branch sets).
						vim.wo[float_winid].concealcursor = ""
					end
				end

				-- Start a treesitter parser for the chosen syntax. For 'css'/'typescript'/
				-- etc. this is a single-language tree with no injections. For 'markdown' the
				-- patched set-lang-from-info-string! directive handles fenced injections.
				pcall(vim.treesitter.start, float_bufnr, syntax)

				-- For markdown popups: hide ```lang opening and ``` closing fence lines
				-- with extmark-based conceal. We do this manually rather than relying on
				-- the treesitter markdown highlights.scm `conceal_lines` directives,
				-- because those depend on a particular Nvim render path that
				-- open_floating_preview only takes when vim.g.syntax_on is set.
				-- conceal_lines extmark option is Nvim 0.11+ and hides the entire line
				-- when conceallevel >= 1.
				if syntax == "markdown" then
					local ns = vim.api.nvim_create_namespace("smart_hover_fence_conceal")
					vim.api.nvim_buf_clear_namespace(float_bufnr, ns, 0, -1)
					local buf_lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
					for i, line in ipairs(buf_lines) do
						if line:match("^%s*```") then
							pcall(vim.api.nvim_buf_set_extmark, float_bufnr, ns, i - 1, 0, {
								conceal_lines = "",
							})
						end
					end
				end
			end
		end)
	end
	_G.__smart_hover = smart_hover

		-- Setup ts-error-translator
		require('ts-error-translator').setup()
		
		-- Setup LSP performance optimizations, memory monitoring, and debugging
		require('util.lsp-performance').setup()
		require('util.memory-monitor').setup()
		require('util.lsp-debug').setup()

		-- LSP capabilities
		local capabilities = require('cmp_nvim_lsp').default_capabilities()

		-- Function to set up LSP keymaps (extracted so it can be reused)
		local function setup_lsp_keymaps(bufnr)
			local map = function(keys, func, desc)
				-- Force override any existing keymaps (like nvim-surround's gr)
				vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc, remap = false })
			end

			-- All your keybindings - using buffer-specific override
			-- gh uses smart_hover: aggregates all LSP responses, picks highest priority
			-- client with content, shows single "no info" message if none have content
			map("gh", _G.__smart_hover, "Preview Hover")
			map("gd", function()
				-- Optimized definition lookup with timeout
				require("telescope.builtin").lsp_definitions({
					timeout = 5000, -- 5 second timeout
				})
			end, "[G]oto [D]efinition")
			map("gr", function()
				-- Add timeout and performance optimizations for references in large projects
				require("telescope.builtin").lsp_references({
					timeout = 10000, -- 10 second timeout for monorepos
					include_declaration = false, -- Exclude declaration to speed up
				})
			end, "[G]oto [R]eferences")
			map("<leader>cd", vim.diagnostic.open_float, "[S]how [D]iagnostic")
			map("gI", function()
				require("telescope.builtin").lsp_implementations()
			end, "[G]oto [I]mplementation")
			map("<leader>D", function()
				require("telescope.builtin").lsp_type_definitions()
			end, "Type [D]efinition")
			map("<leader>ds", function()
				require("telescope.builtin").lsp_document_symbols()
			end, "[D]ocument [S]ymbols")
			map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
			map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
			map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
		end

		-- Full on_attach function with all keymaps
		local on_attach = function(client, bufnr)
			setup_lsp_keymaps(bufnr)

			-- Document highlighting (disabled for performance in large files)
			-- Uncomment if needed, but can cause slowdowns in monorepos
			-- if client.supports_method("textDocument/documentHighlight") then
			-- 	local highlight_augroup = vim.api.nvim_create_augroup("lsp_document_highlight_" .. bufnr, { clear = true })
			-- 	vim.api.nvim_create_autocmd({ "CursorHold" }, {
			-- 		group = highlight_augroup,
			-- 		buffer = bufnr,
			-- 		callback = function()
			-- 			-- Only highlight if not in a large file
			-- 			if vim.api.nvim_buf_line_count(bufnr) < 1000 then
			-- 				vim.lsp.buf.document_highlight()
			-- 			end
			-- 		end,
			-- 	})
			-- 	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
			-- 		group = highlight_augroup,
			-- 		buffer = bufnr,
			-- 		callback = vim.lsp.buf.clear_references,
			-- 	})
			-- end

			-- Disable LSP format on save when Conform is available
			-- This prevents conflicts and improves performance
			local has_conform = pcall(require, "conform")
			if not has_conform and client.supports_method("textDocument/formatting") then
				-- Only enable LSP formatting as fallback when Conform is not available
				vim.api.nvim_create_autocmd("BufWritePre", {
					buffer = bufnr,
					callback = function()
						if vim.bo.filetype == "bigfile" or vim.b.minianimate_disable then
							return
						end
						vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
					end
				})
			end
		end

		-- Setup Mason (for installation only)
		require("mason").setup({})

		-- Install servers manually through Mason registry
		local mason_registry = require("mason-registry")
		-- Optimized server list - keeping ESLint for JSDoc enforcement
		local servers = {
			"astro",
			"bashls",
			"clangd",
			"dockerls",
			"eslint", -- Keep for JSDoc rules and advanced TypeScript linting
			"glsl_analyzer",
			"gopls",
			"html",
			"jsonls",
			"lua_ls",
			-- "remark_ls", -- REMOVED: Causes exit code 1 errors, mdx_analyzer handles markdown
			"mdx_analyzer", -- Handles both MDX and markdown
			"tailwindcss",
			"taplo",
			"vtsls", -- TypeScript language features
		}

		-- Ensure servers are installed via Mason registry
		local mason_name_map = {
			lua_ls = "lua-language-server",
			-- remark_ls = "remark-language-server", -- REMOVED: causes errors
			mdx_analyzer = "mdx-analyzer",
		}
		for _, server in ipairs(servers) do
			local pkg_name = mason_name_map[server] or server
			local ok, pkg = pcall(mason_registry.get_package, pkg_name)
			if ok and not pkg:is_installed() then
				pkg:install()
			end
		end

		-- Direct LSP setup with loop
		local lspconfig = require("lspconfig")

		for _, server in ipairs(servers) do
			if server == "lua_ls" then
				-- Custom config for lua_ls
				lspconfig.lua_ls.setup({
					on_attach = on_attach,
					capabilities = capabilities,
					settings = {
						Lua = {
							runtime = { version = "LuaJIT" },
							diagnostics = { globals = { "vim" } },
							workspace = {
								library = vim.api.nvim_get_runtime_file("", true),
								checkThirdParty = false,
							},
							telemetry = { enable = false },
						},
					},
				})
			-- remark_ls removed - caused exit code 1 errors
			elseif server == "mdx_analyzer" then
				lspconfig.mdx_analyzer.setup({
					on_attach = on_attach,
					capabilities = capabilities,
					-- Only MDX files. Plain .md is handled by treesitter (no LSP needed).
					-- Attaching to "markdown" causes "Invalid glob: **/*.{mdx}" errors in Nvim 0.12.
					filetypes = { "mdx", "markdown.mdx" },
				})
			elseif server == "tailwindcss" then
				lspconfig.tailwindcss.setup({
					on_attach = on_attach,
					capabilities = capabilities,
					filetypes = {
						"aspnetcorerazor", "astro", "astro-markdown", "blade", "clojure", "django-html",
						"htmldjango", "edge", "eelixir", "elixir", "ejs", "erb", "eruby", "gohtml",
						"gohtmltmpl", "haml", "handlebars", "hbs", "html", "htmlangular", "html-eex",
						"heex", "jade", "leaf", "liquid", "mustache", "njk", "nunjucks", "php",
						"razor", "slim", "twig", "css", "less", "postcss", "sass", "scss", "stylus",
						"sugarss", "javascript", "javascriptreact", "reason", "rescript", "typescript",
						"typescriptreact", "vue", "svelte", "templ",
					},
					-- Support Tailwind v4 CSS-based config (no tailwind.config.js needed)
					-- For monorepos: add tailwind.css with "@import tailwindcss" at root
					root_dir = require("lspconfig.util").root_pattern(
						"tailwind.config.js",
						"tailwind.config.cjs",
						"tailwind.config.mjs",
						"tailwind.config.ts",
						"tailwind.css", -- Tailwind v4 monorepo entry point
						"postcss.config.js",
						"postcss.config.cjs",
						"postcss.config.mjs",
						"postcss.config.ts"
					),
					settings = {
						tailwindCSS = {
							experimental = {
								-- Enable class regex for cn, cva, clsx, cx, etc.
								classRegex = {
									{ "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
									{ "cx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
									{ "cn\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
									{ "clsx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
								},
							},
							classAttributes = { "class", "className", "class:list", "classList", "ngClass" },
							lint = {
								cssConflict = "warning",
								invalidApply = "error",
								invalidConfigPath = "error",
								invalidScreen = "error",
								invalidTailwindDirective = "error",
								invalidVariant = "error",
								recommendedVariantOrder = "warning",
							},
							validate = true,
						},
					},
				})
			elseif server == "eslint" then
				lspconfig.eslint.setup({
					on_attach = on_attach,
					capabilities = capabilities,
					filetypes = {
						"javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact",
						"typescript.tsx", "vue", "svelte", "astro", "htmlangular",
					},
					settings = {
						useFlatConfig = true, -- Enable ESLint 9+ flat config support
						format = false, -- Disable ESLint formatting - use oxfmt instead
						-- Keep auto-fix available but not automatic
						codeActionOnSave = {
							enable = false, -- Manual code actions only
						},
						-- Gentle performance optimizations
						workingDirectories = { mode = "auto" }, -- Smart project detection
						run = "onSave", -- Less CPU intensive than onType
					},
				})
			else
				-- Default config for all other servers
				lspconfig[server].setup({
					on_attach = on_attach,
					capabilities = capabilities,
				})
			end
		end

		-- Setup nvim-cmp
		local cmp = require("cmp")
		require("luasnip.loaders.from_vscode").lazy_load()

		cmp.setup.cmdline("/", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = { { name = "buffer" } },
		})

		cmp.setup.cmdline(":", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources(
				{ { name = "path" } },
				{ { name = "cmdline", option = { ignore_cmds = { "Man", "!" } } } }
			),
		})

		cmp.setup({
			snippet = {
				expand = function(args)
					require("luasnip").lsp_expand(args.body)
				end,
			},
			sources = {
				{ name = "nvim_lsp", keyword_length = 0 },
				{ name = "luasnip",  keyword_length = 2 },
				{ name = "buffer",   keyword_length = 3 },
				{ name = "path",     keyword_length = 3 },
			},
			formatting = {
				format = require("lspkind").cmp_format({
					before = require("tailwind-tools.cmp").lspkind_format,
				}),
			},
			mapping = cmp.mapping.preset.insert({
				["<Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_next_item()
					elseif require("luasnip").expand_or_jumpable() then
						require("luasnip").expand_or_jump()
					else
						fallback()
					end
				end, { "i", "s" }),
				["<S-Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_prev_item()
					elseif require("luasnip").jumpable(-1) then
						require("luasnip").jump(-1)
					else
						fallback()
					end
				end, { "i", "s" }),
				["<CR>"] = cmp.mapping.confirm({ select = false }),
				["<Esc>"] = cmp.mapping(function(fallback)
					cmp.mapping.abort()
					vim.cmd("stopinsert")
				end, { "i", "s" }),
			}),
		})

		-- Add LspAttach autocmd to ensure keymaps are always restored after LSP restart
		-- This is a safety net in case on_attach doesn't fire reliably during restart
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("lsp_keymaps_restore", { clear = true }),
			callback = function(args)
				local bufnr = args.buf
				-- Only set up keymaps if they don't already exist (avoid duplicates)
				local existing_maps = vim.api.nvim_buf_get_keymap(bufnr, "n")
				local has_leader_ca = false
				for _, map in ipairs(existing_maps) do
					if map.lhs == " ca" then
						has_leader_ca = true
						break
					end
				end

				-- If keymaps are missing, restore them
				if not has_leader_ca then
					setup_lsp_keymaps(bufnr)
				end
			end,
		})
	end,
}
