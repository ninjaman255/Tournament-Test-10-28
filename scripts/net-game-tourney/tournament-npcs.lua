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

-- Get random NPC
function tournament_npcs.get_random_npc()
    if #tournament_npcs.NPC_LIST == 0 then
        return {
            id = "/server/assets/tourney/npc-navis-testing/airman/airman1.zip",
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

-- Get multiple random NPCs
function tournament_npcs.get_random_npcs(count)
    local npcs = {}
    
    for i = 1, count do
        table.insert(npcs, tournament_npcs.get_random_npc())
    end
    
    return npcs
end

return tournament_npcs