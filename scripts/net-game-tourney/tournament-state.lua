-- tournament-state.lua
local TableUtils = require("scripts/table-utils")

local TournamentState = {
    tournaments = {}, -- stores all tournament data
}

-- Create a new tournament and return ID
function TournamentState.create_tournament(object_id, area, creator_player_id)
    local tid = "tourney_"..tostring(math.random(100000,999999))
    TournamentState.tournaments[tid] = {
        id = tid,
        object_id = object_id,
        area = area,
        creator_player_id = creator_player_id,
        participants = {},
        matches = {},
        winners = {},
        current_round = 1,
        status = "PENDING"
    }
    return tid
end

-- Add a participant
function TournamentState.add_participant(tournament_id, participant)
    local t = TournamentState.tournaments[tournament_id]
    if t and participant then
        table.insert(t.participants, participant)
    end
end

-- Get participants
function TournamentState.get_participants(tournament_id)
    local t = TournamentState.tournaments[tournament_id]
    return t and t.participants or {}
end

-- Get tournament by ID
function TournamentState.get_tournament(tournament_id)
    return TournamentState.tournaments[tournament_id]
end

-- Get tournament ID by player
function TournamentState.get_tournament_id_by_player(player_id)
    for tid, t in pairs(TournamentState.tournaments) do
        for _, p in ipairs(t.participants or {}) do
            if p.player_id == player_id then
                return tid
            end
        end
    end
    return nil
end

-- Start a round
function TournamentState.start_round(tournament_id)
    local t = TournamentState.tournaments[tournament_id]
    if not t then return false end
    t.status = "ACTIVE"
    t.matches = {}

    -- simple random pairings for 8 participants or fewer
    local shuffled = TableUtils.shuffle(t.participants or {})
    for i=1,#shuffled,2 do
        if shuffled[i+1] then
            table.insert(t.matches, {
                player1 = shuffled[i],
                player2 = shuffled[i+1],
                completed = false
            })
        end
    end
    return true
end

-- Get current round
function TournamentState.get_current_round(tournament_id)
    local t = TournamentState.tournaments[tournament_id]
    return t and t.current_round or nil
end

-- Record battle result
function TournamentState.record_battle_result(tournament_id, match_index, winner, loser, ran)
    local t = TournamentState.tournaments[tournament_id]
    if not t or not t.matches[match_index] then return end
    local match = t.matches[match_index]
    match.completed = true
    match.winner = winner
    match.loser = loser
    match.ran = ran or false
    table.insert(t.winners, winner)
end

-- Advance round
function TournamentState.advance_to_next_round(tournament_id)
    local t = TournamentState.tournaments[tournament_id]
    if not t then return end
    t.current_round = t.current_round + 1
    local active_matches = {}
    for i=1,#t.winners,2 do
        if t.winners[i+1] then
            table.insert(active_matches, {player1=t.winners[i], player2=t.winners[i+1], completed=false})
        end
    end
    t.matches = active_matches
    t.winners = {}
    if #active_matches == 0 then
        t.status = "COMPLETED"
    else
        t.status = "ACTIVE"
    end
end

-- Store round positions (optional)
function TournamentState.store_round_positions(tournament_id, round_number, positions)
    local t = TournamentState.tournaments[tournament_id]
    if t then
        t.round_positions = t.round_positions or {}
        t.round_positions[round_number] = positions
    end
end

function TournamentState.store_current_state_positions(tournament_id, positions)
    local t = TournamentState.tournaments[tournament_id]
    if t then
        t.current_positions = positions
    end
end

-- Get champion
function TournamentState.get_champion(tournament_id)
    local t = TournamentState.tournaments[tournament_id]
    if t and t.status == "COMPLETED" and t.matches and #t.matches == 0 and t.winners[1] then
        return t.winners[1]
    elseif t and t.status == "COMPLETED" and t.matches and #t.matches == 1 then
        return t.matches[1].winner
    end
    return nil
end

-- Handle player disconnect
function TournamentState.handle_player_disconnect(player_id)
    for tid, t in pairs(TournamentState.tournaments) do
        for i=#t.participants,1,-1 do
            if t.participants[i].player_id == player_id then
                table.remove(t.participants, i)
            end
        end
    end
end

return TournamentState
