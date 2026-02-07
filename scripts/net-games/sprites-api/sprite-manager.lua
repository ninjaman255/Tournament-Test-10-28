-- scripts/net-games/sprite-manager.lua
-- Updated Sprite Manager API with global instance and categorization

local SpriteConstants = require("scripts/net-games/sprites-api/sprite-constants")

-- Global sprite manager instance
local SpriteManager = {}
SpriteManager.__index = SpriteManager

-- Store player managers in a global table
local player_managers = {}

-- Debug helper
local DEBUG = true
local function debug_log(...)
    if DEBUG then
        print("[SpriteManager]", ...)
    end
end

-- Get or create a sprite manager for a player
function SpriteManager.get_player_manager(player_id)
    if not player_managers[player_id] then
        player_managers[player_id] = setmetatable({
            player_id = player_id,
            
            -- Track allocated sprites by sprite_id
            allocated_sprites = {},
            
            -- Track object instances by obj_id
            objects = {},
            
            -- Track available obj_ids for reuse
            available_ids = {},
            
            -- Internal counter for generating unique obj_ids
            next_obj_id = 1,
            
            -- Categorize sprites for better organization
            categories = {
                fonts = {},
                backdrops = {},
                cursors = {},
                textboxes = {},
                mugshots = {},
                ui = {},
                screens = {}
            }
        }, SpriteManager)
    end
    
    return player_managers[player_id]
end

-- Clean up a player's manager
function SpriteManager.cleanup_player(player_id)
    local manager = player_managers[player_id]
    if manager then
        manager:clear_all()
        player_managers[player_id] = nil
    end
end

-- Initialize a player with auto-allocated assets
function SpriteManager.init_player(player_id)
    local manager = SpriteManager.get_player_manager(player_id)
    
    -- Auto-allocate system assets
    for _, asset_config in pairs(SpriteConstants.AUTO_ALLOC_ASSETS) do
        manager:strict_alloc_sprite(asset_config.sprite_id, {
            texture_path = asset_config.texture_path,
            anim_path = asset_config.anim_path,
            anim_state = "OPEN_IDLE"  -- Default state for textbox panels
        })
    end
    
    return manager
end

-- Strict allocation (immediate allocation)
function SpriteManager:strict_alloc_sprite(sprite_id, fields)
    -- Validate required fields
    if not fields or not fields.texture_path then
        error("Sprite allocation requires texture_path")
    end
    
    -- Check if already allocated
    if self.allocated_sprites[sprite_id] then
        return true
    end
    
    -- Provide assets
    Net.provide_asset_for_player(self.player_id, fields.texture_path)
    if fields.anim_path then
        Net.provide_asset_for_player(self.player_id, fields.anim_path)
    end
    
    -- Call engine allocation
    Net.player_alloc_sprite(self.player_id, sprite_id, fields)
    
    -- Store sprite info with categorization
    local sprite_info = {
        texture_path = fields.texture_path,
        anim_path = fields.anim_path,
        anim_state = fields.anim_state or "default",
        objects = {},
        category = self:_categorize_sprite(sprite_id)
    }
    
    self.allocated_sprites[sprite_id] = sprite_info
    
    -- Add to category
    if sprite_info.category then
        self.categories[sprite_info.category][sprite_id] = true
    end
    
    return true
end

-- Lazy allocation (allocate only when needed)
function SpriteManager:lazy_alloc_sprite(sprite_id, fields, alloc_if_not_exists)
    -- If sprite already allocated, return success
    if self.allocated_sprites[sprite_id] then
        return true
    end
    
    -- If allocation is required and sprite doesn't exist, allocate it
    if alloc_if_not_exists then
        return self:strict_alloc_sprite(sprite_id, fields)
    end
    
    -- Return false if not allocated and not required to allocate
    return false
end

-- Categorize sprite based on ID
function SpriteManager:_categorize_sprite(sprite_id)
    debug_log("_categorize_sprite: sprite_id =", sprite_id, "type =", type(sprite_id))
    
    if SpriteConstants:is_font_sprite(sprite_id) then
        debug_log("  categorized as fonts")
        return "fonts"
    end
    
    -- For numeric sprite IDs, check against system constants
    local num_id = tonumber(sprite_id)
    if num_id then
        debug_log("  num_id =", num_id)
        if num_id == SpriteConstants.SYSTEM.CURSOR then
            debug_log("  categorized as cursors")
            return "cursors"
        elseif num_id == SpriteConstants.SYSTEM.TEXTBOX_PANEL or 
               num_id == SpriteConstants.SYSTEM.TEXTBOX_FRAME then
            debug_log("  categorized as textboxes")
            return "textboxes"
        elseif num_id >= SpriteConstants.SYSTEM.MUGSHOT_BASE and 
               num_id < SpriteConstants.SYSTEM.MUGSHOT_BASE + 100 then
            debug_log("  categorized as mugshots")
            return "mugshots"
        elseif num_id == SpriteConstants.SYSTEM.BACKDROP then
            debug_log("  categorized as backdrops")
            return "backdrops"
        end
    end
    
    debug_log("  categorized as ui (default)")
    return "ui"
