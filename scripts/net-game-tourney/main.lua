-- main.lua
local TournamentAPI = require("scripts/net-game-tourney/tourney-api")
local constants = require("scripts/net-game-tourney/constants")

-- Scan all areas and objects for Tournament Boards
local function initialize_all_boards()
    if not Net or not Net.get_areas then return end

    local areas = Net.get_areas() or {}
    for _, area in ipairs(areas) do
        local objects = area.objects or {}
        for _, obj in ipairs(objects) do
            local obj_type = obj.type or obj.class
            if obj_type and obj_type == "Tournament Board" then
                TournamentAPI.initialize_board(area.id, obj)
            end
        end
    end
end

-- Initialize default boards/UI assets
initialize_all_boards()

-- Hook interaction events with boards
if Net and type(Net.on) == "function" then
    Net:on("object_interaction", function(event)
        if not event or not event.object or not event.player_id then return end
        local obj_type = event.object.type or event.object.class
        if obj_type == "Tournament Board" then
            local board_id = event.object.id or tostring(event.object)
            local board = TournamentAPI.get_board(event.area_id, board_id)
            if board then
                -- Emit board opening event
                if TournamentAPI.events.board_opening and TournamentAPI.events.board_opening.emit then
                    TournamentAPI.events.board_opening:emit({
                        player_id = event.player_id,
                        board_id = board_id,
                        area_id = event.area_id
                    })
                end
            end
        end
    end)

    -- Optional: handle player disconnects
    Net:on("player_disconnect", function(event)
        if event and event.player_id then
            TournamentAPI.handle_player_disconnect(event.player_id)
        end
    end)
end

-- Expose initialization for external use if needed
return {
    initialize_all_boards = initialize_all_boards
}
