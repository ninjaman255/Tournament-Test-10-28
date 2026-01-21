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
        
        -- Round 0: Initial display
        print("[Flow] Starting Round 0")
        tournament.current_round = 0
        TournamentCore.update_positions(tournament_id, 0)
        
        -- Show round 0 board with all participants at bottom (NO PROGRESS BARS)
        await(TournamentFlow.show_board_to_all(tournament_id, "round0"))
        await(Async.sleep(2.0))
        
        -- Close board for all players
        await(TournamentFlow.hide_board_from_all(tournament_id))
        await(Async.sleep(0.5))
        
        -- Run Round 1 battles
        print("[Flow] Starting Round 1 battles")
        tournament.current_round = 1
        await(TournamentFlow.run_round_battles(tournament_id, 1))
        
        -- Check if Round 1 is complete before advancing
        if not TournamentCore.is_round_complete(tournament_id, 1) then
            print("[Flow] ERROR: Round 1 not complete, cannot advance!")
            return
        end
        
        -- ADVANCE TO ROUND 2 - CRITICAL FIX
        print("[Flow] Advancing to Round 2...")
        if not TournamentCore.advance_round(tournament_id) then
            print("[Flow] ERROR: Failed to advance to Round 2!")
            return
        end
        
        -- Show board for Round 1 results - NO PROGRESS BARS yet (Round 1 not processed)
        print("[Flow] Showing board for Round 1 results (no progress bars yet)")
        await(TournamentFlow.show_board_to_all(tournament_id, "current"))
        await(Async.sleep(1.5))
        
        -- Process Round 1 matches one by one (spawns progress bars, greyscales losers, moves winners)
        print("[Flow] Processing Round 1 matches one by one...")
        await(TournamentFlow.process_round_one_by_one(tournament_id, 1))
        
        -- Close board after processing Round 1
        await(TournamentFlow.hide_board_from_all(tournament_id))
        await(Async.sleep(0.5))
        
        -- Run Round 2 battles
        print("[Flow] Starting Round 2 battles")
        tournament.current_round = 2
        await(TournamentFlow.run_round_battles(tournament_id, 2))
        
        -- Check if Round 2 is complete before advancing
        if not TournamentCore.is_round_complete(tournament_id, 2) then
            print("[Flow] ERROR: Round 2 not complete, cannot advance!")
            return
        end
        
        -- ADVANCE TO ROUND 3 - CRITICAL FIX
        print("[Flow] Advancing to Round 3...")
        if not TournamentCore.advance_round(tournament_id) then
            print("[Flow] ERROR: Failed to advance to Round 3!")
            return
        end
        
        -- Show board for Round 2 results - NOW SHOULD SHOW ROUND 1 PROGRESS BARS
        print("[Flow] Showing board for Round 2 results (with Round 1 progress bars)")
        await(TournamentFlow.show_board_to_all(tournament_id, "current"))
        await(Async.sleep(1.5))
        
        -- Process Round 2 matches one by one (spawns Round 2 progress bars, greyscales losers, moves winners)
        print("[Flow] Processing Round 2 matches one by one...")
        await(TournamentFlow.process_round_one_by_one(tournament_id, 2))
        
        -- Close board after processing Round 2
        await(TournamentFlow.hide_board_from_all(tournament_id))
        await(Async.sleep(0.5))
        
        -- Run Round 3 battles
        print("[Flow] Starting Round 3 battles")
        tournament.current_round = 3
        await(TournamentFlow.run_round_battles(tournament_id, 3))
        
        -- Check if Round 3 is complete
        if not TournamentCore.is_round_complete(tournament_id, 3) then
            print("[Flow] ERROR: Round 3 not complete!")
            return
        end
        
        -- Show board for Round 3 results - NOW SHOULD SHOW ROUND 1 & 2 PROGRESS BARS
        print("[Flow] Showing board for Round 3 results (with Round 1 & 2 progress bars)")
        await(TournamentFlow.show_board_to_all(tournament_id, "current"))
        await(Async.sleep(1.5))
        
        -- Process Round 3 matches one by one (spawns Round 3 progress bar, greyscales loser, moves champion)
        print("[Flow] Processing Round 3 match...")
        await(TournamentFlow.process_round_one_by_one(tournament_id, 3))
        
        -- Final champion announcement
        await(Async.sleep(1.0))
        await(TournamentFlow.announce_champion(tournament_id))
        await(Async.sleep(3.0))
        
        -- Cleanup
        await(TournamentFlow.hide_board_from_all(tournament_id))
        TournamentFlow.cleanup_tournament(tournament_id)
    end)
