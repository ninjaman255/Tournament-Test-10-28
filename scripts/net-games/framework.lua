--[[
* ---------------------------------------------------------- *
           Net Games (framework) - Combined Edition
           (net-games + tournament compatibility)
* ---------------------------------------------------------- *

Goals:
- Preserve the existing net-games API used by your scripts.
- Provide the lifecycle functions expected by tournament scripts.
- Keep Displayer optional (do not hard-crash if Displayer is missing).
- Fix known bugs/landmines from the tourney framework code path.
- Avoid Net sprite "rebind" issues by default (no reuse-by-texture unless enabled).

]]--

-- ============================================================
-- Optional Displayer init (tournament uses Displayer heavily, but don't hard crash)
-- ============================================================
local Displayer_ok, Displayer = pcall(require, "scripts/net-games/displayer/displayer")
local DISPLAYER_READY = false

if Displayer_ok and Displayer and Displayer.init and Displayer.isValid then
  local ok = false
  pcall(function()
    ok = (Displayer:init() == true) and (Displayer:isValid() == true)
  end)
  DISPLAYER_READY = ok
end

if not DISPLAYER_READY then
  print("[net-games][framework] Displayer not available/valid; text/timers will be no-ops.")
end

-- ============================================================
-- Framework state / caches
-- ============================================================
local frame = {}

local last_position_cache = {} -- tracks player's last known area
local button_states = {}       -- latest button states
local tracking_state = {}      -- hold-to-repeat tracker for state=2 buttons
local cosmetic_cache = {}      -- cosmetics per player
local cursor_cache = {}        -- cursor config per player
local avatar_cache = {}        -- reserved (used by some forks)
local ui_cache = {}            -- ui elements per player
local map_elements = {}        -- map elements per player
local ui_update = {}           -- reserved for future sliding UI
local online_players = {}      -- list of online players (for exclusions)

-- Default: do NOT reuse sprite allocations by texture.
-- Net.player_draw_sprite can be "sticky" across sprite_id reuse in some forks.
-- If you really want old behavior, set to true.
local REUSE_SPRITES_BY_TEXTURE = false

-- ============================================================
-- Async helpers
-- ============================================================
local function async(p)
  local co = coroutine.create(p)
  return Async.promisify(co)
end

local function await(v) return Async.await(v) end

-- ============================================================
-- Math helpers (UI offset jitter fixes)
-- ============================================================
local function round_fraction(value, denominator)
  local int_part = math.floor(value)
  local decimal = value - int_part
  local n = math.floor(decimal * denominator + 0.5)
  return int_part, n / denominator
end

local function convertOffsets(horizontalOffset, verticalOffset, Z)
  local xoffset = ((2 * -verticalOffset + horizontalOffset) / 64) + (Z / 2)
  local yoffset = ((2 * -verticalOffset - horizontalOffset) / 64) + (Z / 2)
  return xoffset, yoffset
end

local function fixOffsets(a, b)
  local a_int, a_dec = round_fraction(a, 32)
  local b_int, b_dec = round_fraction(b, 32)

  local diff = math.abs(a_dec - b_dec)
  if diff < 1 then
    local diff_adj = math.floor(diff * 16 + 0.5) / 16
    if a_dec >= b_dec then
      b_dec = a_dec - diff_adj
    else
      b_dec = a_dec + diff_adj
    end
    if b_dec < 0 then b_dec = 0 end
    if b_dec >= 1 then b_dec = 1 - (1 / 32) end
  end

  return a_int + a_dec, b_int + b_dec
end

local function table_has_value(tab, val)
  for _, value in ipairs(tab) do
    if value == val then return true end
  end
  return false
end

local function exclude_except_for(player_id, bot_id)
  for _, p_id in next, online_players do
    if p_id ~= player_id then
      Net.exclude_actor_for_player(p_id, bot_id)
    end
  end
end

-- ============================================================
-- Asset provision (fonts etc.)
-- ============================================================
local function provide_framework_assets(player_id)
  -- Some assets won't load reliably unless provided on join.
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_compressed.png") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_dark_compressed.png") end)

  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_wide.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_gradient.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_thick.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_battle.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_thin.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_tiny.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts_compressed.animation") end)
