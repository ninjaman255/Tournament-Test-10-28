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

-- Helper function to clamp values to 0-255 range
local function clamp_color_value(value)
  if value == nil then return nil end
  return math.max(0, math.min(255, tonumber(value) or 0))
end

-- Helper function to prepare sprite draw parameters with all properties
local function prepare_draw_params(base_params, properties)
  properties = properties or {}
  
  -- Start with base parameters
  local draw_params = {}
  for k, v in pairs(base_params) do
    draw_params[k] = v
  end
  
  -- Apply all properties from the properties table
  if properties.x then draw_params.x = properties.x end
  if properties.y then draw_params.y = properties.y end
  if properties.z then draw_params.z = properties.z end
  if properties.sx then draw_params.sx = properties.sx end
  if properties.sy then draw_params.sy = properties.sy end
  if properties.ox then draw_params.ox = properties.ox end
  if properties.oy then draw_params.oy = properties.oy end
  if properties.ro then draw_params.ro = properties.ro end
  if properties.rotation then draw_params.ro = properties.rotation end
  
  -- Handle opacity/alpha (both names supported)
  if properties.opacity ~= nil then
    draw_params.opacity = clamp_color_value(properties.opacity)
    draw_params.a = draw_params.opacity
  end
  if properties.a ~= nil then
    draw_params.a = clamp_color_value(properties.a)
    draw_params.opacity = draw_params.a
  end
  
  -- Handle color tint with clamping
  if properties.r ~= nil then draw_params.r = clamp_color_value(properties.r) end
  if properties.g ~= nil then draw_params.g = clamp_color_value(properties.g) end
  if properties.b ~= nil then draw_params.b = clamp_color_value(properties.b) end
  
  -- Handle color mode (0=multiply, 1=add, 2=colorize)
  if properties.color_mode ~= nil then
    local mode = tonumber(properties.color_mode)
    if mode == 0 or mode == 1 or mode == 2 then
      draw_params.color_mode = mode
    end
  end
  
  -- Animation state
  if properties.animation_state then draw_params.anim_state = properties.animation_state end
  if properties.anim_state then draw_params.anim_state = properties.anim_state end
  
  -- Ensure id is present
  if not draw_params.id then
    print("[net-games][framework] Warning: Sprite draw params missing 'id' field")
  end
  
  return draw_params
end