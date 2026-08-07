local mainMod = "SUPER"
local noctCall = "noctalia msg "
local launchPrefix = "uwsm app -- " -- if you are not using UWSM, make this empty (e.g. "")

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- Window manipulation
hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D",           hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))

-- Change focus
hl.bind(mainMod .. " + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down",  hl.dsp.focus({ direction = "down" }))
-- ALT + Tab rebound below in the aerospace section (was: hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + Tab",   hl.dsp.exec_cmd(noctCall .. "window-switcher"))

-- Move active window around workspaces & monitors
hl.bind(mainMod .. " + SHIFT + Up",                   hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Right",                hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Left",                 hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Down",                 hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + 1",                    hl.dsp.window.move({ monitor = MONITOR1 }))
hl.bind(mainMod .. " + SHIFT + 2",                    hl.dsp.window.move({ monitor = MONITOR2 }))
hl.bind(mainMod .. " + SHIFT + 3",                    hl.dsp.window.move({ monitor = MONITOR3 }))
hl.bind(mainMod .. " + SHIFT + mouse_up",             hl.dsp.window.move({ monitor   = "+1" }))
hl.bind(mainMod .. " + SHIFT + mouse_down",           hl.dsp.window.move({ monitor   = "-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Right",      hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",       hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "r-1" }))
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + CONTROL + " .. key, hl.dsp.window.move({ workspace = "m~" .. i }))
end

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

------------------
---- LAUNCHER ----
------------------

hl.bind(mainMod .. " + Return",     hl.dsp.exec_cmd(launchPrefix .. TERMINAL))
hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER))
hl.bind(mainMod .. " + T",          hl.dsp.exec_cmd(launchPrefix .. EDITOR))
hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind(mainMod .. " + W",          hl.dsp.exec_cmd(launchPrefix .. BROWSER))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"))
hl.bind(mainMod .. " + Z",          hl.dsp.exec_cmd(noctCall .. "settings-toggle"))
hl.bind(mainMod .. " + X",          hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center"))
hl.bind(mainMod .. " + Space",      hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher"))
hl.bind(mainMod .. " + period",     hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher /emo"))
hl.bind(mainMod .. " + L",          hl.dsp.exec_cmd(noctCall .. "session lock"))
hl.bind(mainMod .. " + ALT + C",    hl.dsp.exec_cmd(noctCall .. "panel-toggle session"))

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctCall .. "volume-up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctCall .. "volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(noctCall .. "volume-mute"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(noctCall .. "mic-mute"),    { locked = true })

-- Media
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(noctCall .. "media toggle"),   { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(noctCall .. "media toggle"),   { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(noctCall .. "media next"),     { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(noctCall .. "media previous"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(noctCall .. "brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctCall .. "brightness-down"), { locked = true, repeating = true })

-------------------
---- UTILITIES ----
-------------------

-- Screen Capture
hl.bind(mainMod .. " + P",     hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("Print",               hl.dsp.exec_cmd(noctCall .. "screenshot-region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(noctCall .. "screenshot-fullscreen"))

-- Theming and Wallpaper
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(noctCall .. "panel-toggle wallpaper"))

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(noctCall .. "panel-toggle clipboard"))

-- Notifications
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center notifications"))

-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Focus on monitors
hl.bind(mainMod .. " + 1", hl.dsp.focus({ monitor = MONITOR1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ monitor = MONITOR2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ monitor = MONITOR3 }))

-- Focus on workspace number
-- Absolute
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + TAB + " .. key, hl.dsp.focus({ workspace = i }))
end
-- Relative
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + CONTROL + " .. key, hl.dsp.focus({ workspace = "m~" .. i }))
end

-- Move to adjacent workspaces and next empty on a given monitor
hl.bind(mainMod .. " + CONTROL + Right",       hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + Left",        hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + Down",        hl.dsp.focus({ workspace = "emptym" }))

-- Scroll through existing workspaces & monitors
hl.bind(mainMod .. " + mouse_down",           hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + mouse_up",             hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up",   hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m-1" }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special())

--------------------------------------------------------------------
---- AEROSPACE (ALT) SCHEME — ported from macOS ~/.aerospace.toml ----
--------------------------------------------------------------------
-- Coexists with the SUPER system binds above: ALT = window management,
-- SUPER = system/noctalia. Mirrors aerospace muscle memory exactly.
local aero = "ALT"

-- Focus (aerospace: alt-h/j/k/l)
hl.bind(aero .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(aero .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(aero .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(aero .. " + L", hl.dsp.focus({ direction = "r" }))

-- Move window (aerospace: alt-shift-h/j/k/l)
hl.bind(aero .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(aero .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(aero .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(aero .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

-- Join-with approximation (aerospace: alt-ctrl-h/j/k/l) — dwindle preselect
hl.bind(aero .. " + CONTROL + H", hl.dsp.layout("preselect l")) -- aerospace: join-with left
hl.bind(aero .. " + CONTROL + J", hl.dsp.layout("preselect d")) -- aerospace: join-with down
hl.bind(aero .. " + CONTROL + K", hl.dsp.layout("preselect u")) -- aerospace: join-with up
hl.bind(aero .. " + CONTROL + L", hl.dsp.layout("preselect r")) -- aerospace: join-with right

-- Fullscreen / layout (aerospace: alt-f, alt-period, alt-comma)
hl.bind(aero .. " + F",      hl.dsp.window.fullscreen())
hl.bind(aero .. " + period", hl.dsp.layout("togglesplit"))                    -- aerospace: layout tiles horizontal vertical
hl.bind(aero .. " + comma",  hl.dsp.window.pseudo({ action = "toggle" }))     -- aerospace: layout accordion (approximation)

-- Resize (aerospace: alt-up/down = resize smart ±50)
hl.bind(aero .. " + Up",   hl.dsp.window.resize({ x = 0, y = 50,  relative = true }), { repeating = true })
hl.bind(aero .. " + Down", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })

-- Previous workspace (aerospace: alt-tab focused the other monitor;
-- single-monitor adaptation: toggle between two most recent workspaces)
hl.bind(aero .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

-- Terminal (linux addition — macOS launched apps outside aerospace)
hl.bind(aero .. " + Return", hl.dsp.exec_cmd(launchPrefix .. TERMINAL))

-- Workspaces: 1-9 + letters (exact aerospace set; F/H/I/J/K/L/Z reserved)
--   alt + <key>                 focus workspace
--   alt + shift + <key>         move window + follow
--   alt + ctrl + shift + <key>  move window silently
local aeroNumWs = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
local aeroLetterWs = {
    "A", "B", "C", "D", "E", "G", "M", "N", "O", "P",
    "Q", "R", "S", "T", "U", "V", "W", "X", "Y",
}
for _, k in ipairs(aeroNumWs) do
    hl.bind(aero .. " + " .. k,                        hl.dsp.focus({ workspace = tonumber(k) }))
    hl.bind(aero .. " + SHIFT + " .. k,                hl.dsp.window.move({ workspace = tonumber(k), follow = true }))
    hl.bind(aero .. " + CONTROL + SHIFT + " .. k,      hl.dsp.window.move({ workspace = tonumber(k) }))
end
for _, k in ipairs(aeroLetterWs) do
    hl.bind(aero .. " + " .. k,                        hl.dsp.focus({ workspace = "name:" .. k }))
    hl.bind(aero .. " + SHIFT + " .. k,                hl.dsp.window.move({ workspace = "name:" .. k, follow = true }))
    hl.bind(aero .. " + CONTROL + SHIFT + " .. k,      hl.dsp.window.move({ workspace = "name:" .. k }))
end

-- Service submap (aerospace: alt-shift-semicolon → mode service)
hl.bind(aero .. " + SHIFT + semicolon", hl.dsp.submap("service"))
hl.define_submap("service", function()
    -- esc = reload config + back to main (aerospace: reload-config, mode main)
    hl.bind("escape", hl.dsp.exec_cmd("hyprctl reload"))
    hl.bind("escape", hl.dsp.submap("reset"))

    -- f = toggle floating/tiling (aerospace: layout floating tiling)
    hl.bind("F", hl.dsp.window.float({ action = "toggle" }))
    hl.bind("F", hl.dsp.submap("reset"))

    -- backspace = close all windows but current
    hl.bind("backspace", hl.dsp.exec_cmd("~/.config/hypr/scripts/close-others.sh"))
    hl.bind("backspace", hl.dsp.submap("reset"))

    -- alt-shift-hjkl = join-with (preselect approximation), then back to main
    hl.bind(aero .. " + SHIFT + H", hl.dsp.layout("preselect l"))
    hl.bind(aero .. " + SHIFT + H", hl.dsp.submap("reset"))
    hl.bind(aero .. " + SHIFT + J", hl.dsp.layout("preselect d"))
    hl.bind(aero .. " + SHIFT + J", hl.dsp.submap("reset"))
    hl.bind(aero .. " + SHIFT + K", hl.dsp.layout("preselect u"))
    hl.bind(aero .. " + SHIFT + K", hl.dsp.submap("reset"))
    hl.bind(aero .. " + SHIFT + L", hl.dsp.layout("preselect r"))
    hl.bind(aero .. " + SHIFT + L", hl.dsp.submap("reset"))
end)