end

-- ============================================================
-- Cross-fork movement/animation helpers (used by Simon Says / tournament fades)
-- ============================================================
local function try_move_player(player_id, area_id, x, y, z)
  local ok = pcall(function()
    if Net.transfer_player then Net.transfer_player(player_id, area_id, x, y, z) end
  end)
  if ok and Net.transfer_player then return true end

  ok = pcall(function()
    if Net.transfer_player then Net.transfer_player(player_id, area_id, false, x, y, z) end
  end)
  if ok and Net.transfer_player then return true end

  ok = pcall(function()
    if Net.move_player then Net.move_player(player_id, x, y, z) end
  end)
  if ok and Net.move_player then return true end

  ok = pcall(function()
    if Net.set_player_position then Net.set_player_position(player_id, x, y, z) end
  end)
  if ok and Net.set_player_position then return true end

  return false
end

local function try_animate_player(player_id, anim_state)
  local ok = pcall(function()
    if Net.animate_player_properties then
      local keyframes = {
        { properties = { { property = "Animation", value = anim_state } }, duration = 0 }
      }
      Net.animate_player_properties(player_id, keyframes)
    end
  end)
  if ok and Net.animate_player_properties then return true end

  ok = pcall(function()
    if Net.set_player_animation then Net.set_player_animation(player_id, anim_state) end
  end)
  if ok and Net.set_player_animation then return true end

  return false
end

function frame.move_frozen_player(player_id, x, y, z)
  return async(function()
    local area_id = Net.get_player_area(player_id)
    try_move_player(player_id, area_id, x, y, z)
    await(Async.sleep(0))
  end)
end

function frame.animate_frozen_player(player_id, anim_state)
  return async(function()
    try_animate_player(player_id, anim_state)
    await(Async.sleep(0))
  end)
end

-- ============================================================
-- Cosmetics
-- ============================================================
function frame.set_cosmetic(cosmetic_id, player_id, texture, animation, state, x, y, visible, player_xoffset, player_yoffset)
  return async(function()
    if cosmetic_id == nil or player_id == nil or texture == nil or animation == nil or state == nil or x == nil or y == nil then
      print("[net-games][framework] set_cosmetic(): missing required arguments")
      return false
    end

    local visibility = (visible ~= false)

    cosmetic_cache[player_id] = cosmetic_cache[player_id] or {}
    if cosmetic_cache[player_id][cosmetic_id] then
      print("[net-games][framework] set_cosmetic(): player already has cosmetic '" .. cosmetic_id .. "'")
      return false
    end

    local p_xoffset = player_xoffset or 0
    local p_yoffset = player_yoffset or 0

    pcall(function() Net.provide_asset_for_player(player_id, texture) end)
    pcall(function() Net.provide_asset_for_player(player_id, animation) end)

    Net.player_alloc_sprite(player_id, cosmetic_id, { texture_path = texture, anim_path = animation, anim_state = state })
    Net.player_draw_sprite(player_id, cosmetic_id, {
      id = cosmetic_id .. "_obj",
      x = (x + 120 + p_xoffset) * 2,
      y = (y + 80 + p_yoffset) * 2,
      sx = 2,
      sy = 2,
      anim_state = state
    })

    last_position_cache[player_id] = last_position_cache[player_id] or {}
    local area_id = last_position_cache[player_id].area or Net.get_player_area(player_id)

    local position = Net.get_player_position(player_id)
    local xoffset, yoffset = convertOffsets(x * -1, y * -1, position.z + 3)
    xoffset, yoffset = fixOffsets(xoffset, yoffset)

    cosmetic_cache[player_id][cosmetic_id] = {
      id = cosmetic_id,
      texture = texture,
      x = xoffset,
      y = yoffset,
      visibility = visibility,
      animation = animation,
      state = state,
      spritex = (x + 120 + p_xoffset) * 2,
      spritey = (y + 80 + p_yoffset) * 2
    }

    local bot_id = cosmetic_id .. "_" .. player_id
    Net.create_bot(bot_id, {
      area_id = area_id,
      warp_in = false,
      texture_path = texture,
      animation_path = animation,
      animation = state,
      x = position.x + xoffset,
      y = position.y + yoffset,
      z = position.z + 3,
      solid = false
    })

    -- Hide bot from owning player (they see the cosmetic via player sprite)
    Net.exclude_actor_for_player(player_id, bot_id)

    -- If visibility=false, hide from everyone else too
    if not visibility then
      exclude_except_for(player_id, bot_id)
    end

    return true
  end)
