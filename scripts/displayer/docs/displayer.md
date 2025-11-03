Timer and Text Display System Documentation
A comprehensive system for displaying timers, countdowns, and scrolling text marquees in a multiplayer game environment.

Table of Contents
System Overview

Font System

Text Display System

Timer Display System

Timer System

Main Integration

API Reference

System Overview
This system provides four main components:

Font System: Renders text using custom bitmap fonts

Text Display System: Manages static and scrolling text with backdrops

Timer Display System: Visual display of timers and countdowns

Timer System: Backend logic for timer management

Font System (font-system.lua)
Handles font rendering with multiple font styles and character spacing.

Features
Three font styles: THICK, GRADIENT, BATTLE

Monospaced character rendering

Automatic asset provisioning

Player-specific font management

Available Fonts
Font Name	Character Width	Use Case
THICK	6px	Default timers, general text
GRADIENT	7px	Styled text, emphasis
BATTLE	8px	Large displays, headers
Supported Characters
Numbers: 0-9

Symbols: :, ., -

Space character

Example Usage
lua
local FontSystem = require("scripts/displayer/font-system")

-- Draw static text
local textId = FontSystem:drawText(player_id, "12:34", 100, 50, "THICK", 1.0, 100)

-- Get text width for positioning
local width = FontSystem:getTextWidth("Hello", "BATTLE", 1.5)

-- Remove text when done
FontSystem:eraseTextDisplay(player_id, textId)
Text Display System (text-display.lua)
Advanced text rendering with marquee scrolling and backdrop support.

Features
Static text positioning

Scrolling marquee text with configurable speeds

Backdrop boxes with padding

Individual character wrapping with gaps

Real-time text updates

Marquee Speed Options
slow: 30 pixels/second

medium: 60 pixels/second (default)

quick: 120 pixels/second

Example Usage
lua
local TextDisplay = require("scripts/displayer/text-display")

-- Static text with backdrop
local staticId = TextDisplay:drawText(player_id, "SCORE: 100", 10, 10, "THICK", 1.0, 100)
TextDisplay:addBackdrop(player_id, staticId, {
    x = 5, y = 5, width = 80, height = 15,
    padding_x = 4, padding_y = 2
})

-- Scrolling marquee
local marqueeId = TextDisplay:drawMarqueeText(player_id, "news", 
    "Breaking news: Player joined the game!", 
    30, "THICK", 1.0, 100, "medium", {
        x = 10, y = 25, width = 220, height = 15,
        padding_x = 8, padding_y = 2
    })

-- Update text content
TextDisplay:updateText(player_id, marqueeId, "New message here!")

-- Change marquee speed
TextDisplay:setMarqueeSpeed(player_id, marqueeId, "quick")
Timer Display System (timer-display.lua)
Visual display system for timers and countdowns using the font system.

Features
Player-specific and global timer displays

Multiple display configurations

Real-time updates

Automatic formatting (HH:MM:SS for timers, MM:SS for countdowns)

Display Configurations
Config	Font	Scale	Use Case
default	THICK	1.0	Standard timers
large	BATTLE	1.5	Important displays
gradient	GRADIENT	1.2	Styled timers
small	THICK	0.8	Secondary information
Example Usage
lua
local TimerDisplay = require("scripts/displayer/timer-display")

-- Player-specific timer (counts up)
TimerDisplay:createPlayerTimerDisplay(player_id, "playtime", 120, 80, "default")
TimerDisplay:updatePlayerTimerDisplay(player_id, "playtime", 125.5) -- 2 minutes, 5.5 seconds

-- Player countdown (counts down)
TimerDisplay:createPlayerCountdownDisplay(player_id, "cooldown", 120, 100, "default")
TimerDisplay:updatePlayerCountdownDisplay(player_id, "cooldown", 45) -- 45 seconds remaining

-- Global timer (visible to all players)
TimerDisplay:createGlobalTimerDisplay("session_timer", 10, 10, "large")
TimerDisplay:updateGlobalTimerDisplay("session_timer", 3600) -- 1 hour

-- Remove displays when done
TimerDisplay:removePlayerDisplay(player_id, "playtime")
TimerDisplay:removeGlobalDisplay("session_timer")
Timer System (timer-system.lua)
Backend logic for managing timer states and callbacks.

Features
Global and player-specific timers

Loopable timers

Pause/resume functionality

Callback support on completion

Automatic synchronization with new players

Example Usage
lua
local TimerSystem = require("scripts/displayer/timer-system")

-- Global countdown with callback
TimerSystem:createGlobalCountdown("game_start", 10, function(player_id, timer_id, time)
    print("Game starting!")
    -- Start the game logic here
end, false)

-- Player-specific timer
TimerSystem:createPlayerTimer(player_id, "ability_cooldown", 30, function(p_id, t_id, elapsed)
    print("Ability ready for player " .. p_id)
end, true) -- loops = true

