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
-- Dependencies: Sprite Management System
-- ============================================================
local SpriteManager_ok, SpriteManager = pcall(require, "scripts/net-games/sprites-api/sprite-manager")
local SpriteConstants_ok, SpriteConstants = pcall(require, "scripts/net-games/sprites-api/sprite-constants")

if not SpriteManager_ok then
    print("[net-games][framework] WARNING: SpriteManager not available. Falling back to legacy sprite handling.")
    SpriteManager = nil
end

if not SpriteConstants_ok then
    print("[net-games][framework] WARNING: SpriteConstants not available.")
    SpriteConstants = nil
end

-- ============================================================
-- Optional Displayer init (tournament uses Displayer heavily, but don't hard crash)
-- ============================================================
local Displayer_ok, Displayer = pcall(require, "scripts/net-games/displayer/displayer")
local DISPLAYER_READY = false
-- require("scripts/net-games/displayer/demo_core_overlay")

if Displayer_ok and Displayer and Displayer.init and Displayer.isValid then
  local ok = false
  local err
  local success = pcall(function()
    -- Displayer:init() returns self (a table), not boolean.
    -- Treat "init succeeded" + "isValid" as readiness.
    Displayer:init()
    ok = (Displayer:isValid() == true)
  end)
  DISPLAYER_READY = (success == true) and (ok == true)

  if not DISPLAYER_READY then
    err = err or "(unknown)"
    print("[net-games][framework] Displayer init failed or invalid; text/timers will be no-ops.")
  end
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
local cosmetic_cache = {}      -- cosmetics per player (stores bot IDs and offsets)
local cursor_cache = {}        -- cursor config per player (now stores SpriteManager obj_ids)
local avatar_cache = {}        -- reserved (used by some forks)
local map_elements = {}        -- map elements per player
local ui_cache = {}
local ui_update = {}           -- reserved for future sliding UI
local online_players = {}      -- list of online players (for exclusions)

-- Default: do NOT reuse sprite allocations by texture.
-- Net.player_draw_sprite can be "sticky" across sprite_id reuse in some forks.
-- If you really want old behavior, set to true.
local REUSE_SPRITES_BY_TEXTURE = false

-- ============================================================
-- Sprite Management Wrappers
-- ============================================================
local function get_sprite_manager(player_id)
    if SpriteManager then
        return SpriteManager.get_player_manager(player_id)
    end
    return nil
end

local function safe_sprite_operation(player_id, operation, ...)
    if SpriteManager then
        local manager = get_sprite_manager(player_id)
        if manager and manager[operation] then
            return manager[operation](manager, ...)
        end
    end
    return false
end

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

-- ============================================================
-- Properties helpers (Sprite API draw/update options)
-- ============================================================
local prepare_draw_params = nil
do
  local ok, mh = pcall(require, "scripts/net-games/math-helpers")
  if ok and type(mh) == "table" and type(mh.prepare_draw_params) == "function" then
    prepare_draw_params = mh.prepare_draw_params
  end
end

local function _copy_table(t)
  local o = {}
  if t then
    for k, v in pairs(t) do o[k] = v end
  end
  return o
end

local function _merge_tables(a, b)
  local out = _copy_table(a)
  if b then
    for k, v in pairs(b) do out[k] = v end
  end
  return out
end

-- Copy properties, but if x/y are present, replace them with scaled values (so callers can supply unscaled x/y)
local function _with_scaled_xy(properties, x_scaled, y_scaled)
  if not properties then return nil end
  local p = _copy_table(properties)
  if properties.x ~= nil then p.x = x_scaled end
  if properties.y ~= nil then p.y = y_scaled end
  return p
end

-- For framework-style coordinates (call sites already do X*2, Y*2)
local function _resolve_xy_scaled(X, Y, properties)
  local rawX, rawY = X, Y
  if properties then
    if properties.x ~= nil then rawX = properties.x end
    if properties.y ~= nil then rawY = properties.y end
  end
  return rawX, rawY, rawX * 2, rawY * 2
end

-- For cosmetic-style coordinates (x/y are offset by +120/+80 and then *2)
local function _resolve_xy_scaled_with_offsets(x, y, offX, offY, properties)
  local rawX, rawY = x, y
  if properties then
    if properties.x ~= nil then rawX = properties.x end
    if properties.y ~= nil then rawY = properties.y end
  end
  return rawX, rawY, (rawX + offX) * 2, (rawY + offY) * 2
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
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts/fonts_compressed.png") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts/fonts_dark_compressed.png") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts/fonts_wide.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts/fonts_gradient.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts/fonts_thick.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts/fonts_battle.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts/fonts_thin.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts/fonts_tiny.animation") end)
  pcall(function() Net.provide_asset_for_player(player_id, "/server/assets/net-games/fonts/fonts_compressed.animation") end)
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
-- Cosmetics (uses bots + legacy sprite system)
-- ============================================================
function frame.set_cosmetic(cosmetic_id, player_id, texture, animation, state, x, y, visible, player_xoffset, player_yoffset, properties)
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

    -- Use SpriteManager if available, otherwise legacy system
    if SpriteManager then
        local manager = get_sprite_manager(player_id)
        if manager then
            -- Use cosmetic_id as sprite_id
            manager:strict_alloc_sprite(cosmetic_id, {
                texture_path = texture,
                anim_path = animation,
                anim_state = state
            })
        else
            Net.player_alloc_sprite(player_id, cosmetic_id, { texture_path = texture, anim_path = animation, anim_state = state })
        end
    else
        Net.player_alloc_sprite(player_id, cosmetic_id, { texture_path = texture, anim_path = animation, anim_state = state })
    end
    
    local rawX, rawY, drawX, drawY = _resolve_xy_scaled_with_offsets(x, y, 120 + p_xoffset, 80 + p_yoffset, properties)
    
    -- Draw using SpriteManager or legacy
    if SpriteManager then
        local manager = get_sprite_manager(player_id)
        if manager then
            local draw_params = {
                x = drawX,
                y = drawY,
                sx = 2,
                sy = 2,
                anim_state = state
            }
            
            if prepare_draw_params then
                draw_params = prepare_draw_params(draw_params, _with_scaled_xy(properties, drawX, drawY))
            end
            
            local obj_id = cosmetic_id .. "_obj"
            manager:draw_sprite(cosmetic_id, obj_id, draw_params)
        end
    else
        local draw_params = {
            id = cosmetic_id .. "_obj",
            x = drawX,
            y = drawY,
            sx = 2,
            sy = 2,
            anim_state = state
        }
        
        if prepare_draw_params then
            draw_params = prepare_draw_params(draw_params, _with_scaled_xy(properties, drawX, drawY))
        end
        
        Net.player_draw_sprite(player_id, cosmetic_id, draw_params)
    end

    last_position_cache[player_id] = last_position_cache[player_id] or {}
    local area_id = last_position_cache[player_id].area or Net.get_player_area(player_id)

    local position = Net.get_player_position(player_id)
    local xoffset, yoffset = convertOffsets(rawX * -1, rawY * -1, position.z + 3)
    xoffset, yoffset = fixOffsets(xoffset, yoffset)

    cosmetic_cache[player_id][cosmetic_id] = {
        id = cosmetic_id,
        texture = texture,
        x = xoffset,
        y = yoffset,
        visibility = visibility,
        animation = animation,
        state = state,
        spritex = drawX,
        spritey = drawY,
        -- Store whether we used SpriteManager
        uses_sprite_manager = SpriteManager ~= nil
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

  -- Erase using SpriteManager or legacy
  local cosmetic_data = cosmetic_cache[player_id][cosmetic_id]
  if cosmetic_data.uses_sprite_manager and SpriteManager then
    local manager = get_sprite_manager(player_id)
    if manager then
        manager:erase_sprite(cosmetic_id .. "_obj")
    end
  else
    Net.player_erase_sprite(player_id, cosmetic_id .. "_obj")
  end
  
  cosmetic_cache[player_id][cosmetic_id] = nil
  return true
end

-- ============================================================
-- Map elements (bots) - unchanged
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
    x = rawX, y = rawY, z = Z,
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
-- UI elements (screen-space sprites) - Properties-based API
-- ============================================================
function frame.add_ui_element(sprite_id, player_id, texture_path, animation_path, animation_state, properties)
  -- Validate parameters
  if not sprite_id or not player_id or not texture_path then
    print("[net-games][framework] add_ui_element(): missing required arguments")
    return false
  end
  
  properties = properties or {}
  
  -- Extract values from properties
  local xPos = properties.x or 0
  local yPos = properties.y or 0
  local zPos = properties.z or 0
  local scaleX = properties.sx or properties.scale or 2.0
  local scaleY = properties.sy or properties.scale or 2.0
  animation_path = animation_path or ""
  animation_state = animation_state or ""

  -- Use SpriteManager if available
  if SpriteManager then
    local manager = get_sprite_manager(player_id)
    if manager then
        local alloc_id = tostring(sprite_id)
        
        -- Provide assets
        if animation_path ~= "" then 
            pcall(function() Net.provide_asset_for_player(player_id, animation_path) end) 
        end
        pcall(function() Net.provide_asset_for_player(player_id, texture_path) end)

        -- Allocate sprite if not already allocated
        if not manager:is_sprite_allocated(alloc_id) then
            manager:strict_alloc_sprite(alloc_id, {
                texture_path = texture_path,
                anim_path = animation_path,
                anim_state = animation_state
            })
        end
        
        -- Prepare draw parameters
        local rawX, rawY, drawX, drawY = _resolve_xy_scaled(xPos, yPos, properties)
        
        local draw_params = {
            x = drawX,
            y = drawY,
            sx = scaleX,
            sy = scaleY
        }
        
        -- Add other properties from the properties table
        for k, v in pairs(properties) do
            if k ~= "x" and k ~= "y" then  -- x and y are already handled
                if k == "z" then
                    draw_params.z = v
                elseif k == "rotation" or k == "ro" then
                    draw_params.ro = v
                elseif k == "opacity" or k == "a" then
                    draw_params.opacity = v
                    draw_params.a = v
                elseif k == "sx" or k == "sy" or k == "scale" then
                    -- Already handled above
                elseif k == "anim_state" or k == "animation_state" then
                    draw_params.anim_state = v
                elseif k == "r" or k == "g" or k == "b" then
                    draw_params[k] = v
                elseif k == "color_mode" then
                    draw_params.color_mode = v
                elseif k == "ox" or k == "oy" then
                    draw_params[k] = v
                else
                    draw_params[k] = v
                end
            end
        end
        
        -- Ensure animation state is set
        if animation_state and animation_state ~= "" and not draw_params.anim_state then
            draw_params.anim_state = animation_state
        end
        
        -- Apply prepare_draw_params if available
        if prepare_draw_params then
            draw_params = prepare_draw_params(draw_params, _with_scaled_xy(properties, drawX, drawY))
        end
        
        -- Create object ID
        local obj_id = sprite_id .. "_obj"
        manager:draw_sprite(alloc_id, obj_id, draw_params)
        
        -- Store in cache
        ui_cache[player_id] = ui_cache[player_id] or {}
        ui_cache[player_id][sprite_id] = {
            alloc_id = alloc_id,
            obj_id = obj_id,
            texture_path = texture_path,
            rawX = xPos,
            rawY = yPos,
            drawX = drawX,
            drawY = drawY,
            z = zPos,
            scaleX = scaleX,
            scaleY = scaleY,
            animation_state = animation_state,
            uses_sprite_manager = true
        }
        
        return true
    end
  end
  
  -- Fallback: use direct Net API
  local alloc_id = tostring(sprite_id) .. "|" .. tostring(texture_path) .. "|" .. tostring(animation_path or "")

  if animation_path ~= "" then pcall(function() Net.provide_asset_for_player(player_id, animation_path) end) end
  pcall(function() Net.provide_asset_for_player(player_id, texture_path) end)

  Net.player_alloc_sprite(player_id, alloc_id, { 
      texture_path = texture_path, 
      anim_path = animation_path, 
      anim_state = animation_state 
  })
  
  local rawX, rawY, drawX, drawY = _resolve_xy_scaled(xPos, yPos, properties)

  local draw_params = {
    id = sprite_id .. "_obj",
    x = drawX,
    y = drawY,
    sx = scaleX,
    sy = scaleY
  }
  
  -- Add properties to draw params
  for k, v in pairs(properties) do
    if k ~= "x" and k ~= "y" then
      if k == "z" then
        draw_params.z = v
      elseif k == "rotation" or k == "ro" then
        draw_params.ro = v
      elseif k == "opacity" or k == "a" then
        draw_params.opacity = v
        draw_params.a = v
      elseif k == "anim_state" or k == "animation_state" then
        draw_params.anim_state = v
      elseif k == "r" or k == "g" or k == "b" then
        draw_params[k] = v
      elseif k == "color_mode" then
        draw_params.color_mode = v
      elseif k == "ox" or k == "oy" then
        draw_params[k] = v
      else
        draw_params[k] = v
      end
    end
  end
  
  if prepare_draw_params then
    draw_params = prepare_draw_params(draw_params, _with_scaled_xy(properties, drawX, drawY))
  end
  
  Net.player_draw_sprite(player_id, alloc_id, draw_params)
  
  -- Store in cache
  ui_cache[player_id] = ui_cache[player_id] or {}
  ui_cache[player_id][sprite_id] = {
    alloc_id = alloc_id,
    obj_id = sprite_id .. "_obj",
    texture_path = texture_path,
    rawX = xPos,
    rawY = yPos,
    drawX = drawX,
    drawY = drawY,
    z = zPos,
    scaleX = scaleX,
    scaleY = scaleY,
    animation_state = animation_state,
    uses_sprite_manager = false
  }

  return true
end

function frame.update_ui_element(sprite_id, player_id, properties)
  if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
    print("[net-games][framework] update_ui_element(): UI element not found: " .. tostring(sprite_id))
    return false
  end
  
  local element = ui_cache[player_id][sprite_id]
  properties = properties or {}
  
  -- Handle with SpriteManager
  if element.uses_sprite_manager and SpriteManager then
    local manager = get_sprite_manager(player_id)
    if manager then
        local obj_id = element.obj_id
        
        if not manager:object_exists(obj_id) then
            print("[net-games][framework] update_ui_element(): Object not found in SpriteManager: " .. obj_id)
            return false
        end
        
        -- Get current properties
        local current_props = manager:get_properties(obj_id) or {}
        local draw_props = {}
        
        -- Copy existing properties
        for k, v in pairs(current_props) do
            if k ~= "id" then
                draw_props[k] = v
            end
        end
        
        -- Update with new properties
        for k, v in pairs(properties) do
            if k == "x" or k == "y" then
                -- Update position
                if k == "x" then
                    local _, _, drawX, _ = _resolve_xy_scaled(v, element.rawY, properties)
                    draw_props.x = drawX
                    element.rawX = v
                    element.drawX = drawX
                else
                    local _, _, _, drawY = _resolve_xy_scaled(element.rawX, v, properties)
                    draw_props.y = drawY
                    element.rawY = v
                    element.drawY = drawY
                end
            elseif k == "sx" or k == "scaleX" then
                draw_props.sx = v
                element.scaleX = v
            elseif k == "sy" or k == "scaleY" then
                draw_props.sy = v
                element.scaleY = v
            elseif k == "scale" then
                draw_props.sx = v
                draw_props.sy = v
                element.scaleX = v
                element.scaleY = v
            elseif k == "rotation" or k == "ro" then
                draw_props.ro = v
                element.rotation = v
            elseif k == "opacity" or k == "a" then
                draw_props.opacity = v
                draw_props.a = v
                element.opacity = v
            elseif k == "anim_state" or k == "animation_state" then
                draw_props.anim_state = v
                element.animation_state = v
            elseif k == "z" then
                draw_props.z = v
                element.z = v
            elseif k == "r" or k == "g" or k == "b" then
                draw_props[k] = v
                element[k] = v
            elseif k == "color_mode" then
                draw_props.color_mode = v
                element.color_mode = v
            elseif k == "ox" or k == "oy" then
                draw_props[k] = v
                element[k] = v
            else
                draw_props[k] = v
                element[k] = v
            end
        end
        
        return manager:set_properties(obj_id, draw_props, true)
    end
  else
    -- Legacy update
    local alloc_id = element.alloc_id
    local obj_id = element.obj_id
    
    -- Update cache
    if properties.x then element.rawX = properties.x end
    if properties.y then element.rawY = properties.y end
    
    local rawX = properties.x or element.rawX or 0
    local rawY = properties.y or element.rawY or 0
    local _, _, drawX, drawY = _resolve_xy_scaled(rawX, rawY, properties)
    element.drawX = drawX
    element.drawY = drawY
    
    local draw_params = {
        id = obj_id,
        x = drawX,
        y = drawY
    }
    
    -- Update other properties
    for k, v in pairs(properties) do
        if k ~= "x" and k ~= "y" then
            if k == "sx" or k == "scaleX" then
                draw_params.sx = v
                element.scaleX = v
            elseif k == "sy" or k == "scaleY" then
                draw_params.sy = v
                element.scaleY = v
            elseif k == "scale" then
                draw_params.sx = v
                draw_params.sy = v
                element.scaleX = v
                element.scaleY = v
            elseif k == "rotation" or k == "ro" then
                draw_params.ro = v
                element.rotation = v
            elseif k == "opacity" or k == "a" then
                draw_params.opacity = v
                draw_params.a = v
                element.opacity = v
            elseif k == "anim_state" or k == "animation_state" then
                draw_params.anim_state = v
                element.animation_state = v
            elseif k == "z" then
                draw_params.z = v
                element.z = v
            elseif k == "r" or k == "g" or k == "b" then
                draw_params[k] = v
                element[k] = v
            elseif k == "color_mode" then
                draw_params.color_mode = v
                element.color_mode = v
            elseif k == "ox" or k == "oy" then
                draw_params[k] = v
                element[k] = v
            else
                draw_params[k] = v
                element[k] = v
            end
        end
    end
    
    if prepare_draw_params then
        draw_params = prepare_draw_params(draw_params, _with_scaled_xy(properties, drawX, drawY))
    end
    
    Net.player_draw_sprite(player_id, alloc_id, draw_params)
    return true
  end
  
  return false
end

function frame.set_ui_animation(sprite_id, player_id, animation_state, properties)
  local props = properties or {}
  props.anim_state = animation_state
  return frame.update_ui_element(sprite_id, player_id, props)
end

function frame.move_ui_element(sprite_id, player_id, properties)
  return frame.update_ui_element(sprite_id, player_id, properties)
end

function frame.update_ui_position(sprite_id, player_id, properties)
  return frame.update_ui_element(sprite_id, player_id, properties)
end

function frame.remove_ui_element(sprite_id, player_id)
  -- Check if we have this UI element in cache
  if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
    print("[net-games][framework] remove_ui_element(): UI element not found: " .. tostring(sprite_id))
    return false
  end
  
  local element = ui_cache[player_id][sprite_id]
  
  -- Handle with SpriteManager
  if element.uses_sprite_manager and SpriteManager then
    local manager = get_sprite_manager(player_id)
    if manager then
        local obj_id = element.obj_id
        if manager:object_exists(obj_id) then
            manager:erase_sprite(obj_id)
        end
    end
  else
    -- Legacy system removal
    Net.player_erase_sprite(player_id, element.obj_id)
  end
  
  -- Remove from cache
  ui_cache[player_id][sprite_id] = nil
  
  return true
end

local function clear_all_ui_for_player(player_id)
  -- Clear using SpriteManager if available
  if SpriteManager then
    local manager = get_sprite_manager(player_id)
    if manager then
        -- Get all objects and erase them
        for _, obj in pairs(manager.objects) do
            manager:erase_sprite(obj.properties.id)
        end
    end
  end
  
  -- Clear cache
  ui_cache[player_id] = {}
  
  return true
end

-- ============================================================
-- Text (Displayer-backed, no-op if missing)
-- ============================================================
function frame.draw_text(text_id, player_id, text, x, y, z, font, scale, properties)
  if not DISPLAYER_READY then return false end  
  properties = properties or {}
  local _, _, drawX, drawY = _resolve_xy_scaled(tonumber(x), tonumber(y), properties)
  Displayer.Text.drawText(player_id, text_id, text, drawX, drawY, z, font, scale, properties)
  return true
end

-- NEW FUNCTION: Get text width before displaying it
function frame.get_text_width(text, font, scale)
  if not DISPLAYER_READY then 
    print("[net-games][framework] get_text_width(): Displayer not available")
    return 0 
  end
  
  if Displayer.Font and Displayer.Font.getTextWidth then
    local width = Displayer.Font.getTextWidth(text, font or "THICK", scale or 2.0)
    return width or 0
  else
    local success, width = pcall(function()
      return Displayer.Font.getTextWidth(text, font or "THICK", scale or 2.0)
    end)
    
    if success then
      return width or 0
    else
      print("[net-games][framework] get_text_width(): Font subsystem not available")
      return 0
    end
  end
end

function frame.update_text(text_id, player_id, text, properties)
  if not DISPLAYER_READY then return false end
  Displayer.Text.updateText(player_id, text_id, tostring(text), properties)
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
function frame.spawn_timer(timer_id, player_id, X, Y, duration, loop, properties)
  if not DISPLAYER_READY then return false end
  loop = loop or false
  Displayer.Timer.createPlayerTimer(player_id, timer_id, duration, function(_, _, _) end, loop)
  do
    properties = properties or {}
    local _, _, drawX, drawY = _resolve_xy_scaled(X, Y, properties)
    Displayer.TimerDisplay.createPlayerTimerDisplay(player_id, timer_id, drawX, drawY, "default", properties)
  end
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

function frame.spawn_countdown(countdown_id, player_id, X, Y, duration, loop, properties)
  if not DISPLAYER_READY then return false end
  loop = loop or false
  Displayer.Timer.createPlayerCountdown(player_id, countdown_id, duration, function(_, id, value)
    if value <= 0 then
      Net:emit("countdown_ended", { player_id = player_id, countdown_id = id })
    end
  end, loop)
  do
    properties = properties or {}
    local _, _, drawX, drawY = _resolve_xy_scaled(X, Y, properties)
    Displayer.TimerDisplay.createPlayerCountdownDisplay(player_id, countdown_id, drawX, drawY, "default", properties)
  end
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
-- Cursor system (virtual_input-driven) - Updated for SpriteManager
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

    -- Use SpriteManager if available
    if SpriteManager then
        local manager = get_sprite_manager(player_id)
        if manager then
            manager:strict_alloc_sprite(cursor_id, {
                texture_path = tex,
                anim_path = anim,
                anim_state = state
            })
            
            local merged_props = _merge_tables(options.properties, selection.properties)
            local rawX, rawY, drawX, drawY = _resolve_xy_scaled(selection.x, selection.y, merged_props)
            
            local draw_params = {
                x = drawX,
                y = drawY,
                sx = 2,
                sy = 2
            }
            
            if selection.z then draw_params.z = selection.z end
            if state and state ~= "" then draw_params.anim_state = state end

            if prepare_draw_params then
                draw_params = prepare_draw_params(draw_params, _with_scaled_xy(merged_props, drawX, drawY))
            end

            -- Draw cursor with obj_id
            local obj_id = cursor_id .. "_obj"
            manager:draw_sprite(cursor_id, obj_id, draw_params)
            
            -- Store sprite manager info
            cursor_cache[player_id].sprite_manager = {
                alloc_id = cursor_id,
                obj_id = obj_id,
                manager = manager
            }
        end
    else
        -- Legacy allocation
        Net.player_alloc_sprite(player_id, cursor_id, {
            texture_path = tex,
            anim_path = anim,
            anim_state = state
        })

        local merged_props = _merge_tables(options.properties, selection.properties)
        local rawX, rawY, drawX, drawY = _resolve_xy_scaled(selection.x, selection.y, merged_props)

        local draw_params = {
            id = cursor_id .. "_obj",
            x = drawX,
            y = drawY,
            sx = 2,
            sy = 2
        }
        
        if selection.z then draw_params.z = selection.z end
        if state and state ~= "" then draw_params.anim_state = state end

        if prepare_draw_params then
            draw_params = prepare_draw_params(draw_params, _with_scaled_xy(merged_props, drawX, drawY))
        end

        Net.player_draw_sprite(player_id, cursor_id, draw_params)
    end

    cursor_cache[player_id].sprites = cursor_cache[player_id].sprites or {}
    cursor_cache[player_id].current = 1
    cursor_cache[player_id].locked = false
    cursor_cache[player_id].uses_sprite_manager = SpriteManager ~= nil
    
    return true
  end)