end

function frame.remove_cosmetic(cosmetic_id, player_id)
  if not cosmetic_cache[player_id] or not cosmetic_cache[player_id][cosmetic_id] then
    print("[net-games][framework] remove_cosmetic(): cosmetic not found '" .. tostring(cosmetic_id) .. "'")
    return false
  end

  local bot_id = cosmetic_id .. "_" .. player_id
  if Net.is_bot(bot_id) then
    Net.remove_bot(bot_id, false)
  end

  Net.player_erase_sprite(player_id, cosmetic_id .. "_obj")
  cosmetic_cache[player_id][cosmetic_id] = nil
  return true
end

-- ============================================================
-- Map elements (bots)
-- ============================================================
function frame.add_map_element(name, player_id, texture, animation, animation_state, X, Y, Z, exclude)
  local area_id = (last_position_cache[player_id] and last_position_cache[player_id].area) or Net.get_player_area(player_id)

  local bot_id = player_id .. "-map-" .. name
  Net.create_bot(bot_id, {
    area_id = area_id,
    warp_in = false,
    texture_path = texture,
    animation_path = animation,
    animation = animation_state,
    x = X, y = Y, z = Z,
    solid = false
  })

  if exclude == true then
    exclude_except_for(player_id, bot_id)
  end

  Net.animate_bot(bot_id, animation_state, true)

  map_elements[player_id] = map_elements[player_id] or {}
  map_elements[player_id][name] = {
    name = name,
    state = animation_state,
    id = player_id .. "-map-" .. name
  }

  return true
end

function frame.change_map_element(name, player_id, animation_state, loop)
  local bot_id = player_id .. "-map-" .. name
  if Net.is_bot(bot_id) then
    Net.animate_bot(bot_id, animation_state, loop == true)
    return true
  end
  print("[net-games][framework] change_map_element(): not found " .. tostring(name))
  return false
end

function frame.move_map_element(name, player_id, X, Y, Z)
  local bot_id = player_id .. "-map-" .. name
  local area_id = (last_position_cache[player_id] and last_position_cache[player_id].area) or Net.get_player_area(player_id)
  if Net.is_bot(bot_id) then
    pcall(function()
      if Net.transfer_bot then
        Net.transfer_bot(bot_id, area_id, false, X, Y, Z)
      else
        Net.move_bot(bot_id, X, Y, Z)
      end
    end)
    return true
  end
  return false
end

function frame.remove_map_element(name, player_id)
  local bot_id = player_id .. "-map-" .. name
  if Net.is_bot(bot_id) then
    if map_elements[player_id] then map_elements[player_id][name] = nil end
    Net.remove_bot(bot_id, false)
    return true
  end
  return false
end

