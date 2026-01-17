-- tournament-ui.lua
local TournamentUI = {}

local constants = require("scripts/net-game-tourney/tournament-constants")
local games = require("scripts/net-games/framework")

-- Show tournament board to a player
function TournamentUI.show_board(player_id, tournament_data, view_type)
    if not player_id or not tournament_data then
        print("[UI] Invalid parameters")
        return false
    end
    
    print(string.format("[UI] Showing board to %s (tournament %d, view: %s)", 
          player_id, tournament_data.id, view_type or "default"))
    
    -- Cleanup any existing UI first
    TournamentUI.cleanup(player_id)
    
    -- Setup background
    TournamentUI.setup_background(player_id, tournament_data.config.theme)
    
    -- Setup bracket elements
    TournamentUI.setup_bracket_elements(player_id)
    
    -- Show participants based on view type
    if view_type == "initial" then
        -- Show all participants at initial positions
        TournamentUI.show_initial_participants(player_id, tournament_data)
    elseif view_type == "round0" then
        -- Show all participants at initial positions (round 0)
        TournamentUI.show_initial_participants(player_id, tournament_data)
    elseif view_type == "champion" then
        -- Show champion at top
        TournamentUI.show_champion_view(player_id, tournament_data)
    else
        -- Show current state
        TournamentUI.show_current_participants(player_id, tournament_data)
    end
    
    -- Show progress bars based on current round
    TournamentUI.show_progress_bars(player_id, tournament_data.current_round)
    
    return true
end

