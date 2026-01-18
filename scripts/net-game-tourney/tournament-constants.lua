-- tournament-constants.lua
local constants = {
    -- Paths
    ui_element_paths = "/server/assets/tourney/tourney-board-elements/",
    
    -- Background themes
    bracket_background_path = {
        blue_bn4 = {
            gradient_texture = "/server/assets/tourney/tourney-board-elements/blue-bn4/gradient.png",
            grid_texture = "/server/assets/tourney/tourney-board-elements/blue-bn4/grid.png",
        },
        green_bn4 = {
            gradient_texture = "/server/assets/tourney/tourney-board-elements/green-bn4/gradient.png",
            grid_texture = "/server/assets/tourney/tourney-board-elements/green-bn4/grid.png",
        },
        pink_yellow_bn4 = {
            gradient_texture = "/server/assets/tourney/tourney-board-elements/pink-yellow-bn4/gradient.png",
            grid_texture = "/server/assets/tourney/tourney-board-elements/pink-yellow-bn4/grid.png",
        },
        pink_bn4 = {
            gradient_texture = "/server/assets/tourney/tourney-board-elements/pink-bn4/gradient.png",
            grid_texture = "/server/assets/tourney/tourney-board-elements/pink-bn4/grid.png",
        },
        lemon_lime_bn4 = {
            gradient_texture = "/server/assets/tourney/tourney-board-elements/lemon-lime-bn4/gradient.png",
            grid_texture = "/server/assets/tourney/tourney-board-elements/lemon-lime-bn4/grid.png",
        },
        green_blue_white_bn4 = {
            gradient_texture = "/server/assets/tourney/tourney-board-elements/green-blue-white-bn4/gradient.png",
            grid_texture = "/server/assets/tourney/tourney-board-elements/green-blue-white-bn4/grid.png",
        },
        red_orange_bn4 = {
            gradient_texture = "/server/assets/tourney/tourney-board-elements/red-orange-bn4/gradient.png",
            grid_texture = "/server/assets/tourney/tourney-board-elements/red-orange-bn4/grid.png",
        },
    },
    
    -- Progress bars
    progress_bar_path = {
        bottom_tier = {
            texture = "/server/assets/tourney/tourney-board-elements/progress-bar-base/bottom-tier.png",
            anim = "/server/assets/tourney/tourney-board-elements/progress-bar-base/bottom-tier.anim"
        },
        middle_tier = {
            texture = "/server/assets/tourney/tourney-board-elements/progress-bar-base/middle-tier.png",
            anim = "/server/assets/tourney/tourney-board-elements/progress-bar-base/middle-tier.anim",
        },
        top_tier = {    
            texture = "/server/assets/tourney/tourney-board-elements/progress-bar-base/top-tier.png",
            anim = "/server/assets/tourney/tourney-board-elements/progress-bar-base/top-tier.anim",
        },
    },
    
    -- Bracket graphics
    bracket_bm_bn4 = "/server/assets/tourney/tourney-board-elements/bracket-bm.png",
    bracket_rs_bn4 = "/server/assets/tourney/tourney-board-elements/bracket-rs.png",
    
    -- Animations
    default_bracket_anim_path_bn4 = "/server/assets/tourney/tourney-board-elements/bracket.anim",
    default_background_anim_path_bn4 = "/server/assets/tourney/tourney-board-elements/gradient.anim",
    default_grid_anim_path_bn4 = "/server/assets/tourney/tourney-board-elements/grid.anim",
    default_mug_anim = "/server/assets/tourney/tourney-board-elements/mug.anim",
    
    -- Crown elements
    crown_texture_path = "/server/assets/tourney/tourney-board-elements/crown.png",
    crown_anim_path = "/server/assets/tourney/tourney-board-elements/crown.anim",
    
    -- Champion toppers
    champion_topper_bn4 = "/server/assets/tourney/tourney-board-elements/champion-topper-bn4.png",
    champion_topper_bn45 = "/server/assets/tourney/tourney-board-elements/champion-topper-bn45.png",
    champion_topper_bn4_anim = "/server/assets/tourney/tourney-board-elements/champion-topper-bn4.anim",
    champion_topper_bn45_anim = "/server/assets/tourney/tourney-board-elements/champion-topper-bn45.anim",
    
    -- Music
    tournament_music = "/server/assets/tourney/music/bbn4_tournament_announcement.ogg",
    
    -- NPC path
    default_npc_path = "/server/assets/tourney/npc-navis-testing/",

    greyscale_properties = 
    {
        color_mode = 2,
        r = 128,
        g = 128,
        b = 128,
        a = 200
    }
}

return constants