-- ============================================================
-- UI elements (screen-space sprites)
-- ============================================================
function frame.add_ui_element(sprite_id, player_id, texture_path, animation_path, animation_state, X, Y, Z, ScaleX, ScaleY)
  local scaleX = (ScaleX ~= nil and ScaleX >= 0.0) and ScaleX or 2.0
  local scaleY = (ScaleY ~= nil and ScaleY >= 0.0) and ScaleY or 2.0
  animation_path = animation_path or ""
  animation_state = animation_state or ""

  ui_cache[player_id] = ui_cache[player_id] or {}

  -- Allocation ids must be unique per texture/anim, otherwise Net ignores re-allocs
  -- and you'll get stale visuals (exactly your tourney bracket issue).
  local alloc_id = tostring(sprite_id) .. "|" .. tostring(texture_path) .. "|" .. tostring(animation_path or "")


  -- Always provide assets (safe) before alloc
  if animation_path ~= "" then pcall(function() Net.provide_asset_for_player(player_id, animation_path) end) end
  pcall(function() Net.provide_asset_for_player(player_id, texture_path) end)

  -- Allocate sprite (safe even if alloc_id matches prior; Net tends to ignore duplicates)
  Net.player_alloc_sprite(player_id, alloc_id, { texture_path = texture_path, anim_path = animation_path, anim_state = animation_state })

  -- Draw under the requested draw id (separate from alloc_id)
  Net.player_draw_sprite(player_id, alloc_id, {
    id = sprite_id .. "_obj",
    x = X * 2,
    y = Y * 2,
    z = Z,
    sx = scaleX,
    sy = scaleY,
    anim_state = animation_state
  })

  ui_cache[player_id][sprite_id] = {
    texture_path = texture_path,
    alloc_id = alloc_id,
    sprite_id = sprite_id,
    x = X, y = Y, z = Z,
    scaleX = scaleX, scaleY = scaleY,
    rotation = 0,
    animation_state = animation_state,
    opacity = 255
  }

  return true
end

function frame.update_ui_element(sprite_id, player_id, properties)
  if not (ui_cache[player_id] and ui_cache[player_id][sprite_id]) then return false end
  local element = ui_cache[player_id][sprite_id]

  local draw = { id = sprite_id .. "_obj" }

  if properties.x then draw.x = properties.x; element.x = properties.x end
  if properties.y then draw.y = properties.y; element.y = properties.y end
  if properties.z then draw.z = properties.z; element.z = properties.z end
  if properties.ox then draw.ox = properties.ox; element.ox = properties.ox end
  if properties.oy then draw.oy = properties.oy; element.oy = properties.oy end

  if properties.scale then
    draw.sx = properties.scale
    draw.sy = properties.scale
    element.scaleX = properties.scale
    element.scaleY = properties.scale
  end

  if properties.rotation then
    draw.ro = properties.rotation
    element.rotation = properties.rotation
  end

  if properties.opacity then
    draw.opacity = properties.opacity
    element.opacity = properties.opacity
  end

  if properties.animation_state then
    draw.anim_state = properties.animation_state
    element.animation_state = properties.animation_state
  end

  Net.player_draw_sprite(player_id, element.alloc_id, draw)
  return true
end

function frame.set_ui_animation(sprite_id, player_id, animation_state)
  if not (ui_cache[player_id] and ui_cache[player_id][sprite_id]) then return false end
  local element = ui_cache[player_id][sprite_id]
  element.animation_state = animation_state
  Net.player_draw_sprite(player_id, element.alloc_id, { id = sprite_id .. "_obj", anim_state = animation_state })
  return true
end

function frame.move_ui_element(sprite_id, player_id, X, Y, Z)
  if not (ui_cache[player_id] and ui_cache[player_id][sprite_id]) then return false end
  local element = ui_cache[player_id][sprite_id]
  element.x, element.y, element.z = X, Y, Z
  Net.player_draw_sprite(player_id, element.alloc_id, { id = sprite_id .. "_obj", x = X * 2, y = Y * 2, z = Z })
  return true
end

