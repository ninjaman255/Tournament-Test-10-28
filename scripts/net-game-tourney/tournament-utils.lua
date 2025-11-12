-- tournament-utils.lua
local TournamentUtils = {}
local TableUtils = require("scripts/table-utils")

-- Normalize raw battle results into standard format
function TournamentUtils.normalize_battle_results(event)
    if not event or not event.player_id then return nil end
    return {
        player_id = event.player_id,
        health = tonumber(event.health or 0),
        time = tonumber(event.time or 0),
        ran = event.ran or false,
        enemies = event.enemies or {}
    }
end

-- Process battle results and return winner and loser objects
function TournamentUtils.process_battle_results(event, tournament_id, match_index, TournamentState)
    local t = TournamentState.get_tournament(tournament_id)
    if not t or not t.matches[match_index] then return nil, nil end
    local match = t.matches[match_index]
    if match.player1.player_id == event.player_id then
        return match.player1, match.player2
    elseif match.player2.player_id == event.player_id then
        return match.player2, match.player1
    end
    return nil, nil
end

-- Calculate round positions (simple bracket order)
function TournamentUtils.calculate_round_positions(tournament, round_number)
    local positions = {}
    local participants = tournament.participants or {}
    for i,p in ipairs(participants) do
        positions[p.player_id] = i
    end
    return positions
end

return TournamentUtils
