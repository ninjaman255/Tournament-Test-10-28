-- tournament-ui.lua
local TournamentUI = {}

local constants = require("scripts/net-game-tourney/tournament-constants")
local ui_positions = require("scripts/net-game-tourney/ui-pos")
local games = require("scripts/net-games/framework")

-- Track greyscale participants per player AND per tournament
local greyscale_tracking = {} -- tournament_id -> {player_id -> {participant_id = true}}

-- Track progress bars per participant per round
local progress_bar_tracking = {} -- tournament_id -> {player_id -> {participant_id -> {tier1 = true, tier2 = true, tier3 = true}}}

-- Clear progress bar tracking for a player in a tournament
function TournamentUI.clear_progress_bar_tracking(player_id, tournament_id)
    if not tournament_id then return end
    if progress_bar_tracking[tournament_id] then
        progress_bar_tracking[tournament_id][player_id] = nil
    end
end

-- Mark a progress bar tier as spawned for a participant
function TournamentUI.mark_progress_bar_spawned(tournament_id, player_id, participant_id, tier)
    if not tournament_id then return end
    if not progress_bar_tracking[tournament_id] then
        progress_bar_tracking[tournament_id] = {}
    end
    if not progress_bar_tracking[tournament_id][player_id] then
        progress_bar_tracking[tournament_id][player_id] = {}
    end
    if not progress_bar_tracking[tournament_id][player_id][participant_id] then
        progress_bar_tracking[tournament_id][player_id][participant_id] = {}
    end
    progress_bar_tracking[tournament_id][player_id][participant_id][tier] = true
end

-- Check if a progress bar tier is already spawned for a participant
function TournamentUI.has_progress_bar_tier(tournament_id, player_id, participant_id, tier)
    if not tournament_id then return false end
    return progress_bar_tracking[tournament_id] 
           and progress_bar_tracking[tournament_id][player_id]
           and progress_bar_tracking[tournament_id][player_id][participant_id]
           and progress_bar_tracking[tournament_id][player_id][participant_id][tier]
end

-- Clear greyscale tracking for a player in a tournament
function TournamentUI.clear_greyscale_tracking(player_id, tournament_id)
    if not tournament_id then return end
    if greyscale_tracking[tournament_id] then
        greyscale_tracking[tournament_id][player_id] = nil
    end
end

-- Mark a participant as greyscale for a player in a tournament
function TournamentUI.mark_greyscale(tournament_id, player_id, participant_id)
    if not tournament_id then return end
    if not greyscale_tracking[tournament_id] then
        greyscale_tracking[tournament_id] = {}
    end
    if not greyscale_tracking[tournament_id][player_id] then
        greyscale_tracking[tournament_id][player_id] = {}
    end
    greyscale_tracking[tournament_id][player_id][participant_id] = true
end

-- Check if a participant should be greyscale for a player
function TournamentUI.is_greyscale(tournament_id, player_id, participant_id)
    if not tournament_id then return false end
    return greyscale_tracking[tournament_id] 
           and greyscale_tracking[tournament_id][player_id]
           and greyscale_tracking[tournament_id][player_id][participant_id]
end

-- Show tournament board to a player
function TournamentUI.show_board(player_id, tournament_data, view_type)
    if not player_id or not tournament_data then
        print("[UI] Invalid parameters")
        return false
    end
    
    print(string.format("[UI] Showing board to %s (tournament %d, view: %s)", 
          player_id, tournament_data.id, view_type or "default"))
    
    -- Cleanup any existing UI first
    TournamentUI.cleanup(player_id, tournament_data.id)
    
    -- Setup background
    TournamentUI.setup_background(player_id, tournament_data.config.theme)
    
    -- Setup bracket elements
    TournamentUI.setup_bracket_elements(player_id)
    
    -- Show participants based on view type
    if view_type == "initial" or view_type == "round0" then
        -- Show all participants at initial positions
        TournamentUI.show_initial_participants(player_id, tournament_data)
    else
        -- Show participants at current positions
        TournamentUI.show_current_participants(player_id, tournament_data)
    end
    
    -- Always show progress bars from all previous rounds
    TournamentUI.show_all_progress_bars(player_id, tournament_data)
    
    return true
end

-- Show progress bars from all completed rounds
function TournamentUI.show_all_progress_bars(player_id, tournament_data)
    local round = tournament_data.current_round or 0
    
    -- Show progress bars for all completed rounds
    for r = 1, round - 1 do
        TournamentUI.show_progress_bars_for_specific_round(player_id, tournament_data, r)
    end
end

-- Show progress bars for a specific round
function TournamentUI.show_progress_bars_for_specific_round(player_id, tournament_data, round)
    if round == 1 and tournament_data.matches.round1 then
        for match_index, match in ipairs(tournament_data.matches.round1) do
            if match.completed and match.winner then
                local tier1_index = (match_index * 2) - 1
                local bottom_positions = ui_positions.get_progress_bar_positions("bottom")
                if bottom_positions[tier1_index] then
                    TournamentUI.add_progress_bar(player_id, "TIER1_" .. tier1_index, "bottom", 
                        bottom_positions[tier1_index].x, bottom_positions[tier1_index].y, 
                        bottom_positions[tier1_index].z, tier1_index)
                end
            end
        end
    elseif round == 2 and tournament_data.matches.round2 then
        for match_index, match in ipairs(tournament_data.matches.round2) do
            if match.completed and match.winner then
                local tier2_index = match_index  -- Fixed: Should be 1 or 2, not (match_index * 2) - 1
                local middle_positions = ui_positions.get_progress_bar_positions("middle")
                if middle_positions[tier2_index] then
                    TournamentUI.add_progress_bar(player_id, "TIER2_" .. tier2_index, "middle", 
                        middle_positions[tier2_index].x, middle_positions[tier2_index].y, 
                        middle_positions[tier2_index].z, tier2_index)
                end
            end
        end
    elseif round == 3 and tournament_data.matches.round3 and tournament_data.matches.round3[1] then
        local final_match = tournament_data.matches.round3[1]
        if final_match.completed and final_match.winner then
            local top_positions = ui_positions.get_progress_bar_positions("top")
            if top_positions[1] then
                TournamentUI.add_progress_bar(player_id, "TIER3_1", "top", 
                    top_positions[1].x, top_positions[1].y, 
                    top_positions[1].z, 1)
            end
        end
    end
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
            
            -- Apply greyscale if this participant was marked as greyscale in any previous round
            if TournamentUI.is_greyscale(tournament_data.id, player_id, participant.id) then
                games.update_ui_element("MUG_" .. i, player_id, constants.greyscale_properties)
                print(string.format("[UI] Starting with greyscaled mugshot %d for player %s", i, player_id))
            end
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
        
        -- Apply greyscale to all non-champion participants
        for i, p in ipairs(tournament_data.participants) do
            if p.id ~= winner.id then
                games.update_ui_element("MUG_" .. i, player_id, constants.greyscale_properties)
                -- Mark as greyscale for tracking
                TournamentUI.mark_greyscale(tournament_data.id, player_id, p.id)
            end
        end
        
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
function TournamentUI.cleanup(player_id, tournament_id)
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
    
    -- Clear greyscale tracking for this player in this tournament
    if tournament_id then
        TournamentUI.clear_greyscale_tracking(player_id, tournament_id)
        TournamentUI.clear_progress_bar_tracking(player_id, tournament_id)
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