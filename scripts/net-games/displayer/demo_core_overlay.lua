-- scripts/net-games/displayer/demo_core_overlay.lua
-- Recreates the 9 "core" on-screen displays from the old example main.lua
-- using the NEW net-games Displayer tech at scripts/net-games/displayer/.

local Displayer = require("scripts/net-games/displayer/displayer")

-- Initialize once
Displayer:init()
if not Displayer:isValid() then
  print("[demo_core_overlay] ERROR: Displayer failed to init/isValid.")
  return
end

print("[demo_core_overlay] Loaded (9-core overlay).")

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local player_data = {}
local global_timer_value = 0
local global_timer_created = false

-- Tunables
local SPRITE_LIST_COUNTDOWN_SECONDS = 3.0
local MISSION_COUNTDOWN_START = 60.0
local FULLSCREEN_DELAY_AFTER_COUNTDOWN = 8.0

-- ---------------------------------------------------------------------------
-- Layout (derived positions: edit these 3 knobs, everything else follows)
-- ---------------------------------------------------------------------------

local HUD_X = 10
local HUD_Y = 10
local HUD_LINE = 18 -- vertical rhythm; increase if any overlap

-- Positions derived from the HUD column
local POS_GLOBAL_TIMER_X, POS_GLOBAL_TIMER_Y = HUD_X, HUD_Y

-- PLAY TIME (label above value)
local POS_LABEL_PLAY_X, POS_LABEL_PLAY_Y = HUD_X + 2, POS_GLOBAL_TIMER_Y + HUD_LINE
local POS_PLAYER_TIMER_X, POS_PLAYER_TIMER_Y = HUD_X, POS_LABEL_PLAY_Y + HUD_LINE

-- MISSION TIMER (label above value)
local POS_LABEL_MISSION_X, POS_LABEL_MISSION_Y = HUD_X + 2, POS_PLAYER_TIMER_Y + HUD_LINE
local POS_MISSION_TIMER_X, POS_MISSION_TIMER_Y = HUD_X, POS_LABEL_MISSION_Y + HUD_LINE

-- Sprite list countdown: separated slightly from timers
local POS_SPRITE_COUNTDOWN_X, POS_SPRITE_COUNTDOWN_Y = HUD_X + 2, POS_MISSION_TIMER_Y + math.floor(HUD_LINE * 1.5)

-- Debug text: below countdown
local POS_DEBUG_X, POS_DEBUG_Y = HUD_X, POS_SPRITE_COUNTDOWN_Y + math.floor(HUD_LINE * 1.5)

-- Mission complete box (kept as-is; separate layout region)
local POS_COMPLETE_X, POS_COMPLETE_Y = 150, 120
local COMPLETE_W, COMPLETE_H = 80, 40

-- Fullscreen (same as old example)
local FULL_W, FULL_H = 480, 320

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function ids_for_player(player_id)
  -- Keep IDs stable + unique per player to avoid cross-player collisions.
  return {
    marquee_id = "demo_news_ticker_" .. player_id,

    label_play_id = "demo_label_play_" .. player_id,
    label_mission_id = "demo_label_mission_" .. player_id,
    debug_id = "demo_debug_" .. player_id,

    player_timer_id = "demo_player_timer",          -- display id (can be shared name; system scopes by player)
    mission_countdown_id = "demo_mission_countdown",-- display id (can be shared name; system scopes by player)

    sprite_countdown_text_id = "demo_sprite_list_countdown_" .. player_id,

    complete_box_id = "demo_countdown_complete_" .. player_id,

    fullscreen_list_id = "demo_fullscreen_display_" .. player_id,
  }
end

