local icons = require("icons")
local colors = require("colors")

local media_cover = sbar.add("item", {
	position = "right",
	background = {
		image = {
			string = "media.artwork",
			scale = 0.85,
		},
		color = colors.transparent,
	},
	label = { drawing = false },
	icon = { drawing = false },
	drawing = false,
	updates = true,
	popup = {
		align = "center",
		horizontal = true,
	},
	update_freq = 2
})

local media_artist = sbar.add("item", {
	position = "right",
	drawing = false,
	padding_left = 3,
	padding_right = 0,
	width = 0,
	icon = { drawing = false },
	label = {
		width = 0,
		font = { size = 9 },
		color = colors.with_alpha(colors.white, 0.6),
		max_chars = 18,
		y_offset = 6,
	},
})

local media_title = sbar.add("item", {
	position = "right",
	drawing = false,
	padding_left = 3,
	padding_right = 0,
	icon = { drawing = false },
	label = {
		font = { size = 11 },
		width = 0,
		max_chars = 25,
		y_offset = -5,
	},
})

local function split_by_pipe(str)
	local t = {}; for s in string.gmatch(str, "([^|]+)") do
		table.insert(t, s)
	end; return t
end

local interrupt = 0
local function animate_detail(detail)
	if (not detail) then interrupt = interrupt - 1 end
	if interrupt > 0 and (not detail) then return end

	sbar.animate("tanh", 30, function()
		media_artist:set({ label = { width = detail and "dynamic" or 0 } })
		media_title:set({ label = { width = detail and "dynamic" or 0 } })
	end)
end

-- Update every 2 seconds with track info
media_cover:subscribe("routine", function(env)
	-- Try to get Spotify info with more robust error handling
	sbar.exec([[
    osascript -e '
    try
      if application "Spotify" is running then
        tell application "Spotify"
          try
            set trackName to name of current track
            set artistName to artist of current track
            set artworkURL to artwork url of current track
            set playerState to player state as string
            set output to playerState & "|" & trackName & "|" & artistName & "|" & artworkURL
          on error errMsg
            set output to "Spotify Error: " & errMsg
          end try
        end tell
      else
        set output to "Spotify not running"
      end if
    on error generalErr
      set output to "General Error: " & generalErr
    end try
    return output'
  ]], function(result)
		if result and result ~= "" and not result:match("^Spotify Error") and not result:match("^General Error") and not result:match("^Spotify not running") then
			local infoArr = split_by_pipe(result)

			if #infoArr >= 4 then
				local playerState = infoArr[1] -- "playing" or "paused"
				local trackName = infoArr[2]
				local artistName = infoArr[3]
				local artworkURL = infoArr[4]

				-- Only show if playing
				local isPlaying = (playerState == "playing")

				-- Update artwork if available
				if artworkURL and artworkURL ~= "" then
					-- Trim any whitespace including newlines from the URL
					artworkURL = artworkURL:gsub("%s+", "")

					-- Use an icon as fallback if URL loading fails
					media_cover:set({
						icon = {
							string = "♫",
							drawing = false
						},
						background = {
							image = {
								string = artworkURL,
								drawing = isPlaying
							},
							color = colors.transparent
						},
						drawing = isPlaying
					})
				else
					-- No artwork URL, use music icon
					media_cover:set({
						icon = {
							string = "♫",
							drawing = isPlaying
						},
						background = {
							image = { drawing = false },
							color = colors.transparent
						},
						drawing = isPlaying
					})
				end

				-- Update text display
				media_artist:set({
					drawing = isPlaying,
					label = { string = artistName }
				})

				media_title:set({
					drawing = isPlaying,
					label = { string = trackName }
				})

				if isPlaying then
					animate_detail(true)
				else
					animate_detail(false)
				end
			else
				media_cover:set({ drawing = false })
				media_artist:set({ drawing = false })
				media_title:set({ drawing = false })
			end
		end
	end)
end)
