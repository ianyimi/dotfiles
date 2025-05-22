return {
	"VonHeikemen/lsp-zero.nvim",
	branch = "v2.x",
	dependencies = {
		-- LSP Support
		{ "neovim/nvim-lspconfig" }, -- Required
		{                          -- Optional
			"williamboman/mason.nvim",
			build = function()
				pcall(vim.cmd, "MasonUpdate")
			end,
		},
		{ "williamboman/mason-lspconfig.nvim" }, -- Optional
		{ "j-hui/fidget.nvim",                  opts = {} },

		-- Tailwind Tools
		{ "luckasRanarison/tailwind-tools.nvim" },
		{ "onsails/lspkind-nvim" },

		-- Autocompletion
		{ "hrsh7th/nvim-cmp" },   -- Required
		{ "hrsh7th/cmp-nvim-lsp" }, -- Required
		{ "L3MON4D3/LuaSnip" },   -- Required
		{ "rafamadriz/friendly-snippets" },
		{ "hrsh7th/cmp-buffer" },
		{ "hrsh7th/cmp-path" },
		{ "hrsh7th/cmp-cmdline" },
		{ "saadparwaiz1/cmp_luasnip" },
		{ 'dmmulroy/ts-error-translator.nvim' },
	},
	config = function()
		local lsp = require("lsp-zero")

		lsp.on_attach(function(client, bufnr)
			local map = function(keys, func, desc)
				vim.keymap.set("n", keys, func, { buffer = buffer, desc = "LSP: " .. desc })
			end

			-- Key mappings
			map("gh", vim.lsp.buf.hover, "Preview Hover")
			map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
			map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
			map("<leader>cd", vim.diagnostic.open_float, "[S]how [D]iagnostic")
			map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
			map("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")
			map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
			-- map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
			map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
			map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
			map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

			-- Highlight references
			if client.supports_method("textDocument/documentHighlight") then
				vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx)
					require("ts-error-translator").translate_diagnostics(err, result, ctx)
					vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
				end
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

			client.server_capabilities.documentFormattingProvider = true
			vim.api.nvim_create_autocmd("BufWritePre", {
				callback = function()
					-- Skip formatting for bigfiles
					if vim.bo.filetype == "bigfile" or vim.b.minianimate_disable then
						return
					end
					vim.lsp.buf.format()
				end
			})
		end)

		require("mason").setup({})
		require("mason-lspconfig").setup({
			ensure_installed = {
				"astro",
				"bashls",
				"clangd",
				"dockerls",
				"eslint",
				"gopls",
				"html",
				"jsonls",
				"lua_ls",
				"tailwindcss",
				"taplo",
				"vtsls",
			},
			handlers = {
				lsp.default_setup,
				lua_ls = function()
					local lua_opts = lsp.nvim_lua_ls()
					require("lspconfig").lua_ls.setup(lua_opts)
				end,
			},
		})

		local cmp_action = require("lsp-zero").cmp_action()
		local cmp = require("cmp")
		local cmp_select = { behavior = cmp.SelectBehavior.Select }

		require("luasnip.loaders.from_vscode").lazy_load()

		-- `/` cmdline setup.
		cmp.setup.cmdline("/", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = {
				{ name = "buffer" },
			},
		})

		-- `:` cmdline setup.
		cmp.setup.cmdline(":", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources({
				{ name = "path" },
			}, {
				{
					name = "cmdline",
					option = {
						ignore_cmds = { "Man", "!" },
					},
				},
			}),
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
