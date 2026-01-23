-- tournament-manager.lua
local TournamentManager = {}

-- Async/await helpers
local async = function(p) local co = coroutine.create(p) return Async.promisify(co) end
local await = function(v) return Async.await(v) end

local games = require("scripts/net-games/framework")
local TournamentCore = require("scripts/net-game-tourney/tournament-core")
local TournamentFlow = require("scripts/net-game-tourney/tournament-flow")
local tournament_npcs = require("scripts/net-game-tourney/tournament-npcs")
local tournament_ui = require("scripts/net-game-tourney/tournament-ui")
local ui_pos = require("scripts/net-game-tourney/ui-pos")
local constants = require("scripts/net-game-tourney/tournament-constants")

local waiting_queues = {} -- board_id -> {players = {}, host_id, area_id}
local active_interactions = {} -- Prevent duplicate interactions
-- Track all players in waiting queues across all boards
local all_queued_players = {} -- player_id -> board_id

-- Initialize the tournament system
function TournamentManager.init()
    print("[Tournament Manager] Initializing tournament system...")
    -- Framework is already started by main.lua
end

-- Create a single-player tournament
function TournamentManager.create_single_player_tournament(player_id, board_id, area_id, theme, title)
    return async(function()
        -- Get player info
        local player_name = Net.get_player_name(player_id) or "Player"
        local player_mugshot = Net.get_player_mugshot(player_id)
        
        -- Create tournament config
        local config = {
            host_id = player_id,
            theme = theme or "red_orange_bn4",
            title = title,  -- Add title to config
            type = "single_player",
            board_id = board_id,
            area_id = area_id
        }
        
        -- Create tournament
        local tournament_id = TournamentCore.create_tournament(config)
        if not tournament_id then 
            Net.message_player(player_id, "Failed to create tournament.")
            return nil 
        end
        
        print(string.format("[Manager] Created tournament %d for player %s", tournament_id, player_id))
        
        -- Add player as participant
        local player_added = TournamentCore.add_participant(tournament_id, {
            id = player_id,
            type = "player",
            name = player_name,
            mugshot = player_mugshot.texture_path,
            weight = 50
        })
        
        if not player_added then
            Net.message_player(player_id, "Could not add player to tournament.")
            TournamentCore.cleanup_tournament(tournament_id)
            return nil
        end
        
        -- Add 7 unique random NPCs for this tournament
        local npcs = tournament_npcs.get_unique_random_npcs(tournament_id, 7)
        local npc_count = 0
        for _, npc in ipairs(npcs) do
            if TournamentCore.add_participant(tournament_id, npc) then
                npc_count = npc_count + 1
            end
        end
        
        print(string.format("[Manager] Added %d unique NPCs to tournament %d", npc_count, tournament_id))
        
        -- Initialize tournament
        if TournamentCore.initialize_tournament(tournament_id) then
            print(string.format("[Manager] Tournament %d initialized successfully", tournament_id))
            return tournament_id
        else
            print("[Manager] Failed to initialize tournament")
            TournamentCore.cleanup_tournament(tournament_id)
            return nil
        end
    end)
end

-- Start a tournament
function TournamentManager.start_tournament(tournament_id)
    return async(function()
        print(string.format("[Manager] Starting tournament %d", tournament_id))
        await(TournamentFlow.run_tournament(tournament_id))
        print(string.format("[Manager] Tournament %d completed", tournament_id))
    end)
end

-- Remove player from all queue tracking
local function remove_player_from_queue_tracking(player_id)
    -- Remove from global queue tracking
    all_queued_players[player_id] = nil
    
    -- Also remove from active interactions
    active_interactions[player_id] = nil
end