function frame.update_ui_position(sprite_id, player_id, X, Y, Z)
  if not (ui_cache[player_id] and ui_cache[player_id][sprite_id]) then return false end
  local element = ui_cache[player_id][sprite_id]
  element.x = X
  element.y = Y
  element.z = Z or element.z

  Net.player_draw_sprite(player_id, element.alloc_id, {
    id = sprite_id .. "_obj",
    x = X * 2,
    y = Y * 2,
    z = element.z,
    sx = element.scaleX,
    sy = element.scaleY,
    anim_state = element.animation_state
  })
  return true
end

function frame.remove_ui_element(sprite_id, player_id)
  if ui_cache[player_id] then ui_cache[player_id][sprite_id] = nil end
  Net.player_erase_sprite(player_id, sprite_id .. "_obj")
  return true
end

local function clear_all_ui_for_player(player_id)
  if not ui_cache[player_id] then return end

  for sprite_id, element in next, ui_cache[player_id] do
    -- erase draw object
    Net.player_erase_sprite(player_id, sprite_id .. "_obj")
  end

  -- hard reset cache
  ui_cache[player_id] = {}
end


-- ============================================================
-- Text (Displayer-backed, no-op if missing)
-- ============================================================
function frame.draw_text(text_id, player_id, text, x, y, z, font, scale)
  if not DISPLAYER_READY then return false end
  Displayer.Text.drawText(player_id, text_id, text, tonumber(x) * 2, tonumber(y) * 2, z, font, scale)
  return true
end

function frame.update_text(text_id, player_id, text)
  if not DISPLAYER_READY then return false end
  Displayer.Text.updateText(player_id, text_id, tostring(text))
  return true
end

function frame.remove_text(text_id, player_id)
  if not DISPLAYER_READY then return false end
  Displayer.Text.removeText(player_id, text_id)
  return true
end

function frame.draw_marquee_text(marquee_id, player_id, text, y, font, scale, z_order, speed, backdrop)
  if not DISPLAYER_READY then return false end
  Displayer.Text.drawMarqueeText(player_id, marquee_id, text, y, font, scale, z_order, speed, backdrop)
  return true
end

function frame.set_marquee_position(player_id, marquee_id, x, y)
  if not DISPLAYER_READY then return false end
  Displayer.Text.setMarqueePosition(player_id, marquee_id, x, y)
  return true
end

function frame.set_marquee_speed(player_id, marquee_id, speed)
  if not DISPLAYER_READY then return false end
  Displayer.Text.setMarqueeSpeed(player_id, marquee_id, speed)
  return true
end

-- ============================================================
-- Timers / Countdowns (Displayer-backed, emits countdown_ended)
-- ============================================================
function frame.spawn_timer(timer_id, player_id, X, Y, duration, loop)
  if not DISPLAYER_READY then return false end
  loop = loop or false
  Displayer.Timer.createPlayerTimer(player_id, timer_id, duration, function(_, _, _) end, loop)
  Displayer.TimerDisplay.createPlayerTimerDisplay(player_id, timer_id, X * 2, Y * 2, "default")
  return true
end

function frame.resume_timer(timer_id, player_id)
  if not DISPLAYER_READY then return false end
  Displayer.Timer.resumePlayerTimer(player_id, timer_id)
  return true
end

function frame.pause_timer(timer_id, player_id)
  if not DISPLAYER_READY then return false end
  Displayer.Timer.pausePlayerTimer(player_id, timer_id)
  return true
end

function frame.remove_timer(timer_id, player_id)
  if not DISPLAYER_READY then return false end
  Displayer.Timer.removePlayerTimer(player_id, timer_id)
  return true
end

function frame.update_timer(timer_id, player_id, duration)
  if not DISPLAYER_READY then return false end
  Displayer.Timer.updatePlayerTimer(player_id, timer_id, duration)
  return true
end

