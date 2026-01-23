-- file name: displayer-utils.lua
-- Shared utilities for displayer scripts to work with framework properties

-- Load the prepare_draw_params function from the framework
local function load_framework_utils()
    -- Try multiple ways to get the prepare_draw_params function
    local success, utils = pcall(require, "scripts/net-games/math-helpers")
    if success and utils then
        return utils.prepare_draw_params
    end
    
    -- Fallback: try to get it from the framework
    success, utils = pcall(require, "framework")
    if success and utils and utils.prepare_draw_params then
        return utils.prepare_draw_params
    end
    
    -- Last resort: define a minimal version
    print("[displayer] WARNING: Could not load framework utils, using minimal implementation")
    return function(base_params, properties)
        properties = properties or {}
        local draw_params = {}
        for k, v in pairs(base_params) do
            draw_params[k] = v
        end
        
        -- Apply basic properties
        if properties.x then draw_params.x = properties.x end
        if properties.y then draw_params.y = properties.y end
        if properties.z then draw_params.z = properties.z end
        if properties.sx then draw_params.sx = properties.sx end
        if properties.sy then draw_params.sy = properties.sy end
        if properties.ox then draw_params.ox = properties.ox end
        if properties.oy then draw_params.oy = properties.oy end
        if properties.ro then draw_params.ro = properties.ro end
        if properties.rotation then draw_params.ro = properties.rotation end
        if properties.opacity then draw_params.opacity = properties.opacity end
        if properties.a then draw_params.a = properties.a end
        if properties.r then draw_params.r = properties.r end
        if properties.g then draw_params.g = properties.g end
        if properties.b then draw_params.b = properties.b end
        if properties.color_mode then draw_params.color_mode = properties.color_mode end
        if properties.anim_state then draw_params.anim_state = properties.anim_state end
        
        return draw_params
    end
end

local prepare_draw_params = load_framework_utils()

-- Helper to extract tint properties from a properties table
local function extract_tint_properties(properties)
    if not properties then return nil end
    
    local tint = {}
    if properties.r ~= nil then tint.r = properties.r end
    if properties.g ~= nil then tint.g = properties.g end
    if properties.b ~= nil then tint.b = properties.b end
    if properties.a ~= nil then tint.a = properties.a end
    if properties.opacity ~= nil then tint.opacity = properties.opacity end
    if properties.color_mode ~= nil then tint.color_mode = properties.color_mode end
    
    return next(tint) ~= nil and tint or nil
end

-- Helper to merge properties with defaults
local function merge_properties(defaults, overrides)
    local result = {}
    if defaults then
        for k, v in pairs(defaults) do
            result[k] = v
        end
    end
    if overrides then
        for k, v in pairs(overrides) do
            result[k] = v
        end
    end
    return result
end

return {
    prepare_draw_params = prepare_draw_params,
    extract_tint_properties = extract_tint_properties,
    merge_properties = merge_properties,
    clamp_color_value = function(value)
        if value == nil then return nil end
        return math.max(0, math.min(255, tonumber(value) or 0))
    end
}