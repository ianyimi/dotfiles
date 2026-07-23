local icons = require("icons")
local colors = require("colors")

-- Define whitelist of music apps
local whitelist = { ["Spotify"] = true, ["Music"] = true }

-- Current track state to detect changes
local current_track = nil
local title_timer = nil

-- Create media cover item (artwork display) - replicate original style
local media_cover = sbar.add("item", {
  position = "right",
  background = {
    image = {
      scale = 0.85,
      drawing = false
    },
    color = colors.transparent,
  },
  label = { drawing = false },
  icon = { drawing = false },
  drawing = false,
  update_freq = 1,
  popup = {
    align = "center",
    horizontal = true,
  }
})

-- Create artist item (top line) - replicate original style
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

-- Create title item (bottom line) - replicate original style
local media_title = sbar.add("item", {
  position = "right",
  drawing = false,
  padding_left = 3,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    font = { size = 11 },
    width = 0,
    max_chars = 16,
    y_offset = -5,
  },
})

-- Add control buttons in popup menu
sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.back },
  label = { drawing = false },
  click_script = "osascript -e 'tell application \"Spotify\" to previous track' 2>/dev/null || osascript -e 'tell application \"Music\" to previous track' 2>/dev/null",
})

sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.play_pause },
  label = { drawing = false },
  click_script = "osascript -e 'tell application \"Spotify\" to playpause' 2>/dev/null || osascript -e 'tell application \"Music\" to playpause' 2>/dev/null",
})

sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.forward },
  label = { drawing = false },
  click_script = "osascript -e 'tell application \"Spotify\" to next track' 2>/dev/null || osascript -e 'tell application \"Music\" to next track' 2>/dev/null",
})

-- Animation function for showing/hiding artist and title - using original style
local interrupt = 0
local function animate_detail(detail)
  if (not detail) then interrupt = interrupt - 1 end
  if interrupt > 0 and (not detail) then return end

  sbar.animate("tanh", 30, function()
    media_artist:set({ label = { width = detail and "dynamic" or 0 } })
    media_title:set({ label = { width = detail and "dynamic" or 0 } })
  end)
end

-- Simulate a media_change event with data from our script
local function process_media_info(app, state, title, artist, artwork_url)
  if whitelist[app] then
    local drawing = (state == "playing")
    
    -- Update track info using exactly the same format as the original widget
    media_artist:set({ 
      drawing = drawing, 
      label = { string = artist } 
    })
    
    media_title:set({ 
      drawing = drawing, 
      label = { string = title } 
    })
    
    -- Update artwork 
    if drawing and artwork_url and artwork_url ~= "" then
      media_cover:set({ 
        drawing = drawing,
        background = {
          image = {
            string = artwork_url,
            drawing = true
          }
        }
      })
    else
      media_cover:set({ drawing = drawing })
    end
    
    -- Handle animation exactly like the original
    if drawing then
      animate_detail(true)
      interrupt = interrupt + 1
      
      -- Use timer to hide details after 5 seconds
      if title_timer then 
        sbar.cancel_timeout(title_timer) 
      end
      
      title_timer = sbar.delay(5, function()
        animate_detail(false)
        title_timer = nil
      end)
    else
      media_cover:set({ popup = { drawing = false } })
    end
  end
end

-- Update track info using script
media_cover:subscribe("routine", function(env)
  -- Get Spotify info from our script
  sbar.exec("$CONFIG_DIR/scripts/get_spotify_info.sh", function(info)
    if info and info ~= "" then
      local parts = {}
      for part in info:gmatch("([^||]+)") do
        table.insert(parts, part)
      end
      
      if parts[1] == "playing" and #parts >= 4 then
        local state = parts[1]
        local title = parts[2]
        local artist = parts[3]
        local artwork_url = parts[4]
        
        -- Check if track has changed
        local track_string = title .. " - " .. artist
        local track_changed = (current_track ~= track_string)
        
        if track_changed then
          current_track = track_string
          process_media_info("Spotify", state, title, artist, artwork_url)
        else
          -- Just ensure cover art remains visible
          media_cover:set({ drawing = true })
        end
      elseif parts[1] == "paused" then
        -- Handle paused state
        media_cover:set({ drawing = false })
        media_artist:set({ drawing = false })
        media_title:set({ drawing = false })
      elseif parts[1] == "error" then
        -- Try Apple Music
        check_apple_music()
      else
        -- Try Apple Music
        check_apple_music()
      end
    else
      -- Try Apple Music
      check_apple_music()
    end
  end)
end)

-- Check Apple Music as fallback
function check_apple_music()
  sbar.exec("$CONFIG_DIR/scripts/get_music_info.sh", function(music_info)
    if music_info and music_info ~= "" then
      local music_parts = {}
      for part in music_info:gmatch("([^||]+)") do
        table.insert(music_parts, part)
      end
      
      if music_parts[1] == "playing" and #music_parts >= 3 then
        local state = music_parts[1]
        local title = music_parts[2]
        local artist = music_parts[3]
        
        -- Track changed detection
        local track_string = title .. " - " .. artist
        local track_changed = (current_track ~= track_string)
        
        if track_changed then
          current_track = track_string
          
          -- For Music app, use default icon since artwork URL isn't available
          process_media_info("Music", state, title, artist, nil)
          
          -- Set icon for Music app
          media_cover:set({
            background = { image = { drawing = false } },
            icon = {
              string = icons.music or "♫",
              drawing = true,
              color = colors.white
            },
            drawing = true
          })
        else
          -- Just ensure cover art remains visible
          media_cover:set({ drawing = true })
        end
      else
        -- No music playing
        media_cover:set({ drawing = false })
        media_artist:set({ drawing = false })
        media_title:set({ drawing = false })
        current_track = nil
      end
    else
      -- No music playing
      media_cover:set({ drawing = false })
      media_artist:set({ drawing = false })
      media_title:set({ drawing = false })
      current_track = nil
    end
  end)
end

-- Keep the same mouse interaction handlers as the original
media_cover:subscribe("mouse.entered", function(env)
  interrupt = interrupt + 1
  animate_detail(true)
end)

media_cover:subscribe("mouse.exited", function(env)
  animate_detail(false)
end)

media_cover:subscribe("mouse.clicked", function(env)
  media_cover:set({ popup = { drawing = "toggle" }})
end)

media_title:subscribe("mouse.exited.global", function(env)
  media_cover:set({ popup = { drawing = false }})
end)