-- Handle board interaction
function TournamentManager.handle_board_interaction(player_id, board_object, area_id)
    return async(function()
        -- Prevent duplicate interactions
        if active_interactions[player_id] then
            print("[Manager] Player already in interaction: " .. player_id)
            return
        end
        active_interactions[player_id] = true
        
        -- Check if player is already in a tournament
        if TournamentCore.is_player_in_tournament(player_id) then
            Net.message_player(player_id, "You are already in a tournament!")
            active_interactions[player_id] = nil
            return
        end
        
        -- Check if player is already in any waiting queue
        if all_queued_players[player_id] then
            Net.message_player(player_id, "You are already in a tournament queue!")
            active_interactions[player_id] = nil
            return
        end
        
        -- Get board theme and title from custom properties
        local theme = "red_orange_bn4"
        local board_title = nil
        if board_object.custom_properties then
            theme = board_object.custom_properties["Board Background"] or 
                   board_object.custom_properties["board_theme"] or 
                   "red_orange_bn4"
            -- Read title property if it exists
            board_title = board_object.custom_properties["Board Title"] or 
                         board_object.custom_properties["board_title"]
        end
        
        -- Check if there's a waiting queue for this board
        local board_id = tostring(board_object.id)
        local queue = waiting_queues[board_id]
        
        if not queue then
            -- No existing queue, create a new one
            waiting_queues[board_id] = {
                players = {player_id},
                host_id = player_id,
                area_id = area_id,
                theme = theme,
                title = board_title,  -- Store the title
                waiting = false,
                created_time = os.time()
            }
            queue = waiting_queues[board_id]
            
            -- Track player in global queue
            all_queued_players[player_id] = board_id
            
            print(string.format("[Manager] Created new queue for board %s with player %s", 
                  board_id, player_id))
        else
            -- Existing queue, check if player is already in it
            for _, p in ipairs(queue.players) do
                if p == player_id then
                    Net.message_player(player_id, "You are already in the waiting queue!")
                    active_interactions[player_id] = nil
                    return
                end
            end
            
            -- Add player to queue
            table.insert(queue.players, player_id)
            
            -- Track player in global queue
            all_queued_players[player_id] = board_id
            
            print(string.format("[Manager] Added player %s to queue for board %s (total: %d)", 
                  player_id, board_id, #queue.players))
        end
        
        -- Notify player about queue status
        Net.message_player(player_id, string.format("Tournament queue: %d/8 players", #queue.players))
        
        -- If this is the first player, ask for tournament type
        if #queue.players == 1 then
            await(Async.sleep(0.5))
            Net.message_player(player_id, "Start tournament as:")
            local choice = await(Async.quiz_player(player_id, "Multi-player", "Single Player", "Cancel"))
            
            if choice == 0 then -- Multi-player
                Net.message_player(player_id, "Waiting for more players... (10 seconds)")
                queue.type = "multi_player"
                queue.waiting = true
                
                -- Start countdown
                games.activate_framework(player_id)
                games.spawn_countdown(100, player_id, ui_pos.queue_timer_position.x, ui_pos.queue_timer_position.y, 30, false)
                queue.countdown_player = player_id
                queue.countdown_end = os.time() + 30
                
            elseif choice == 1 then -- Single player
                queue.type = "single_player"
                -- Create single player tournament immediately
                local tournament_id = await(TournamentManager.create_single_player_tournament(
                    player_id, board_id, area_id, theme, board_title
                ))
                
                if tournament_id then
                    -- Remove players from queue tracking
                    for _, pid in ipairs(queue.players) do
                        remove_player_from_queue_tracking(pid)
                    end
                    waiting_queues[board_id] = nil
                    await(TournamentManager.start_tournament(tournament_id))
                end
                
            else -- Cancel
                -- Remove player from tracking
                remove_player_from_queue_tracking(player_id)
                waiting_queues[board_id] = nil
                Net.message_player(player_id, "Cancelled.")
            end
            
        elseif #queue.players >= 2 and #queue.players < 8 then
            -- Additional players joining a multi-player queue
            if queue.type == "multi_player" then
                Net.message_player(player_id, "Joined tournament queue.")
                
                -- Notify all players in queue about new player
                for _, pid in ipairs(queue.players) do
                    if pid ~= player_id then
                        Net.message_player(pid, 
                            string.format("%s joined the queue. Total: %d/8", 
                            Net.get_player_name(player_id) or "Player", #queue.players))
                    end
                end
                
                -- If there was a countdown, reset it
                if queue.countdown_player and Net.is_player(queue.countdown_player) then
                    -- Remove old countdown
                    games.remove_ui_element("countdown", queue.countdown_player)
                    -- Start new countdown
                    games.spawn_countdown(100, queue.countdown_player, ui_pos.queue_timer_position.x, ui_pos.queue_timer_position.y, 30, false)
                    queue.countdown_end = os.time() + 30
                end
            else
                Net.message_player(player_id, "This queue is for single player only.")
                -- Remove from queue
                for i, pid in ipairs(queue.players) do
                    if pid == player_id then
                        table.remove(queue.players, i)
                        remove_player_from_queue_tracking(player_id)
                        break
                    end
                end
            end
            
        elseif #queue.players >= 8 then
            -- Start multi-player tournament with 8 players
            Net.message_player(player_id, "Queue full! Starting tournament...")
            
            -- Notify all players
            for _, pid in ipairs(queue.players) do
                if pid ~= player_id then
                    Net.message_player(pid, "Queue full! Starting tournament...")
                end
            end
            
            -- Create tournament with all players
            local tournament_id = TournamentCore.create_tournament({
                host_id = queue.host_id,
                theme = queue.theme,
                title = queue.title,  -- Pass the title
                type = "multi_player",
                board_id = board_id,
                area_id = area_id
            })
            
            if tournament_id then
                -- Add all players
                for _, pid in ipairs(queue.players) do
                    local player_name = Net.get_player_name(pid) or "Player"
                    local player_mugshot = Net.get_player_mugshot(pid)
                    
                    TournamentCore.add_participant(tournament_id, {
                        id = pid,
                        type = "player",
                        name = player_name,
                        mugshot = player_mugshot.texture_path,
                        weight = 50
                    })
                end
                
                -- Initialize and start
                if TournamentCore.initialize_tournament(tournament_id) then
                    -- Remove players from queue tracking
                    for _, pid in ipairs(queue.players) do
                        remove_player_from_queue_tracking(pid)
                    end
                    -- Clean up queue
                    waiting_queues[board_id] = nil
                    
                    -- Start tournament
                    await(TournamentManager.start_tournament(tournament_id))
                else
                    Net.message_player(player_id, "Failed to initialize tournament.")
                    TournamentCore.cleanup_tournament(tournament_id)
                end
            else
                Net.message_player(player_id, "Failed to create tournament.")
            end
        end
        
        active_interactions[player_id] = nil
    end)
end

-- Handle countdown ended
Net:on("countdown_ended", function(event)
    return async(function()
        local player_id = event.player_id
        
        -- Find which queue this player was waiting in
        for board_id, queue in pairs(waiting_queues) do
            if queue.countdown_player == player_id then
                print(string.format("[Manager] Countdown ended for player %s on board %s", player_id, board_id))
                
                -- Ask what to do
                Net.message_player(player_id, 
                    string.format("Queue has %d/8 players. What would you like to do?", #queue.players))
                
                local choice = await(Async.quiz_player(player_id, "Start with NPCs", "Wait longer", "Cancel"))
                
                if choice == 0 then -- Start with NPCs
                    -- Create tournament with current players + NPCs
                    local tournament_id = TournamentCore.create_tournament({
                        host_id = queue.host_id,
                        theme = queue.theme,
                        title = queue.title,  -- Pass the title
                        type = "multi_player",
                        board_id = board_id,
                        area_id = queue.area_id
                    })
                    
                    if tournament_id then
                        -- Add current players
                        for _, pid in ipairs(queue.players) do
                            local player_name = Net.get_player_name(pid) or "Player"
                            local player_mugshot = Net.get_player_mugshot(pid)
                            
                            TournamentCore.add_participant(tournament_id, {
                                id = pid,
                                type = "player",
                                name = player_name,
                                mugshot = player_mugshot.texture_path,
                                weight = 50
                            })
                        end
                        
                        -- Add unique NPCs to fill remaining slots
                        local slots_needed = 8 - #queue.players
                        if slots_needed > 0 then
                            local npcs = tournament_npcs.get_unique_random_npcs(tournament_id, slots_needed)
                            for _, npc in ipairs(npcs) do
                                TournamentCore.add_participant(tournament_id, npc)
                            end
                        end
                        
                        -- Initialize and start
                        if TournamentCore.initialize_tournament(tournament_id) then
                            -- Remove players from queue tracking
                            for _, pid in ipairs(queue.players) do
                                remove_player_from_queue_tracking(pid)
                            end
                            waiting_queues[board_id] = nil
                            await(TournamentManager.start_tournament(tournament_id))
                        else
                            Net.message_player(player_id, "Failed to initialize tournament.")
                            TournamentCore.cleanup_tournament(tournament_id)
                        end
                    end
                    
                elseif choice == 1 then -- Wait longer
                    games.spawn_countdown(100, player_id, ui_pos.queue_timer_position.x, ui_pos.queue_timer_position.y, 30, false)
                    queue.countdown_end = os.time() + 30
                    
                else -- Cancel
                    -- Remove players from queue tracking
                    for _, pid in ipairs(queue.players) do
                        remove_player_from_queue_tracking(pid)
                    end
                    waiting_queues[board_id] = nil
                    Net.message_player(player_id, "Cancelled.")
                end
                
                break
            end
        end
    end)
end)

-- Handle battle results
function TournamentManager.handle_battle_result(player_id, battle_data)
    print(string.format("[Manager] Processing battle result for %s", player_id))
    -- TournamentFlow handles battle results internally
end

-- Handle player disconnect
function TournamentManager.handle_player_disconnect(player_id)
    print(string.format("[Manager] Player disconnected: %s", player_id))
    
    -- Remove from any waiting queues
    for board_id, queue in pairs(waiting_queues) do
        local new_players = {}
        for _, pid in ipairs(queue.players) do
            if pid ~= player_id then
                table.insert(new_players, pid)
            end
        end
        
        if #new_players == 0 then
            -- Remove all players from tracking
            for _, pid in ipairs(queue.players) do
                remove_player_from_queue_tracking(pid)
            end
            waiting_queues[board_id] = nil
        else
            queue.players = new_players
            -- Update host if needed
            if queue.host_id == player_id and #new_players > 0 then
                queue.host_id = new_players[1]
            end
            -- Remove disconnected player from tracking
            remove_player_from_queue_tracking(player_id)
        end
    end
    
    -- Remove from active interactions
    active_interactions[player_id] = nil
    
    -- Handle tournament cleanup (TournamentCore handles this)
    TournamentCore.handle_player_disconnect(player_id)
end

-- Cleanup orphaned tournaments
function TournamentManager.cleanup_orphaned_tournaments()
    TournamentCore.cleanup_orphaned_tournaments()
end

-- Cleanup expired queues
function TournamentManager.cleanup_expired_queues()
    local now = os.time()
    local cleaned = 0
    
    for board_id, queue in pairs(waiting_queues) do
        -- Clean up queues older than 5 minutes or countdown expired
        if now - queue.created_time > 300 or (queue.countdown_end and now > queue.countdown_end) then
            -- Remove all players from tracking
            for _, pid in ipairs(queue.players) do
                remove_player_from_queue_tracking(pid)
            end
            waiting_queues[board_id] = nil
            cleaned = cleaned + 1
            print("[Manager] Cleaned expired queue for board " .. board_id)
        end
    end
    
    if cleaned > 0 then
        print("[Manager] Cleaned " .. cleaned .. " expired queues")
    end
end

return TournamentManager