-- Show participants at initial positions (all at bottom)
function TournamentUI.show_initial_participants(player_id, tournament_data)
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
    
    for i = 1, math.min(#tournament_data.participants, 8) do
        local participant = tournament_data.participants[i]
        local pos = base_positions[i]
        
        if participant and participant.mugshot then
            TournamentUI.add_mugshot(player_id, i, participant.mugshot, pos.x, pos.y, pos.z)
        end
    end
end

-- Show participants at current positions
function TournamentUI.show_current_participants(player_id, tournament_data)
    if not tournament_data.ui_state or not tournament_data.ui_state.positions then
        TournamentUI.show_initial_participants(player_id, tournament_data)
        return
    end
    
    for i, position in ipairs(tournament_data.ui_state.positions) do
        -- Find participant
        local participant
        for _, p in ipairs(tournament_data.participants) do
            if p.id == position.participant_id then
                participant = p
                break
            end
        end
        
        if participant and participant.mugshot then
            TournamentUI.add_mugshot(player_id, i, participant.mugshot, position.x, position.y, position.z)
        end
    end
end

-- NEW FUNCTION: Show participants (alias for show_current_participants)
function TournamentUI.show_participants(player_id, tournament_data)
    TournamentUI.show_current_participants(player_id, tournament_data)
end

-- Show champion view
function TournamentUI.show_champion_view(player_id, tournament_data)
    -- First show all participants at current positions
    TournamentUI.show_current_participants(player_id, tournament_data)
    
    -- Highlight champion
    local winner = tournament_data.matches.round3 and tournament_data.matches.round3[1] and 
                   tournament_data.matches.round3[1].winner
    if winner then
        -- Add crown or other champion indicator
        games.add_ui_element("CHAMPION_INDICATOR", player_id,
            constants.crown_texture_path,
            constants.crown_anim_path,
            "ACTIVE", 120, 35, 4)
        
        -- Announce champion
        Net.message_player(player_id, "CHAMPION: " .. winner.name)
    end
end

-- Setup background
function TournamentUI.setup_background(player_id, theme)
    theme = theme or "red_orange_bn4"
    local bg_paths = constants.bracket_background_path[theme]
    
    if not bg_paths then
        print("[UI] Theme not found: " .. theme)
        bg_paths = constants.bracket_background_path.red_orange_bn4
    end
    
    -- Background gradient
    games.add_ui_element("BOARD_BG", player_id, 
        bg_paths.gradient_texture,
        constants.default_background_anim_path_bn4,
        "BG", 0, 0, -2)
    
    -- Grid
    games.add_ui_element("BOARD_GRID", player_id,
        bg_paths.grid_texture,
        constants.default_grid_anim_path_bn4,
        "UI", 0, 0, -1)
end

-- Setup bracket elements
function TournamentUI.setup_bracket_elements(player_id)
    -- Bracket graphic
    games.add_ui_element("TOURNEY_TREE", player_id,
        constants.bracket_bm_bn4,
        constants.default_bracket_anim_path_bn4,
        "UI", 0, 0, 0)
    
    -- Champion topper
    games.add_ui_element("CHAMPION_TOPPER", player_id,
        constants.champion_topper_bn4,
        constants.champion_topper_bn4_anim,
        "UI", 80, 40, 1)
    
    -- Title banner
    games.add_ui_element("TITLE_BANNER", player_id,
        "/server/assets/tourney/title-banner.png",
        "/server/assets/tourney/title-banner.anim",
        "RED", 0, 0, 0)
    
    -- Crowns
    games.add_ui_element("CROWN_1", player_id,
        constants.crown_texture_path,
        constants.crown_anim_path,
        "INACTIVE", 64, 48, 0)
    
    games.add_ui_element("CROWN_2", player_id,
        constants.crown_texture_path,
        constants.crown_anim_path,
        "INACTIVE", 176, 48, 0)
end

-- Add a mugshot
function TournamentUI.add_mugshot(player_id, index, mugshot_texture, x, y, z)
    local frame_id = "MUG_FRAME_" .. index
    local mug_id = "MUG_" .. index
    
    -- Frame
    games.add_ui_element(frame_id, player_id,
        "/server/assets/tourney/tourney-board-elements/mini-mug-frame.png",
        "/server/assets/tourney/tourney-board-elements/mini-mug-frame.anim",
        "ACTIVE", x, y, 3)
    
    -- Mugshot
    games.add_ui_element(mug_id, player_id,
        mugshot_texture,
        constants.default_mug_anim,
        "UI", x, y, 2, 1, 1)
end

-- Show progress bars
function TournamentUI.show_progress_bars(player_id, round)
    -- Tier 1 (always) - 8 positions
    -- Start with left (odd positions) then right (even positions)
    TournamentUI.add_progress_bar(player_id, "TIER1_1", "bottom", 17, 96, 1, 1)
    TournamentUI.add_progress_bar(player_id, "TIER1_2", "bottom", 47, 96, 1, 2)
    TournamentUI.add_progress_bar(player_id, "TIER1_3", "bottom", 73, 96, 1, 3)
    TournamentUI.add_progress_bar(player_id, "TIER1_4", "bottom", 103, 96, 1, 4)
    TournamentUI.add_progress_bar(player_id, "TIER1_5", "bottom", 137, 96, 1, 5)
    TournamentUI.add_progress_bar(player_id, "TIER1_6", "bottom", 167, 96, 1, 6)
    TournamentUI.add_progress_bar(player_id, "TIER1_7", "bottom", 193, 96, 1, 7)
    TournamentUI.add_progress_bar(player_id, "TIER1_8", "bottom", 223, 96, 1, 8)
    
    if round >= 2 then
        -- Tier 2 - 4 positions
        TournamentUI.add_progress_bar(player_id, "TIER2_1", "middle", 29, 72, 1, 1)
        TournamentUI.add_progress_bar(player_id, "TIER2_2", "middle", 91, 72, 1, 2)
        TournamentUI.add_progress_bar(player_id, "TIER2_3", "middle", 149, 72, 1, 3)
        TournamentUI.add_progress_bar(player_id, "TIER2_4", "middle", 211, 72, 1, 4)
    end
    
    if round >= 3 then
        -- Tier 3 - 2 positions
        TournamentUI.add_progress_bar(player_id, "TIER3_1", "top", 57, 56, 1, 1)
        TournamentUI.add_progress_bar(player_id, "TIER3_2", "top", 183, 56, 1, 2)
    end
end

-- Add a progress bar with alternating direction based on position in tier
function TournamentUI.add_progress_bar(player_id, element_id, tier, x, y, z, position_index)
    local paths = constants.progress_bar_path
    
    local anim_state = "INACTIVE"
    
    -- Determine direction based on position index (odd = left, even = right)
    -- This ensures alternation starting with left
    if tier == "bottom" then
        anim_state = (position_index % 2 == 1) and "L1_MOVE" or "R1_MOVE"
    elseif tier == "middle" then
        anim_state = (position_index % 2 == 1) and "L2_MOVE" or "R2_MOVE"
    elseif tier == "top" then
        anim_state = (position_index % 2 == 1) and "L3_MOVE" or "R3_MOVE"
    end
    
    games.add_ui_element(element_id, player_id,
        paths[tier .. "_tier"].texture,
        paths[tier .. "_tier"].anim,
        anim_state, x, y, z)
end

-- Cleanup participants
function TournamentUI.cleanup_participants(player_id)
    for i = 1, 8 do
        games.remove_ui_element("MUG_FRAME_" .. i, player_id)
        games.remove_ui_element("MUG_" .. i, player_id)
    end
end

-- Cleanup all UI
function TournamentUI.cleanup(player_id)
    TournamentUI.cleanup_participants(player_id)
    
    local elements = {
        "BOARD_BG", "BOARD_GRID", "TOURNEY_TREE", "CHAMPION_TOPPER",
        "TITLE_BANNER", "CROWN_1", "CROWN_2", "CHAMPION_INDICATOR",
        "TIER1_1", "TIER1_2", "TIER1_3", "TIER1_4", "TIER1_5", "TIER1_6", "TIER1_7", "TIER1_8",
        "TIER2_1", "TIER2_2", "TIER2_3", "TIER2_4",
        "TIER3_1", "TIER3_2"
    }
    
    for _, element in ipairs(elements) do
        games.remove_ui_element(element, player_id)
    end
    
    print("[UI] Cleaned UI for " .. player_id)
end

-- Fade transition
function TournamentUI.show_transition(player_id, fade_in, duration)
    duration = duration or 0.3
    
    if fade_in then
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, duration)
    else
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, duration)
    end
end

return TournamentUI