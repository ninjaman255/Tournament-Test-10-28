-- tournament.lua - Complete battle management system (Refactored with API)
local Tournament = {}

local TournamentState = require("scripts/net-game-tourney/tournament-state")
local TournamentUtils = require("scripts/net-game-tourney/tournament-utils")
local TourneyEmitters = require("scripts/net-game-tourney/emitters")
local games = require("scripts/net-games/framework")

-- Battle state tracking
Tournament.active_battles = {}
Tournament.battle_promises = {}

local function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end
local function await(v) return Async.await(v) end


-- NPC weight lookup table
Tournament.NPC_WEIGHTS = {
    ["airman/airman1.zip"] = 50,
    ["blastman/blastman1.zip"] = 60,
    ["burnerman/burnerman1.zip"] = 55,
    ["colonel/colonel1.zip"] = 70,
    ["circusman/circusman1.zip"] = 45,
    ["cutman/cutman1.zip"] = 40,
    ["elementman/elementman1.zip"] = 65,
    ["fireman/fireman1.zip"] = 58,
    ["gbeast-megaman/gbeast-megaman1.zip"] = 80,
    ["gutsman/gutsman1.zip"] = 62,
    ["hatman/hatman1.zip"] = 48,
    ["iceman/iceman1.zip"] = 52,
    ["jammingman/jammingman1.zip"] = 47,
    ["protoman/protoman1.zip"] = 75,
    ["quickman/quickman1.zip"] = 68,
    ["roll/roll1.zip"] = 42,
    ["shadowman/shadowman1.zip"] = 72,
    ["starman/starman1.zip"] = 54,
    ["woodman/woodman1.zip"] = 56
}

-- Get NPC weight for battle calculations
function Tournament.get_npc_weight(npc_id)
    for name, weight in pairs(Tournament.NPC_WEIGHTS) do
        if string.find(npc_id, name) then
            return weight
        end
    end
    return 50
end

-- ENHANCED: Initialize battle with proper player state management
function Tournament.initialize_battle(player1_id, player2_id, tournament_id, match_index)
    local battle_id = tournament_id .. "_" .. match_index
    
    print(string.format("[Tournament] Initializing battle %s: %s vs %s", battle_id, player1_id, player2_id))
    
    -- Store battle info
    Tournament.active_battles[battle_id] = {
        player1_id = player1_id,
        player2_id = player2_id,
        tournament_id = tournament_id,
        match_index = match_index,
        started = false,
        completed = false,
        result = nil
    }
    
    -- Prepare players for battle
    local is_player1_npc = string.find(player1_id, ".zip")
    local is_player2_npc = string.find(player2_id, ".zip")
    
    -- Unfreeze and deactivate framework for human players BEFORE battle
    if not is_player1_npc then
        Net.unlock_player_input(player1_id)
        games.deactivate_framework(player1_id)
        Net.close_bbs(player1_id)
    end
    
    if not is_player2_npc then
        Net.unlock_player_input(player2_id)
        games.deactivate_framework(player2_id)
        Net.close_bbs(player2_id)
    end
    
    return battle_id
end
-- In tournament.lua, ensure battle flow matches working code

-- Fix the battle initiation to use Async directly
function Tournament.start_battle(player1_id, player2_id, tournament_id, match_index)
    return async(function()
        local is_player1_npc = string.find(player1_id, ".zip")
        local is_player2_npc = string.find(player2_id, ".zip")
        
        print("[Tournament] Starting battle: " .. player1_id .. " vs " .. player2_id)
        
        if is_player1_npc and is_player2_npc then
            -- NPC vs NPC - use weighted random from working code
            local npc1_weight = Tournament.get_npc_weight(player1_id)
            local npc2_weight = Tournament.get_npc_weight(player2_id)
            local total_weight = npc1_weight + npc2_weight
            local random_val = math.random(1, total_weight)
            
            local winner_id = random_val <= npc1_weight and player1_id or player2_id
            local loser_id = winner_id == player1_id and player2_id or player1_id
            
            -- Use Async.sleep like working code
            await(Async.sleep(2.0))
            
            return {player_id = winner_id, health = 100, ran = false}
            
        elseif is_player1_npc or is_player2_npc then
            -- Player vs NPC
            local player_id = is_player1_npc and player2_id or player1_id
            local npc_id = is_player1_npc and player1_id or player2_id
            
            -- Use Async.initiate_encounter directly like working code
            local result = await(Async.initiate_encounter(player_id, npc_id))
            return result
            
        else
            -- PvP battle  
            local result = await(Async.initiate_pvp(player1_id, player2_id))
            return result
        end
    end)
end