-- Control timers
TimerSystem:pauseGlobalCountdown("game_start")
TimerSystem:resumeGlobalCountdown("game_start")
TimerSystem:removeGlobalCountdown("game_start")
Main Integration (main.lua)
Example implementation showing how to integrate all systems.

Key Features Demonstrated
Player join/disconnect handling

Coordinated timer starts

Fixed positioning relative to player

Multiple display types

Example Event Handlers
lua
-- Custom commands for testing
Net:on("add_marquee", function(event)
    TextDisplay:drawMarqueeText(event.player_id, "custom", 
        event.text or "Default text", 90, "THICK", 1.0, 100, "medium")
end)

Net:on("reset_countdown", function(event)
    -- Reset player countdown to 60 seconds
    player_timers[event.player_id].countdown = 60
    TimerDisplay:updatePlayerCountdownDisplay(event.player_id, "player_countdown", 60)
end)
API Reference
Font System API
FontSystem:drawText(player_id, text, x, y, font_name, scale, z_order)
Draws static text at specified coordinates.

Parameters:

player_id: Target player

text: String to display

x, y: Screen coordinates

font_name: "THICK", "GRADIENT", or "BATTLE"

scale: Size multiplier (default: 1.0)

z_order: Render order (default: 100)

Returns: Display ID for later reference

FontSystem:getTextWidth(text, font_name, scale)
Calculates pixel width of text.

FontSystem:eraseTextDisplay(player_id, display_id)
Removes previously drawn text.

Text Display System API
TextDisplay:drawText(player_id, text, x, y, font_name, scale, z_order)
Draws static text with system management.

TextDisplay:drawMarqueeText(player_id, marquee_id, text, y, font_name, scale, z_order, speed, backdrop)
Creates scrolling marquee text.

Parameters:

marquee_id: Unique identifier for this marquee

speed: "slow", "medium", or "quick"

backdrop: Optional backdrop configuration table

TextDisplay:addBackdrop(player_id, text_id, backdrop_config)
Adds backdrop to existing text.

Backdrop Config:

lua
{
    x = 10, y = 10,        -- Position
    width = 100,           -- Width in pixels
    height = 20,           -- Height in pixels
    padding_x = 4,         -- Horizontal padding
    padding_y = 2          -- Vertical padding
}
TextDisplay:updateText(player_id, text_id, new_text)
Updates text content in real-time.

TextDisplay:setMarqueeSpeed(player_id, text_id, speed)
Changes marquee scroll speed.

Timer Display System API
TimerDisplay:createPlayerTimerDisplay(player_id, timer_id, x, y, config_name)
Creates a player-specific timer display.

TimerDisplay:createPlayerCountdownDisplay(player_id, countdown_id, x, y, config_name)
Creates a player-specific countdown display.

TimerDisplay:createGlobalTimerDisplay(timer_id, x, y, config_name)
Creates a global timer visible to all players.

Update Methods
updatePlayerTimerDisplay(player_id, timer_id, value)

updatePlayerCountdownDisplay(player_id, countdown_id, value)

updateGlobalTimerDisplay(timer_id, value)

updateGlobalCountdownDisplay(countdown_id, value)

Timer System API
TimerSystem:createGlobalTimer(timer_id, duration, callback, loop)
Creates a global timer.

TimerSystem:createGlobalCountdown(countdown_id, duration, callback, loop)
Creates a global countdown.

Control Methods
pauseGlobalTimer(timer_id) / resumeGlobalTimer(timer_id)

pauseGlobalCountdown(countdown_id) / resumeGlobalCountdown(countdown_id)

removeGlobalTimer(timer_id) / removeGlobalCountdown(countdown_id)

Best Practices
Naming Conventions: Use descriptive IDs for timers and text displays

Memory Management: Always remove displays when no longer needed

Positioning: Use getTextWidth() for dynamic positioning

Z-Order: Higher numbers render on top (100 = default UI layer)

Error Handling: Check for nil returns when players disconnect

Common Use Cases
Game Session Timer
lua
-- Create when game starts
TimerDisplay:createGlobalTimerDisplay("session", 10, 10, "large")

-- Update every tick
TimerDisplay:updateGlobalTimerDisplay("session", elapsed_time)
Player Ability Cooldown
lua
-- When ability is used
TimerDisplay:createPlayerCountdownDisplay(player_id, "ability_cd", x, y, "default")
TimerDisplay:updatePlayerCountdownDisplay(player_id, "ability_cd", cooldown_time)

-- Remove when complete
TimerDisplay:removePlayerDisplay(player_id, "ability_cd")
News Ticker
lua
TextDisplay:drawMarqueeText(player_id, "news", 
    "Welcome to the server! Events starting soon.", 
    30, "THICK", 1.0, 100, "slow", {
        x = 10, y = 25, width = 220, height = 15
    })
This system provides a robust foundation for in-game UI elements with flexible positioning, styling, and real-time updates suitable for multiplayer games.