end

-- Process a round one by one following the specified flow
function TournamentFlow.process_round_one_by_one(tournament_id, round)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        local round_key = round == 1 and "round1" or (round == 2 and "round2" or "round3")
        local matches = tournament.matches[round_key]
        
        if not matches then 
            print(string.format("[Flow] No matches found for round %d, round_key: %s", round, round_key))
            return 
        end
        
        print(string.format("[Flow] Processing round %d one by one, matches: %d", round, #matches))
        
        -- For Rounds 2 and 3: ensure all previous losers are greyscaled before processing
        if round >= 2 then
            -- Greyscale all losers from previous rounds first
            print(string.format("[Flow] Greyscaling all losers from previous rounds for round %d", round))
            await(TournamentFlow.greyscale_all_previous_losers(tournament_id, round))
            await(Async.sleep(1.0))
        end
        
        -- Process each match in the round one by one
        for match_index, match in ipairs(matches) do
            if match.completed then
                print(string.format("[Flow] Processing match %d in round %d", match_index, round))
                
                -- 1. FIRST: Spawn progress bar for the winner (based on tier and who won)
                if match.winner then
                    print(string.format("[Flow] Spawning progress bar for winner: %s", match.winner.name))
                    await(TournamentFlow.spawn_progress_bar_for_match(tournament_id, round, match_index))
                    await(Async.sleep(0.5))
                end
                
                -- 2. SECOND: Greyscale the loser for this match
                if match.loser then
                    print(string.format("[Flow] Greyscaling loser: %s", match.loser.name))
                    await(TournamentFlow.greyscale_specific_loser(tournament_id, round, match_index))
                    await(Async.sleep(0.5))
                end
                
                -- 3. THIRD: Move the winner to their new position
                if match.winner then
                    print(string.format("[Flow] Moving winner: %s", match.winner.name))
                    await(TournamentFlow.move_winner_for_match(tournament_id, round, match_index))
                    await(Async.sleep(0.5))
                end
                
                -- Wait between matches
                if match_index < #matches then
                    await(Async.sleep(0.5))
                end
            else
                print(string.format("[Flow] Match %d in round %d not completed", match_index, round))
            end
        end
        
        print(string.format("[Flow] Completed processing round %d one by one", round))
    end)
end

-- Greyscale all losers from previous rounds
function TournamentFlow.greyscale_all_previous_losers(tournament_id, current_round)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local games = require("scripts/net-games/framework")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        -- Collect all losers from previous rounds
        local all_previous_losers = {}
        
        for r = 1, current_round - 1 do
            local round_key = r == 1 and "round1" or (r == 2 and "round2" or "round3")
            local matches = tournament.matches[round_key]
            
            if matches then
                for _, match in ipairs(matches) do
                    if match.completed and match.loser then
                        local loser_id = match.loser.id
                        
                        -- Check if not already greyscaled
                        local already_greyscaled = false
                        for _, participant in ipairs(tournament.participants) do
                            if participant.type == "player" and Net.is_player(participant.id) then
                                if TournamentUI.is_greyscale(tournament_id, participant.id, loser_id) then
                                    already_greyscaled = true
                                    break
                                end
                            end
                        end
                        
                        if not already_greyscaled then
                            table.insert(all_previous_losers, {
                                loser_id = loser_id,
                                loser_name = match.loser.name,
                                from_round = r
                            })
                        end
                    end
                end
            end
        end
        
        print(string.format("[Flow] Found %d previous losers to greyscale", #all_previous_losers))
        
        -- Apply greyscale to all previous losers for all players
        for _, participant in ipairs(tournament.participants) do
            if participant.type == "player" and Net.is_player(participant.id) then
                local player_id = participant.id
                
                for _, loser_info in ipairs(all_previous_losers) do
                    -- Find the loser's current position in UI
                    for j, pos in ipairs(tournament.ui_state.positions) do
                        if pos.participant_id == loser_info.loser_id then
                            -- Apply greyscale effect
                            games.update_ui_element("MUG_" .. j, player_id, constants.greyscale_properties)
                            
                            -- Mark as greyscale for tracking
                            TournamentUI.mark_greyscale(tournament_id, player_id, loser_info.loser_id)
                            print(string.format("[Flow] Grey-scaled previous round loser %s at position %d for player %s", 
                                  loser_info.loser_name, j, player_id))
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- Greyscale specific loser from a match
function TournamentFlow.greyscale_specific_loser(tournament_id, round, match_index)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local games = require("scripts/net-games/framework")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        local round_key = round == 1 and "round1" or (round == 2 and "round2" or "round3")
        local matches = tournament.matches[round_key]
        local match = matches[match_index]
        
        if not match or not match.completed or not match.loser then return end
        
        local loser_id = match.loser.id
        local loser_name = match.loser.name
        
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
    end)
end

-- Spawn progress bar for a specific match winner
function TournamentFlow.spawn_progress_bar_for_match(tournament_id, round, match_index)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local ui_positions = require("scripts/net-game-tourney/ui-pos")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        local round_key = round == 1 and "round1" or (round == 2 and "round2" or "round3")
        local matches = tournament.matches[round_key]
        local match = matches[match_index]
        
        if not match or not match.completed or not match.winner then return end
        
        local winner = match.winner
        
        -- Determine which participant won (player1 or player2)
        local winner_is_player1 = (winner.id == match.player1.id)
        
        -- Define progress_bar_index variable in outer scope
        local progress_bar_index = 1
        
        -- Determine which tier and index to use
        if round == 1 then
            -- Round 1: bottom tier progress bars
            progress_bar_index = ui_positions.get_progress_bar_index(1, match_index, winner_is_player1)
            
            -- Update UI for all players to show the progress bar
            for _, participant in ipairs(tournament.participants) do
                if participant.type == "player" and Net.is_player(participant.id) then
                    local player_id = participant.id
                    local bottom_positions = ui_positions.get_progress_bar_positions("bottom")
                    if bottom_positions[progress_bar_index] then
                        TournamentUI.add_progress_bar(player_id, "TIER1_" .. progress_bar_index, "bottom", 
                            bottom_positions[progress_bar_index].x, bottom_positions[progress_bar_index].y, 
                            bottom_positions[progress_bar_index].z, progress_bar_index)
                        TournamentUI.mark_progress_bar_spawned(tournament_id, player_id, winner.id, "tier1")
                        -- Mark Round 1 as processed for this player
                        TournamentUI.mark_round_processed(tournament_id, player_id, 1)
                    end
                end
            end
            
        elseif round == 2 then
            -- Round 2: middle tier progress bars
            progress_bar_index = ui_positions.get_progress_bar_index(2, match_index, winner_is_player1)
            
            -- Update UI for all players to show the progress bar
            for _, participant in ipairs(tournament.participants) do
                if participant.type == "player" and Net.is_player(participant.id) then
                    local player_id = participant.id
                    local middle_positions = ui_positions.get_progress_bar_positions("middle")
                    if middle_positions[progress_bar_index] then
                        TournamentUI.add_progress_bar(player_id, "TIER2_" .. progress_bar_index, "middle", 
                            middle_positions[progress_bar_index].x, middle_positions[progress_bar_index].y, 
                            middle_positions[progress_bar_index].z, progress_bar_index)
                        TournamentUI.mark_progress_bar_spawned(tournament_id, player_id, winner.id, "tier2")
                        -- Mark Round 2 as processed for this player
                        TournamentUI.mark_round_processed(tournament_id, player_id, 2)
                    end
                end
            end
            
        elseif round == 3 then
            -- Round 3: top tier progress bar for champion
            progress_bar_index = ui_positions.get_progress_bar_index(3, match_index, winner_is_player1)
            
            -- Update UI for all players to show the progress bar
            for _, participant in ipairs(tournament.participants) do
                if participant.type == "player" and Net.is_player(participant.id) then
                    local player_id = participant.id
                    local top_positions = ui_positions.get_progress_bar_positions("top")
                    if top_positions[progress_bar_index] then
                        TournamentUI.add_progress_bar(player_id, "TIER3_" .. progress_bar_index, "top", 
                            top_positions[progress_bar_index].x, top_positions[progress_bar_index].y, 
                            top_positions[progress_bar_index].z, progress_bar_index)
                        TournamentUI.mark_progress_bar_spawned(tournament_id, player_id, winner.id, "tier3")
                        -- Mark Round 3 as processed for this player
                        TournamentUI.mark_round_processed(tournament_id, player_id, 3)
                    end
                end
            end
        end
        
        print(string.format("[Flow] Spawned progress bar for winner %s in round %d match %d (is_player1: %s, index: %d)", 
              winner.name, round, match_index, tostring(winner_is_player1), progress_bar_index))
    end)
end

-- Move winner for a specific match
function TournamentFlow.move_winner_for_match(tournament_id, round, match_index)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local games = require("scripts/net-games/framework")
        
        local tournament = TournamentCore.get_tournament(tournament_id)
        if not tournament then return end
        
        local round_key = round == 1 and "round1" or (round == 2 and "round2" or "round3")
        local matches = tournament.matches[round_key]
        local match = matches[match_index]
        
        if not match or not match.completed or not match.winner then return end
        
        local winner_id = match.winner.id
        local winner_name = match.winner.name
        
        -- Get new positions for this round
        local new_positions = TournamentCore.calculate_round_positions(tournament_id, round)
        if not new_positions then return end
        
        -- Find the winner's new position
        local new_pos = nil
        for _, pos in ipairs(new_positions) do
            if pos.participant_id == winner_id then
                new_pos = pos
                break
            end
        end
        
        if not new_pos then return end
        
        -- Find the winner's current position
        local current_pos = nil
        for _, pos in ipairs(tournament.ui_state.positions) do
            if pos.participant_id == winner_id then
                current_pos = pos
                break
            end
        end
        
        if not current_pos then return end
        
        -- Only move if position changed
        if current_pos.x ~= new_pos.x or current_pos.y ~= new_pos.y then
            -- Update the tournament's UI state for this winner
            for j, pos in ipairs(tournament.ui_state.positions) do
                if pos.participant_id == winner_id then
                    tournament.ui_state.positions[j] = {
                        participant_id = winner_id,
                        x = new_pos.x,
                        y = new_pos.y,
                        z = new_pos.z
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
            
            print(string.format("[Flow] Moved winner %s to new position (%d, %d)", 
                  winner_name, new_pos.x, new_pos.y))
        else
            print(string.format("[Flow] Winner %s already at correct position", winner_name))
        end
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
            print("[Flow] No matches for round " .. round .. " (round_key: " .. round_key .. ")")
            return
        end
        
        print("[Flow] Running " .. #matches .. " battles for round " .. round)
        
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
        
        print("[Flow] Completed all battles for round " .. round)
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
            if battle_result.reason and (battle_result.reason == 2 or 
                                         battle_result.reason == 3 or 
                                         battle_result.reason == 4) then
                -- Player ran away or lost - opponent wins
                winner_id = opponent_id
                loser_id = player_id
                print(string.format("[Flow] Player lost (reason=%d), opponent wins", battle_result.reason))
            else
                -- No losing reason specified, check health and enemies
                local player_alive = (battle_result.health or 0) > 0
                
                if player_alive and battle_result.reason == 1 then
                    -- Player survived and all enemies defeated
                    winner_id = player_id
                    loser_id = opponent_id
                    print("[Flow] Player survived and all enemies defeated, player wins")
                else
                    -- Player died
                    winner_id = opponent_id
                    loser_id = player_id
                    print("[Flow] Player died, opponent wins")
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

-- Announce champion after final round
function TournamentFlow.announce_champion(tournament_id)
    return async(function()
        local TournamentCore = require("scripts/net-game-tourney/tournament-core")
        local TournamentUI = require("scripts/net-game-tourney/tournament-ui")
        local games = require("scripts/net-games/framework")
        
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
        
        -- Note: The round 3 loser should already be greyscaled by process_round_one_by_one
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
                
                print(string.format("[Flow] Board shown to player %s (tournament %d, current round: %d)", 
                      player_id, tournament_id, tournament.current_round or 0))
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