-- ENHANCED: Wait for battle completion with timeout using API
function Tournament.wait_for_battle_completion(battle_id, timeout_seconds)
    return async(function()
        timeout_seconds = timeout_seconds or 300 -- 5 minute default timeout
        
        local battle = Tournament.active_battles[battle_id]
        if not battle then
            print("[Tournament] Battle not found: " .. battle_id)
            return nil
        end
        
        if battle.completed then
            return battle.result
        end
        
        local battle_promise = Tournament.battle_promises[battle_id]
        if not battle_promise then
            print("[Tournament] No promise found for battle: " .. battle_id)
            return nil
        end
        
        -- Wait for battle completion or timeout using API
        local completed_promises = await(Async.await_all({
            battle_promise,
            Async.sleep(timeout_seconds)
        }))
        
        local result = completed_promises[1]
        
        if not result then
            print("[Tournament] Battle timeout: " .. battle_id)
            -- Handle timeout - determine winner based on who's still connected
            local player1_connected = Net.is_player(battle.player1_id) and not string.find(battle.player1_id, ".zip")
            local player2_connected = Net.is_player(battle.player2_id) and not string.find(battle.player2_id, ".zip")
            
            if player1_connected and not player2_connected then
                result = {player_id = battle.player1_id, health = 100, ran = false, timeout = true}
            elseif player2_connected and not player1_connected then
                result = {player_id = battle.player2_id, health = 100, ran = false, timeout = true}
            else
                -- Both disconnected or both NPCs - random winner
                local winner_id = math.random(1, 2) == 1 and battle.player1_id or battle.player2_id
                result = {player_id = winner_id, health = 100, ran = false, timeout = true}
            end
            
            -- Record timeout result
            battle.completed = true
            battle.result = result
        end
        
        -- Clean up battle state
        Tournament.cleanup_battle(battle_id)
        
        return result
    end)
end

-- Clean up battle resources
function Tournament.cleanup_battle(battle_id)
    local battle = Tournament.active_battles[battle_id]
    if battle then
        -- Reactivate framework and freeze human players after battle
        if not string.find(battle.player1_id, ".zip") and Net.is_player(battle.player1_id) then
            games.activate_framework(battle.player1_id)
            games.freeze_player(battle.player1_id)
            Net.lock_player_input(battle.player1_id)
        end
        
        if not string.find(battle.player2_id, ".zip") and Net.is_player(battle.player2_id) then
            games.activate_framework(battle.player2_id)
            games.freeze_player(battle.player2_id)
            Net.lock_player_input(battle.player2_id)
        end
        
        -- Clean up state
        Tournament.active_battles[battle_id] = nil
        Tournament.battle_promises[battle_id] = nil
    end
end

