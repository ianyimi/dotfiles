--- Interactive-session performance probe.
---
--- Diagnoses stalls that only appear in a real UI session: redraw cost, picker
--- latency, deferred-callback pileups, subprocess churn and handle leaks. None
--- of that is observable from `nvim --headless`, which is why this exists as a
--- load-on-demand module rather than part of the config proper.
---
--- Usage:
---   :PerfStart                 begin recording (low overhead, safe to leave on)
---   :PerfMark oil-open         label the next thing you're about to do
---   <do the slow thing>
---   :PerfSnap                  snapshot session state (handles, clients, buffers)
---   :PerfReport                write aggregates
---   :PerfStop
---   :PerfLog                   open the log
---
--- How attribution works: a libuv timer ticks every `tick_ms`. Because timer
--- callbacks can only run when the event loop is free, a late tick *is* a
--- main-loop stall, and the lateness is its duration. In parallel a `debug`
--- count-hook samples the Lua stack into a ring buffer. When a stall is seen we
--- dump the samples whose timestamps fall inside it, which names the Lua code
--- responsible. A stall with *no* Lua samples is itself a finding: the time went
--- into C -- redraw, the treesitter parser, regex syntax, or a blocking wait.
---@class util.perf_probe
local M = {}

local uv = vim.uv or vim.loop

-- LuaJIT (which Nvim embeds) has neither table.pack nor table.unpack; `unpack`
-- is a global. Wrappers here must forward an unknown number of return values,
-- including nils, so varargs are packed with an explicit count.
local unpack_ = table.unpack or unpack

---@return table
local function pack(...)
	return { n = select("#", ...), ... }
end

local LOG = vim.fn.stdpath("cache") .. "/perf-probe.log"

local cfg = {
	tick_ms = 20,
	-- Report a stall when a tick arrives this many ms later than scheduled.
	stall_ms = 80,
	-- VM instructions between stack samples. Lower = better attribution, more
	-- overhead. 20k is roughly a few hundred samples/sec of busy Lua.
	sample_every = 20000,
	-- Stack depth captured per sample.
	depth = 6,
	-- Ring capacity for samples.
	ring = 16384,
	-- Interval for automatic snapshot/leak/attribution capture, so a profile
	-- needs no commands beyond :PerfStart and :PerfStop. The deltas between
	-- consecutive captures are what expose leaks and gradual degradation.
	auto_ms = 30000,
}

local state = {
	running = false,
	timer = nil,
	last_tick = 0,
	mark = "startup",
	mark_at = 0,
	started_at = 0,
	stalls = {},
	-- Flat ring: src[i], line[i], time[i]. Avoids per-sample table allocation.
	s_src = {},
	s_line = {},
	s_time = {},
	s_n = 0,
	-- label -> { n, total_ms, max_ms }
	spans = {},
	-- event -> count
	events = {},
	-- Attribution tables: creation site -> { n, ms, max }. These answer "who",
	-- which plain span timing cannot.
	sched = {},
	defer = {},
	parse = {},
	decor = {},
	-- caller -> {n,ms,max} for blocking plenary Job:sync
	jobsync = {},
	-- path -> {n,ms,max} for per-file open latency
	opens = {},
	-- path -> {n,ms,max} for Telescope select -> ready-for-input
	selects = {},
	select_pending = nil,
	-- mark -> { spans = {label -> {n,total,max}}, stalls = n }. Lets two
	-- conditions ("spec in split" vs not) be compared numerically instead of
	-- being averaged together in the global table.
	marks = {},
	auto_timer = nil,
	orig_schedule = nil,
	wrapped = {},
}

-- ---------------------------------------------------------------- log plumbing

local function log(line)
	local f = io.open(LOG, "a")
	if not f then
		return
	end
	f:write(line, "\n")
	f:close()
end

local function logf(fmt, ...)
	log(string.format(fmt, ...))
end

local function ms(hr)
	return hr / 1e6
end

