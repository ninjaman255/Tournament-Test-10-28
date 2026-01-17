-- ui-pos.lua
local UIPositions = {}

UIPositions.mugshot_positions = {
    -- Round 0: All participants at bottom
    round0 = {
        {x = 8, y = 132, z = 3},
        {x = 34, y = 132, z = 3},
        {x = 64, y = 132, z = 3},
        {x = 90, y = 132, z = 3},
        {x = 128, y = 132, z = 3},
        {x = 154, y = 132, z = 3},
        {x = 184, y = 132, z = 3},
        {x = 210, y = 132, z = 3}
    },
    -- Round 1: Winners move to round 1 positions
    round1 = {
        {x = 22, y = 82, z = 3},   -- Match 1 winner
        {x = 78, y = 82, z = 3},   -- Match 2 winner
        {x = 142, y = 82, z = 3},  -- Match 3 winner
        {x = 198, y = 82, z = 3}   -- Match 4 winner
    },
    -- Round 2: Winners move to round 2 positions
    round2 = {
        {x = 50, y = 56, z = 3},   -- Match 1 winner
        {x = 170, y = 56, z = 3}   -- Match 2 winner
    },
    -- Round 3: Champion moves to top
    round3 = {
        {x = 110, y = 34, z = 3}   -- Champion position
    }
}

UIPositions.progress_bar_positions = {
    -- Bottom tier (always shown) - 8 positions
    bottom_tier = {
        {x = 17, y = 96, z = 1},
        {x = 47, y = 96, z = 1},
        {x = 73, y = 96, z = 1},
        {x = 103, y = 96, z = 1},
        {x = 137, y = 96, z = 1},
        {x = 167, y = 96, z = 1},
        {x = 193, y = 96, z = 1},
        {x = 223, y = 96, z = 1}
    },
    -- Middle tier (round 2+) - 4 positions
    middle_tier = {
        {x = 29, y = 72, z = 1},
        {x = 91, y = 72, z = 1},
        {x = 149, y = 72, z = 1},
        {x = 211, y = 72, z = 1}
    },
    -- Top tier (round 3+) - 2 positions
    top_tier = {
        {x = 57, y = 56, z = 1},
        {x = 183, y = 56, z = 1}
    }
}

UIPositions.ui_element_positions = {
    -- Bracket elements
    tournament_tree = {x = 0, y = 0, z = 0},
    champion_topper = {x = 80, y = 40, z = 1},
    title_banner = {x = 0, y = 0, z = 0},
    crown_1 = {x = 64, y = 48, z = 0},
    crown_2 = {x = 176, y = 48, z = 0},
    champion_crown = {x = 120, y = 36, z = 4},
    background = {x = 0, y = 0, z = -2},
    grid = {x = 0, y = 0, z = -1}
}

-- Helper function to get mugshot positions for a round
function UIPositions.get_mugshot_positions(round)
    local round_key = "round" .. round
    return UIPositions.mugshot_positions[round_key] or UIPositions.mugshot_positions.round0
end

-- Helper function to get progress bar positions for a tier
function UIPositions.get_progress_bar_positions(tier)
    local tier_key = tier .. "_tier"
    return UIPositions.progress_bar_positions[tier_key] or {}
end

return UIPositions