-- local function create_core_displays(player_id)
--   local ids = ids_for_player(player_id)
-- 
--   -- 1) Hide default HUD
--   Displayer:hidePlayerHUD(player_id)
-- 
--   -- 2) Global timer display (top-left)
--   if not global_timer_created then
--     Displayer.TimerDisplay.createGlobalTimerDisplay("global_timer", POS_GLOBAL_TIMER_X, POS_GLOBAL_TIMER_Y, "default")
--     global_timer_created = true
--   end
--   Displayer.TimerDisplay.updateGlobalTimerDisplay("global_timer", global_timer_value)
-- 
--   -- 3) Marquee/news ticker (top-ish)
--   Displayer.Text.drawMarqueeText(
--     player_id,
--     ids.marquee_id,
--     "Welcome! Sprite list will appear in 3 seconds!",
--     30,
--     "THICK",
--     1.0,
--     100,
--     "slow",
--     {
--       x = 10, y = 25, width = 220, height = 15,
--       padding_x = 8, padding_y = 2
--     }
--   )
-- 
--   -- 4) Player timer display
--   Displayer.TimerDisplay.createPlayerTimerDisplay(player_id, ids.player_timer_id, POS_PLAYER_TIMER_X, POS_PLAYER_TIMER_Y, "default")
--   Displayer.TimerDisplay.updatePlayerTimerDisplay(player_id, ids.player_timer_id, 0)
-- 
--   -- 5) Mission countdown display
--   Displayer.TimerDisplay.createPlayerCountdownDisplay(player_id, ids.mission_countdown_id, POS_MISSION_TIMER_X, POS_MISSION_TIMER_Y, "default")
--   Displayer.TimerDisplay.updatePlayerCountdownDisplay(player_id, ids.mission_countdown_id, MISSION_COUNTDOWN_START)
-- 
--   -- 6) Labels for timers
--   Displayer.Text.drawText(player_id, ids.label_play_id, "PLAY TIME", POS_LABEL_PLAY_X, POS_LABEL_PLAY_Y, 100, "THICK", 0.7)
--   Displayer.Text.drawText(player_id, ids.label_mission_id, "MISSION TIMER", POS_LABEL_MISSION_X, POS_LABEL_MISSION_Y, 100, "THICK", 0.7)
-- 
--   -- 7) "Sprite list in: 3" countdown text (temporary)
--   Displayer.Text.drawText(
--     player_id,
--     ids.sprite_countdown_text_id,
--     "Sprite list in: 3",
--     POS_SPRITE_COUNTDOWN_X,
--     POS_SPRITE_COUNTDOWN_Y,
--     100,
--     "THICK",
--     0.7
--   )
-- 
--   -- 8) Debug text
--   Displayer.Text.drawText(player_id, ids.debug_id, "DEBUG: Display working", POS_DEBUG_X, POS_DEBUG_Y, 100, "THICK", 0.7)
-- 
--   -- player state
--   player_data[player_id] = {
--     ids = ids,
-- 
--     session_started = true,
-- 
--     player_timer_value = 0,
--     mission_countdown_value = MISSION_COUNTDOWN_START,
--     mission_countdown_running = true,
--     mission_complete_box_shown = false,
-- 
--     sprite_list_countdown_elapsed = 0,
--     sprite_list_countdown_done = false,
-- 
--     fullscreen_elapsed = 0,
--     fullscreen_created = false,
--     fullscreen_armed = false, -- becomes true once sprite-list countdown finishes
--   }
-- end

local function remove_core_displays(player_id)
  local data = player_data[player_id]
  if not data then return end

  local ids = data.ids

  -- remove marquee + texts + textbox + scrolling list
  pcall(function() Displayer.Text.removeText(player_id, ids.label_play_id) end)
  pcall(function() Displayer.Text.removeText(player_id, ids.label_mission_id) end)
  pcall(function() Displayer.Text.removeText(player_id, ids.debug_id) end)
  pcall(function() Displayer.Text.removeText(player_id, ids.sprite_countdown_text_id) end)

  -- marquee removal: TextDisplaySystem typically treats marquee as text_id; removeText should work.
  pcall(function() Displayer.Text.removeText(player_id, ids.marquee_id) end)

  pcall(function() Displayer.ScrollingText.removeList(player_id, ids.fullscreen_list_id) end)

  -- text box removal depends on TextDisplaySystem implementation; safest is reset/overwrite.
  -- If your TextDisplaySystem supports removeTextBox, you can add it here.
  -- For now: attempt to reset it to empty (no-op if not present).
  pcall(function()
    Displayer.Text.resetTextBox(player_id, ids.complete_box_id, "", POS_COMPLETE_X, POS_COMPLETE_Y, COMPLETE_W, COMPLETE_H, "THICK", 0.9, 100, nil, 30)
  end)

  player_data[player_id] = nil
end

