-- tourney-api.lua
local Tournament = require("scripts/net-game-tourney/tournament")
local TournamentState = require("scripts/net-game-tourney/tournament-state")
local TournamentUtils = require("scripts/net-game-tourney/tournament-utils")
local constants = require("scripts/net-game-tourney/constants")
local TableUtils = require("scripts/table-utils")

local function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end
local function await(v) return Async.await(v) end

local TournamentAPI = {}

-----------------------------------------------------------
--  🔹  Deep Copy Utility (Safe)
-----------------------------------------------------------
function TournamentAPI.deepCopy(obj, ignoreKeys, seen)
    if type(obj) ~= 'table' then return obj end
    seen = seen or {}
    if seen[obj] then return seen[obj] end
    local res = {}
    seen[obj] = res
    local mt = getmetatable(obj)
    if mt then setmetatable(res, mt) end
    for k, v in next, obj do
        if not (ignoreKeys and ignoreKeys[k]) then
            res[TournamentAPI.deepCopy(k, ignoreKeys, seen)] = TournamentAPI.deepCopy(v, ignoreKeys, seen)
        end
    end
    return res
end

-----------------------------------------------------------
--  🔹  Event Emitters (One Stop Shop)
-----------------------------------------------------------
TournamentAPI.events = {
    tournament_created   = Net.EventEmitter.new(),
    tournament_started   = Net.EventEmitter.new(),
    battle_completed     = Net.EventEmitter.new(),
    tournament_completed = Net.EventEmitter.new(),
    board_opening        = Net.EventEmitter.new(),
    board_shown          = Net.EventEmitter.new(),
    board_closed         = Net.EventEmitter.new(),
}

-----------------------------------------------------------
--  🔹  Internal Battle Normalizer
-----------------------------------------------------------
local function normalize_battle_event(event)
    if not event or not event.player_id then return nil end
    local normalized = {
        player_id = event.player_id,
        health = tonumber(event.health or 0),
        time = tonumber(event.time or 0),
        ran = event.ran or false,
        enemies = event.enemies or {}
    }
    return normalized
end

local function handle_normalized_battle(event)
    local normalized = normalize_battle_event(event)
    if not normalized then return end

    local tournament_id = TournamentState.get_tournament_id_by_player(normalized.player_id)
    if not tournament_id then return end
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return end

    local match_index = nil
    for i, match in ipairs(tournament.matches or {}) do
        if not match.completed and ((match.player1 and match.player1.player_id == normalized.player_id) or
                                   (match.player2 and match.player2.player_id == normalized.player_id)) then
            match_index = i
            break
        end
    end
    if not match_index then return end

    local winner, loser
    if TournamentUtils and TournamentUtils.process_battle_results then
        winner, loser = TournamentUtils.process_battle_results(normalized, tournament_id, match_index, TournamentState)
    end
    if winner and loser then
        TournamentState.record_battle_result(tournament_id, match_index, winner, loser, normalized.ran)
        TournamentAPI.events.battle_completed:emit({
            tournament_id = tournament_id,
            match_index = match_index,
            winner = winner,
            loser = loser,
            event = normalized
        })

        -- Check round completion
        local all_done = true
        for _, m in ipairs(tournament.matches or {}) do
            if not m.completed then all_done = false; break end
        end
        if all_done then
            tournament.status = "ROUND_COMPLETE"
            local positions
            if TournamentUtils and TournamentUtils.calculate_round_positions then
                positions = TournamentUtils.calculate_round_positions(tournament, tournament.current_round)
            end
            if positions and TournamentState.store_round_positions then
                TournamentState.store_round_positions(tournament_id, tournament.current_round, positions)
                TournamentState.store_current_state_positions(tournament_id, positions)
            end
        end
    end
end

-- Bind Net raw battle_results
if Net and type(Net.on) == "function" then
    Net:on("battle_results", function(event)
        async(function() handle_normalized_battle(event) end)()
    end)
end

-----------------------------------------------------------
--  🔹  Default Board/UI Asset Initialization
-----------------------------------------------------------
TournamentAPI.boards = {} -- keyed by area_id -> board_id

function TournamentAPI.initialize_board(area_id, object)
    if not area_id or not object then return end
    local board_id = object.id or tostring(object)
    local board_type = object.type or object.class
    if not board_type or board_type ~= "Tournament Board" then return end

    TournamentAPI.boards[area_id] = TournamentAPI.boards[area_id] or {}
    local board_entry = {}

    -- Gradient + Grid
    local gradient = constants.BRACKET_TEXTURES.DEFAULT
    local grid = constants.BRACKET_TEXTURES.DEFAULT
    if object.custom_properties then
        local grad_val = object.custom_properties["gradient_texture"]
        local grid_val = object.custom_properties["grid_texture"]
        if grad_val and type(grad_val) == "string" and #grad_val > 0 then
            gradient = grad_val
        end
        if grid_val and type(grid_val) == "string" and #grid_val > 0 then
            grid = grid_val
        end
    end
    board_entry.gradient = gradient
    board_entry.grid = grid

    -- Store
    TournamentAPI.boards[area_id][board_id] = board_entry
end

function TournamentAPI.get_board(area_id, board_id)
    if not area_id or not board_id then return nil end
    if TournamentAPI.boards[area_id] then
        return TournamentAPI.boards[area_id][board_id]
    end
    return nil
end

-----------------------------------------------------------
--  🔹  Public API Functions
-----------------------------------------------------------
function TournamentAPI.create_tournament(player_id, object_id, area, board_info)
    return async(function()
        local tournament_id = TournamentState.create_tournament(object_id, area, player_id)
        if tournament_id and TournamentAPI.events.tournament_created.emit then
            TournamentAPI.events.tournament_created:emit({ tournament_id = tournament_id, area = area })
        end
        return tournament_id
    end)
end

function TournamentAPI.start_tournament(tournament_id)
    return async(function()
        local ok = TournamentState.start_round(tournament_id)
        if ok and TournamentAPI.events.tournament_started.emit then
            TournamentAPI.events.tournament_started:emit({
                tournament_id = tournament_id,
                round = TournamentState.get_current_round(tournament_id)
            })
        end
        return ok
    end)
end

function TournamentAPI.process_battle_event(event)
    async(function()
        handle_normalized_battle(event)
    end)()
end

function TournamentAPI.handle_player_disconnect(player_id)
    if TournamentState and TournamentState.handle_player_disconnect then
        TournamentState.handle_player_disconnect(player_id)
    end
end

return TournamentAPI
