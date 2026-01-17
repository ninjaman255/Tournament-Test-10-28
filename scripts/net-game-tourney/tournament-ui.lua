-- tournament-ui.lua
local TournamentUI = {}

local constants = require("scripts/net-game-tourney/tournament-constants")
local ui_positions = require("scripts/net-game-tourney/ui-pos")
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
    local base_positions = ui_positions.get_mugshot_positions(0)
    
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

-- Show participants (alias for show_current_participants)
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
        local crown_pos = ui_positions.ui_element_positions.champion_crown
        games.add_ui_element("CHAMPION_INDICATOR", player_id,
            constants.crown_texture_path,
            constants.crown_anim_path,
            "ACTIVE", crown_pos.x, crown_pos.y, crown_pos.z)
        
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
    local bg_pos = ui_positions.ui_element_positions.background
    games.add_ui_element("BOARD_BG", player_id, 
        bg_paths.gradient_texture,
        constants.default_background_anim_path_bn4,
        "BG", bg_pos.x, bg_pos.y, bg_pos.z)
    
    -- Grid
    local grid_pos = ui_positions.ui_element_positions.grid
    games.add_ui_element("BOARD_GRID", player_id,
        bg_paths.grid_texture,
        constants.default_grid_anim_path_bn4,
        "UI", grid_pos.x, grid_pos.y, grid_pos.z)
end

-- Setup bracket elements
function TournamentUI.setup_bracket_elements(player_id)
    -- Bracket graphic
    local tree_pos = ui_positions.ui_element_positions.tournament_tree
    games.add_ui_element("TOURNEY_TREE", player_id,
        constants.bracket_bm_bn4,
        constants.default_bracket_anim_path_bn4,
        "UI", tree_pos.x, tree_pos.y, tree_pos.z)
    
    -- Champion topper
    local topper_pos = ui_positions.ui_element_positions.champion_topper
    games.add_ui_element("CHAMPION_TOPPER", player_id,
        constants.champion_topper_bn4,
        constants.champion_topper_bn4_anim,
        "UI", topper_pos.x, topper_pos.y, topper_pos.z)
    
    -- Title banner
    local banner_pos = ui_positions.ui_element_positions.title_banner
    games.add_ui_element("TITLE_BANNER", player_id,
        "/server/assets/tourney/title-banner.png",
        "/server/assets/tourney/title-banner.anim",
        "RED", banner_pos.x, banner_pos.y, banner_pos.z)
    
    -- Crowns
    local crown1_pos = ui_positions.ui_element_positions.crown_1
    games.add_ui_element("CROWN_1", player_id,
        constants.crown_texture_path,
        constants.crown_anim_path,
        "INACTIVE", crown1_pos.x, crown1_pos.y, crown1_pos.z)
    
    local crown2_pos = ui_positions.ui_element_positions.crown_2
    games.add_ui_element("CROWN_2", player_id,
        constants.crown_texture_path,
        constants.crown_anim_path,
        "INACTIVE", crown2_pos.x, crown2_pos.y, crown2_pos.z)
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
    local bottom_positions = ui_positions.get_progress_bar_positions("bottom")
    for i, pos in ipairs(bottom_positions) do
        TournamentUI.add_progress_bar(player_id, "TIER1_" .. i, "bottom", pos.x, pos.y, pos.z, i)
    end
    
    if round >= 2 then
        -- Tier 2 - 4 positions
        local middle_positions = ui_positions.get_progress_bar_positions("middle")
        for i, pos in ipairs(middle_positions) do
            TournamentUI.add_progress_bar(player_id, "TIER2_" .. i, "middle", pos.x, pos.y, pos.z, i)
        end
    end
    
    if round >= 3 then
        -- Tier 3 - 2 positions
        local top_positions = ui_positions.get_progress_bar_positions("top")
        for i, pos in ipairs(top_positions) do
            TournamentUI.add_progress_bar(player_id, "TIER3_" .. i, "top", pos.x, pos.y, pos.z, i)
        end
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