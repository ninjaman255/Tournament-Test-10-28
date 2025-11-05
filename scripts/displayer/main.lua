-- Enhanced Displayer Example - Using Manual Timer Updates
local Displayer = require("scripts/displayer/displayer")

if not Displayer:init() or not Displayer:isValid() then
    print("Failed to initialize Displayer API")
    return
end

print("Displayer API loaded successfully!")

-- Initialize player_data as an empty table at the top level
local player_data = {}
local global_timer = 0

-- Use manual timer updates (more reliable than events)
local use_manual_updates = true

-- Player management
Net:on("player_join", function(event)
    local player_id = event.player_id
    print("Player joined: " .. player_id)
    
    -- Initialize player data for this player
    player_data[player_id] = {
        session_started = false,
        join_time = os.clock(),
        scrolling_list_created = false,
        scrolling_list_timer = 0,
        countdown_text_id = nil,
        fullscreen_scroll_created = false,
        fullscreen_timer = 0,
        player_timer_value = 0,
        mission_countdown_value = 60,
        countdown_running = true
    }
    
    -- Hide default HUD
    Displayer:hidePlayerHUD(player_id)
    
    -- Create global timer display
    Displayer.TimerDisplay.createGlobalTimerDisplay("global_timer", 10, 10, "default")
    Displayer.TimerDisplay.updateGlobalTimerDisplay("global_timer", global_timer)
    
    -- Create news marquee (top-center)
    Displayer.Text.drawMarqueeText(player_id, "news_ticker", 
        "Welcome! Fullscreen display will appear in 5 seconds!", 
        30, "THICK", 1.0, 100, "slow", {
            x = 10, y = 25, width = 220, height = 15,
            padding_x = 8, padding_y = 2
        })
    
    -- Create player timer displays (left side)
    Displayer.TimerDisplay.createPlayerTimerDisplay(player_id, "player_timer", 10, 50, "default")
    
    -- Create mission countdown display
    Displayer.TimerDisplay.createPlayerCountdownDisplay(player_id, "mission_countdown", 10, 70, "default")
    
    -- Add labels for timers
    Displayer.Text.drawText(player_id, "PLAY TIME", 12, 40, "THICK", 0.7, 100)
    Displayer.Text.drawText(player_id, "MISSION TIMER", 12, 60, "THICK", 0.7, 100)
    
    -- Create initial countdown text for fullscreen display
    player_data[player_id].countdown_text_id = Displayer.Text.drawText(player_id, "Fullscreen in: 5", 12, 90, "THICK", 0.7, 100)
    
    -- Set initial timer values
    Displayer.TimerDisplay.updatePlayerTimerDisplay(player_id, "player_timer", 0)
    Displayer.TimerDisplay.updatePlayerCountdownDisplay(player_id, "mission_countdown", 60)
    
    -- Start the session immediately
    player_data[player_id].session_started = true
    
    -- DEBUG: Create a simple test text to verify display is working
    Displayer.Text.drawText(player_id, "DEBUG: Display working", 10, 110, "THICK", 0.7, 100)
end)

