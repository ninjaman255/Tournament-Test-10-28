-- tournament-core.lua
local TournamentCore = {}

-- Storage
local tournaments = {} -- tournament_id -> data
local player_tournaments = {} -- player_id -> tournament_id
local npc_results = {} -- Consistent NPC results

-- Helper function to shuffle table
local function shuffle_table(t)
    local shuffled = {}
    for i = 1, #t do
        local pos = math.random(1, #shuffled + 1)
        table.insert(shuffled, pos, t[i])
    end
    return shuffled
end

-- Create a new tournament
function TournamentCore.create_tournament(config)
    local tournament_id = #tournaments + 1
    
    local tournament = {
        id = tournament_id,
        config = config or {},
        participants = {}, -- Will have exactly 8 entries
        matches = {
            round1 = {}, -- 4 matches
            round2 = {}, -- 2 matches
            round3 = {}  -- 1 match
        },
        status = "created", -- created, battling, round_complete, finished
        current_round = 0,
        host_id = config.host_id,
        winners = {},
        ui_state = {
            positions = {},
            round = 0
        },
        created_time = os.time()
    }
    
    tournaments[tournament_id] = tournament
    print(string.format("[Core] Created tournament %d for host %s", tournament_id, config.host_id or "unknown"))
    return tournament_id
end

-- Add a participant
function TournamentCore.add_participant(tournament_id, participant)
    local tournament = tournaments[tournament_id]
    if not tournament then
        print("[Core] Tournament not found: " .. tournament_id)
        return false
    end
    
    if #tournament.participants >= 8 then
        print("[Core] Tournament is full (8/8)")
        return false
    end
    
    -- For real players, check if already in a tournament
    if participant.type == "player" and player_tournaments[participant.id] then
        print("[Core] Player already in tournament: " .. participant.id)
        return false
    end
    
    table.insert(tournament.participants, {
        id = participant.id,
        type = participant.type,
        name = participant.name or participant.id,
        mugshot = participant.mugshot,
        weight = participant.weight or 50,
        original_index = #tournament.participants + 1
    })
    
    -- Track real players
    if participant.type == "player" then
        player_tournaments[participant.id] = tournament_id
        print(string.format("[Core] Added player %s to tournament %d", participant.id, tournament_id))
    else
        print(string.format("[Core] Added NPC %s to tournament %d", participant.name or participant.id, tournament_id))
    end
    
    return true
end

-- Initialize tournament (must have 8 participants)
function TournamentCore.initialize_tournament(tournament_id)
    local tournament = tournaments[tournament_id]
    if not tournament then
        print("[Core] Tournament not found: " .. tournament_id)
        return false
    end
    
    if #tournament.participants ~= 8 then
        print(string.format("[Core] Need 8 participants, have %d", #tournament.participants))
        return false
    end
    
    -- Seed for consistent randomization across all participants
    math.randomseed(tournament.id * 1000 + os.time())
    
    -- Shuffle participants once at the start
    tournament.participants = shuffle_table(tournament.participants)
    
    -- Update original_index after shuffling
    for i, participant in ipairs(tournament.participants) do
        participant.original_index = i
    end
    
    print("[Core] Shuffled participants:")
    for i, p in ipairs(tournament.participants) do
        print(string.format("  Position %d: %s (%s)", i, p.name, p.type))
    end
    
    -- Generate round 1 matches (1v2, 3v4, 5v6, 7v8) from shuffled participants
    tournament.matches.round1 = {}
    for i = 1, 4 do
        local p1_index = (i * 2) - 1
        local p2_index = i * 2
        
        tournament.matches.round1[i] = {
            player1 = tournament.participants[p1_index],
            player2 = tournament.participants[p2_index],
            winner = nil,
            loser = nil,
            completed = false
        }
        
        print(string.format("[Core] Round 1 Match %d: %s vs %s", i,
              tournament.participants[p1_index].name,
              tournament.participants[p2_index].name))
    end
    
    tournament.current_round = 0
    tournament.status = "created"
    
    -- Initialize positions for round 0
    TournamentCore.initialize_positions(tournament_id)
    
    print(string.format("[Core] Tournament %d initialized with round 0", tournament_id))
    return true
end

-- Initialize positions
function TournamentCore.initialize_positions(tournament_id)
    local tournament = tournaments[tournament_id]
    if not tournament then return end
    
    tournament.ui_state.positions = {}
    tournament.ui_state.round = 0
    
    -- Initial positions (all at bottom) - ROUND 0
    local base_positions = {
        {x = 8, y = 132, z = 3},
        {x = 34, y = 132, z = 3},
        {x = 64, y = 132, z = 3},
        {x = 90, y = 132, z = 3},
        {x = 128, y = 132, z = 3},
        {x = 154, y = 132, z = 3},
        {x = 184, y = 132, z = 3},
        {x = 210, y = 132, z = 3}
    }
    
    for i = 1, #tournament.participants do
        tournament.ui_state.positions[i] = {
            participant_id = tournament.participants[i].id,
            x = base_positions[i].x,
            y = base_positions[i].y,
            z = base_positions[i].z
        }
    end
end

-- Calculate positions for a round
function TournamentCore.calculate_round_positions(tournament_id, round)
    local tournament = tournaments[tournament_id]
    if not tournament then return nil end
    
    local new_positions = {}
    
    -- Start with current positions
    for i, pos in ipairs(tournament.ui_state.positions) do
        new_positions[i] = {
            participant_id = pos.participant_id,
            x = pos.x,
            y = pos.y,
            z = pos.z
        }
    end
    
    if round == 0 then
        -- Round 0: All participants at initial positions
        local base_positions = {
            {x = 8, y = 132, z = 3},
            {x = 34, y = 132, z = 3},
            {x = 64, y = 132, z = 3},
            {x = 90, y = 132, z = 3},
            {x = 128, y = 132, z = 3},
            {x = 154, y = 132, z = 3},
            {x = 184, y = 132, z = 3},
            {x = 210, y = 132, z = 3}
        }
        
        for i = 1, #tournament.participants do
            new_positions[i] = {
                participant_id = tournament.participants[i].id,
                x = base_positions[i].x,
                y = base_positions[i].y,
                z = base_positions[i].z
            }
        end
        
    elseif round == 1 then
        -- Move winners to round 1 positions
        local round1_positions = {
            {x = 22, y = 82, z = 3},  -- Match 1 winner
            {x = 78, y = 82, z = 3},  -- Match 2 winner
            {x = 142, y = 82, z = 3}, -- Match 3 winner
            {x = 198, y = 82, z = 3}  -- Match 4 winner
        }
        
        -- Track which positions have been updated
        local updated_positions = {}
        
        for i, match in ipairs(tournament.matches.round1) do
            if match.completed and match.winner then
                local winner_id = match.winner.id
                
                -- Find the position index for this winner
                for j, pos in ipairs(new_positions) do
                    if pos.participant_id == winner_id then
                        new_positions[j] = {
                            participant_id = winner_id,
                            x = round1_positions[i].x,
                            y = round1_positions[i].y,
                            z = round1_positions[i].z
                        }
                        updated_positions[winner_id] = true
                        break
                    end
                end
            end
        end
        
    elseif round == 2 then
        -- Move winners to round 2 positions
        local round2_positions = {
            {x = 50, y = 56, z = 3},  -- Match 1 winner
            {x = 170, y = 56, z = 3}  -- Match 2 winner
        }
        
        local updated_positions = {}
        
        for i, match in ipairs(tournament.matches.round2 or {}) do
            if match.completed and match.winner then
                local winner_id = match.winner.id
                
                for j, pos in ipairs(new_positions) do
                    if pos.participant_id == winner_id then
                        new_positions[j] = {
                            participant_id = winner_id,
                            x = round2_positions[i].x,
                            y = round2_positions[i].y,
                            z = round2_positions[i].z
                        }
                        updated_positions[winner_id] = true
                        break
                    end
                end
            end
        end
        
    elseif round == 3 then
        -- Move champion to top
        local champion_position = {x = 110, y = 34, z = 3}
        
        for _, match in ipairs(tournament.matches.round3 or {}) do
            if match.completed and match.winner then
                local champion_id = match.winner.id
                
                for j, pos in ipairs(new_positions) do
                    if pos.participant_id == champion_id then
                        new_positions[j] = {
                            participant_id = champion_id,
                            x = champion_position.x,
                            y = champion_position.y,
                            z = champion_position.z
                        }
                        break
                    end
                end
                break
            end
        end
    end
    
    return new_positions
end

-- Update positions after a round
function TournamentCore.update_positions(tournament_id, round)
    local tournament = tournaments[tournament_id]
    if not tournament then 
        print("[Core] Tournament not found for position update")
        return false 
    end
    
    -- Calculate new positions based on current round
    local new_positions = TournamentCore.calculate_round_positions(tournament_id, round)
    
    if new_positions then
        tournament.ui_state.positions = new_positions
        tournament.ui_state.round = round
        
        -- Debug: Print positions
        print(string.format("[Core] Updated positions for tournament %d round %d", tournament_id, round))
        for i, pos in ipairs(new_positions) do
            local participant = nil
            for _, p in ipairs(tournament.participants) do
                if p.id == pos.participant_id then
                    participant = p
                    break
                end
            end
            print(string.format("  Position %d: %s at (%d, %d)", 
                  i, participant and participant.name or "Unknown", pos.x, pos.y))
        end
        
        return true
    end
    
    print("[Core] Failed to calculate positions for round " .. tostring(round))
    return false
end

-- Record a battle result
function TournamentCore.record_battle_result(tournament_id, round, match_index, winner_id, loser_id)
    local tournament = tournaments[tournament_id]
    if not tournament then
        print("[Core] Tournament not found: " .. tournament_id)
        return false
    end
    
    local round_key = round == 1 and "round1" or (round == 2 and "round2" or "round3")
    local matches = tournament.matches[round_key]
    
    if not matches or not matches[match_index] then
        print(string.format("[Core] Invalid match: round %d, index %d", round, match_index))
        return false
    end
    
    local match = matches[match_index]
    
    -- Find participants
    local winner, loser
    for _, participant in ipairs(tournament.participants) do
        if participant.id == winner_id then winner = participant end
        if participant.id == loser_id then loser = participant end
        if winner and loser then break end
    end
    
    if not winner or not loser then
        print("[Core] Could not find participants")
        return false
    end
    
    -- Update match
    match.winner = winner
    match.loser = loser
    match.completed = true
    
    -- Track winner
    table.insert(tournament.winners, winner)
    
    print(string.format("[Core] Recorded result: %s defeated %s in round %d match %d",
          winner.name, loser.name, round, match_index))
    
    return true
end

-- Get deterministic NPC battle result
function TournamentCore.get_npc_battle_result(tournament_id, round, match_index, npc1_id, npc2_id)
    local key = string.format("%d_%d_%d", tournament_id, round, match_index)
    
    -- Return cached result if exists
    if npc_results[key] then
        return npc_results[key]
    end
    
    local tournament = tournaments[tournament_id]
    if not tournament then return nil end
    
    -- Find NPC weights
    local npc1_weight, npc2_weight = 50, 50
    for _, participant in ipairs(tournament.participants) do
        if participant.id == npc1_id then npc1_weight = participant.weight end
        if participant.id == npc2_id then npc2_weight = participant.weight end
    end
    
    -- Deterministic RNG
    local seed = tournament.id * 1000 + round * 100 + match_index
    math.randomseed(seed)
    for _ = 1, 10 do math.random() end -- Warm up
    
    -- Determine winner
    local total_weight = npc1_weight + npc2_weight
    local roll = math.random(1, total_weight)
    local winner_id = roll <= npc1_weight and npc1_id or npc2_id
    local loser_id = winner_id == npc1_id and npc2_id or npc1_id
    
    local result = {
        winner_id = winner_id,
        loser_id = loser_id,
        health = math.random(50, 100),
        score = math.random(1000, 5000)
    }
    
    -- Cache result
    npc_results[key] = result
    
    print(string.format("[Core] Generated NPC result: %s defeats %s", winner_id, loser_id))
    return result
end

-- Check if round is complete
function TournamentCore.is_round_complete(tournament_id, round)
    local tournament = tournaments[tournament_id]
    if not tournament then return false end
    
    local round_key = round == 1 and "round1" or (round == 2 and "round2" or "round3")
    local matches = tournament.matches[round_key]
    
    if not matches then return false end
    
    for _, match in ipairs(matches) do
        if not match.completed then return false end
    end
    
    return true
end

-- Advance to next round
function TournamentCore.advance_round(tournament_id)
    local tournament = tournaments[tournament_id]
    if not tournament then return false end
    
    if tournament.current_round == 1 then
        -- Move to round 2
        tournament.current_round = 2
        
        -- Get winners from round 1
        local winners = {}
        for _, match in ipairs(tournament.matches.round1) do
            if match.winner then
                table.insert(winners, match.winner)
            end
        end
        
        if #winners ~= 4 then
            print("[Core] Not enough winners for round 2")
            return false
        end
        
        -- Create round 2 matches
        tournament.matches.round2 = {}
        for i = 1, 2 do
            tournament.matches.round2[i] = {
                player1 = winners[(i * 2) - 1],
                player2 = winners[i * 2],
                winner = nil,
                loser = nil,
                completed = false
            }
            
            print(string.format("[Core] Round 2 Match %d: %s vs %s", i,
                  winners[(i * 2) - 1].name, winners[i * 2].name))
        end
        
        tournament.status = "battling"
        return true
        
    elseif tournament.current_round == 2 then
        -- Move to round 3
        tournament.current_round = 3
        
        -- Get winners from round 2
        local winners = {}
        for _, match in ipairs(tournament.matches.round2) do
            if match.winner then
                table.insert(winners, match.winner)
            end
        end
        
        if #winners ~= 2 then
            print("[Core] Not enough winners for round 3")
            return false
        end
        
        -- Create round 3 match
        tournament.matches.round3 = {
            {
                player1 = winners[1],
                player2 = winners[2],
                winner = nil,
                loser = nil,
                completed = false
            }
        }
        
        print(string.format("[Core] Round 3 Final: %s vs %s", winners[1].name, winners[2].name))
        tournament.status = "battling"
        return true
    end
    
    return false
end

-- Mark round as complete
function TournamentCore.complete_round(tournament_id)
    local tournament = tournaments[tournament_id]
    if not tournament then return false end
    
    tournament.status = "round_complete"
    return true
end

-- Get tournament winner
function TournamentCore.get_winner(tournament_id)
    local tournament = tournaments[tournament_id]
    if not tournament then return nil end
    
    if tournament.matches.round3 and tournament.matches.round3[1] then
        return tournament.matches.round3[1].winner
    end
    
    return nil
end

-- Cleanup tournament
function TournamentCore.cleanup_tournament(tournament_id)
    local tournament = tournaments[tournament_id]
    if not tournament then return end
    
    -- Remove player tracking
    for _, participant in ipairs(tournament.participants) do
        if participant.type == "player" then
            player_tournaments[participant.id] = nil
        end
    end
    
    -- Clean up NPC results
    for key, _ in pairs(npc_results) do
        if string.find(key, "^" .. tournament_id .. "_") then
            npc_results[key] = nil
        end
    end
    
    -- Remove tournament
    tournaments[tournament_id] = nil
    
    print("[Core] Cleaned up tournament " .. tournament_id)
end

-- Handle player disconnect
function TournamentCore.handle_player_disconnect(player_id)
    local tournament_id = player_tournaments[player_id]
    if not tournament_id then return end
    
    print(string.format("[Core] Player %s disconnected from tournament %d", player_id, tournament_id))
    
    -- Remove player tracking
    player_tournaments[player_id] = nil
    
    -- Note: In a full implementation, you'd handle disqualification here
end

-- Cleanup orphaned tournaments
function TournamentCore.cleanup_orphaned_tournaments()
    local now = os.time()
    local cleaned = 0
    
    for tournament_id, tournament in pairs(tournaments) do
        -- Clean up tournaments older than 30 minutes
        if now - tournament.created_time > 1800 then
            TournamentCore.cleanup_tournament(tournament_id)
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        print("[Core] Cleaned " .. cleaned .. " orphaned tournaments")
    end
end

-- Getter functions
function TournamentCore.get_tournament(tournament_id)
    return tournaments[tournament_id]
end

function TournamentCore.get_player_tournament(player_id)
    return player_tournaments[player_id]
end

function TournamentCore.is_player_in_tournament(player_id)
    return player_tournaments[player_id] ~= nil
end

return TournamentCore