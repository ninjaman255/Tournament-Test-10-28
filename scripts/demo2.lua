
local framework = require("scripts/net-games/framework")

-- Shorthand for async/await
local function async(p)
  local co = coroutine.create(p)
  return Async.promisify(co)
end
local function await(v) return Async.await(v) end

-- Example 1: Spawn a UI element (legacy framework API)
function spawn_ui_element_example(player_id)
    -- This uses the existing framework.add_ui_element() which internally uses SpriteManager
    local texture_path = "/server/assets/net-games/text_cursor.png"
    local animation_path = "/server/assets/net-games/text_cursor.animation"
    
    -- Add a UI element at position (100, 80) with scale 1.0
    framework.add_ui_element("example_ui", player_id, texture_path, animation_path, "idle", 100, 80, 0, 1.0, 1.0)
    
    print("UI element spawned at (100, 80)")
end

-- Example 2: Spawn a sprite using the new SpriteManager API
function spawn_sprite_example(player_id)
    -- First, register the sprite asset (get a sprite_id)
    local texture_path = "/server/assets/net-games/text_cursor.png"
    local animation_path = "/server/assets/net-games/text_cursor.animation"
    
    -- Note: In the current implementation, register_sprite just returns an ID
    -- The actual allocation happens per-player when create_sprite is called
    local sprite_id = framework.register_sprite(texture_path, animation_path, "default")
    
    -- Create a sprite object at position (0, 0)
    -- obj_id must be unique for each sprite instance
    local obj_id = "example_sprite_obj"
    
    framework.create_sprite(player_id, sprite_id, obj_id, {
        x = 0,
        y = 0,
        z = 0,
        sx = 1.0,
        sy = 1.0,
        anim_state = "idle",
        texture_path = texture_path,
        anim_path = animation_path
    })
    
    print("Sprite created at (0, 0)")
    
    -- Return the object ID so we can animate it
    return obj_id
end

-- Example 3: Move a sprite from (0,0) to (240,160) over 10 seconds
function move_sprite_example(player_id, obj_id)
    -- Use the interpolation function to move smoothly
    framework.move_sprite_to(player_id, obj_id, 240, 160, 10.0, "linear")
    
    print("Moving sprite from (0, 0) to (240, 160) over 10 seconds")
    
    -- You can also set up a callback when the movement is complete
    framework.interpolate_sprite(player_id, obj_id, 
        {x = 240, y = 160},  -- Target position
        {
            duration = 10.0,
            easing = "linear",
            on_complete = function()
                print("Movement complete!")
                
                -- Example: Start pulsing after movement
                framework.pulse_sprite(player_id, obj_id, 0.8, 1.2, 1.0, 3)
            end
        }
    )
end

-- Example 4: Comprehensive example with chained animations
function comprehensive_sprite_demo(player_id)
    -- Register and create sprite
    local texture_path = "/server/assets/net-games/text_cursor.png"
    local animation_path = "/server/assets/net-games/text_cursor.animation"
    local sprite_id = framework.register_sprite(texture_path, animation_path, "idle")
    local obj_id = "demo_sprite_obj"
    
    -- Create sprite at starting position
    framework.create_sprite(player_id, sprite_id, obj_id, {
        x = 0,
        y = 0,
        sx = 0.5,
        sy = 0.5,
        anim_state = "idle",
        a = 255,  -- Full opacity
        texture_path = texture_path,
        anim_path = animation_path
    })
    
    print("Starting comprehensive sprite demo...")
    
    -- Chain multiple animations
    -- 1. Move to (240, 160) over 10 seconds
    framework.move_sprite_to(player_id, obj_id, 240, 160, 10.0, "ease_in_out")
    
    -- 2. After 3 seconds, start scaling up
    async(function()
        await(Async.sleep(3.0))
        framework.scale_sprite_to(player_id, obj_id, 1.5, 2.0, "ease_in_out")
    end)
    
    -- 3. After 5 seconds, fade out
    async(function()
        await(Async.sleep(5.0))
        framework.fade_sprite_to(player_id, obj_id, 128, 2.0, "linear")
    end)
    
    -- 4. After movement completes, rotate and pulse
    async(function()
        await(Async.sleep(10.0))  -- Wait for movement to complete
        framework.rotate_sprite_to(player_id, obj_id, 360, 3.0, "linear")
        framework.pulse_sprite(player_id, obj_id, 0.8, 1.2, 0.5, 5)
    end)
    
    return obj_id