-- Main update loop
Net:on("tick", function(event)
    local delta = event.delta_time or 0
    
    -- Update global timer
    global_timer = global_timer + delta
    Displayer.TimerDisplay.updateGlobalTimerDisplay("global_timer", global_timer)
    
    -- Safe iteration through player_data
    if not player_data then
        return
    end
    
    for player_id, data in pairs(player_data) do
        if not data then
            goto continue
        end
        
        -- Update player timers manually (reliable approach)
        if data.session_started then
            -- Update player timer (counts up)
            data.player_timer_value = data.player_timer_value + delta
            Displayer.TimerDisplay.updatePlayerTimerDisplay(player_id, "player_timer", data.player_timer_value)
            
            -- Update mission countdown (counts down)
            if data.countdown_running then
                data.mission_countdown_value = math.max(0, data.mission_countdown_value - delta)
                Displayer.TimerDisplay.updatePlayerCountdownDisplay(player_id, "mission_countdown", data.mission_countdown_value)
                
                -- Handle countdown completion
                if data.mission_countdown_value <= 0 then
                    data.countdown_running = false
                    Displayer.Text.createTextBox(player_id, "countdown_complete", 
                        "Time's up! Mission complete!", 
                        150, 120, 80, 40, "THICK", 0.9, 100, {
                            x = 145, y = 115, width = 90, height = 50,
                            padding_x = 4, padding_y = 4
                        }, 35)
                end
            end
        end
        
        -- Handle delayed fullscreen display
        if not data.fullscreen_scroll_created and data.fullscreen_timer then
            data.fullscreen_timer = data.fullscreen_timer + delta
            local time_remaining = math.max(0, 5 - data.fullscreen_timer)
            
            -- Update countdown text using the stored text ID
            if data.countdown_text_id then
                Displayer.Text.updateText(player_id, data.countdown_text_id, "Fullscreen in: " .. math.ceil(time_remaining))
            end
            
            if data.fullscreen_timer >= 5.0 then
                data.fullscreen_scroll_created = true
                
                -- Remove countdown text
                if data.countdown_text_id then
                    Displayer.Text.removeText(player_id, data.countdown_text_id)
                    data.countdown_text_id = nil
                end
                
                -- Create fullscreen scrolling text list
                local fullscreen_messages = {
                    "=== FULLSCREEN DISPLAY ===",
                    "Scale: 2.0x",
                    "Backdrop: Full Screen",
                    "Text: Large and Clear",
                    "Perfect for announcements",
                    "or important messages!",
                    "This text is scaled 2x",
                    "Monospace preserved!",
                    "Character spacing maintained",
                    "Easy to read from distance",
                    "Great for titles and headers",
                    "Backdrop covers entire screen",
                    "Using marquee-backdrop.png",
                    "Dimensions: 240x160",
                    "Position: 0,0",
                    "Enjoy the enhanced visibility!",
                    "======================"
                }
                
                -- Create the fullscreen scrolling list
                local success = Displayer.ScrollingText.createList(player_id, "fullscreen_display", 0, 0, 480, 320, {
                    texts = fullscreen_messages,
                    scroll_speed = 40,
                    entry_delay = 2.0,
                    font = "THICK",
                    scale = 2.0,
                    z_order = 50,
                    loop = true,
                    backdrop = {
                        x = 0, y = 0, width = 480, height = 320,
                        padding_x = 0,
                        padding_y = 0
                    },
                    destroy_when_finished = false
                })
                
                if success then
                    print("Fullscreen 2x scale scrolling list created successfully for player " .. player_id)
                else
                    print("ERROR: Failed to create fullscreen scrolling list for player " .. player_id)
                    Displayer.Text.drawText(player_id, "ERROR: Fullscreen failed", 10, 120, "THICK", 0.7, 100)
                end
            end
        end
        
        ::continue::
    end
end)

-- Update the reset command
Net:on("reset", function(event)
    local player_id = event.player_id
    if player_data and player_data[player_id] then
        player_data[player_id].mission_countdown_value = 60
        player_data[player_id].countdown_running = true
        Displayer.TimerDisplay.updatePlayerCountdownDisplay(player_id, "mission_countdown", 60)
        
        Displayer.Text.createTextBox(player_id, "reset_msg", "Countdown reset to 60 seconds!", 
            150, 60, 80, 30, "THICK", 0.8, 100, nil, 40)
    end
end)

Net:on("add_text", function(event)
    local player_id = event.player_id
    local text = event.text or "This is a test message!"
    Displayer.Text:createTextBox(player_id, "custom_text", text, 
        150, 160, 80, 30, "THICK", 0.8, 100, nil, 35)
end)

Net:on("clear_all", function(event)
    local player_id = event.player_id
    -- Remove all scrolling lists
    Displayer.ScrollingText:removeList(player_id, "fullscreen_display")
    Displayer.ScrollingText:removeList(player_id, "manual_fullscreen") 
    Displayer.ScrollingText:removeList(player_id, "debug_list")
    
    Displayer.Text:createTextBox(player_id, "cleared", "All displays cleared!", 
        150, 180, 80, 30, "THICK", 0.8, 100, nil, 40)
end)

print("Enhanced Displayer example with fullscreen 2x scale display loaded and ready!")
print("Use 'create_fullscreen' command to test manually")
print("Use 'debug_scroll' command to test with small list")
print("Use 'clear_all' command to remove all displays")
print("Use 'reset' command to reset the mission countdown")