function frame.spawn_countdown(countdown_id, player_id, X, Y, duration, loop)
  if not DISPLAYER_READY then return false end
  loop = loop or false
  Displayer.Timer.createPlayerCountdown(player_id, countdown_id, duration, function(_, id, value)
    if value <= 0 then
      Net:emit("countdown_ended", { player_id = player_id, countdown_id = id })
    end
  end, loop)
  Displayer.TimerDisplay.createPlayerCountdownDisplay(player_id, countdown_id, X * 2, Y * 2, "default")
  return true
end

function frame.resume_countdown(countdown_id, player_id)
  if not DISPLAYER_READY then return false end
  Displayer.Timer.resumePlayerCountdown(player_id, countdown_id)
  return true
end

function frame.pause_countdown(countdown_id, player_id)
  if not DISPLAYER_READY then return false end
  Displayer.Timer.pausePlayerCountdown(player_id, countdown_id)
  return true
end

function frame.remove_countdown(countdown_id, player_id)
  if not DISPLAYER_READY then return false end
  Displayer.Timer.removePlayerCountdown(player_id, countdown_id)
  return true
end

function frame.update_countdown(countdown_id, player_id, duration)
  if not DISPLAYER_READY then return false end
  Displayer.Timer.updatePlayerCountdown(player_id, countdown_id, duration)
  return true
end

-- ============================================================
-- Cursor system (virtual_input-driven)
-- ============================================================
function frame.spawn_cursor(cursor_id, player_id, options)
  return async(function()
    if not options or type(options) ~= "table" then
      print("[net-games][framework] spawn_cursor(): missing options table")
      return false
    end

    -- only allow one active cursor per player (matches original behavior)
    if cursor_cache[player_id] and next(cursor_cache[player_id]) ~= nil then
      print("[net-games][framework] spawn_cursor(): cursor already active; remove it first")
      return false
    end

    if Net.lock_player_input then
      Net.lock_player_input(player_id)
    end

    cursor_cache[player_id] = options
    cursor_cache[player_id].name = cursor_id

    local selections = cursor_cache[player_id].selections or {}
    local selection = selections[1]
    if not selection then
      print("[net-games][framework] spawn_cursor(): selections[1] missing")
      return false
    end

    local tex = options.texture
    local anim = options.animation or ""
    local state = selection.state or ""

    if anim ~= "" then pcall(function() Net.provide_asset_for_player(player_id, anim) end) end
    if tex then pcall(function() Net.provide_asset_for_player(player_id, tex) end) end

    Net.player_alloc_sprite(player_id, cursor_id, {
      texture_path = tex,
      anim_path = anim,
      anim_state = state
    })

    Net.player_draw_sprite(player_id, cursor_id, {
      id = cursor_id .. "_obj",
      x = selection.x * 2,
      y = selection.y * 2,
      z = selection.z,
      sx = 2,
      sy = 2,
      anim_state = state
    })

    cursor_cache[player_id].sprites = cursor_cache[player_id].sprites or {}
    cursor_cache[player_id].current = 1
    cursor_cache[player_id].locked = false
    return true
  end)
end

function frame.remove_cursor(cursor_id, player_id)
  cursor_cache[player_id] = nil
  Net.player_erase_sprite(player_id, cursor_id .. "_obj")
  if Net.unlock_player_input then
    Net.unlock_player_input(player_id)
  end
  return true
end

