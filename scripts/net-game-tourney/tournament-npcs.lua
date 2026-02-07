-- tournament-npcs.lua
local tournament_npcs = {}

local npc_path = "/server/assets/tourney/npc-navis-testing/"

-- NPC database
tournament_npcs.NPC_LIST = {
{
id = npc_path .. "airman/airman1.zip",
name = "AirMan",
mugshot = npc_path .. "airman/mug.png",
weight = 50
},
{
id = npc_path .. "blastman/blastman1.zip",
name = "BlastMan",
mugshot = npc_path .. "blastman/mug.png",
weight = 60
},
{
id = npc_path .. "burnerman/burnerman1.zip",
name = "BurnerMan",
mugshot = npc_path .. "burnerman/mug.png",
weight = 55
},
{
id = npc_path .. "colonel/colonel1.zip",
name = "Colonel",
mugshot = npc_path .. "colonel/mug.png",
weight = 70
},
{
id = npc_path .. "circusman/circusman1.zip",
name = "CircusMan",
mugshot = npc_path .. "circusman/mug.png",
weight = 45
},
{
id = npc_path .. "cutman/cutman1.zip",
name = "CutMan",
mugshot = npc_path .. "cutman/mug.png",
weight = 40
},
{
id = npc_path .. "elementman/elementman1.zip",
name = "ElementMan",
mugshot = npc_path .. "elementman/mug.png",
weight = 65
},
{
id = npc_path .. "fireman/fireman1.zip",
name = "FireMan",
mugshot = npc_path .. "fireman/mug.png",
weight = 58
},
{
id = npc_path .. "gbeast-megaman/gbeast-megaman1.zip",
name = "Giga Beast",
mugshot = npc_path .. "gbeast-megaman/mug.png",
weight = 80
},
{
id = npc_path .. "gutsman/gutsman1.zip",
name = "GutsMan",
mugshot = npc_path .. "gutsman/mug.png",
weight = 62
},
{
id = npc_path .. "hatman/hatman1.zip",
name = "HatMan",
mugshot = npc_path .. "hatman/mug.png",
weight = 48
},
{
id = npc_path .. "iceman/iceman1.zip",
name = "IceMan",
mugshot = npc_path .. "iceman/mug.png",
weight = 52
},
{
id = npc_path .. "jammingman/jammingman1.zip",
name = "JammingMan",
mugshot = npc_path .. "jammingman/mug.png",
weight = 47
},
{
id = npc_path .. "protoman/protoman1.zip",
name = "ProtoMan",
mugshot = npc_path .. "protoman/mug.png",
weight = 75
},
{
id = npc_path .. "quickman/quickman1.zip",
name = "QuickMan",
mugshot = npc_path .. "quickman/mug.png",
weight = 68
},
{
id = npc_path .. "roll/roll1.zip",
name = "Roll",
mugshot = npc_path .. "roll/mug.png",
weight = 42
},
{
id = npc_path .. "shadowman/shadowman1.zip",
name = "ShadowMan",
mugshot = npc_path .. "shadowman/mug.png",
weight = 72
},
{
id = npc_path .. "starman/starman1.zip",
name = "StarMan",
mugshot = npc_path .. "starman/mug.png",
weight = 54
},
{
id = npc_path .. "woodman/woodman1.zip",
name = "WoodMan",
mugshot = npc_path .. "woodman/mug.png",
weight = 56
}
}

-- Track used NPCs per tournament to avoid duplicates
local used_npcs_by_tournament = {}

-- Clean up used NPCs when tournament ends
function tournament_npcs.cleanup_tournament_npcs(tournament_id)
used_npcs_by_tournament[tournament_id] = nil
end

-- Get unique random NPC (without duplicates for the same tournament)
function tournament_npcs.get_unique_random_npc(tournament_id)
if not tournament_id then
return tournament_npcs.get_random_npc()
end

-- Initialize used NPCs for this tournament if not exists
if not used_npcs_by_tournament[tournament_id] then
    used_npcs_by_tournament[tournament_id] = {}
end

local used_npcs = used_npcs_by_tournament[tournament_id]
local available_npcs = {}

-- Find all NPCs not yet used in this tournament
for _, npc in ipairs(tournament_npcs.NPC_LIST) do
    local already_used = false
    for _, used_npc in ipairs(used_npcs) do
        if used_npc.id == npc.id then
            already_used = true
            break
        end
    end
    if not already_used then
        table.insert(available_npcs, npc)
    end
end

-- If all NPCs are used, clear the list and start over (shouldn't happen with 19 NPCs)
if #available_npcs == 0 then
    print("[NPCs] All NPCs used for tournament " .. tournament_id .. ", resetting list")
    used_npcs_by_tournament[tournament_id] = {}
    available_npcs = tournament_npcs.NPC_LIST
end

-- Select random NPC from available ones
local index = math.random(1, #available_npcs)
local selected_npc = available_npcs[index]

-- Mark as used for this tournament
table.insert(used_npcs, selected_npc)

return {
    id = selected_npc.id,
    name = selected_npc.name,
    mugshot = selected_npc.mugshot,
    weight = selected_npc.weight,
    type = "npc"
}
end

-- Get multiple unique random NPCs for a tournament
function tournament_npcs.get_unique_random_npcs(tournament_id, count)
local npcs = {}

for i = 1, count do
    local npc = tournament_npcs.get_unique_random_npc(tournament_id)
    table.insert(npcs, npc)
end

return npcs
end

-- Original functions (for backward compatibility)
function tournament_npcs.get_random_npc()
if #tournament_npcs.NPC_LIST == 0 then
return {
id = npc_path .. "airman/airman1.zip",
name = "AirMan",
mugshot = "/server/assets/tourney/npc-navis-testing/airman/mug.png",
weight = 50,
type = "npc"
}
end

local index = math.random(1, #tournament_npcs.NPC_LIST)
local npc = tournament_npcs.NPC_LIST[index]

return {
    id = npc.id,
    name = npc.name,
    mugshot = npc.mugshot,
    weight = npc.weight,
    type = "npc"
}
end

function tournament_npcs.get_random_npcs(count)
local npcs = {}

for i = 1, count do
    table.insert(npcs, tournament_npcs.get_random_npc())
end

return npcs
end

return tournament_npcs