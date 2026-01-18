-- tournament-flow.lua
local TournamentFlow = {}
local constants = require("scripts/net-game-tourney/tournament-constants")

-- Async/await helpers
local async = function(p) local co = coroutine.create(p) return Async.promisify(co) end
local await = function(v) return Async.await(v) end

-- Store original area states for restoration
local original_area_states = {}

-- Run a tournament
function TournamentFlow.run_tournament(tournament_id)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then
            print("[Flow] Tournament not found: " .. tournament_id)
            return
        end
        
        print(string.format("[Flow] Starting tournament %d with %d participants", 
              tournament_id, #tournament.participants))
        
        -- Set initial round to 0 and update positions
        tournament.current_round = 0
        TournamentCore.update_positions(tournament_id, 0)
        
        -- Show round 0 board with all participants at bottom (NO PROGRESS BARS)
        await(TournamentFlow.show_board_to_all(tournament_id, "round0"))
        await(Async.sleep(2.0))
        
        -- Close board for all players
        await(TournamentFlow.hide_board_from_all(tournament_id))
        await(Async.sleep(0.5))
        
        -- Run 3 rounds
        for round = 1, 3 do
            print("[Flow] Starting round " .. round)
            tournament.current_round = round
            
            -- Start battles for this round
            await(TournamentFlow.run_round_battles(tournament_id, round))
            
            -- Show board with previous round positions
            await(TournamentFlow.show_board_to_all(tournament_id, "current"))
            await(Async.sleep(1.5))
            
            -- FIRST: Grey-scale losers one by one with 1-second pauses
            await(TournamentFlow.animate_loser_greyscale_one_by_one(tournament_id, round))
            await(Async.sleep(1.0))
            
            -- NEW: Spawn progress bars for winners BEFORE moving them
            await(TournamentFlow.spawn_progress_bars_for_winners(tournament_id, round))
            await(Async.sleep(1.0))
            
            -- THEN: Move winners to their new positions one by one
            await(TournamentFlow.animate_winner_movement_one_by_one(tournament_id, round))
            await(Async.sleep(1.0))
            
            -- If not final round, handle continuation
            if round < 3 then
                -- Close board for decision
                await(TournamentFlow.hide_board_from_all(tournament_id))
                await(Async.sleep(0.5))
                
                -- Ask host about continuing
                local continue, new_host_id = await(TournamentFlow.handle_round_continuation(tournament_id, round))
                if not continue then
                    print("[Flow] Tournament ended after round " .. round)
                    TournamentFlow.cleanup_tournament(tournament_id)
                    return
                end
                
                -- Update host if needed
                if new_host_id then
                    tournament.host_id = new_host_id
                    print(string.format("[Flow] Host changed to %s", new_host_id))
                end
                
                -- Advance to next round
                TournamentCore.complete_round(tournament_id)
                TournamentCore.advance_round(tournament_id)
            else
                -- Final round - wait a moment then announce champion
                await(Async.sleep(1.0))
                await(TournamentFlow.announce_champion(tournament_id))
                await(Async.sleep(3.0))
                await(TournamentFlow.hide_board_from_all(tournament_id))
            end
        end
        
        TournamentFlow.cleanup_tournament(tournament_id)
    end)
end

-- NEW: Announce champion after final round
function TournamentFlow.announce_champion(tournament_id)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        local winner = TournamentCore.get_winner(tournament_id)
        if not winner then
            print("[Flow] No winner found")
            return
        end
        
        -- Show champion announcement
        print("[Flow] Tournament champion: " .. winner.name)
        
        -- Announce to all players
        for _, participant in ipairs(tournament.participants) do
            if participant.type == "player" and Net.is_player(participant.id) then
                Net.message_player(participant.id, "Tournament Complete! Champion: " .. winner.name)
            end
        end
        
        -- Apply greyscale to all non-champion participants one by one
        local non_champions = {}
        for _, participant in ipairs(tournament.participants) do
            if participant.id ~= winner.id then
                table.insert(non_champions, participant)
            end
        end
        
        print(string.format("[Flow] Greyscaling %d non-champions one by one", #non_champions))
        
        for i, participant in ipairs(non_champions) do
            for _, p in ipairs(tournament.participants) do
                if p.type == "player" and Net.is_player(p.id) then
                    local player_id = p.id
                    
                    -- Find the participant's position in UI
                    for j, pos in ipairs(tournament.ui_state.positions) do
                        if pos.participant_id == participant.id then
                            -- Apply greyscale effect
                            local games = require("scripts/net-games/framework")
                            games.update_ui_element("MUG_" .. j, player_id, constants.greyscale_properties)
                            
                            -- Mark as greyscale for tracking
                            TournamentUI.mark_greyscale(tournament_id, player_id, participant.id)
                            print(string.format("[Flow] Grey-scaled %s at position %d for player %s", 
                                  participant.name, j, player_id))
                            break
                        end
                    end
                end
            end
            
            -- Wait 1 second before greyscaling the next non-champion (except for the last one)
            if i < #non_champions then
                print("[Flow] Waiting 1 second before next greyscale...")
                await(Async.sleep(1.0))
            end
        end
    end)
end

-- NEW: Spawn progress bars for winners at the appropriate tier before moving them
function TournamentFlow.spawn_progress_bars_for_winners(tournament_id, round)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local ui_positions = require("scripts/net-game-tourney/ui-pos")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        print(string.format("[Flow] Spawning progress bars for round %d winners", round))
        
        -- For each winner in this round, spawn their appropriate tier progress bar
        if round == 1 then
            -- Spawn tier1 progress bars for round1 winners
            for match_index, match in ipairs(tournament.matches.round1) do
                if match.completed and match.winner then
                    local winner = match.winner
                    local tier1_index = (match_index * 2) - 1
                    
                    -- Update UI for all players to show the progress bar
                    for _, participant in ipairs(tournament.participants) do
                        if participant.type == "player" and Net.is_player(participant.id) then
                            local bottom_positions = ui_positions.get_progress_bar_positions("bottom")
                            if bottom_positions[tier1_index] then
                                TournamentUI.add_progress_bar(participant.id, "TIER1_" .. tier1_index, "bottom", 
                                    bottom_positions[tier1_index].x, bottom_positions[tier1_index].y, 
                                    bottom_positions[tier1_index].z, tier1_index)
                                TournamentUI.mark_progress_bar_spawned(tournament_id, participant.id, winner.id, "tier1")
                            end
                        end
                    end
                    
                    print(string.format("[Flow] Spawned tier1 progress bar for winner %s at index %d", 
                          winner.name, tier1_index))
                end
            end
            
        elseif round == 2 then
            -- Spawn tier2 progress bars for round2 winners
            for match_index, match in ipairs(tournament.matches.round2) do
                if match.completed and match.winner then
                    local winner = match.winner
                    local tier2_index = (match_index * 2) - 1
                    
                    -- Update UI for all players to show the progress bar
                    for _, participant in ipairs(tournament.participants) do
                        if participant.type == "player" and Net.is_player(participant.id) then
                            local middle_positions = ui_positions.get_progress_bar_positions("middle")
                            if middle_positions[tier2_index] then
                                TournamentUI.add_progress_bar(participant.id, "TIER2_" .. tier2_index, "middle", 
                                    middle_positions[tier2_index].x, middle_positions[tier2_index].y, 
                                    middle_positions[tier2_index].z, tier2_index)
                                TournamentUI.mark_progress_bar_spawned(tournament_id, participant.id, winner.id, "tier2")
                            end
                        end
                    end
                    
                    print(string.format("[Flow] Spawned tier2 progress bar for winner %s at index %d", 
                          winner.name, tier2_index))
                end
            end
            
        elseif round == 3 then
            -- Spawn tier3 progress bar for champion
            local final_match = tournament.matches.round3[1]
            if final_match and final_match.completed and final_match.winner then
                local champion = final_match.winner
                
                -- Update UI for all players to show the progress bar
                for _, participant in ipairs(tournament.participants) do
                    if participant.type == "player" and Net.is_player(participant.id) then
                        local top_positions = ui_positions.get_progress_bar_positions("top")
                        if top_positions[1] then
                            TournamentUI.add_progress_bar(participant.id, "TIER3_1", "top", 
                                top_positions[1].x, top_positions[1].y, 
                                top_positions[1].z, 1)
                            TournamentUI.mark_progress_bar_spawned(tournament_id, participant.id, champion.id, "tier3")
                        end
                    end
                end
                
                print(string.format("[Flow] Spawned tier3 progress bar for champion %s", champion.name))
            end
        end
        
        print(string.format("[Flow] Completed spawning progress bars for round %d", round))
    end)
end

-- NEW: Animate loser greyscaling one by one with 1-second pauses
function TournamentFlow.animate_loser_greyscale_one_by_one(tournament_id, round)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local games = require("scripts/net-games/framework")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        local round_key = round == 1 and "round1" or (round == 2 and "round2" or "round3")
        local matches = tournament.matches[round_key]
        
        if not matches then return end
        
        print(string.format("[Flow] Animating loser greyscaling one by one for round %d", round))
        
        -- Collect all losers first
        local losers_to_greyscale = {}
        for match_index, match in ipairs(matches) do
            if match.completed and match.loser then
                table.insert(losers_to_greyscale, {
                    match_index = match_index,
                    loser_id = match.loser.id,
                    loser_name = match.loser.name
                })
            end
        end
        
        print(string.format("[Flow] Will greyscale %d losers one by one", #losers_to_greyscale))
        
        -- Process each loser one by one with 1-second pauses
        for i, loser_info in ipairs(losers_to_greyscale) do
            local loser_id = loser_info.loser_id
            local loser_name = loser_info.loser_name
            local match_index = loser_info.match_index
            
            print(string.format("[Flow] Greyscaling loser %d/%d: %s from match %d", 
                  i, #losers_to_greyscale, loser_name, match_index))
            
            -- Apply greyscale to loser for all players in the tournament
            for _, participant in ipairs(tournament.participants) do
                if participant.type == "player" and Net.is_player(participant.id) then
                    local player_id = participant.id
                    
                    -- Find the loser's current position in UI
                    for j, pos in ipairs(tournament.ui_state.positions) do
                        if pos.participant_id == loser_id then
                            -- Apply greyscale effect
                            games.update_ui_element("MUG_" .. j, player_id, constants.greyscale_properties)
                            
                            -- Mark as greyscale for tracking
                            TournamentUI.mark_greyscale(tournament_id, player_id, loser_id)
                            print(string.format("[Flow] Grey-scaled %s at position %d for player %s", 
                                  loser_name, j, player_id))
                            break
                        end
                    end
                end
            end
        end
        
        print(string.format("[Flow] Completed loser greyscaling one by one for round %d", round))
    end)
end

-- Animate winner movement for a round (after greyscaling) - also modified to be one by one
function TournamentFlow.animate_winner_movement_one_by_one(tournament_id, round)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local games = require("scripts/net-games/framework")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        local round_key = round == 1 and "round1" or (round == 2 and "round2" or "round3")
        local matches = tournament.matches[round_key]
        
        if not matches then return end
        
        -- Get new positions for this round
        local new_positions = TournamentCore.calculate_round_positions(tournament_id, round)
        if not new_positions then
            print("[Flow] Failed to calculate new positions for round " .. round)
            return
        end
        
        -- Create a map of participant_id to new position for easy lookup
        local new_positions_map = {}
        for _, pos in ipairs(new_positions) do
            new_positions_map[pos.participant_id] = pos
        end
        
        -- Track which participants are winners and need to be moved
        local winners_to_move = {}
        
        -- Collect winners to move
        for _, match in ipairs(matches) do
            if match.completed and match.winner then
                local winner_id = match.winner.id
                local new_pos = new_positions_map[winner_id]
                if new_pos then
                    -- Find current position in UI state
                    local current_pos = nil
                    for _, pos in ipairs(tournament.ui_state.positions) do
                        if pos.participant_id == winner_id then
                            current_pos = pos
                            break
                        end
                    end
                    
                    if current_pos then
                        -- Only add if position actually changed
                        if current_pos.x ~= new_pos.x or current_pos.y ~= new_pos.y then
                            table.insert(winners_to_move, {
                                winner_id = winner_id,
                                winner_name = match.winner.name,
                                current_x = current_pos.x,
                                current_y = current_pos.y,
                                current_z = current_pos.z,
                                new_x = new_pos.x,
                                new_y = new_pos.y,
                                new_z = new_pos.z
                            })
                        end
                    end
                end
            end
        end
        
        print(string.format("[Flow] Moving %d winners one by one for round %d", #winners_to_move, round))
        
        -- Move winners one by one with 1-second pauses
        for i, winner_move in ipairs(winners_to_move) do
            -- Update the tournament's UI state for this winner
            for j, pos in ipairs(tournament.ui_state.positions) do
                if pos.participant_id == winner_move.winner_id then
                    tournament.ui_state.positions[j] = {
                        participant_id = winner_move.winner_id,
                        x = winner_move.new_x,
                        y = winner_move.new_y,
                        z = winner_move.new_z
                    }
                    break
                end
            end
            
            -- Update UI for all players to show the moved winner
            for _, participant in ipairs(tournament.participants) do
                if participant.type == "player" and Net.is_player(participant.id) then
                    TournamentUI.cleanup_participants(participant.id)
                    TournamentUI.show_participants(participant.id, tournament)
                end
            end
            
            -- Announce the winner's movement
            print(string.format("[Flow] Moved winner %d/%d: %s", i, #winners_to_move, winner_move.winner_name))
            
            -- Wait 1 second before moving the next winner (except for the last one)
            if i < #winners_to_move then
                print("[Flow] Waiting 1 second before next winner movement...")
                await(Async.sleep(1.0)) -- 1 second delay between movements
            end
        end
        
        -- Update the round in UI state
        tournament.ui_state.round = round
        
        print(string.format("[Flow] Completed animated winner movement for round %d", round))
    end)
end

-- Handle round continuation with host management
function TournamentFlow.handle_round_continuation(tournament_id, round)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return false, nil end
        
        -- Check if host is still in tournament and is a winner
        local host_is_winner = false
        local host_still_in = false
        
        -- First, find current host
        for _, participant in ipairs(tournament.participants) do
            if participant.type == "player" and participant.id == tournament.host_id then
                host_still_in = true
                -- Check if host is a winner in current round
                local round_key = round == 1 and "round1" or (round == 2 and "round2")
                for _, match in ipairs(tournament.matches[round_key] or {}) do
                    if match.completed and match.winner and match.winner.id == tournament.host_id then
                        host_is_winner = true
                        break
                    end
                end
                break
            end
        end
        
        -- If host is disconnected or not a winner, try to find a new host among human winners
        local new_host_id = nil
        if not host_still_in or not host_is_winner then
            -- Find human winners in current round
            local human_winners = {}
            local round_key = round == 1 and "round1" or (round == 2 and "round2")
            
            for _, match in ipairs(tournament.matches[round_key] or {}) do
                if match.completed and match.winner and match.winner.type == "player" then
                    table.insert(human_winners, match.winner.id)
                end
            end
            
            if #human_winners > 0 then
                -- Pick first available human winner
                for _, player_id in ipairs(human_winners) do
                    if Net.is_player(player_id) then
                        new_host_id = player_id
                        break
                    end
                end
            end
        end
        
        -- Ask about continuation (using appropriate host)
        local host_to_ask = new_host_id or tournament.host_id
        if host_to_ask and Net.is_player(host_to_ask) then
            Net.message_player(host_to_ask, string.format("Round %d complete! Continue to next round?", round))
            local choice = await(Async.quiz_player(host_to_ask, "Continue", "End Tournament"))
            
            return choice == 0, new_host_id
        else
            -- No human players left, auto-continue
            print("[Flow] No human players left, auto-continuing")
            return true, nil
        end
    end)
end

-- Run battles for a round
function TournamentFlow.run_round_battles(tournament_id, round)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        local round_key = round == 1 and "round1" or (round == 2 and "round2" or "round3")
        local matches = tournament.matches[round_key]
        
        if not matches then
            print("[Flow] No matches for round " .. round)
            return
        end
        
        print("[Flow] Running " .. #matches .. " battles")
        
        for i, match in ipairs(matches) do
            print(string.format("[Flow] Match %d: %s vs %s", i, match.player1.name, match.player2.name))
            
            -- Check if player is involved
            local is_player_battle = match.player1.type == "player" or match.player2.type == "player"
            
            if is_player_battle then
                -- Player battle
                print("[Flow] Starting player battle...")
                await(TournamentFlow.start_player_battle(tournament_id, round, i, match))
            else
                -- NPC battle
                print("[Flow] Starting NPC battle...")
                await(TournamentFlow.resolve_npc_battle(tournament_id, round, i, match))
            end
            
            await(Async.sleep(0.5))
        end
    end)
end

-- Start player battle
function TournamentFlow.start_player_battle(tournament_id, round, match_index, match)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        
        local p1_id, p2_id = match.player1.id, match.player2.id
        local p1_type, p2_type = match.player1.type, match.player2.type
        
        print(string.format("[Flow] Player battle: %s (%s) vs %s (%s)", 
              p1_id, p1_type, p2_id, p2_type))
        
        -- Determine which is player and which is opponent
        local player_id, opponent_id, opponent_is_npc
        if p1_type == "player" and p2_type == "npc" then
            player_id = p1_id
            opponent_id = p2_id
            opponent_is_npc = true
        elseif p2_type == "player" and p1_type == "npc" then
            player_id = p2_id
            opponent_id = p1_id
            opponent_is_npc = true
        elseif p1_type == "player" and p2_type == "player" then
            player_id = p1_id
            opponent_id = p2_id
            opponent_is_npc = false
        else
            print("[Flow] No player in this match, should be NPC battle")
            await(TournamentFlow.resolve_npc_battle(tournament_id, round, match_index, match))
            return
        end
        
        -- Check if player is connected
        if not Net.is_player(player_id) then
            print("[Flow] Player disconnected: " .. player_id)
            -- Player disconnected, opponent wins by default
            TournamentCore.record_battle_result(tournament_id, round, match_index, opponent_id, player_id)
            return
        end
        
        -- Start the battle
        Net.lock_player_input(player_id)
        
        local battle_result
        if opponent_is_npc then
            print(string.format("[Flow] Starting PvE battle: %s vs NPC %s", player_id, opponent_id))
            battle_result = await(Async.initiate_encounter(player_id, opponent_id))
        else
            -- Check if opponent is connected
            if not Net.is_player(opponent_id) then
                print("[Flow] Opponent disconnected: " .. opponent_id)
                -- Opponent disconnected, player wins by default
                TournamentCore.record_battle_result(tournament_id, round, match_index, player_id, opponent_id)
                Net.unlock_player_input(player_id)
                return
            end
            
            Net.lock_player_input(opponent_id)
            print(string.format("[Flow] Starting PvP battle: %s vs %s", player_id, opponent_id))
            battle_result = await(Async.initiate_pvp(player_id, opponent_id))
            Net.unlock_player_input(opponent_id)
        end
        
        Net.unlock_player_input(player_id)
        
        -- Process battle result
        if battle_result then
            print("[Flow] Battle completed, processing result...")
            print(string.format("[Flow] Battle data: player_id=%s, health=%d, reason=%d", 
                  battle_result.player_id, battle_result.health or 0, battle_result.reason or 0))
            
            if battle_result.enemies then
                print(string.format("[Flow] Enemies count: %d", #battle_result.enemies))
                for i, enemy in ipairs(battle_result.enemies) do
                    print(string.format("[Flow] Enemy %d: id=%s, health=%d", i, enemy.id, enemy.health))
                end
            end
            
            -- Determine winner based on battle result
            local winner_id, loser_id
            
            -- Check battle reason
            -- Reason 1: Player ran away
            -- Reason 2, 3, 4: Player lost (different defeat conditions)
            -- Reason 0 or other: Check health/enemies
            if battle_result.reason and (battle_result.reason == 1 or 
                                         battle_result.reason == 2 or 
                                         battle_result.reason == 3 or 
                                         battle_result.reason == 4) then
                -- Player ran away or lost - opponent wins
                winner_id = opponent_id
                loser_id = player_id
                print(string.format("[Flow] Player lost (reason=%d), opponent wins", battle_result.reason))
            else
                -- No losing reason specified, check health and enemies
                local player_alive = (battle_result.health or 0) > 0
                
                -- Check enemies status
                local all_enemies_defeated = true
                if battle_result.enemies and #battle_result.enemies > 0 then
                    for _, enemy in ipairs(battle_result.enemies) do
                        if enemy.health > 0 then
                            all_enemies_defeated = false
                            print(string.format("[Flow] Enemy %s still alive with %d health", enemy.id, enemy.health))
                            break
                        end
                    end
                else
                    -- No enemies in result, assume all defeated
                    print("[Flow] No enemies in battle result, assuming all defeated")
                end
                
                if player_alive and all_enemies_defeated then
                    -- Player survived and all enemies defeated
                    winner_id = player_id
                    loser_id = opponent_id
                    print("[Flow] Player survived and all enemies defeated, player wins")
                else
                    -- Player died or enemies survived
                    winner_id = opponent_id
                    loser_id = player_id
                    print("[Flow] Player died or enemies survived, opponent wins")
                end
            end
            
            -- Record the result
            TournamentCore.record_battle_result(tournament_id, round, match_index, winner_id, loser_id)
            print(string.format("[Flow] Recorded result: %s defeated %s", winner_id, loser_id))
            
        else
            print("[Flow] No battle result received, using NPC resolution")
            -- Fall back to NPC resolution
            await(TournamentFlow.resolve_npc_battle(tournament_id, round, match_index, match))
        end
    end)
end

-- Resolve NPC battle
function TournamentFlow.resolve_npc_battle(tournament_id, round, match_index, match)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        
        local npc1_id, npc2_id = match.player1.id, match.player2.id
        print(string.format("[Flow] NPC battle: %s vs %s", npc1_id, npc2_id))
        
        local result = TournamentCore.get_npc_battle_result(tournament_id, round, match_index, npc1_id, npc2_id)
        
        if result then
            TournamentCore.record_battle_result(tournament_id, round, match_index, result.winner_id, result.loser_id)
            print(string.format("[Flow] NPC result: %s defeated %s", result.winner_id, result.loser_id))
            
            -- Simulate battle time
            await(Async.sleep(1.0))
        else
            print("[Flow] Failed to get NPC battle result")
        end
    end)
end

-- Show board to all players
function TournamentFlow.show_board_to_all(tournament_id, view_type)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local constants = require("scripts/net-game-tourney/tournament-constants")
        local games = require("scripts/net-games/framework")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        -- Show to all players
        for _, participant in ipairs(tournament.participants) do
            if participant.type == "player" and Net.is_player(participant.id) then
                local player_id = participant.id
                local area_id = Net.get_player_area(player_id)
                
                -- Save area state
                original_area_states[player_id] = {
                    song = Net.get_song(area_id),
                    name = Net.get_area_name(area_id),
                    area_id = area_id
                }
                
                -- Setup for tournament view
                Net.set_song(area_id, constants.tournament_music)
                Net.set_area_name(area_id, "Tournament")
                
                -- Show UI
                Net.lock_player_input(player_id)
                Net.toggle_player_hud(player_id)
                
                TournamentUI.show_transition(player_id, false, 0.3)
                await(Async.sleep(0.3))
                
                TournamentUI.show_board(player_id, tournament, view_type)
                
                TournamentUI.show_transition(player_id, true, 0.3)
                await(Async.sleep(0.3))
            end
        end
    end)
end

-- Hide board from all players
function TournamentFlow.hide_board_from_all(tournament_id)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local games = require("scripts/net-games/framework")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        for _, participant in ipairs(tournament.participants) do
            if participant.type == "player" and Net.is_player(participant.id) then
                local player_id = participant.id
                
                TournamentUI.show_transition(player_id, false, 0.3)
                await(Async.sleep(0.3))
                
                TournamentUI.cleanup(player_id, tournament_id)
                
                TournamentUI.show_transition(player_id, true, 0.3)
                Net.unlock_player_input(player_id)
                Net.toggle_player_hud(player_id)
                
                -- Restore area state if we have it
                local state = original_area_states[player_id]
                if state then
                    Net.set_song(state.area_id, state.song)
                    Net.set_area_name(state.area_id, state.name)
                    original_area_states[player_id] = nil
                end
            end
        end
    end)
end

-- Cleanup tournament
function TournamentFlow.cleanup_tournament(tournament_id)
    local TournamentCore = require("scripts/net-game-tourney/tournament-core")
    local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
    
    local tournament = TournamentCore.get_tournament(tournament_id)
    if not tournament then return end
    
    -- Cleanup UI for players
    for _, participant in ipairs(tournament.participants) do
        if participant.type == "player" and Net.is_player(participant.id) then
            TournamentUI.cleanup(participant.id, tournament_id)
            
            -- Restore area state if still saved
            local state = original_area_states[participant.id]
            if state then
                Net.set_song(state.area_id, state.song)
                Net.set_area_name(state.area_id, state.name)
                original_area_states[participant.id] = nil
            end
        end
    end
    
    -- Cleanup state
    TournamentCore.cleanup_tournament(tournament_id)
    
    print("[Flow] Tournament cleanup complete")
end

return TournamentFlow