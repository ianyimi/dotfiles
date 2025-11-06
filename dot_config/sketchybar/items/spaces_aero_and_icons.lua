local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local LIST_ALL = "aerospace list-workspaces --all"
local LIST_CURRENT = "aerospace list-workspaces --focused"
local LIST_MONITORS = "aerospace list-monitors | awk '{print $1}'"
local LIST_WORKSPACES = "aerospace list-workspaces --monitor %s"
local LIST_WORKSPACES_OCCUPIED = "aerospace list-workspaces --empty no --monitor %s"
local LIST_APPS = "aerospace list-windows --workspace %s | awk -F'|' '{gsub(/^ *| *$/, \"\", $2); print $2}'"

local spaces = {}
local lastFocusedWorkspace = nil

local function getIconForApp(appName)
	return app_icons[appName] or "?"
end

local function updateSpaceIcons(spaceId, workspaceName)
	local icon_strip = ""
	sbar.exec(LIST_APPS:format(workspaceName), function(appsOutput)
		local appFound = false
		for app in appsOutput:gmatch("[^\r\n]+") do
			local appName = app:match("^%s*(.-)%s*$") -- Trim whitespace
			if appName and appName ~= "" then
				icon_strip = icon_strip .. " " .. getIconForApp(appName)
				appFound = true
			end
		end
		if spaces[spaceId] then
			spaces[spaceId].item:set({ label = { string = icon_strip, drawing = true } })
		end
	end)
end

local function addWorkspaceItem(workspaceName, monitorId, isSelected)
	local spaceId = "workspace_" .. workspaceName
	if not spaces[spaceId] then
		local space_item = sbar.add("item", spaceId, {
			icon = {
				font = { family = settings.font.numbers },
				string = workspaceName,
				padding_left = 10,
				padding_right = 2,
				color = colors.grey,
				highlight_color = colors.purple,
			},
			label = {
				padding_right = 12,
				color = colors.grey,
				highlight_color = colors.purple,
				font = "sketchybar-app-font:Regular:12.0",
				y_offset = -1,
			},
			padding_left = 2,
			padding_right = 2,
			background = {
				color = colors.bg2,
				border_width = 1,
				height = 24,
				border_color = colors.bg1,
				corner_radius = 9,
			},
			click_script = "aerospace workspace " .. workspaceName,
			display = monitorId,
		})

		local space_bracket = sbar.add("bracket", { spaceId }, {
			background = {
				color = colors.transparent,
				border_color = colors.transparent,
				height = 26,
				border_width = 1,
				corner_radius = 9,
			}
		})

		space_item:subscribe("mouse.clicked", function()
			sbar.exec("aerospace workspace " .. workspaceName)
		end)

		spaces[spaceId] = { item = space_item, bracket = space_bracket }
	end

	spaces[spaceId].item:set({
		icon = { highlight = isSelected },
		label = { highlight = isSelected },
	})

	spaces[spaceId].bracket:set({
		background = { border_color = isSelected and colors.dirty_white or colors.transparent }
	})

	updateSpaceIcons(spaceId, workspaceName)
end

local function drawSpaces()
	sbar.exec(LIST_MONITORS, function(monitorsOutput)
		local firstMonitor = monitorsOutput:match("[^\r\n]+")
		sbar.exec(LIST_CURRENT, function(focusedWorkspaceOutput)
			local focusedWorkspace = focusedWorkspaceOutput:match("[^\r\n]+")

			-- Collect all monitors into a table
			local monitors = {}
			for monitorId in monitorsOutput:gmatch("[^\r\n]+") do
				table.insert(monitors, monitorId)
			end

			-- Track which monitors have been processed
			local processedCount = 0
			local allWorkspacesFound = {}

			sbar.exec("aerospace workspace --monitor", function()
				for _, monitorId in ipairs(monitors) do
					sbar.exec(LIST_WORKSPACES_OCCUPIED:format(monitorId), function(workspacesOutput)
						for workspaceName in workspacesOutput:gmatch("[^\r\n]+") do
							allWorkspacesFound[workspaceName] = true
							local isSelected = workspaceName == focusedWorkspace
							addWorkspaceItem(workspaceName, monitorId, isSelected)
						end

						processedCount = processedCount + 1

						-- Only run fallback after ALL monitors have been processed
						if processedCount == #monitors then
							if not allWorkspacesFound[focusedWorkspace] then
								addWorkspaceItem(focusedWorkspace, firstMonitor, true)
							end
						end
					end)
				end
			end)
			if lastFocusedWorkspace and lastFocusedWorkspace ~= focusedWorkspace then
				for spaceId, _ in pairs(spaces) do
					if spaceId ~= "workspace_" .. focusedWorkspace then
						sbar.exec(LIST_APPS:format(spaceId:gsub("workspace_", "")), function(appsOutput)
							if appsOutput == "" then
								sbar.remove(spaces[spaceId].item)
								sbar.remove(spaces[spaceId].bracket)
								spaces[spaceId] = nil
							end
						end)
					end
				end
			end
			lastFocusedWorkspace = focusedWorkspace
		end)
	end)
end

drawSpaces()

local space_window_observer = sbar.add("item", {
	drawing = false,
	updates = true,
})

space_window_observer:subscribe("aerospace_workspace_change", function(env)
	drawSpaces()
end)

space_window_observer:subscribe("front_app_switched", function()
	drawSpaces()
end)