end

function frame.remove_cursor(cursor_id, player_id)
  -- Erase using appropriate method
  if cursor_cache[player_id] and cursor_cache[player_id].uses_sprite_manager and SpriteManager then
    local manager = get_sprite_manager(player_id)
    if manager then
        manager:erase_sprite(cursor_id .. "_obj")
    end
  else
    Net.player_erase_sprite(player_id, cursor_id .. "_obj")
  end
  
  cursor_cache[player_id] = nil
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

  -- Update cursor position using appropriate method
  if cc.uses_sprite_manager and SpriteManager then
    local manager = get_sprite_manager(event.player_id)
    if manager then
        local merged_props = _merge_tables(cc.properties, sel.properties)
        local _, _, drawX, drawY = _resolve_xy_scaled(sel.x, sel.y, merged_props)
        local draw = { x = drawX, y = drawY }
        if prepare_draw_params then
            draw = prepare_draw_params(draw, _with_scaled_xy(merged_props, drawX, drawY))
        end
        manager:set_properties(event.cursor .. "_obj", draw, true)
    end
  else
    local merged_props = _merge_tables(cc.properties, sel.properties)
    local _, _, drawX, drawY = _resolve_xy_scaled(sel.x, sel.y, merged_props)
    local draw = { id = event.cursor .. "_obj", x = drawX, y = drawY }
    if prepare_draw_params then
        draw = prepare_draw_params(draw, _with_scaled_xy(merged_props, drawX, drawY))
    end
    Net.player_draw_sprite(event.player_id, event.cursor, draw)
  end

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
      frame.remove_cursor(cursor_id, player_id)
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

  -- Initialize SpriteManager for player if available
  if SpriteManager then
    SpriteManager.init_player(event.player_id)
  end

  -- caches
  cursor_cache[event.player_id] = cursor_cache[event.player_id] or {}
  avatar_cache[event.player_id] = avatar_cache[event.player_id] or {}
  ui_cache[event.player_id] = ui_cache[event.player_id] or {}

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
  -- Clean up SpriteManager
  if SpriteManager then
    SpriteManager.cleanup_player(event.player_id)
  end

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