Net:on("cursor_move", function(event)
  local cc = cursor_cache[event.player_id]
  if not cc then return end

  local last = cc.current or 1
  local selections = cc.selections or {}
  if #selections == 0 then return end

  if event.button == "Move Left" or event.button == "Shoulder L" or event.button == "Move Up" then
    cc.current = (last == 1) and #selections or (last - 1)
  elseif event.button == "Move Right" or event.button == "Move Down" or event.button == "Shoulder R" then
    cc.current = (last == #selections) and 1 or (last + 1)
  end

  local sel = selections[cc.current]
  if not sel then return end

  Net.player_draw_sprite(event.player_id, event.cursor, {
    id = event.cursor .. "_obj",
    x = sel.x * 2,
    y = sel.y * 2
  })

  Net:emit("cursor_hover", {
    player_id = event.player_id,
    cursor = cc.name,
    selection = sel.name
  })
end)

-- ============================================================
-- Tournament lifecycle compatibility (expected by tournament scripts)
-- ============================================================
frame._started = frame._started or false

function frame.start_framework()
  if frame._started then return true end
  frame._started = true
  return true
end

function frame.activate_framework(...)
  if frame.start_framework then frame.start_framework() end
  return true
end

local function try_lock_input(player_id)
  local ok = pcall(function()
    if Net.lock_player_input then Net.lock_player_input(player_id) end
  end)
  return ok and Net.lock_player_input ~= nil
end

local function try_unlock_input(player_id)
  local ok = pcall(function()
    if Net.unlock_player_input then Net.unlock_player_input(player_id) end
  end)
  return ok and Net.unlock_player_input ~= nil
end

local function try_freeze(player_id)
  local ok = pcall(function()
    if Net.freeze_player then Net.freeze_player(player_id) end
  end)
  if ok and Net.freeze_player then return true end
  return try_lock_input(player_id)
end

local function try_unfreeze(player_id)
  local ok = pcall(function()
    if Net.unfreeze_player then Net.unfreeze_player(player_id) end
  end)
  if ok and Net.unfreeze_player then return true end
  return try_unlock_input(player_id)
end

function frame.freeze_player(player_id, ...)
  if frame.start_framework then frame.start_framework() end
  return try_freeze(player_id)
end

function frame.unfreeze_player(player_id, ...)
  return try_unfreeze(player_id)
end

function frame.deactivate_framework(player_id, ...)
  if not player_id then return true end

  -- 1) unfreeze input
  try_unfreeze(player_id)

  -- 2) remove cursors (tourney assumes this)
  if cursor_cache[player_id] then
    for cursor_id, _ in next, cursor_cache[player_id] do
      Net.player_erase_sprite(player_id, cursor_id .. "_obj")
    end
    cursor_cache[player_id] = nil
  end

  -- 3) clear ALL UI sprites (this fixes the stuck banner)
  clear_all_ui_for_player(player_id)

  return true
end


-- ============================================================
-- Event handlers (join/leave/move/input/tick)
-- ============================================================
Net:on("player_join", function(event)
  -- online list
  if not table_has_value(online_players, event.player_id) then
    table.insert(online_players, event.player_id)
  end

  -- caches
  ui_cache[event.player_id] = ui_cache[event.player_id] or {}
  cursor_cache[event.player_id] = cursor_cache[event.player_id] or {}
  avatar_cache[event.player_id] = avatar_cache[event.player_id] or {}

  provide_framework_assets(event.player_id)

  -- hide player-exclusive cosmetics from joining player (visibility=false)
  if next(cosmetic_cache) ~= nil then
    for owner_id, cosmetics in next, cosmetic_cache do
      for cosmetic_id, cosmetic_data in next, cosmetics do
        if cosmetic_data.visibility == false then
          Net.exclude_actor_for_player(event.player_id, cosmetic_id .. "_" .. owner_id)
        end
      end
    end
  end
end)

Net:on("player_disconnect", function(event)
  cursor_cache[event.player_id] = nil
  avatar_cache[event.player_id] = nil
  ui_cache[event.player_id] = nil
  ui_update[event.player_id] = nil
  button_states[event.player_id] = nil
  tracking_state[event.player_id] = nil
  map_elements[event.player_id] = nil

  -- remove from online list
  for i, pid in next, online_players do
    if pid == event.player_id then
      online_players[i] = nil
    end
  end

  -- remove cosmetics
  if cosmetic_cache[event.player_id] then
    for cosmetic_id, _ in next, cosmetic_cache[event.player_id] do
      local bot_id = cosmetic_id .. "_" .. event.player_id
      if Net.is_bot(bot_id) then Net.remove_bot(bot_id, false) end
    end
    cosmetic_cache[event.player_id] = nil
  end
end)

