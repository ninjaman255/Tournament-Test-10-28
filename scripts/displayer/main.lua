-- Combined Main File - Timers, Text Display, and Text Box System (Fixed Player Position)
local TimerDisplay = require("scripts/displayer/timer-display")
local TextDisplay = require("scripts/displayer/text-display")

-- Store timer states
local player_timers = {}
local global_timers = {
    session_timer = 0,
    session_created = false,
    session_running = false
}

-- Track players waiting for timer start
local players_waiting_for_start = {}

-- Fixed player position (center of 240x160 screen)
local PLAYER_X, PLAYER_Y = 120, 80

-- Timer positions relative to player
local TIMER_Y = PLAYER_Y + 20  -- 20 pixels below player
local COUNTDOWN_Y = PLAYER_Y + 40  -- 40 pixels below player (20 pixels below timer)

-- Function to start global timer
local function startGlobalTimers()
    global_timers.session_running = true
    print("Global timer started!")
end

-- Function to start player-specific countdown
local function startPlayerCountdown(player_id)
    if player_timers[player_id] then
        player_timers[player_id].countdown_running = true
        print("Player countdown started for " .. player_id)
    end
end

-- Example of creating and starting displays when players join
Net:on("player_join", function(event)
    local player_id = event.player_id
    
    -- Initialize player timer data
    player_timers[player_id] = {
        countdown = 60,  -- 60 seconds
        countdown_running = false,
        join_time = os.clock(),
        started = false,
        elapsed_time = 0
    }
    
    -- Create timer displays positioned below the player
    TimerDisplay:createPlayerTimerDisplay(player_id, "player_timer", PLAYER_X, TIMER_Y, "default")
    TimerDisplay:createPlayerCountdownDisplay(player_id, "player_countdown", PLAYER_X, COUNTDOWN_Y, "default")
    
    -- Create global session timer if it doesn't exist yet
    if not global_timers.session_created then
        TimerDisplay:createGlobalTimerDisplay("session_timer", 10, 10, "large")
        global_timers.session_created = true
    end
    
    -- Update the new player with current global timer value
    TimerDisplay:updateGlobalTimerDisplay("session_timer", global_timers.session_timer)
    
    -- Create text displays
    -- Static welcome text
    TextDisplay:drawText(player_id, "WELCOME PLAYER", 10, 140, "THICK", 1.0, 100)
    TextDisplay:addBackdrop(player_id, "text_1", {
        x = 5, y = 135, width = 120, height = 20,
        padding_x = 4,
        padding_y = 2
    })
    
    -- News marquee with backdrop that constrains the text
    TextDisplay:drawMarqueeText(player_id, "news_ticker", 
        "Welcome to the game! Timers are positioned below your character!",
        30, "THICK", 1.0, 100, "slow", {
            x = 10, y = 25, width = 220, height = 15,
            padding_x = 8,
            padding_y = 2
        })
    
    -- MegaMan Battle Network Style Text Box
    local welcome_text = "Welcome to the arena! Your mission is to survive for as long as possible. " ..
                        "Use your abilities wisely and watch your timers. " ..
                        "Good luck, operator! The battle begins in moments..."
    
    TextDisplay:createTextBox(player_id, "welcome_box", welcome_text, 20, 150, 200, 50, "THICK", 1.0, 100, {
        x = 15, y = 140, width = 210, height = 60,
        padding_x = 8,
        padding_y = 6
    }, 25) -- 25 characters per second
    
    -- Mark player as waiting for timer start
    players_waiting_for_start[player_id] = true
    print("Player " .. player_id .. " joined, timers will start in 1 second")
end)

-- Handle player disconnect
Net:on("player_disconnect", function(event)
    local player_id = event.player_id
    player_timers[player_id] = nil
    players_waiting_for_start[player_id] = nil
end)

-- Update all timers every tick
Net:on("tick", function(event)
    local delta = event.delta_time
    local current_time = os.clock()
    
    -- Handle delayed timer starts
    for player_id, _ in pairs(players_waiting_for_start) do
        local player_data = player_timers[player_id]
        if player_data and not player_data.started then
            -- Check if 1 second has passed since join
            if current_time - player_data.join_time >= 1.0 then
                startPlayerCountdown(player_id)
                player_data.started = true
                players_waiting_for_start[player_id] = nil
                
                -- Start global timer if it hasn't been started yet
                if not global_timers.session_running then
                    startGlobalTimers()
                end
            end
        end
    end
    
    -- Update global session timer (counts up)
    if global_timers.session_running then
        global_timers.session_timer = global_timers.session_timer + delta
        TimerDisplay:updateGlobalTimerDisplay("session_timer", global_timers.session_timer)
    end
    
    -- Update per-player timers
    for player_id, timers in pairs(player_timers) do
        -- Update player timer (always counts up once started)
        if timers.started then
            timers.elapsed_time = timers.elapsed_time + delta
            TimerDisplay:updatePlayerTimerDisplay(player_id, "player_timer", timers.elapsed_time)
        end
        
        -- Update countdown if running
        if timers.countdown_running and timers.countdown > 0 then
            timers.countdown = math.max(0, timers.countdown - delta)
            TimerDisplay:updatePlayerCountdownDisplay(player_id, "player_countdown", timers.countdown)
            
            if timers.countdown <= 0 then
                timers.countdown_running = false
                timers.remove_countdown = true
            end
        end
        
        -- Handle scheduled countdown removal
        if timers.remove_countdown then
            TimerDisplay:removePlayerDisplay(player_id, "player_countdown")
            timers.remove_countdown = false
        end
    end
end)