--- Compact "who called me" signature: the first frames outside this module.
--- Defined early because the wrappers below all attribute by creation site.
---@param skip integer
---@return string
local function origin(skip)
	local frames = {}
	for lvl = skip, skip + 8 do
		local info = debug.getinfo(lvl, "Sl")
		if not info then
			break
		end
		local src = info.short_src or "?"
		if not src:find("perf%-probe") and src ~= "[C]" then
			frames[#frames + 1] = src .. ":" .. tostring(info.currentline)
			if #frames >= 3 then
				break
			end
		end
	end
	return #frames > 0 and table.concat(frames, " <- ") or "?"
end

--- Accumulate count + duration into one of the attribution tables.
---@param tbl table<string, {n: integer, ms: number, max: number}>
---@param key string
---@param dur_ms number
local function bump(tbl, key, dur_ms)
	local e = tbl[key]
	if not e then
		e = { n = 0, ms = 0, max = 0 }
		tbl[key] = e
	end
	e.n = e.n + 1
	e.ms = e.ms + dur_ms
	if dur_ms > e.max then
		e.max = dur_ms
	end
end

--- Write one attribution table, hottest first.
---@param title string
---@param tbl table
---@param limit? integer
local function dump_attribution(title, tbl, limit)
	local keys = vim.tbl_keys(tbl)
	if #keys == 0 then
		return
	end
	table.sort(keys, function(a, b)
		return tbl[a].n > tbl[b].n
	end)
	logf("  -- %s --", title)
	for i = 1, math.min(#keys, limit or 14) do
		local e = tbl[keys[i]]
		logf("  %7d x  %8.1f ms tot %7.1f max  %s", e.n, e.ms, e.max, keys[i])
	end
end

--- Record a completed span under `label`, globally and under the current mark.
---@param label string
---@param dur_ms number
local function add_span(label, dur_ms)
	local s = state.spans[label]
	if not s then
		s = { n = 0, total = 0, max = 0 }
		state.spans[label] = s
	end
	s.n = s.n + 1
	s.total = s.total + dur_ms
	if dur_ms > s.max then
		s.max = dur_ms
	end

	-- Same span, bucketed under the active mark. A global average hides the very
	-- thing we are chasing: the same action costing more under one layout than
	-- another. Comparing marks is how a gradient becomes a number.
	local m = state.marks[state.mark]
	if not m then
		m = { spans = {}, stalls = 0 }
		state.marks[state.mark] = m
	end
	local b = m.spans[label]
	if not b then
		b = { n = 0, total = 0, max = 0 }
		m.spans[label] = b
	end
	b.n = b.n + 1
	b.total = b.total + dur_ms
	if dur_ms > b.max then
		b.max = dur_ms
	end
	-- Anything this slow is worth seeing inline, not just in aggregate.
	if dur_ms >= cfg.stall_ms then
		logf("  [slow] %-46s %8.1f ms   (mark=%s)", label, dur_ms, state.mark)
	end
end

M.add_span = add_span

-- --------------------------------------------------------------- stack sampler

--- Count-hook body. MUST stay allocation-light and MUST NOT touch the Nvim API:
--- it runs at arbitrary points inside other people's Lua, including fast
--- contexts.
local function on_count_hook()
	local n = state.s_n
	local t = uv.hrtime()
	local cap = cfg.ring
	for lvl = 2, cfg.depth do
		local info = debug.getinfo(lvl, "Sl")
		if not info then
			break
		end
		n = n + 1
		local i = (n - 1) % cap + 1
		state.s_src[i] = info.short_src
		state.s_line[i] = info.currentline
		state.s_time[i] = t
	end
	state.s_n = n
end

--- Samples whose timestamp lands in [from, to], aggregated by src:line.
---@param from integer hrtime
---@param to integer hrtime
---@return string[]
local function samples_between(from, to)
	local counts, order = {}, {}
	local cap = cfg.ring
	local total = math.min(state.s_n, cap)
	for k = 1, total do
		local i = (state.s_n - k) % cap + 1
		local t = state.s_time[i]
		if t and t >= from and t <= to then
			local key = tostring(state.s_src[i]) .. ":" .. tostring(state.s_line[i])
			if not counts[key] then
				counts[key] = 0
				order[#order + 1] = key
			end
			counts[key] = counts[key] + 1
		end
	end
	table.sort(order, function(a, b)
		return counts[a] > counts[b]
	end)
	local out = {}
	for k = 1, math.min(#order, 12) do
		out[k] = string.format("      %5dx %s", counts[order[k]], order[k])
	end
	return out
end

-- --------------------------------------------------------------- stall detector

-- Ring of recently-fired autocmd events. A stall's breadcrumbs say which event
-- Nvim was servicing, which is the attribution the sampler cannot always give:
-- LuaJIT does not run debug count-hooks inside compiled traces, so hot numeric
-- loops are invisible to it. Events are cheap and always observable.
local BC = 64
local bc_event, bc_buf, bc_time, bc_n = {}, {}, {}, 0

---@param event string
---@param buf integer
local function breadcrumb(event, buf)
	bc_n = bc_n + 1
	local i = (bc_n - 1) % BC + 1
	bc_event[i], bc_buf[i], bc_time[i] = event, buf, uv.hrtime()
end

--- Events fired within [from,to], oldest first.
---@param from integer hrtime
---@param to integer hrtime
---@return string[]
local function breadcrumbs_between(from, to)
	local out = {}
	local total = math.min(bc_n, BC)
	for k = total, 1, -1 do
		local i = (bc_n - k) % BC + 1
		local t = bc_time[i]
		if t and t >= from and t <= to then
			out[#out + 1] = string.format("%s(b%s)", bc_event[i], tostring(bc_buf[i]))
		end
	end
	return out
end

--- Formats one stall. Runs on the main loop (scheduled out of the fast timer
--- callback), so the Nvim API is available here.
---@param late_ms number
---@param from integer hrtime
---@param to integer hrtime
local function report_stall(late_ms, from, to)
	local buf = vim.api.nvim_get_current_buf()
	local ok_name, name = pcall(vim.api.nvim_buf_get_name, buf)
	logf(
		"\n[STALL] %7.1f ms  mark=%-18s ft=%-12s buf=%d wins=%d bufs=%d  %s",
		late_ms,
		state.mark,
		vim.bo[buf].filetype ~= "" and vim.bo[buf].filetype or "-",
		buf,
		#vim.api.nvim_tabpage_list_wins(0),
		#vim.api.nvim_list_bufs(),
		ok_name and vim.fn.fnamemodify(name, ":~:.") or "?"
	)
	local lines = samples_between(from, to)
	if #lines == 0 then
		log("      (no Lua samples -> time spent in C: redraw, treesitter, syntax, or a blocking wait)")
	else
		for _, l in ipairs(lines) do
			log(l)
		end
	end
	local bcs = breadcrumbs_between(from, to)
	if #bcs > 0 then
		logf("      events in window: %s", table.concat(bcs, " -> "))
	end
end

-- ------------------------------------------------------------------- wrapping

--- Replace `tbl[key]` with a timed version. Idempotent per (tbl,key).
---@param tbl table
---@param key string
---@param label string
function M.wrap(tbl, key, label)
	if type(tbl) ~= "table" then
		return false
	end
	local fn = tbl[key]
	if type(fn) ~= "function" then
		return false
	end
	local token = label
	if state.wrapped[token] then
		return true
	end
	state.wrapped[token] = true
	tbl[key] = function(...)
		local t0 = uv.hrtime()
		local r1, r2, r3, r4 = fn(...)
		add_span(label, ms(uv.hrtime() - t0))
		return r1, r2, r3, r4
	end
	return true
end

--- Wrap the things that historically hide latency in this config.
local function install_wrappers()
	-- Subprocess spawns. Sync forms block the loop outright.
	local orig_system = vim.system
	if not state.wrapped["vim.system"] then
		state.wrapped["vim.system"] = true
		vim.system = function(cmd, opts, on_exit)
			local label = "spawn: " .. (type(cmd) == "table" and (cmd[1] or "?") or tostring(cmd))
			local t0 = uv.hrtime()
			if on_exit then
				return orig_system(cmd, opts, function(res)
					add_span(label, ms(uv.hrtime() - t0))
					return on_exit(res)
				end)
			end
			local h = orig_system(cmd, opts)
			add_span(label .. " [SYNC]", ms(uv.hrtime() - t0))
			return h
		end
	end

	if not state.wrapped["io.popen"] then
		state.wrapped["io.popen"] = true
		local orig_popen = io.popen
		io.popen = function(c, m)
			local t0 = uv.hrtime()
			local h = orig_popen(c, m)
			add_span("io.popen [SYNC]: " .. tostring(c):sub(1, 40), ms(uv.hrtime() - t0))
			return h
		end
	end

	M.wrap(vim.fn, "system", "vim.fn.system [SYNC]")

	-- Deferred work: these callbacks execute on the main loop, so a slow one is
	-- indistinguishable from a slow keystroke. Attribution is by *creation* site
	-- rather than execution site: the stack at run time is just the scheduler, so
	-- only the caller identifies who is generating the traffic. This is what
	-- turns "736 callbacks/sec" into a name.
	if not state.wrapped["vim.schedule"] then
		state.wrapped["vim.schedule"] = true
		local orig_schedule = vim.schedule
		state.orig_schedule = orig_schedule
		vim.schedule = function(fn)
			if type(fn) ~= "function" then
				return orig_schedule(fn)
			end
			local site = origin(3)
			return orig_schedule(function()
				local t0 = uv.hrtime()
				fn()
				local d = ms(uv.hrtime() - t0)
				add_span("vim.schedule cb", d)
				bump(state.sched, site, d)
			end)
		end
	end

	if not state.wrapped["vim.defer_fn"] then
		state.wrapped["vim.defer_fn"] = true
		local orig_defer = vim.defer_fn
		vim.defer_fn = function(fn, timeout)
			if type(fn) ~= "function" then
				return orig_defer(fn, timeout)
			end
			local site = origin(3)
			return orig_defer(function()
				local t0 = uv.hrtime()
				fn()
				local d = ms(uv.hrtime() - t0)
				add_span("vim.defer_fn cb", d)
				bump(state.defer, site, d)
			end, timeout)
		end
	end

	-- plenary Job:sync blocks the loop for up to its (5000ms default) timeout.
	-- Attributed by caller: this has surfaced in every profile since the start of
	-- the investigation and a bare span label never identified who runs it.
	local ok_job, Job = pcall(require, "plenary.job")
	if ok_job and type(Job) == "table" and type(Job.sync) == "function" and not state.wrapped["Job.sync"] then
		state.wrapped["Job.sync"] = true
		local orig_sync = Job.sync
		Job.sync = function(self, ...)
			local site = origin(3)
			local cmd = tostring(self and self.command or "?")
			local t0 = uv.hrtime()
			local r = pack(orig_sync(self, ...))
			local d = ms(uv.hrtime() - t0)
			add_span("plenary Job:sync [SYNC]", d)
			bump(state.jobsync, cmd .. "  <- " .. site, d)
			return unpack_(r, 1, r.n)
		end
	end

	-- The real cost of `gd`/`gr` is the picker, not the LSP request.
	local ok_tb, builtin = pcall(require, "telescope.builtin")
	if ok_tb then
		for _, k in ipairs({
			"lsp_definitions",
			"lsp_references",
			"lsp_implementations",
			"lsp_type_definitions",
			"lsp_document_symbols",
			"find_files",
			"live_grep",
			"buffers",
			"oldfiles",
		}) do
			M.wrap(builtin, k, "telescope." .. k)
		end
	end

	local ok_oil, oil = pcall(require, "oil")
	if ok_oil then
		M.wrap(oil, "toggle_float", "oil.toggle_float")
		M.wrap(oil, "open_float", "oil.open_float")
		M.wrap(oil, "open", "oil.open")
	end

	-- Tabline/statusline redraws are O(buffers) and grow over a session.
	local ok_render, render = pcall(require, "barbar.ui.render")
	if ok_render then
		M.wrap(render, "update", "barbar render.update")
	end

	local ok_ll, lualine = pcall(require, "lualine")
	if ok_ll then
		M.wrap(lualine, "statusline", "lualine.statusline")
	end

	local ok_root = pcall(require, "util.root")
	if ok_root then
		M.wrap(require("util.root"), "get", "util.root.get")
	end

	M.wrap(vim.treesitter, "start", "treesitter.start")

	-- LSP request latency, measured request->response rather than round-trip
	-- of a synthetic request_sync.
	if not state.wrapped["lsp.request"] then
		state.wrapped["lsp.request"] = true
		local ok_c, Client = pcall(function()
			return vim.lsp.client
		end)
		if ok_c and type(Client) == "table" and type(Client.request) == "function" then
			local orig = Client.request
			Client.request = function(self, method, params, handler, bufnr)
				local t0 = uv.hrtime()
				local wrapped_handler = handler
					and function(...)
						add_span("lsp " .. tostring(method), ms(uv.hrtime() - t0))
						return handler(...)
					end
				return orig(self, method, params, wrapped_handler or handler, bufnr)
			end
		end
	end
end

-- --------------------------------------------------------------- event counting

local HOT_EVENTS = {
	"BufEnter",
	"BufWinEnter",
	"BufReadPost",
	"CursorHold",
	"CursorHoldI",
	"CursorMoved",
	"CursorMovedI",
	"TextChanged",
	"TextChangedI",
	"WinScrolled",
	"WinEnter",
	"FileType",
	"BufWritePre",
	"BufWritePost",
	"DiagnosticChanged",
	"LspAttach",
	"ColorScheme",
}

--- Per-file open latency, keyed by path.
---
--- Nothing else here measures "opening THIS file took 1.2s". Spans cover named
--- functions and stalls cover main-loop blocking, but a slow open can be a chain
--- of individually-acceptable steps across BufReadPre -> BufWinEnter. Timing that
--- window per buffer and reporting the worst offenders with their paths turns a
--- vague "files in .agent are slow" into a ranked list.
local function install_open_timing()
	if state.wrapped["open_timing"] then
		return
	end
	state.wrapped["open_timing"] = true
	local grp = vim.api.nvim_create_augroup("perf_probe_open", { clear = true })
	local started = {}

	vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
		group = grp,
		callback = function(a)
			started[a.buf] = uv.hrtime()
		end,
	})

	-- BufWinEnter is the first point at which the buffer is actually displayed,
	-- which is what the developer perceives as "opened".
	vim.api.nvim_create_autocmd({ "BufWinEnter", "BufReadPost" }, {
		group = grp,
		callback = function(a)
			local t0 = started[a.buf]
			if not t0 then
				return
			end
			started[a.buf] = nil
			local d = ms(uv.hrtime() - t0)
			local name = vim.api.nvim_buf_get_name(a.buf)
			local key = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or ("buf" .. a.buf)
			bump(state.opens, key, d)
			if d >= cfg.stall_ms then
				logf("  [slow open] %8.1f ms  %s  (mark=%s)", d, key, state.mark)
			end
		end,
	})
end

--- Time from a Telescope selection to Nvim being ready for input.
---
--- This is the window the developer actually perceives: "I hit enter on the
--- preview and waited before I could type." `BufReadPre -> BufWinEnter` cannot
--- measure it, because the previewer has already read the file, so BufReadPre may
--- never fire on select. It is also not necessarily one main-loop stall -- it can
--- be several small steps across separate loop turns, which is why a profile can
--- show zero stalls while an action still feels slow.
---
--- `SafeState` fires when Nvim is about to block for a character, so it is the
--- honest end marker for "ready to edit".
--- Shared finaliser for a pending select measurement. Runs on the main loop.
---@param now integer hrtime at which the editor became ready
local function finalize_select(now)
	local pend = state.select_pending
	if not pend then
		return
	end
	state.select_pending = nil
	local d = ms(now - pend.t0)
	local label = pend.label
	if not label or label == "" then
		local name = vim.api.nvim_buf_get_name(0)
		label = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or ("ft=" .. vim.bo.filetype)
	end
	bump(state.selects, label, d)
	if d >= cfg.stall_ms then
		logf("  [slow ready] %8.1f ms  %s  (mark=%s)", d, label, state.mark)
	end
end

local function install_select_timing()
	if state.wrapped["select_timing"] then
		return
	end
	state.wrapped["select_timing"] = true

	local grp = vim.api.nvim_create_augroup("perf_probe_select", { clear = true })

	-- Start the clock on entering a real file buffer.
	--
	-- This measures "I landed in this file, how long until I could type" -- the
	-- settle cost after the buffer appears: LSP attach, treesitter start,
	-- render-markdown, decoration providers, statusline/tabline rebuild. Paired with
	-- the BufReadPre -> BufWinEnter table it brackets a perceived open delay.
	--
	-- Keyed on BufEnter rather than on leaving a TelescopePrompt: `edit` on an
	-- existing buffer fires NO BufLeave (verified), and BufEnter clears 'filetype'
	-- before handlers run, so prompt-based triggers are unreliable. BufEnter always
	-- fires and needs nothing from telescope.
	vim.api.nvim_create_autocmd("BufEnter", {
		group = grp,
		callback = function(a)
			if state.select_pending then
				return
			end
			local ok, bt = pcall(function()
				return vim.bo[a.buf].buftype
			end)
			if not ok or bt ~= "" then
				return
			end
			local name = vim.api.nvim_buf_get_name(a.buf)
			if name == "" then
				return
			end
			state.select_pending = { t0 = uv.hrtime(), label = vim.fn.fnamemodify(name, ":~:.") }
		end,
	})

	-- Two end markers, first to fire wins.
	--
	-- `SafeState` is the accurate one: it fires when Nvim is about to block for a
	-- character, i.e. the instant you can type. It never fires in a headless session
	-- (verified: 0 fires), so it cannot be tested without a UI.
	--
	-- The fallback lives in the stall timer: while the loop is busy ticks arrive
	-- late, so the first on-time tick means the loop is free. Granularity is one
	-- tick (20ms) -- ample for diagnosing a 1s delay -- and it works everywhere.
	vim.api.nvim_create_autocmd("SafeState", {
		group = grp,
		callback = function()
			if state.select_pending then
				finalize_select(uv.hrtime())
			end
		end,
	})
end

local function install_counters()
	local grp = vim.api.nvim_create_augroup("perf_probe_counters", { clear = true })
	for _, e in ipairs(HOT_EVENTS) do
		vim.api.nvim_create_autocmd(e, {
			group = grp,
			callback = function(a)
				state.events[e] = (state.events[e] or 0) + 1
				breadcrumb(e, a.buf)
			end,
		})
	end
end

-- ------------------------------------------------------------------- snapshot

--- Counts live libuv handles by type. A session that gets slower over hours
--- should show these climbing; a flat count falsifies the leak theory.
---@return table<string, integer>
local function handle_census()
	local by_type = {}
	uv.walk(function(h)
		local ok, t = pcall(function()
			return h:get_type()
		end)
		local key = (ok and t) or "unknown"
		local active = false
		local ok_a, a = pcall(function()
			return h:is_active()
		end)
		if ok_a then
			active = a
		end
		local k = key .. (active and " (active)" or " (idle)")
		by_type[k] = (by_type[k] or 0) + 1
	end)
	return by_type
end

-- Handle-leak attribution. `handle_census` proves handles are accumulating but
-- not who made them, so the libuv constructors are wrapped to record a creation
-- site per handle.
--
-- Liveness is resolved via `uv.walk` and NEVER by calling a method on a stored
-- handle. Once luv has closed a handle and its userdata has been collected,
-- `h:is_closing()` dereferences freed memory and aborts the process -- a native
-- crash that `pcall` cannot catch (it exited Nvim mid-census when this module
-- iterated its own table). `uv.walk` only yields handles the loop still owns,
-- so anything it hands back is safe to inspect.
--
-- Weak keys let a collected handle drop out on its own; entries are only ever
-- read for handles that walk has just proven alive.
local handle_origin = setmetatable({}, { __mode = "k" })

-- `origin` is defined near the top of this file, above the wrappers that use it.

local function install_handle_tracking()
	for name, kind in pairs({ new_timer = "timer", new_fs_event = "fs_event", new_fs_poll = "fs_poll" }) do
		local token = "uv." .. name
		if not state.wrapped[token] and type(uv[name]) == "function" then
			state.wrapped[token] = true
			local ctor = uv[name]
			uv[name] = function(...)
				local h = ctor(...)
				if h then
					handle_origin[h] = { kind = kind, at = origin(3), t = uv.hrtime() }
				end
				return h
			end
		end
	end
end

--- Attribute `LanguageTree:parse` by caller.
---
--- This is the instrument for the injection-resolution question. Stack sampling
--- told us the highlighter spends its time in languagetree, but not how many
--- times it is entered per redraw. Counting calls and callers turns "roughly
--- once per visible line" from inference into a measurement.
---
--- Caveat: parse recurses into child trees, so nested calls are counted too.
--- Read the counts as "parse entries", not distinct top-level parses.
local function install_parse_attribution()
	if state.wrapped["LanguageTree.parse"] then
		return
	end
	local ok, LT = pcall(require, "vim.treesitter.languagetree")
	if not ok or type(LT) ~= "table" or type(LT.parse) ~= "function" then
		return
	end
	state.wrapped["LanguageTree.parse"] = true
	local orig = LT.parse
	LT.parse = function(self, ...)
		local t0 = uv.hrtime()
		local r = pack(orig(self, ...))
		local lang = "?"
		local ok_lang, l = pcall(function()
			return self:lang()
		end)
		if ok_lang and l then
			lang = l
		end
		bump(state.parse, lang .. "  <- " .. origin(3), ms(uv.hrtime() - t0))
		return unpack_(r, 1, r.n)
	end
end

--- Time every decoration provider callback, attributed to its registrar.
---
--- Decoration providers are the redraw path: `on_win` fires per window per
--- redraw and `on_line` per visible line. That is exactly where the 1129ms went,
--- and it is invisible to headless runs because nothing redraws.
---
--- Catches every provider registered while the probe runs -- which includes
--- core's, because treesitter and the LSP modules re-register theirs (observed
--- namespaces: nvim.treesitter.highlighter, nvim.lsp.semantic_tokens,
--- nvim.lsp.document_color, gitsigns).
---
--- The inner call is wrapped in pcall for a hard reason: Nvim *disables* a
--- decoration provider that throws. An earlier version of this used table.pack,
--- which does not exist in LuaJIT, and killed treesitter highlighting outright.
--- Instrumentation must never be able to break rendering, so failures are
--- swallowed and counted instead of propagated.
local function install_decor_attribution()
	if state.wrapped["set_decoration_provider"] then
		return
	end
	state.wrapped["set_decoration_provider"] = true
	local orig = vim.api.nvim_set_decoration_provider
	vim.api.nvim_set_decoration_provider = function(ns, opts)
		local site = origin(3)
		local wrapped = {}
		for k, v in pairs(opts or {}) do
			if type(v) == "function" then
				wrapped[k] = function(...)
					local t0 = uv.hrtime()
					local r = pack(pcall(v, ...))
					local d = ms(uv.hrtime() - t0)
					local okc = r[1]
					bump(state.decor, k .. "  " .. site, d)
					if not okc then
						bump(state.decor, "ERROR in " .. k .. "  " .. site, d)
						return
					end
					return unpack_(r, 2, r.n)
				end
			else
				wrapped[k] = v
			end
		end
		return orig(ns, wrapped)
	end
end

--- Periodic auto-capture. The whole point is that a profile needs no commands
--- beyond :PerfStart and :PerfStop -- everything a later reader might want is
--- already in the log, including deltas over time, which is what exposes leaks
--- and gradual degradation.
---@param label string
function M.tick(label)
	logf("\n===== AUTO CAPTURE %s (probe age %.0fs) =====",
		label or "", state.started_at > 0 and ms(uv.hrtime() - state.started_at) / 1000 or 0)
	for _, section in ipairs({
		{ "snapshot", function()
			M.snapshot(label or "auto")
		end },
		{ "leaks", M.leaks },
		{ "attribution", function()
			dump_attribution("vim.schedule by creation site", state.sched)
			dump_attribution("vim.defer_fn by creation site", state.defer)
			dump_attribution("LanguageTree:parse by caller", state.parse)
			dump_attribution("decoration providers", state.decor)
			dump_attribution("plenary Job:sync by caller [BLOCKING]", state.jobsync)
			dump_attribution("slowest file opens (BufReadPre -> BufWinEnter)", state.opens, 20)
			dump_attribution("buffer ready (BufEnter -> ready for input)", state.selects, 20)
		end },
	}) do
		local ok, err = pcall(section[2])
		if not ok then
			logf("  [%s section failed] %s", section[1], tostring(err))
		end
	end
end

--- Report open handles grouped by creation site. A site whose count climbs
--- between two calls is the leak.
function M.leaks()
	logf("\n===== HANDLE LEAK CENSUS =====")
	local groups, order = {}, {}
	local tracked, untracked = 0, 0
	local ok_walk, err = pcall(uv.walk, function(h)
		-- `h` is live by construction here, so these calls are safe.
		local closing = false
		local ok_c, c = pcall(function()
			return h:is_closing()
		end)
		if ok_c then
			closing = c
		end
		if closing then
			return
		end
		local meta = handle_origin[h]
		if not meta then
			untracked = untracked + 1
			return
		end
		tracked = tracked + 1
		local key = meta.kind .. "  " .. meta.at
		if not groups[key] then
			groups[key] = 0
			order[#order + 1] = key
		end
		groups[key] = groups[key] + 1
	end)
	if not ok_walk then
		logf("  census aborted: %s", tostring(err))
		return
	end
	table.sort(order, function(a, b)
		return groups[a] > groups[b]
	end)
	logf("  open handles: %d attributed, %d created before :PerfStart", tracked, untracked)
	for _, k in ipairs(order) do
		logf("  %5d  %s", groups[k], k)
	end
	if tracked == 0 then
		log("  (nothing attributed -- :PerfStart must run before the work you want blamed)")
	end
end

--- Duplicate-handler census. Tests the "handlers stack instead of being
--- replaced" theory directly: an autocmd created without a `group` inside
--- another callback (e.g. LSP `on_attach`) is *added* every time that callback
--- runs, so the same buffer accrues N copies across server restarts. A healthy
--- config shows 1 per (event,buffer); growth over a session is the bug.
---@return nil
function M.duplicates()
	logf("\n===== DUPLICATE AUTOCMD CENSUS =====")
	local interesting = { "BufWritePre", "BufWritePost", "BufEnter", "CursorHold", "CursorMoved", "TextChanged" }
	for _, e in ipairs(interesting) do
		local per_buf, ungrouped = {}, 0
		for _, a in ipairs(vim.api.nvim_get_autocmds({ event = e })) do
			if a.buflocal and a.buffer then
				per_buf[a.buffer] = (per_buf[a.buffer] or 0) + 1
			end
			if not a.group then
				ungrouped = ungrouped + 1
			end
		end
		local dupes = {}
		for b, n in pairs(per_buf) do
			if n > 1 then
				dupes[#dupes + 1] = string.format("buf%d x%d", b, n)
			end
		end
		logf("  %-14s total=%-4d ungrouped=%-4d buflocal_dupes=[%s]",
			e, #vim.api.nvim_get_autocmds({ event = e }), ungrouped, table.concat(dupes, " "))
	end

	-- Wrapper-stacking check: how many layers deep is vim.notify?
	local depth, seen = 0, {}
	local fn = vim.notify
	while type(fn) == "function" and depth < 40 do
		local info = debug.getinfo(fn, "S")
		local key = (info.short_src or "?") .. ":" .. tostring(info.linedefined)
		if seen[key] then
			break
		end
		seen[key] = true
		depth = depth + 1
		local up, nxt = 1, nil
		while true do
			local n, v = debug.getupvalue(fn, up)
			if not n then
				break
			end
			if type(v) == "function" and (n:find("orig") or n:find("notify")) then
				nxt = v
				break
			end
			up = up + 1
		end
		fn = nxt
	end
	logf("  vim.notify wrapper depth: %d  (1 = unwrapped; >2 means layers stacked)", depth)

	-- Extmark growth: a namespace that never clears makes every redraw of the
	-- visible range O(marks).
	local buf = vim.api.nvim_get_current_buf()
	logf("  extmarks in current buffer (buf=%d):", buf)
	local names = vim.api.nvim_get_namespaces()
	local rows = {}
	for name, ns in pairs(names) do
		local ok, marks = pcall(vim.api.nvim_buf_get_extmarks, buf, ns, 0, -1, {})
		if ok and #marks > 0 then
			rows[#rows + 1] = { name = name, n = #marks }
		end
	end
	table.sort(rows, function(a, b)
		return a.n > b.n
	end)
	for i = 1, math.min(#rows, 15) do
		logf("    %-46s %d", rows[i].name, rows[i].n)
	end
	if #rows == 0 then
		log("    (none)")
	end
end


function M.snapshot(label)
	local age = state.started_at > 0 and ms(uv.hrtime() - state.started_at) / 1000 or 0
	logf("\n===== SNAPSHOT %s  (probe age %.0fs) =====", label or "", age)
	logf("  buffers=%d  loaded=%d  windows=%d  tabs=%d",
		#vim.api.nvim_list_bufs(),
		#vim.tbl_filter(function(b)
			return vim.api.nvim_buf_is_loaded(b)
		end, vim.api.nvim_list_bufs()),
		#vim.api.nvim_tabpage_list_wins(0),
		#vim.api.nvim_list_tabpages())
	logf("  nvim RSS=%.1f MB", (uv.resident_set_memory() or 0) / 1024 / 1024)
	logf("  lua heap=%.1f MB", collectgarbage("count") / 1024)

	local clients = {}
	for _, c in ipairs(vim.lsp.get_clients()) do
		local pending = 0
		for _ in pairs(c.requests or {}) do
			pending = pending + 1
		end
		clients[#clients + 1] = string.format("%s(buf=%d,pending=%d)", c.name, vim.tbl_count(c.attached_buffers or {}), pending)
	end
	logf("  lsp clients: %s", #clients > 0 and table.concat(clients, " ") or "none")

	local census = handle_census()
	local keys = vim.tbl_keys(census)
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		parts[#parts + 1] = string.format("%s=%d", k, census[k])
	end
	logf("  uv handles: %s", table.concat(parts, " "))

	local acs = {}
	for _, e in ipairs(HOT_EVENTS) do
		local n = #vim.api.nvim_get_autocmds({ event = e })
		if n > 0 then
			acs[#acs + 1] = string.format("%s=%d", e, n)
		end
	end
	logf("  autocmds: %s", table.concat(acs, " "))
	logf("  mru entries: %d", #(_G.__mru_files or {}))
	logf("  lsp.log size: %.1f MB", math.max(vim.fn.getfsize(vim.lsp.log.get_filename()), 0) / 1024 / 1024)

	-- Buffer inventory. Which files are loaded and visible is the context that
	-- makes a stall interpretable later: per-redraw decoration cost is paid by
	-- *visible* windows, and injected-region count scales with line count.
	log("  buffers (v=visible, ts=treesitter highlighter attached):")
	local wins_by_buf = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local ok, b = pcall(vim.api.nvim_win_get_buf, win)
		if ok then
			wins_by_buf[b] = (wins_by_buf[b] or 0) + 1
		end
	end
	local rows = {}
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(b) then
			local name = vim.api.nvim_buf_get_name(b)
			rows[#rows + 1] = {
				buf = b,
				lines = vim.api.nvim_buf_line_count(b),
				ft = vim.bo[b].filetype ~= "" and vim.bo[b].filetype or "-",
				vis = wins_by_buf[b] or 0,
				ts = vim.treesitter.highlighter.active[b] ~= nil,
				name = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[No Name]",
			}
		end
	end
	-- Visible first, then biggest: the likely stall contributors float to the top.
	table.sort(rows, function(a, b)
		if (a.vis > 0) ~= (b.vis > 0) then
			return a.vis > 0
		end
		return a.lines > b.lines
	end)
	for _, r in ipairs(rows) do
		logf("    b%-3d %-6s %6d lines  %-14s %s",
			r.buf,
			r.vis > 0 and ("v" .. r.vis) or "",
			r.lines,
			r.ft,
			r.name .. (r.ts and "  [ts]" or ""))
	end
end

-- --------------------------------------------------------------------- report

function M.report()
	logf("\n===== REPORT  (mark=%s) =====", state.mark)
	local keys = vim.tbl_keys(state.spans)
	table.sort(keys, function(a, b)
		return state.spans[a].total > state.spans[b].total
	end)
	log(string.format("  %-46s %10s %8s %10s %10s", "span", "calls", "n/call", "max", "total"))
	for _, k in ipairs(keys) do
		local s = state.spans[k]
		logf("  %-46s %10d %8.2f %10.1f %10.1f", k, s.n, s.total / s.n, s.max, s.total)
	end

	-- Per-mark comparison. This is the table that makes a gradient measurable:
	-- the same span under "spec in split" vs "no spec" side by side.
	local mk = vim.tbl_keys(state.marks)
	if #mk > 1 then
		log("  -- spans by mark (compare the same label across marks) --")
		table.sort(mk)
		for _, mark in ipairs(mk) do
			local m = state.marks[mark]
			local labels = vim.tbl_keys(m.spans)
			table.sort(labels, function(a, b)
				return m.spans[a].total > m.spans[b].total
			end)
			logf("    [%s]", mark)
			for i = 1, math.min(#labels, 8) do
				local e = m.spans[labels[i]]
				logf("      %-42s %6d x %8.2f ms/call %8.1f max", labels[i], e.n, e.total / e.n, e.max)
			end
		end
	end

	dump_attribution("vim.schedule by creation site", state.sched)
	dump_attribution("vim.defer_fn by creation site", state.defer)
	dump_attribution("LanguageTree:parse by caller", state.parse)
	dump_attribution("decoration providers", state.decor)
	dump_attribution("plenary Job:sync by caller [BLOCKING]", state.jobsync)
	dump_attribution("slowest file opens (BufReadPre -> BufWinEnter)", state.opens, 20)
	dump_attribution("buffer ready (BufEnter -> ready for input)", state.selects, 20)

	log("  -- event fires --")
	local ek = vim.tbl_keys(state.events)
	table.sort(ek, function(a, b)
		return state.events[a] > state.events[b]
	end)
	for _, e in ipairs(ek) do
		logf("  %-30s %d", e, state.events[e])
	end

	logf("  -- stalls >= %d ms: %d --", cfg.stall_ms, #state.stalls)
	local worst = vim.deepcopy(state.stalls)
	table.sort(worst, function(a, b)
		return a > b
	end)
	for i = 1, math.min(#worst, 15) do
		logf("    #%d  %.1f ms", i, worst[i])
	end
	-- Each subsection is isolated: a diagnostic must never be able to take down
	-- the session it is diagnosing, and a partial report still beats none.
	for _, section in ipairs({ { "leaks", M.leaks }, { "snapshot", function()
		M.snapshot("at report")
	end } }) do
		local ok, err = pcall(section[2])
		if not ok then
			logf("  [%s section failed] %s", section[1], tostring(err))
		end
	end
	log("")
	vim.notify("perf-probe: report written to " .. LOG, vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------- control

---@param opts? { stall_ms?: integer, sample_every?: integer, tick_ms?: integer, sample?: boolean }
function M.start(opts)
	opts = opts or {}
	cfg.stall_ms = opts.stall_ms or cfg.stall_ms
	cfg.sample_every = opts.sample_every or cfg.sample_every
	cfg.tick_ms = opts.tick_ms or cfg.tick_ms
	cfg.auto_ms = opts.auto_ms or cfg.auto_ms
	if state.running then
		vim.notify("perf-probe: already running", vim.log.levels.WARN)
		return
	end
	state.running = true
	state.started_at = uv.hrtime()
	state.last_tick = uv.hrtime()

	logf("\n\n########## perf-probe start %s ##########", os.date("%Y-%m-%d %H:%M:%S"))
	logf("nvim %s  tick=%dms stall_threshold=%dms sample_every=%d",
		tostring(vim.version()), cfg.tick_ms, cfg.stall_ms, cfg.sample_every)

	install_handle_tracking()
	install_open_timing()
	install_select_timing()
	install_parse_attribution()
	install_decor_attribution()
	install_wrappers()
	install_counters()

	-- Auto-capture so a profile needs no commands beyond start/stop. Uses the
	-- unwrapped scheduler so the probe's own ticks never pollute the attribution
	-- tables it is writing.
	state.auto_timer = uv.new_timer()
	local sched = state.orig_schedule or vim.schedule
	local n = 0
	state.auto_timer:start(cfg.auto_ms, cfg.auto_ms, function()
		n = n + 1
		local i = n
		sched(function()
			pcall(M.tick, "#" .. i)
		end)
	end)

	if opts.sample ~= false then
		debug.sethook(on_count_hook, "", cfg.sample_every)
	end

	state.timer = uv.new_timer()
	local expected = cfg.tick_ms * 1e6
	state.timer:start(cfg.tick_ms, cfg.tick_ms, function()
		local now = uv.hrtime()
		local delta = now - state.last_tick
		local prev = state.last_tick
		state.last_tick = now
		local late = ms(delta - expected)
		-- Idle-tick fallback for select->ready: an on-time tick means the loop is
		-- free again, which is the observable form of "ready for input".
		if state.select_pending and late < cfg.stall_ms then
			vim.schedule(function()
				finalize_select(now)
			end)
		end
		if late >= cfg.stall_ms then
			state.stalls[#state.stalls + 1] = late
			-- Fast context here: no Nvim API. Hand off to the main loop.
			vim.schedule(function()
				report_stall(late, prev, now)
			end)
		end
	end)

	M.snapshot("at start")
	vim.notify("perf-probe: recording -> " .. LOG, vim.log.levels.INFO)
end

function M.stop()
	if not state.running then
		return
	end
	state.running = false
	debug.sethook()
	-- Tear the probe down before reporting. If reporting ever dies, the hook and
	-- timer are already gone, so the session is left clean rather than half
	-- instrumented.
	if state.timer then
		pcall(function()
			state.timer:stop()
			state.timer:close()
		end)
		state.timer = nil
	end
	if state.auto_timer then
		pcall(function()
			state.auto_timer:stop()
			state.auto_timer:close()
		end)
		state.auto_timer = nil
	end
	pcall(vim.api.nvim_del_augroup_by_name, "perf_probe_counters")
	pcall(vim.api.nvim_del_augroup_by_name, "perf_probe_select")
	pcall(vim.api.nvim_del_augroup_by_name, "perf_probe_open")
	state.select_pending = nil
	local ok, err = pcall(M.report)
	logf("########## perf-probe stop %s ##########", os.date("%Y-%m-%d %H:%M:%S"))
	if ok then
		vim.notify("perf-probe: stopped -> " .. LOG, vim.log.levels.INFO)
	else
		logf("  [report failed] %s", tostring(err))
		vim.notify("perf-probe: stopped, report failed -> " .. LOG .. "\n" .. tostring(err), vim.log.levels.ERROR)
	end
end

---@param label string
function M.set_mark(label)
	state.mark = label
	state.mark_at = uv.hrtime()
	logf("\n--- MARK: %s ---", label)
end

--- Register the `Perf*` commands. Idempotent: `plugin/perf-probe.lua` registers
--- lazy forwarders at startup that call this on first use, and it may also be
--- called by hand, so it must be safe to reach more than once.
function M.setup()
	if state.commands_installed then
		return
	end
	state.commands_installed = true

	vim.api.nvim_create_user_command("PerfStart", function(a)
		M.start({ stall_ms = tonumber(a.args) })
	end, { nargs = "?", desc = "perf-probe: start recording (optional stall threshold ms)" })
	vim.api.nvim_create_user_command("PerfStop", M.stop, { desc = "perf-probe: stop + report" })
	-- nargs="*" so a label may contain spaces; a.args keeps it as one raw string.
	vim.api.nvim_create_user_command("PerfMark", function(a)
		M.set_mark(a.args ~= "" and a.args or "unlabelled")
	end, { nargs = "*", desc = "perf-probe: label the next action" })
	vim.api.nvim_create_user_command("PerfSnap", function(a)
		M.snapshot(a.args)
	end, { nargs = "*", desc = "perf-probe: snapshot session state" })
	vim.api.nvim_create_user_command("PerfReport", M.report, { desc = "perf-probe: write aggregates" })
	vim.api.nvim_create_user_command("PerfDup", M.duplicates,
		{ desc = "perf-probe: duplicate-autocmd / wrapper-depth / extmark census" })
	vim.api.nvim_create_user_command("PerfLeak", M.leaks,
		{ desc = "perf-probe: still-open libuv handles grouped by creation site" })
	vim.api.nvim_create_user_command("PerfLog", function()
		vim.cmd("tabnew " .. LOG)
	end, { desc = "perf-probe: open the log" })
end

M.log_path = LOG

return M