-- Helper function to show tournament stage (from your working code)
local function show_tournament_stage(player_id, tournament, stage_type, is_current_state)
    return async(function()
        if not tournament or not tournament.board_data then
            print("[Tournament] No board data stored for tournament")
            return
        end
        
        local player_area = Net.get_player_area(player_id)
        local original_map_name = Net.get_area_name(player_area)
        Net.set_area_name(player_area, "            ")
        local original_map_song = Net.get_song(player_area)
        Net.set_song(player_area, "/server/assets/tourney/music/bbn4_tournament_announcement.ogg")

        games.activate_framework(player_id)
        games.freeze_player(player_id)
        Net.lock_player_input(player_id)
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, 0.3)
        await(Async.sleep(0.3))
        
        -- Setup board background
        local constants = require("scripts/net-game-tourney/constants")
        local ui_data = require("scripts/net-game-tourney/ui-data")
        local ui_data_pos = ui_data.unmoving_ui_pos
        
        -- Setup board background elements
        games.add_ui_element("BOARD BG", player_id, tournament.board_data.background_info.gradient_texture,
            constants.default_background_anim_path_bn4, "BG", ui_data_pos.bg.x, ui_data_pos.bg.y, ui_data_pos.bg.z)
        games.add_ui_element("BOARD GRID", player_id, tournament.board_data.background_info.grid_texture,
            constants.default_grid_anim_path_bn4, "UI", ui_data_pos.grid.x, ui_data_pos.grid.y, ui_data_pos.grid.z)
        games.add_ui_element("TOURNEY TREE", player_id, constants.bracket_bm_bn4,
            constants.default_bracket_anim_path_bn4, "UI", ui_data_pos.bracket.x, ui_data_pos.bracket.y, ui_data_pos.bracket.z)
        games.add_ui_element("CHAMPION TOPPER", player_id, constants.champion_topper_bn4,
            constants.champion_topper_bn4_anim, "UI", ui_data_pos.champion_topper_bn4.x, ui_data_pos.champion_topper_bn4.y, ui_data_pos.champion_topper_bn4.z)
        games.add_ui_element("TITLE BANNER", player_id, constants.default_title_banners.free_tourney,
            constants.default_title_banner_anim, "UI", ui_data_pos.title_banner.x, ui_data_pos.title_banner.y, ui_data_pos.title_banner.z)
        games.add_ui_element("CROWN_1", player_id, constants.crown_texture_path,
            constants.crown_anim_path, "IDLE", ui_data_pos.crown1.x, ui_data_pos.crown1.y, ui_data_pos.crown1.z)
        games.add_ui_element("CROWN_2", player_id, constants.crown_texture_path,
            constants.crown_anim_path, "IDLE", ui_data_pos.crown2.x, ui_data_pos.crown2.y, ui_data_pos.crown2.z)
        
        -- Get positions based on stage type and actual pairings
        local display_positions = {}
        local mug_pos = require("scripts/net-game-tourney/mug-pos")
        
        if is_current_state then
            -- Show current state (positions from end of previous round)
            display_positions = TournamentState.get_current_state_positions(tournament.tournament_id) or {}
            print("[Tournament] Showing CURRENT STATE for round " .. tournament.current_round)
        else
            -- Show updated state (new positions based on current round results)
            if stage_type == "initial" then
                -- Use initial positions
                for i, mugshot_data in ipairs(tournament.board_data.stored_mugshots) do
                    if mug_pos.initial[i] then
                        display_positions[i] = mug_pos.initial[i]
                    end
                end
                
            elseif stage_type == "round1_results" then
                -- Calculate positions based on round 1 pairings
                display_positions = TournamentUtils.calculate_round_positions(tournament, 1)
                
            elseif stage_type == "round2_results" then
                -- Calculate positions based on round 2 pairings
                display_positions = TournamentUtils.calculate_round_positions(tournament, 2)
                
            elseif stage_type == "champion" then
                -- Calculate positions for champion display
                display_positions = TournamentUtils.calculate_round_positions(tournament, 3)
            end
            print("[Tournament] Showing UPDATED STATE for " .. stage_type)
        end
        
        -- Show all participants in their calculated positions
        for i, mugshot_data in ipairs(tournament.board_data.stored_mugshots) do
            if display_positions[i] then
                local pos = display_positions[i]
                games.add_ui_element("MUG_FRAME_" .. i, player_id,
                    "/server/assets/tourney/mini-mug-frame.png", "/server/assets/tourney/mini-mug-frame.anim", 
                    "ACTIVE", pos.x, pos.y, pos.z + 1)
                games.add_ui_element("MUG_" .. i, player_id, mugshot_data.mug_texture,
                    "/server/assets/tourney/mug.anim", "UI", pos.x, pos.y, pos.z, .50, .50)
            elseif mug_pos.initial[i] then
                -- Fallback to initial position
                local pos = mug_pos.initial[i]
                games.add_ui_element("MUG_FRAME_" .. i, player_id,
                    "/server/assets/tourney/mini-mug-frame.png", "/server/assets/tourney/mini-mug-frame.anim", 
                    "ACTIVE", pos.x, pos.y, pos.z + 1)
                games.add_ui_element("MUG_" .. i, player_id, mugshot_data.mug_texture,
                    "/server/assets/tourney/mug.anim", "UI", pos.x, pos.y, pos.z, .50, .50)
            end
        end
        
        -- STORE positions if this is an updated state (not current state display)
        if not is_current_state and stage_type ~= "initial" then
            local round_number = nil
            if stage_type == "round1_results" then round_number = 1
            elseif stage_type == "round2_results" then round_number = 2
            elseif stage_type == "champion" then round_number = 3 end
            
            if round_number then
                TournamentState.store_round_positions(tournament.tournament_id, round_number, display_positions)
                TournamentState.store_current_state_positions(tournament.tournament_id, display_positions)
                print("[Tournament] Stored pairing-based positions for " .. stage_type)
            end
        elseif is_current_state then
            print("[Tournament] Displayed current state, no storage needed")
        end
        
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, 0.3)
        await(Async.sleep(2.0)) -- Show positions
        
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, 0.3)
        await(Async.sleep(0.3))
        
        -- Clean up UI
        for _, element in ipairs(ui_data.frame_names) do
            games.remove_ui_element(element, player_id)
        end
        
        Net.set_area_name(player_area, original_map_name)
        Net.set_song(player_area, original_map_song)
        await(Async.sleep(0.1))
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, 0.3)
        Net.unlock_player_input(player_id)
        games.deactivate_framework(player_id)
    end)
end

