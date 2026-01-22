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

UIPositions.progress_bar_overlays = {
    -- Tier 1
    bottom_tier = {
        { x = 17,  y = 96, z = 2 },
        { x = 47,  y = 96, z = 2 },
        { x = 73,  y = 96, z = 2 },
        { x = 103, y = 96, z = 2 },
        { x = 137, y = 96, z = 2 },
        { x = 167, y = 96, z = 2 },
        { x = 193, y = 96, z = 2 },
        { x = 223, y = 96, z = 2 },
    },
    -- Tier 2
    middle_tier = {
        { x = 29,  y = 72, z = 2 },
        { x = 91,  y = 72, z = 2 },
        { x = 149, y = 72, z = 2 },
        { x = 211, y = 72, z = 2 },
    },
    -- Tier 3
    top_tier = {
        { x = 57,  y = 56, z = 2 },
        { x = 183, y = 56, z = 2 },
    },
}

UIPositions.queue_timer_position = {
    x = 100,
    y = 20,
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

-- Helper function to get progress bar index based on match position and which participant won
function UIPositions.get_progress_bar_index(round, match_index, winner_is_player1)
    if round == 1 then
        -- Bottom tier: 8 progress bars (1-8)
        -- Each match has 2 possible progress bars:
        -- Match 1: bars 1 (player1) and 2 (player2)
        -- Match 2: bars 3 (player1) and 4 (player2)
        -- Match 3: bars 5 (player1) and 6 (player2)
        -- Match 4: bars 7 (player1) and 8 (player2)
        local base_index = (match_index - 1) * 2
        return winner_is_player1 and (base_index + 1) or (base_index + 2)
        
    elseif round == 2 then
        -- Middle tier: 4 progress bars (1-4)
        -- Each match has 2 possible progress bars:
        -- Match 1: bars 1 (player1) and 2 (player2)
        -- Match 2: bars 3 (player1) and 4 (player2)
        local base_index = (match_index - 1) * 2
        return winner_is_player1 and (base_index + 1) or (base_index + 2)
        
    elseif round == 3 then
        -- Top tier: 2 progress bars (1-2)
        -- Only 1 match, but 2 possible progress bars:
        -- Bar 1 (player1) or bar 2 (player2)
        return winner_is_player1 and 1 or 2
    end
    
    return 1
end

return UIPositions