end

-- Get or generate a unique obj_id
function SpriteManager:_get_obj_id(requested_id)
    if requested_id then
        -- Check if requested ID is available
        if self.objects[requested_id] then
            return requested_id
        end
        return requested_id
    else
        -- Try to reuse available ID
        for id, _ in pairs(self.available_ids) do
            self.available_ids[id] = nil
            return id
        end
        
        -- Generate new unique ID
        local new_id = "obj_" .. tostring(self.next_obj_id)
        self.next_obj_id = self.next_obj_id + 1
        return new_id
    end
end

-- Draw a sprite instance
function SpriteManager:draw_sprite(sprite_id, obj_id, properties)
    -- Validate sprite exists or try lazy allocation
    local sprite = self.allocated_sprites[sprite_id]
    if not sprite then
        -- Try to see if this is a font that needs to be allocated
        local font_name = SpriteConstants:font_name_from_sprite(sprite_id)
        if font_name then
            -- This is a font, should have been allocated by font-system
            error("Font sprite not allocated: " .. sprite_id)
        end
        error("Sprite not allocated: " .. sprite_id)
    end
    
    -- Get valid obj_id
    local actual_obj_id = self:_get_obj_id(obj_id)
    
    -- Check if object already exists
    local existing_obj = self.objects[actual_obj_id]
    
    -- Create or update object
    local obj = existing_obj or {
        sprite_id = sprite_id,
        properties = {},
        locked = {},
        category = sprite.category
    }
    
    -- Update properties if provided
    if properties then
        -- Don't allow id field in properties (use obj_id parameter)
        properties.id = nil
        
        -- Apply properties, respecting locks
        for key, value in pairs(properties) do
            if not obj.locked[key] then
                -- Handle opacity alias
                if key == "a" then
                    obj.properties.opacity = value
                else
                    obj.properties[key] = value
                end
            end
        end
    end
    
    -- Ensure required id field for draw call
    obj.properties.id = actual_obj_id
    
    -- Store object
    self.objects[actual_obj_id] = obj
    sprite.objects[actual_obj_id] = true
    
    -- Remove from available IDs if it was there
    self.available_ids[actual_obj_id] = nil
    
    -- Call engine draw function
    Net.player_draw_sprite(self.player_id, sprite_id, obj.properties)
    
    return actual_obj_id
end

-- Set properties for an existing sprite instance
function SpriteManager:set_properties(obj_id, properties, force)
    local obj = self.objects[obj_id]
    if not obj then
        return false
    end
    
    -- Don't allow changing sprite_id through properties
    properties.id = nil
    
    local changed = false
    
    for key, value in pairs(properties) do
        -- Check if property is locked
        if force or not obj.locked[key] then
            -- Handle opacity alias
            if key == "a" then
                if obj.properties.opacity ~= value then
                    obj.properties.opacity = value
                    changed = true
                end
            else
                if obj.properties[key] ~= value then
                    obj.properties[key] = value
                    changed = true
                end
            end
        end
    end
    
    -- Redraw if properties changed
    if changed then
        Net.player_draw_sprite(self.player_id, obj.sprite_id, obj.properties)
    end
    
    return changed
end

-- Get properties of a sprite instance
function SpriteManager:get_properties(obj_id)
    local obj = self.objects[obj_id]
    if not obj then return nil end
    
    -- Return a copy to prevent external modification
    local props = {}
    for key, value in pairs(obj.properties) do
        props[key] = value
    end
    return props
end

-- Lock properties to prevent modification
function SpriteManager:lock_properties(obj_id, property_names)
    local obj = self.objects[obj_id]
    if not obj then return end
    
    if type(property_names) == "string" then
        property_names = {property_names}
    end
    
    for _, prop_name in ipairs(property_names or {}) do
        local target = (prop_name == "a") and "opacity" or prop_name
        obj.locked[target] = true
    end
end

-- Unlock properties to allow modification
function SpriteManager:unlock_properties(obj_id, property_names)
    local obj = self.objects[obj_id]
    if not obj then return end
    
    if type(property_names) == "string" then
        property_names = {property_names}
    end
    
    for _, prop_name in ipairs(property_names or {}) do
        local target = (prop_name == "a") and "opacity" or prop_name
        obj.locked[target] = nil
    end