-- Helper function to show tournament results with animation
local function show_tournament_results_with_animation(player_id, tournament, round_number)
    return async(function()
        if not tournament or not tournament.board_data then
            print("[Tournament] No board data stored for tournament")
            return
        end
        
        local player_area = Net.get_player_area(player_id)
        local original_map_name = Net.get_area_name(player_area)
        Net.set_area_name(player_area, "            ")
        local original_map_song = Net.get_song(player_area)
        Net.set_song(player_area, "/server/assets/tourney/music/bbn4_tournament_announcement.ogg")

        games.activate_framework(player_id)
        games.freeze_player(player_id)
        Net.lock_player_input(player_id)
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, 0.3)
        await(Async.sleep(0.3))
        
        -- Setup board background once (keep it open throughout)
        local constants = require("scripts/net-game-tourney/constants")
        local ui_data = require("scripts/net-game-tourney/ui-data")
        local ui_data_pos = ui_data.unmoving_ui_pos
        
        games.add_ui_element("BOARD BG", player_id, tournament.board_data.background_info.gradient_texture,
            constants.default_background_anim_path_bn4, "BG", ui_data_pos.bg.x, ui_data_pos.bg.y, ui_data_pos.bg.z)
        games.add_ui_element("BOARD GRID", player_id, tournament.board_data.background_info.grid_texture,
            constants.default_grid_anim_path_bn4, "UI", ui_data_pos.grid.x, ui_data_pos.grid.y, ui_data_pos.grid.z)
        games.add_ui_element("TOURNEY TREE", player_id, constants.bracket_bm_bn4,
            constants.default_bracket_anim_path_bn4, "UI", ui_data_pos.bracket.x, ui_data_pos.bracket.y, ui_data_pos.bracket.z)
        games.add_ui_element("CHAMPION TOPPER", player_id, constants.champion_topper_bn4,
            constants.champion_topper_bn4_anim, "UI", ui_data_pos.champion_topper_bn4.x, ui_data_pos.champion_topper_bn4.y, ui_data_pos.champion_topper_bn4.z)
        games.add_ui_element("TITLE BANNER", player_id, "/server/assets/tourney/title-banner.png",
            "/server/assets/tourney/title-banner.anim", "RED", ui_data_pos.title_banner.x, ui_data_pos.title_banner.y, ui_data_pos.title_banner.z)
        games.add_ui_element("CROWN_1", player_id, constants.crown_texture_path,
            constants.crown_anim_path, "IDLE", ui_data_pos.crown1.x, ui_data_pos.crown1.y, ui_data_pos.crown1.z)
        games.add_ui_element("CROWN_2", player_id, constants.crown_texture_path,
            constants.crown_anim_path, "IDLE", ui_data_pos.crown2.x, ui_data_pos.crown2.y, ui_data_pos.crown2.z)
        
        -- PHASE 1: Show current state positions
        local current_positions = TournamentState.get_current_state_positions(tournament.tournament_id) or {}
        
        -- If no current positions, use initial positions
        if not current_positions or next(current_positions) == nil then
            current_positions = {}
            for i = 1, #tournament.board_data.stored_mugshots do
                local mug_pos = require("scripts/net-game-tourney/mug-pos")
                if mug_pos.initial[i] then
                    current_positions[i] = mug_pos.initial[i]
                end
            end
        end
        
        -- Display all participants in their current positions
        for i, mugshot_data in ipairs(tournament.board_data.stored_mugshots) do
            if current_positions[i] then
                local pos = current_positions[i]
                games.add_ui_element("MUG_FRAME_" .. i, player_id,
                    "/server/assets/tourney/mini-mug-frame.png", "/server/assets/tourney/mini-mug-frame.anim", 
                    "ACTIVE", pos.x, pos.y, pos.z + 1)
                games.add_ui_element("MUG_" .. i, player_id, mugshot_data.mug_texture,
                    "/server/assets/tourney/mug.anim", "UI", pos.x, pos.y, pos.z, .50, .50)
            end
        end
        
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, 0.3)
        await(Async.sleep(0.3))
        
        print("[Tournament] Showing CURRENT STATE for round " .. round_number)
        
        -- Let players see the current state
        await(Async.sleep(1.5))
        
        -- PHASE 2: Calculate new positions and animate transitions
        local new_positions = TournamentUtils.calculate_round_positions(tournament, round_number)
        
        if new_positions and next(new_positions) ~= nil then
            print("[Tournament] Animating transitions to new positions")
            
            -- Enhanced winner detection for all rounds with proper round 3 champion handling
            local winners_to_move = {}
            for i, mugshot_data in ipairs(tournament.board_data.stored_mugshots) do
                local current_pos = current_positions[i]
                local new_pos = new_positions[i]
                
                -- Check if this participant's position changed
                if current_pos and new_pos and 
                   (current_pos.x ~= new_pos.x or current_pos.y ~= new_pos.y) then
                    
                    -- More robust winner detection
                    local is_winner = false
                    
                    if round_number == 1 then
                        -- For round 1, check if they won their match
                        for _, match in ipairs(tournament.matches) do
                            if match.completed and match.winner and match.winner.player_id == mugshot_data.player_id then
                                is_winner = true
                                break
                            end
                        end
                    elseif round_number == 2 then
                        -- For round 2, check if they are in the winners list
                        for _, winner in ipairs(tournament.winners) do
                            if winner.player_id == mugshot_data.player_id then
                                is_winner = true
                                break
                            end
                        end
                    elseif round_number == 3 then
                        -- For round 3, only the champion should move
                        for _, match in ipairs(tournament.matches) do
                            if match.completed and match.winner and match.winner.player_id == mugshot_data.player_id then
                                is_winner = true
                                print("[Tournament] Champion detected: " .. mugshot_data.player_id)
                                break
                            end
                        end
                    end
                    
                    if is_winner then
                        table.insert(winners_to_move, {
                            index = i,
                            mugshot_data = mugshot_data,
                            from_pos = current_pos,
                            to_pos = new_pos
                        })
                        print(string.format("[Tournament] Will move participant %d from (%d,%d) to (%d,%d) - round %d winner", 
                              i, current_pos.x, current_pos.y, new_pos.x, new_pos.y, round_number))
                    end
                end
            end
            
            -- Animate winners moving one by one
            for _, move_data in ipairs(winners_to_move) do
                print(string.format("[Tournament] Moving winner mugshot %d", move_data.index))
                
                -- Remove from old position and add to new position
                games.remove_ui_element("MUG_FRAME_" .. move_data.index, player_id)
                games.remove_ui_element("MUG_" .. move_data.index, player_id)
                
                games.add_ui_element("MUG_FRAME_" .. move_data.index, player_id,
                    "/server/assets/tourney/mini-mug-frame.png", "/server/assets/tourney/mini-mug-frame.anim", 
                    "ACTIVE", move_data.to_pos.x, move_data.to_pos.y, move_data.to_pos.z + 1)
                games.add_ui_element("MUG_" .. move_data.index, player_id, move_data.mugshot_data.mug_texture,
                    "/server/assets/tourney/mug.anim", "UI", move_data.to_pos.x, move_data.to_pos.y, move_data.to_pos.z, .50, .50)
                
                -- Brief pause between each movement
                await(Async.sleep(0.6))
            end
            
            -- Store the new positions as current state
            TournamentState.store_current_state_positions(tournament.tournament_id, new_positions)
            TournamentState.store_round_positions(tournament.tournament_id, round_number, new_positions)
            
            print("[Tournament] Finished animating transitions")
            
            -- Final pause to let players see the updated board
            await(Async.sleep(1.5))
        else
            -- No position changes needed, just show for longer
            await(Async.sleep(2.0))
        end
        
        -- Clean up (only after everything is complete)
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, 0.3)
        await(Async.sleep(0.3))
        
        -- Clean up UI
        for _, element in ipairs(ui_data.frame_names) do
            games.remove_ui_element(element, player_id)
        end
        
        Net.set_area_name(player_area, original_map_name)
        Net.set_song(player_area, original_map_song)
        await(Async.sleep(0.1))
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, 0.3)
        Net.unlock_player_input(player_id)
        games.deactivate_framework(player_id)
    end)