Net:on("player_area_transfer", function(event)
  last_position_cache[event.player_id] = last_position_cache[event.player_id] or {}
  last_position_cache[event.player_id].area = Net.get_player_area(event.player_id)

  -- transfer cosmetic bots to new area
  if cosmetic_cache[event.player_id] then
    for cosmetic_id, _ in next, cosmetic_cache[event.player_id] do
      local bot_id = cosmetic_id .. "_" .. event.player_id
      pcall(function()
        if Net.transfer_bot then
          Net.transfer_bot(bot_id, last_position_cache[event.player_id].area, false)
        end
      end)
    end
  end
end)

Net:on("player_move", function(event)
  -- update cosmetic bots to follow
  if cosmetic_cache[event.player_id] ~= nil then
    for cosmetic_id, cosmetic_data in next, cosmetic_cache[event.player_id] do
      local bot_id = cosmetic_id .. "_" .. event.player_id
      if Net.is_bot(bot_id) then
        Net.move_bot(bot_id, event.x + cosmetic_data.x, event.y + cosmetic_data.y, event.z + 3)
        pcall(function()
          if Net.animate_bot then Net.animate_bot(bot_id, cosmetic_data.state, true) end
        end)
      end
    end
  end
end)

-- cache virtual input states
Net:on("virtual_input", function(event)
  button_states[event.player_id] = button_states[event.player_id] or {}
  for _, button in next, event.events do
    button_states[event.player_id][button.name] = button.state
  end
end)

-- emit repeated state=4 for held buttons (scrolling)
Net:on("tick", function(event)
  for player_id, buttons in next, button_states do
    tracking_state[player_id] = tracking_state[player_id] or {}

    for name, state in next, buttons do
      if not tracking_state[player_id][name] then
        tracking_state[player_id][name] = { tracked = 0, elapsed = 0 }
      end

      local t = tracking_state[player_id][name]
      if state == 2 then
        if t.tracked == 0 then
          t.elapsed = 0
          t.tracked = 1
        else
          t.elapsed = t.elapsed + event.delta_time
        end

        if t.elapsed > 0.3 and t.tracked == 1 then
          t.elapsed = 0
          Net:emit("virtual_input", { player_id = player_id, events = { { state = 4, name = name } } })
          t.tracked = 2
        elseif t.elapsed > 0.1 and t.tracked == 2 then
          t.elapsed = 0
          Net:emit("virtual_input", { player_id = player_id, events = { { state = 4, name = name } } })
        end
      else
        t.tracked = 0
        t.elapsed = 0
      end
    end
  end
end)

-- cursor control via virtual_input (safe-guarded)
Net:on("virtual_input", function(event)
  local cc = cursor_cache[event.player_id]
  if not cc then return end

  local direction = cc.movement
  for _, button in next, event.events do
    local is_repeat_or_press = (button.state == 1 or button.state == 4)

    if is_repeat_or_press then
      if ((button.name == "Move Down" or button.name == "Move Up") and direction == "vertical")
        or ((button.name == "Move Left" or button.name == "Move Right") and direction == "horizontal")
        or ((button.name == "Shoulder L" or button.name == "Shoulder R") and direction == "shoulder") then
        Net:emit("cursor_move", { player_id = event.player_id, cursor = cc.name, selection = cc.current, button = button.name })
      end
    end

    if (button.name == "Interact" or button.name == "Confirm") and button.state == 1 then
      local selections = cc.selections
      local idx = cc.current
      if selections and idx and selections[idx] and selections[idx].name then
        Net:emit("cursor_selection", { player_id = event.player_id, cursor = cc.name, selection = selections[idx].name })
      end
    end
  end
end)

return frame
