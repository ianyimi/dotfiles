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
		require("fidget").setup({})

		-- Setup ts-error-translator
		require('ts-error-translator').setup()

		-- LSP capabilities
		local capabilities = require('cmp_nvim_lsp').default_capabilities()

		-- Full on_attach function with all keymaps
		local on_attach = function(client, bufnr)
			local map = function(keys, func, desc)
				vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
			end

			-- All your keybindings - using buffer-specific override
			map("gh", vim.lsp.buf.hover, "Preview Hover")
			map("gd", function()
				require("telescope.builtin").lsp_definitions()
			end, "[G]oto [D]efinition")
			map("gr", function()
				require("telescope.builtin").lsp_references()
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

			-- Document highlighting
			if client.supports_method("textDocument/documentHighlight") then
				local highlight_augroup = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })
				vim.api.nvim_clear_autocmds({ group = highlight_augroup, buffer = bufnr })
				vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
					group = highlight_augroup,
					buffer = bufnr,
					callback = vim.lsp.buf.document_highlight,
				})
				vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
					group = highlight_augroup,
					buffer = bufnr,
					callback = vim.lsp.buf.clear_references,
				})
			end

			-- Format on save
			if client.supports_method("textDocument/formatting") then
				vim.api.nvim_create_autocmd("BufWritePre", {
					buffer = bufnr,
					callback = function()
						if vim.bo.filetype == "bigfile" or vim.b.minianimate_disable then
							return
						end
						vim.lsp.buf.format({ async = false })
					end
				})
			end
		end

		-- Setup Mason (for installation only)
		require("mason").setup({})

		-- Install servers manually through Mason registry
		local mason_registry = require("mason-registry")
		local servers = {
			"astro",
			"bashls",
			"clangd",
			"dockerls",
			"eslint",
			"glsl_analyzer",
			"gopls",
			"html",
			"jsonls",
			"lua_ls",
			"tailwindcss",
			"taplo",
			"vtsls",
		}

		-- Ensure servers are installed via Mason registry
		for _, server in ipairs(servers) do
			local ok, pkg = pcall(mason_registry.get_package, server)
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
	end,
}