end

-- Add this to tournament.lua
function Tournament.start_all_battles(tournament_id)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then 
            print("[Tournament] Tournament not found: " .. tostring(tournament_id))
            return 
        end
        
        print("[Tournament] Starting all battles for tournament " .. tournament_id .. ", round " .. tournament.current_round)
        
        -- First, unfreeze all players so they can participate in battles
        local real_players = {}
        for _, participant in ipairs(tournament.participants) do
            if not string.find(participant.player_id, ".zip") then
                table.insert(real_players, participant.player_id)
            end
        end
        
        -- Unfreeze players for battles
        TournamentUtils.unfreeze_players(real_players)
        
        -- FIRST: Show current state of the board before any battles
        if tournament.current_round == 1 then
            print("[Tournament] Showing initial tournament board")
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") then
                    -- Show initial board state
                    await(show_tournament_stage(participant.player_id, tournament, "initial", false))
                    await(Async.sleep(0.3)) -- Stagger board displays
                end
            end
            await(Async.sleep(1.0)) -- Additional pause after all boards are shown
        else
            -- For subsequent rounds, show the CURRENT STATE (positions from previous round)
            print("[Tournament] Showing CURRENT STATE before round " .. tournament.current_round .. " battles")
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") then
                    await(show_tournament_stage(participant.player_id, tournament, "current_state", true))
                    await(Async.sleep(0.3)) -- Stagger board displays
                end
            end
            await(Async.sleep(1.0)) -- Additional pause after all boards are shown
        end
        
        -- First, resolve all NPC vs NPC battles instantly for consistency
        for i, match in ipairs(tournament.matches) do
            local player1_id = match.player1.player_id
            local player2_id = match.player2.player_id
            local is_npc_battle = string.find(player1_id, ".zip") and string.find(player2_id, ".zip")
            
            if is_npc_battle then
                print("[Tournament] Resolving NPC vs NPC battle instantly: " .. player1_id .. " vs " .. player2_id)
                await(Tournament.start_battle(player1_id, player2_id, tournament_id, i))
            end
        end
        
        -- Then, run player battles (PvP and PvE)
        for i, match in ipairs(tournament.matches) do
            local player1_id = match.player1.player_id
            local player2_id = match.player2.player_id
            local is_npc_battle = string.find(player1_id, ".zip") and string.find(player2_id, ".zip")
            
            if not is_npc_battle then
                -- Close any open text boxes for human players before battle
                if not string.find(player1_id, ".zip") then
                    Net.close_bbs(player1_id)
                end
                if not string.find(player2_id, ".zip") then
                    Net.close_bbs(player2_id)
                end
                await(Async.sleep(0.3)) -- Pause to ensure text boxes close
                
                -- Start the battle
                print("[Tournament] Starting player battle: " .. player1_id .. " vs " .. player2_id)
                await(Tournament.start_battle(player1_id, player2_id, tournament_id, i))
                
                -- Brief pause between matches
                if i < #tournament.matches then
                    await(Async.sleep(0.5))
                end
            end
        end
        
        print("[Tournament] Finished all battles for round " .. tournament.current_round)
        
        -- Wait a moment to ensure all battle results are processed
        await(Async.sleep(1.0))
        
        -- Check if all matches are completed, if not, manually complete any remaining battles
        local all_matches_completed = true
        for i, match in ipairs(tournament.matches) do
            if not match.completed then
                all_matches_completed = false
                print("[Tournament] Match not completed: " .. match.player1.player_id .. " vs " .. match.player2.player_id)
                
                -- For any remaining NPC vs NPC battles, complete them with predetermined results
                if string.find(match.player1.player_id, ".zip") and string.find(match.player2.player_id, ".zip") then
                    print("[Tournament] Manually completing NPC vs NPC match")
                    await(Tournament.start_battle(match.player1.player_id, match.player2.player_id, tournament_id, i))
                end
            end
        end
        
        -- Show appropriate results board after the round is complete
        if all_matches_completed then
            local results_stage = nil
            if tournament.current_round == 1 then
                results_stage = "round1_results"
            elseif tournament.current_round == 2 then
                results_stage = "round2_results" 
            elseif tournament.current_round == 3 then
                results_stage = "champion"
            end
            
            if results_stage then
                print("[Tournament] Showing tournament UPDATED STATE with animations: " .. results_stage)
                
                local round_number = nil
                if results_stage == "round1_results" then round_number = 1
                elseif results_stage == "round2_results" then round_number = 2
                elseif results_stage == "champion" then round_number = 3 end
                
                -- Use the new animation function for seamless transitions
                for _, participant in ipairs(tournament.participants) do
                    if not string.find(participant.player_id, ".zip") then
                        await(show_tournament_results_with_animation(participant.player_id, tournament, round_number))
                        await(Async.sleep(0.3)) -- Stagger board displays
                    end
                end
                
                await(Async.sleep(1.0)) -- Additional pause after all boards are shown
            end
        end
        
        -- IMPORTANT: Check for remaining real players AFTER board display
        local current_real_players = {}
        for _, winner in ipairs(tournament.winners) do
            if not string.find(winner.player_id, ".zip") then
                table.insert(current_real_players, winner)
            end
        end
        
        -- If no real players remain after this round, end the tournament
        if #current_real_players == 0 then
            print("[Tournament] No real players left after round " .. tournament.current_round .. ", ending tournament")
            
            -- Clean up all original participants
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") then
                    games.deactivate_framework(participant.player_id)
                    TournamentState.remove_player_from_tournament(participant.player_id)
                end
            end
            
            TournamentState.cleanup_tournament(tournament_id)
            return
        end
        
        -- Check if tournament is completed (after 3 rounds)
        if tournament.current_round >= 3 and #tournament.winners == 1 then
            print("[Tournament] Tournament completed! Winner: " .. tournament.winners[1].player_id)
            
            -- Announce winner to all players
            local winner = tournament.winners[1]
            local winner_name = winner.player_id
            if not string.find(winner.player_id, ".zip") then
                winner_name = Net.get_player_name(winner.player_id) or winner.player_id
            end
            
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") then
                    Net.message_player(participant.player_id, "Tournament completed! Winner: " .. winner_name)
                    await(Async.sleep(0.1)) -- Small delay between messages
                end
            end
            
            -- Clean up all players
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") then
                    games.deactivate_framework(participant.player_id)
                    TournamentState.remove_player_from_tournament(participant.player_id)
                end
            end
            
            TournamentState.cleanup_tournament(tournament_id)
            return
        end
        
        -- Check if current host is still in tournament and is a real player
        local current_host = tournament.host_player_id
        local host_still_in_tournament = false
        
        -- Check if host is still in the current winners
        for _, winner in ipairs(tournament.winners) do
            if winner.player_id == current_host then
                host_still_in_tournament = true
                break
            end
        end
        
        -- If host is eliminated or disconnected, assign new host from remaining real players
        if not host_still_in_tournament or not Net.is_player(current_host) or string.find(current_host, ".zip") then
            local new_host = nil
            -- Find first real player in winners to be new host
            for _, winner in ipairs(tournament.winners) do
                if not string.find(winner.player_id, ".zip") then
                    new_host = winner.player_id
                    break
                end
            end
            
            if new_host then
                tournament.host_player_id = new_host
                print("[Tournament] Host eliminated or disconnected. New host: " .. new_host)
                Net.message_player(new_host, "You are now the tournament host!")
                await(Async.sleep(0.1)) -- Wait for message to be read
                current_host = new_host
            else
                print("[Tournament] No real players left to be host, ending tournament")
                -- Clean up all original participants
                for _, participant in ipairs(tournament.participants) do
                    if not string.find(participant.player_id, ".zip") then
                        games.deactivate_framework(participant.player_id)
                        TournamentState.remove_player_from_tournament(participant.player_id)
                    end
                end
                TournamentState.cleanup_tournament(tournament_id)
                return
            end
        end
        
        -- Ask host if they want to start next round
        local start_next_round = await(TournamentUtils.ask_host_about_next_round(tournament_id, TournamentState))
        
        -- DEBUG: Print the host's decision
        print("[Tournament] Host decision for next round: " .. tostring(start_next_round))
        
        if start_next_round then
            -- Advance to next round
            if TournamentState.advance_to_next_round(tournament_id) then
                local tournament = TournamentState.get_tournament(tournament_id)
                if tournament and tournament.status == "COMPLETED" then
                    -- Tournament is complete
                    print("[Tournament] Tournament completed!")
                    
                    -- Announce winner
                    local winner = tournament.winners[1]
                    if winner then
                        local winner_name = winner.player_id
                        if not string.find(winner.player_id, ".zip") then
                            winner_name = Net.get_player_name(winner.player_id) or winner.player_id
                        end
                        
                        for _, participant in ipairs(tournament.participants) do
                            if not string.find(participant.player_id, ".zip") then
                                Net.message_player(participant.player_id, "Tournament completed! Winner: " .. winner_name)
                                await(Async.sleep(0.1)) -- Small delay between messages
                            end
                        end
                    end
                    
                    -- Clean up all players
                    for _, participant in ipairs(tournament.participants) do
                        if not string.find(participant.player_id, ".zip") then
                            games.deactivate_framework(participant.player_id)
                            TournamentState.remove_player_from_tournament(participant.player_id)
                        end
                    end
                else
                    -- Start next round
                    print("[Tournament] Starting next round...")
                    await(Tournament.start_all_battles(tournament_id))
                end
            else
                print("[Tournament] Failed to advance to next round - checking tournament state")
                -- Debug: Check why advancement failed
                local tournament = TournamentState.get_tournament(tournament_id)
                if tournament then
                    print("[Tournament] Tournament status: " .. (tournament.status or "nil"))
                    print("[Tournament] Current round: " .. tournament.current_round)
                    print("[Tournament] Winners count: " .. #tournament.winners)
                    print("[Tournament] Matches count: " .. #tournament.matches)
                    
                    -- Check if all matches are completed
                    local all_matches_completed = true
                    for _, match in ipairs(tournament.matches) do
                        if not match.completed then
                            all_matches_completed = false
                            print("[Tournament] Match not completed: " .. match.player1.player_id .. " vs " .. match.player2.player_id)
                            break
                        end
                    end
                    
                    -- Force advancement if we have winners but some matches didn't complete properly
                    if #tournament.winners > 0 then
                        print("[Tournament] Attempting forced advancement with existing winners")
                        tournament.current_round = tournament.current_round + 1
                        tournament.participants = tournament.winners
                        tournament.winners = {}
                        tournament.matches = TournamentState.generate_matches(tournament.participants)
                        tournament.status = "IN_PROGRESS"
                        
                        -- Start next round
                        print("[Tournament] Starting next round after forced advancement...")
                        await(Tournament.start_all_battles(tournament_id))
                    else
                        print("[Tournament] Cannot force advancement, ending tournament")
                        TournamentState.cleanup_tournament(tournament_id)
                    end
                else
                    print("[Tournament] Tournament not found, ending")
                end
            end
        else
            -- Host chose not to continue, end tournament
            print("[Tournament] Host chose to end tournament after round " .. tournament.current_round)
            
            -- Clean up all players
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") then
                    games.deactivate_framework(participant.player_id)
                    TournamentState.remove_player_from_tournament(participant.player_id)
                end
            end
            
            TournamentState.cleanup_tournament(tournament_id)
        end
        
        -- Re-freeze all players after battles
        TournamentUtils.freeze_players(real_players)
    end)
end

-- Check and emit round complete if all matches are finished
function Tournament.check_and_emit_round_complete(tournament_id)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return false end
    
    local all_completed = true
    for i, match in ipairs(tournament.matches) do
        if not match.completed then
            all_completed = false
            break
        end
    end
    
    if all_completed then
        print("[Tournament] All battles completed for tournament " .. tournament_id .. ", emitting round complete event")
        TourneyEmitters.tourney_emitter:emit("tournament_round_complete", {
            tournament_id = tournament_id,
            round = tournament.current_round,
            winners = tournament.winners
        })
        return true
    end
    
    return false
end

-- ENHANCED: Process battle results from network events with escape handling
function Tournament.process_battle_result_event(event)
    print("[Tournament] Battle results received:", event.player_id, event.health, event.time, event.ran)
    
    local tournament_id = TournamentState.get_tournament_id_by_player(event.player_id)
    if not tournament_id then
        print("[Tournament] Player not in any tournament: " .. event.player_id)
        return
    end
    
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return end
    
    -- Find the match this player was in
    local match_index = nil
    local match = nil
    for i, m in ipairs(tournament.matches) do
        if not m.completed and (m.player1.player_id == event.player_id or m.player2.player_id == event.player_id) then
            match_index = i
            match = m
            break
        end
    end
    
    if not match_index then
        print("[Tournament] No active match found for player: " .. event.player_id)
        return
    end
    
    -- Process battle results to determine winner and loser
    local winner, loser = TournamentUtils.process_battle_results(event, tournament_id, match_index, TournamentState)
    
    if winner and loser then
        -- Record the battle result - IMPORTANT: Mark escape as true if player ran
        TournamentState.record_battle_result(tournament_id, match_index, winner, loser, event.ran)
        
        print("[Tournament] Battle completed: " .. winner.player_id .. " defeated " .. loser.player_id)
        
        if event.ran then
            print("[Tournament] Player ran from battle: " .. event.player_id)
            -- The player who ran is automatically the loser
        end
        
        -- Check if round is complete and emit event if so
        Tournament.check_and_emit_round_complete(tournament_id)
        
        -- Also handle via emitters for other systems
        TourneyEmitters.handle_battle_result(event)
    else
        print("[Tournament] Could not determine battle winner/loser")
    end
end

-- Handle player disconnect during battle
function Tournament.handle_player_disconnect(player_id)
    -- Find any active battles involving this player
    for battle_id, battle in pairs(Tournament.active_battles) do
        if not battle.completed and (battle.player1_id == player_id or battle.player2_id == player_id) then
            print("[Tournament] Player disconnected during battle: " .. player_id)
            
            local opponent_id = battle.player1_id == player_id and battle.player2_id or battle.player1_id
            
            -- Mark battle as completed with opponent as winner
            battle.completed = true
            battle.result = {player_id = opponent_id, health = 100, ran = false, disconnected = player_id}
            
            -- Resolve the battle promise if it exists
            local battle_promise = Tournament.battle_promises[battle_id]
            if battle_promise then
                battle_promise:resolve(battle.result)
            end
            
            -- Record the result in tournament state
            local tournament = TournamentState.get_tournament(battle.tournament_id)
            if tournament and tournament.matches and tournament.matches[battle.match_index] then
                local match = tournament.matches[battle.match_index]
                local winner = match.player1.player_id == opponent_id and match.player1 or match.player2
                local loser = match.player1.player_id == player_id and match.player1 or match.player2
                
                TournamentState.record_battle_result(battle.tournament_id, battle.match_index, winner, loser, true)
            end
            
            -- Clean up the battle
            Tournament.cleanup_battle(battle_id)
            
            break
        end
    end
end

return Tournament