-- Command to reset player countdown
Net:on("reset_countdown", function(event)
    local player_id = event.player_id
    if player_timers[player_id] then
        player_timers[player_id].countdown = 60
        player_timers[player_id].countdown_running = true
        TimerDisplay:updatePlayerCountdownDisplay(player_id, "player_countdown", 60)
        print("Countdown reset for player " .. player_id)
    end
end)

-- Command to add new marquee
Net:on("add_marquee", function(event)
    local player_id = event.player_id
    local text = event.text or "New marquee text"
    local speed = event.speed or "medium"
    
    TextDisplay:drawMarqueeText(player_id, "custom_marquee", text, 90, "THICK", 1.0, 100, speed, {
        x = 20, y = 85, width = 200, height = 15,
        padding_x = 4,
        padding_y = 2
    })
end)

-- Command to add marquee without backdrop
Net:on("add_marquee_no_backdrop", function(event)
    local player_id = event.player_id
    local text = event.text or "New marquee text"
    local speed = event.speed or "medium"
    
    TextDisplay:drawMarqueeText(player_id, "custom_marquee", text, 90, "THICK", 1.0, 100, speed)
end)

-- Command to update existing text
Net:on("update_text", function(event)
    local player_id = event.player_id
    local text_id = event.text_id
    local new_text = event.new_text
    
    TextDisplay:updateText(player_id, text_id, new_text)
end)

-- Command to change marquee speed
Net:on("change_speed", function(event)
    local player_id = event.player_id
    local text_id = event.text_id
    local speed = event.speed
    
    TextDisplay:setMarqueeSpeed(player_id, text_id, speed)
end)

-- Command to remove text
Net:on("remove_text", function(event)
    local player_id = event.player_id
    local text_id = event.text_id
    
    TextDisplay:removeText(player_id, text_id)
end)

-- Text Box Commands
Net:on("create_text_box", function(event)
    local player_id = event.player_id
    local text = event.text or "This is a sample text box that demonstrates the MegaMan Battle Network style text display system. It shows text character by character with proper word wrapping and automatic pagination. You can use this for dialogues, instructions, or story elements in your game."
    local speed = event.speed or 25
    
    TextDisplay:createTextBox(player_id, "story_box", text, 20, 30, 200, 80, "THICK", 1.0, 100, {
        x = 15, y = 25, width = 210, height = 90,
        padding_x = 8,
        padding_y = 6
    }, speed)
    
    print("Created text box for player " .. player_id)
end)

Net:on("advance_text_box", function(event)
    local player_id = event.player_id
    local box_id = event.box_id or "story_box"
    
    TextDisplay:advanceTextBox(player_id, box_id)
    print("Advanced text box for player " .. player_id)
end)

Net:on("remove_text_box", function(event)
    local player_id = event.player_id
    local box_id = event.box_id or "story_box"
    
    TextDisplay:removeTextBox(player_id, box_id)
    print("Removed text box for player " .. player_id)
end)

Net:on("check_text_box", function(event)
    local player_id = event.player_id
    local box_id = event.box_id or "story_box"
    
    local completed = TextDisplay:isTextBoxCompleted(player_id, box_id)
    print("Text box completed: " .. tostring(completed))
end)

-- Example: Create a multi-page story text box
Net:on("create_story", function(event)
    local player_id = event.player_id
    local story_text = "In the year 210X, the digital world has become intertwined with our reality. " ..
                      "As a net operator, you have been chosen to participate in the annual tournament. " ..
                      "Your mission is to survive against waves of digital creatures and other operators. " ..
                      "Use your abilities wisely and remember: timing is everything. " ..
                      "The fate of the digital world rests in your hands. Good luck!"
    
    TextDisplay:createTextBox(player_id, "story_teller", story_text, 10, 20, 220, 70, "THICK", 1.0, 100, {
        x = 5, y = 15, width = 230, height = 80,
        padding_x = 10,
        padding_y = 8
    }, 20)
end)

-- Example: Create a quick notification text box
Net:on("create_notification", function(event)
    local player_id = event.player_id
    local notification = "Alert! New enemy detected in sector 7. Proceed with caution. Use defensive abilities and watch for attack patterns."
    
    TextDisplay:createTextBox(player_id, "notification", notification, 40, 110, 160, 40, "THICK", 0.9, 100, {
        x = 35, y = 105, width = 170, height = 50,
        padding_x = 6,
        padding_y = 4
    }, 35) -- Faster speed for notifications
end)

-- Debug command to check timer states
Net:on("debug_timers", function(event)
    local player_id = event.player_id
    print("=== TIMER DEBUG INFO ===")
    print("Global timer:")
    print("  session_timer: " .. global_timers.session_timer .. " (running: " .. tostring(global_timers.session_running) .. ")")
    
    if player_timers[player_id] then
        print("Player " .. player_id .. " timers:")
        print("  countdown: " .. player_timers[player_id].countdown .. " (running: " .. tostring(player_timers[player_id].countdown_running) .. ")")
        print("  elapsed_time: " .. (player_timers[player_id].elapsed_time or 0))
        print("  started: " .. tostring(player_timers[player_id].started))
    else
        print("Player " .. player_id .. " not found in player_timers")
    end
    print("Players waiting for start: " .. table_count(players_waiting_for_start))
    print("========================")
end)

-- Helper function to count table elements
function table_count(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

print("Combined timer, text display, and text box system loaded successfully!")