local function create_fullscreen_scroll(player_id, ids)
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
    "Dimensions: 240x160 (logical)",
    "Position: 0,0",
    "Enjoy the enhanced visibility!",
    "======================"
  }

  local ok = Displayer.ScrollingText.createList(player_id, ids.fullscreen_list_id, 0, 0, FULL_W, FULL_H, {
    texts = fullscreen_messages,
    scroll_speed = 40,
    entry_delay = 2.0,
    font = "THICK",
    scale = 2.0,
    z_order = 50,
    loop = true,
    backdrop = {
      x = 0, y = 0, width = FULL_W, height = FULL_H,
      padding_x = 0, padding_y = 0
    },
    destroy_when_finished = false
  })

  if not ok then
    -- If fullscreen fails, at least show an error text where you'd notice it.
    Displayer.Text.drawText(player_id, "demo_fullscreen_failed_" .. player_id, "ERROR: Fullscreen failed", 10, 120, 100, "THICK", 0.7)
  end

  return ok
end

-- ---------------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------------

Net:on("player_join", function(event)
  local player_id = event.player_id
  print("[demo_core_overlay] player_join " .. player_id)

  -- Guard: if this overlay is loaded twice (or join fires twice), don't double-draw UI.
  if player_data[player_id] then
    return
  end

  -- create_core_displays(player_id)
end)


Net:on("player_leave", function(event)
  local player_id = event.player_id
  print("[demo_core_overlay] player_leave " .. player_id)

  -- remove_core_displays(player_id)
end)

Net:on("tick", function(event)
  local dt = event.delta_time or 0

  -- Global timer increments
  global_timer_value = global_timer_value + dt
  Displayer.TimerDisplay.updateGlobalTimerDisplay("global_timer", global_timer_value)

  for player_id, data in pairs(player_data) do
    local ids = data.ids

    -- 7) "Sprite list in: N" countdown text (3 seconds)
    if not data.sprite_list_countdown_done then
      data.sprite_list_countdown_elapsed = data.sprite_list_countdown_elapsed + dt
      local remaining = math.max(0, SPRITE_LIST_COUNTDOWN_SECONDS - data.sprite_list_countdown_elapsed)
      local shown = math.ceil(remaining)

      -- Update countdown text
      Displayer.Text.updateText(player_id, ids.sprite_countdown_text_id, "Sprite list in: " .. tostring(shown))

      if data.sprite_list_countdown_elapsed >= SPRITE_LIST_COUNTDOWN_SECONDS then
        data.sprite_list_countdown_done = true
        data.fullscreen_armed = true

        -- Remove countdown text (like old example)
        Displayer.Text.removeText(player_id, ids.sprite_countdown_text_id)
      end
    end

    -- 4) Player timer increments
    data.player_timer_value = data.player_timer_value + dt
    Displayer.TimerDisplay.updatePlayerTimerDisplay(player_id, ids.player_timer_id, data.player_timer_value)

    -- 5) Mission countdown decrements
    if data.mission_countdown_running then
      data.mission_countdown_value = math.max(0, data.mission_countdown_value - dt)
      Displayer.TimerDisplay.updatePlayerCountdownDisplay(player_id, ids.mission_countdown_id, data.mission_countdown_value)

      -- 8) + 9) Mission completion textbox when it hits 0
      if (data.mission_countdown_value <= 0) and (not data.mission_complete_box_shown) then
        data.mission_countdown_running = false
        data.mission_complete_box_shown = true

        Displayer.Text.createTextBox(
          player_id,
          ids.complete_box_id,
          "Time's up! Mission complete!",
          POS_COMPLETE_X, POS_COMPLETE_Y,
          COMPLETE_W, COMPLETE_H,
          "THICK",
          0.9,
          100,
          {
            x = 145, y = 115, width = 90, height = 50,
            padding_x = 4, padding_y = 4
          },
          35
        )
      end
    end

    -- 9) Fullscreen scrolling text list (after countdown finishes + 8 seconds)
    if data.fullscreen_armed and (not data.fullscreen_created) then
      data.fullscreen_elapsed = data.fullscreen_elapsed + dt
      if data.fullscreen_elapsed >= FULLSCREEN_DELAY_AFTER_COUNTDOWN then
        data.fullscreen_created = true
        create_fullscreen_scroll(player_id, ids)
      end
    end
  end
end)

-- Optional: simple command to re-run the overlay for your player without reconnecting.
Net:on("demo_core_overlay_reset", function(event)
  local player_id = event.player_id
  remove_core_displays(player_id)
  create_core_displays(player_id)
end)
