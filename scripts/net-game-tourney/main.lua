-- main.lua
print("[Tournament System] Initializing...")

-- Load core modules
local games = require("scripts/net-games/framework")
local TournamentManager = require("scripts/net-game-tourney/tournament-manager")

-- Start the games framework
games.start_framework()

-- Initialize tournament system
TournamentManager.init()

print("[Tournament System] Loaded and ready!")

-- Handle player interactions with tournament boards
Net:on("object_interaction", function(event)
    local player_id = event.player_id
    local area_id = Net.get_player_area(player_id)
    local object = Net.get_object_by_id(area_id, event.object_id)
    
    -- Check if it's a tournament board
    if object and (object.type == "Tournament Board" or (object.custom_properties and 
               (object.custom_properties["Board Background"] or object.custom_properties["board_theme"]))) then
        print(string.format("[Main] Player %s interacted with tournament board in area %s", 
              player_id, area_id))
        
        TournamentManager.handle_board_interaction(player_id, object, area_id)
    end
end)

-- Handle battle results
Net:on("battle_results", function(event)
    print(string.format("[Main] Battle results: player=%s, health=%d, enemies=%d", 
          event.player_id, event.health or 0, #(event.enemies or {})))
    
    TournamentManager.handle_battle_result(event.player_id, event)
end)

-- Handle player disconnects
Net:on("player_disconnect", function(event)
    TournamentManager.handle_player_disconnect(event.player_id)
end)

-- Handle player area transfers (for cleanup)
Net:on("player_transfer_area", function(event)
    -- Could track player movement for tournament state
end)

-- Periodic cleanup (every 30 seconds for tournaments, 60 seconds for queues)
local cleanup_timer = 0
local queue_cleanup_timer = 0
Net:on("on_tick", function(event)
    cleanup_timer = cleanup_timer + event.delta
    queue_cleanup_timer = queue_cleanup_timer + event.delta
    
    if cleanup_timer >= 30 then
        TournamentManager.cleanup_orphaned_tournaments()
        cleanup_timer = 0
    end
    
    if queue_cleanup_timer >= 60 then
        TournamentManager.cleanup_expired_queues()
        queue_cleanup_timer = 0
    end
end)