local icons = require("icons")
local colors = require("colors")

-- Create a media display item
local media_item = sbar.add("item", {
  position = "right",
  icon = { 
    string = icons.media.play_pause,
    color = colors.white,
    padding_right = 8
  },
  label = { 
    string = "",
    font = { size = 11 }
  },
  update_freq = 2
})

-- Update media info from Spotify or Music app
media_item:subscribe("routine", function(env)
  -- Try Spotify first
  sbar.exec("osascript -e 'tell application \"Spotify\"' -e 'if player state is playing then' -e '\"Playing: \" & name of current track & \" - \" & artist of current track' -e 'else' -e '\"\"' -e 'end if' -e 'end tell' 2>/dev/null || echo \"\"", function(spotify_result)
    if spotify_result ~= "" then
      media_item:set({
        label = { string = spotify_result },
        icon = { color = colors.green }
      })
      return
    end
    
    -- Then try Music app
    sbar.exec("osascript -e 'tell application \"Music\"' -e 'if player state is playing then' -e '\"Playing: \" & name of current track & \" - \" & artist of current track' -e 'else' -e '\"\"' -e 'end if' -e 'end tell' 2>/dev/null || echo \"\"", function(music_result)
      if music_result ~= "" then
        media_item:set({
          label = { string = music_result },
          icon = { color = colors.red }
        })
      else
        -- No music playing
        media_item:set({
          label = { string = "" }
        })
      end
    end)
  end)
end)

-- Add click actions for player control
media_item:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    -- Next track
    sbar.exec("osascript -e 'tell application \"Spotify\" to next track' 2>/dev/null || osascript -e 'tell application \"Music\" to next track' 2>/dev/null")
  elseif env.BUTTON == "left" then
    -- Play/pause
    sbar.exec("osascript -e 'tell application \"Spotify\" to playpause' 2>/dev/null || osascript -e 'tell application \"Music\" to playpause' 2>/dev/null")
  end
end)