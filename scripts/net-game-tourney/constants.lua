local ui_element_paths = "/server/assets/tourney/tourney-board-elements/"

local CONSTANTS = {
    
    bn4_bg_data = {
        blue_bn4 = {
            gradient_texture=ui_element_paths.."blue-bn4/gradient.png",
            grid_texture=ui_element_paths.."blue-bn4/grid.png",
        },
        green_bn4 = {
            gradient_texture=ui_element_paths.."green-bn4/gradient.png",
            grid_texture=ui_element_paths.."green-bn4/grid.png",
        },
        pink_yellow_bn4 = {
            gradient_texture=ui_element_paths.."pink-yellow-bn4/gradient.png",
            grid_texture=ui_element_paths.."pink-yellow-bn4/grid.png",
        },
        pink_bn4 = {
            gradient_texture=ui_element_paths.."pink-bn4/gradient.png",
            grid_texture=ui_element_paths.."pink-bn4/grid.png",
        },
        lemon_lime_bn4 = {
            gradient_texture=ui_element_paths.."lemon-lime-bn4/gradient.png",
            grid_texture=ui_element_paths.."lemon-lime-bn4/grid.png",
        },
        green_blue_white_bn4 = {
            gradient_texture=ui_element_paths.."green-blue-white-bn4/gradient.png",
            grid_texture=ui_element_paths.."green-blue-white-bn4/grid.png",
        },
        red_orange_bn4 = {
            gradient_texture=ui_element_paths.."red-orange-bn4/gradient.png",
            grid_texture=ui_element_paths.."red-orange-bn4/grid.png",
        },
    },

    bn4_default_titles = {
        den_battle = ui_element_paths.."title-banners-bn4/den-battle.png",
        eagle = ui_element_paths.."title-banners-bn4/eagle.png",
        free_tournament = ui_element_paths.."title-banners-bn4/free-tourney.png",
        red_sun = ui_element_paths.."title-banners-bn4/red-sun.png",
    },

    default_progress_bars = {
        bottom_tier = {texture = ui_element_paths.."progress-bar-base/bottom-tier.png", anim = ui_element_paths.."progress-bar-base/bottom-tier.anim"},
        middle_tier = {texture = ui_element_paths.."progress-bar-base/middle-tier.png", anim = ui_element_paths.."progress-bar-base/middle-tier.anim"},
        top_tier    = {texture = ui_element_paths.."progress-bar-base/top-tier.png", anim = ui_element_paths.."progress-bar-base/top-tier.anim"},
    },

    default_progress_bar_overlays = {
        none = {
            bottom_tier = {texture = ui_element_paths.."progress-bar-overlays/none/bottom-tier.png", anim = ui_element_paths.."progress-bar-overlays/none/bottom-tier.anim"},
            middle_tier = {texture = ui_element_paths.."progress-bar-overlays/none/middle-tier.png", anim = ui_element_paths.."progress-bar-overlays/none/middle-tier.anim"},
            top_tier    = {texture = ui_element_paths.."progress-bar-overlays/none/top-tier.png", anim = ui_element_paths.."progress-bar-overlays/none/top-tier.anim"},
        },
        bn4_blue_moon = {
            bottom_tier = {texture = ui_element_paths.."progress-bar-overlays/blue-moon/bottom-tier.png", anim = ui_element_paths.."progress-bar-overlays/blue-moon/bottom-tier.anim"},
            middle_tier = {texture = ui_element_paths.."progress-bar-overlays/blue-moon/middle-tier.png", anim = ui_element_paths.."progress-bar-overlays/blue-moon/middle-tier.anim"},
            top_tier    = {texture = ui_element_paths.."progress-bar-overlays/blue-moon/top-tier.png", anim = ui_element_paths.."progress-bar-overlays/blue-moon/top-tier.anim"},
        },
    },
    
    -- Bracket/Tourney Path paths
    bracket_bm_bn4 = ui_element_paths.."bracket-bm.png",
    bracket_rs_bn4 = ui_element_paths.."bracket-rs.png",
    
    -- Default bracket animation to be used with the above bracket_texture(s).
    default_bracket_anim_path_bn4 = ui_element_paths.."bracket.anim",
    
    -- Default bg animation to be used with the above BG gradients_texture(s).
    default_background_anim_path_bn4 = ui_element_paths.."gradient.anim",
    
    -- Default grid animation to be used with the above grid_textures.
    default_grid_anim_path_bn4 = ui_element_paths.."grid.anim",
    
    -- Default mugshot animation has all the needed built in empty animation_state(s)
    default_mug_anim = ui_element_paths.."mug.anim",
    
    -- Default Crown Texture and anim (BN4)
    crown_texture_path = ui_element_paths.."crown.png",
    crown_anim_path = ui_element_paths.."crown.anim",
    
    -- Default Champion Toppers for the top of our Brackets/Tourney Path graphic
    champion_topper_bn4=ui_element_paths.."champion-topper-bn4.png",
    champion_topper_bn45=ui_element_paths.."champion-topper-bn45.png",
    
    -- Default Champion Topper animation path
    champion_topper_bn4_anim=ui_element_paths.."champion-topper-bn4.anim",
    champion_topper_bn45_anim=ui_element_paths.."champion-topper-bn45.anim",
    
    -- Default Mini Mugshot Frames
    default_mini_mug_texture = ui_element_paths.."mini-mug-frame.png",
    default_mini_mug_anim = ui_element_paths.."mini-mug-frame.anim",
    
    -- Default title banner animation path
    default_bn4_title_banner_anim = ui_element_paths.."title-banners-bn4/title-banner.anim",    
    
    -- Default Music and SFX.
    default_tourney_announcement_music = "/server/assets/tourney/music/bbn4_tournament_announcement.ogg",
    
    -- Delay before we should start battles for all players for board close We need to make it async for timing but not lock as we want to show to all players at the same time. Below will be values to use for waiting immediately after showing a board before starting battles.
    first_show_board_time = 13,
    first_show_board_sleep_time_fix = 15,
}

return CONSTANTS