end

-- Example 5: Using the framework's built-in slide function for UI elements
function slide_ui_element_example(player_id)
    -- First add a UI element
    local texture_path = "/server/assets/net-games/text_cursor.png"
    local animation_path = "/server/assets/net-games/text_cursor.animation"
    
    framework.add_ui_element("sliding_ui", player_id, texture_path, animation_path, "default", 0, 0, 0, 1.0, 1.0)
    
    -- Slide it across the screen
    framework.slide_ui_element("sliding_ui", player_id, 240, 160, 10.0)
    
    print("UI element sliding from (0, 0) to (240, 160) over 10 seconds")
end

-- Example 6: Creating and managing multiple sprites
function multiple_sprites_example(player_id)
    local sprites = {}
    
    -- Create 5 sprites in a row
    for i = 1, 5 do
        local texture_path = "/server/assets/net-games/text_cursor.png"
        local animation_path = "/server/assets/net-games/text_cursor.animation"
        local sprite_id = framework.register_sprite(texture_path, animation_path, "idle")
        local obj_id = "multi_sprite_" .. i
        
        framework.create_sprite(player_id, sprite_id, obj_id, {
            x = (i - 1) * 60,
            y = 0,
            sx = 0.8,
            sy = 0.8,
            anim_state = "idle",
            texture_path = texture_path,
            anim_path = animation_path
        })
        
        table.insert(sprites, obj_id)
        
        -- Animate each with a delay
        async(function()
            await(Async.sleep(i * 0.5))  -- Staggered start
            framework.move_sprite_to(player_id, obj_id, (i - 1) * 60, 160, 5.0, "ease_in_out")
            framework.pulse_sprite(player_id, obj_id, 0.6, 1.0, 0.8, 0)  -- Infinite pulse
        end)

    
    print("Created 5 sprites with staggered animations")
    return sprites
    end
end

-- Example usage in a game context
Net:on("player_join", function(event)
    local player_id = event.player_id
    
    -- Wait a moment for player to load
    async(function()
        await(Async.sleep(2.0))
        
        print("Starting sprite demonstrations for player " .. player_id)
        
        -- Demo 1: Basic UI element
        spawn_ui_element_example(player_id)
        
        -- Demo 2: Sprite with movement
        await(Async.sleep(1.0))
        local sprite_obj = spawn_sprite_example(player_id)
        await(Async.sleep(1.0))
        move_sprite_example(player_id, sprite_obj)
        
        -- Demo 3: Comprehensive demo
        await(Async.sleep(12.0))  -- Wait for first movement to complete
        comprehensive_sprite_demo(player_id)
        
        -- Demo 4: Multiple sprites
        await(Async.sleep(15.0))
        multiple_sprites_example(player_id)
    end)
end)

-- Helper function to test from console or other scripts
function run_demo_for_player(player_id)
    if not player_id then
        print("Please provide a player_id")
        return
    end
    
    print("Running sprite demos for player: " .. player_id)
    
    -- Run the comprehensive demo
    comprehensive_sprite_demo(player_id)
end

-- Export the functions if this is used as a module
return {
    spawn_ui_element = spawn_ui_element_example,
    spawn_sprite = spawn_sprite_example,
    move_sprite = move_sprite_example,
    comprehensive_demo = comprehensive_sprite_demo,
    slide_ui = slide_ui_element_example,
    multiple_sprites = multiple_sprites_example,
    run_demo = run_demo_for_player
}