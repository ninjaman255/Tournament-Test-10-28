-- emitters.lua
local Net = Net
local TourneyEmitters = {}

-- central registry of emitters
TourneyEmitters.emitters = {}

-- helper to create or get an emitter
function TourneyEmitters.get(name)
    if not TourneyEmitters.emitters[name] then
        if Net and Net.EventEmitter then
            TourneyEmitters.emitters[name] = Net.EventEmitter.new()
        else
            -- fallback dummy emitter for safety
            TourneyEmitters.emitters[name] = { on = function() end, emit = function() end }
        end
    end
    return TourneyEmitters.emitters[name]
end

-- predefined emitters
TourneyEmitters.tourney = TourneyEmitters.get("tourney")
TourneyEmitters.normalized = TourneyEmitters.get("normalized")
TourneyEmitters.board = TourneyEmitters.get("board")
TourneyEmitters.ui = TourneyEmitters.get("ui")

-- optional helper for async
local function async(fn)
    local co = coroutine.create(fn)
    return Async.promisify(co)
end
local function await(v) return Async.await(v) end

-- example raw Net normalization setup
if Net and type(Net.on) == "function" then
    Net:on("battle_results", function(event)
        async(function()
            if not event or not event.player_id then return end
            local normalized
            if TournamentUtils and TournamentUtils.normalize_battle_results then
                normalized = TournamentUtils.normalize_battle_results(event)
            else
                normalized = {
                    player_id = event.player_id,
                    health = tonumber(event.health or 0),
                    time = tonumber(event.time or 0),
                    ran = event.ran or false,
                    enemies = event.enemies or {}
                }
            end
            TourneyEmitters.normalized:emit("battle_results_normalized", normalized)
        end)()
    end)
end

return TourneyEmitters