end

-- Check if a property is locked
function SpriteManager:is_property_locked(obj_id, property_name)
    local obj = self.objects[obj_id]
    if not obj then return false end
    
    local target = (property_name == "a") and "opacity" or property_name
    return obj.locked[target] == true
end

-- Erase a sprite instance
function SpriteManager:erase_sprite(obj_id)
    local obj = self.objects[obj_id]
    if not obj then return end
    
    -- Remove from sprite's object tracking
    local sprite = self.allocated_sprites[obj.sprite_id]
    if sprite then
        sprite.objects[obj_id] = nil
    end
    
    -- Call engine erase function
    Net.player_erase_sprite(self.player_id, obj_id)
    
    -- Remove object
    self.objects[obj_id] = nil
    
    -- Make ID available for reuse
    self.available_ids[obj_id] = true
end

-- Deallocate a sprite asset (erases all instances)
function SpriteManager:dealloc_sprite(sprite_id)
    local sprite = self.allocated_sprites[sprite_id]
    if not sprite then return end
    
    -- Erase all objects using this sprite
    for obj_id, _ in pairs(sprite.objects) do
        self:erase_sprite(obj_id)
    end
    
    -- Call engine deallocation
    Net.player_dealloc_sprite(self.player_id, sprite_id)
    
    -- Remove from category
    if sprite.category then
        self.categories[sprite.category][sprite_id] = nil
    end
    
    -- Remove sprite
    self.allocated_sprites[sprite_id] = nil
end

-- Get sprites by category
function SpriteManager:get_sprites_by_category(category)
    local result = {}
    for sprite_id, _ in pairs(self.categories[category] or {}) do
        table.insert(result, sprite_id)
    end
    return result
end

-- Get all objects for a sprite
function SpriteManager:get_objects_for_sprite(sprite_id)
    local sprite = self.allocated_sprites[sprite_id]
    if not sprite then return {} end
    
    local objects = {}
    for obj_id, _ in pairs(sprite.objects) do
        table.insert(objects, obj_id)
    end
    return objects
end

-- Check if a sprite is allocated
function SpriteManager:is_sprite_allocated(sprite_id)
    return self.allocated_sprites[sprite_id] ~= nil
end

-- Check if an object exists
function SpriteManager:object_exists(obj_id)
    return self.objects[obj_id] ~= nil
end

-- Get the sprite ID for an object
function SpriteManager:get_sprite_for_object(obj_id)
    local obj = self.objects[obj_id]
    return obj and obj.sprite_id
end

-- Clear all sprites and objects for this player
function SpriteManager:clear_all()
    -- Deallocate all sprites
    for sprite_id, _ in pairs(self.allocated_sprites) do
        self:dealloc_sprite(sprite_id)
    end
    
    -- Clear all tables
    self.allocated_sprites = {}
    self.objects = {}
    self.available_ids = {}
    self.next_obj_id = 1
    
    -- Clear categories
    for category, _ in pairs(self.categories) do
        self.categories[category] = {}
    end
end

-- Get manager statistics
function SpriteManager:get_stats()
    local stats = {
        allocated_sprites = 0,
        active_objects = 0,
        available_ids = 0,
        by_category = {}
    }
    
    stats.allocated_sprites = 0
    for _ in pairs(self.allocated_sprites) do
        stats.allocated_sprites = stats.allocated_sprites + 1
    end
    
    stats.active_objects = 0
    for _ in pairs(self.objects) do
        stats.active_objects = stats.active_objects + 1
    end
    
    stats.available_ids = 0
    for _ in pairs(self.available_ids) do
        stats.available_ids = stats.available_ids + 1
    end
    
    for category, sprites in pairs(self.categories) do
        stats.by_category[category] = 0
        for _ in pairs(sprites) do
            stats.by_category[category] = stats.by_category[category] + 1
        end
    end
    
    return stats
end

-- Global helper functions
function SpriteManager.get_all_player_ids()
    local ids = {}
    for player_id, _ in pairs(player_managers) do
        table.insert(ids, player_id)
    end
    return ids
end

function SpriteManager.get_total_stats()
    local total = {
        players = 0,
        total_sprites = 0,
        total_objects = 0
    }
    
    for player_id, manager in pairs(player_managers) do
        total.players = total.players + 1
        local stats = manager:get_stats()
        total.total_sprites = total.total_sprites + stats.allocated_sprites
        total.total_objects = total.total_objects + stats.active_objects
    end
    
    return total
end

return SpriteManager