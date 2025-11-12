-- constants.lua
local ui_element_paths = "/server/assets/tourney/tourney-board-elements/"
local backgrounds_and_grids_path = ui_element_paths.."backgrounds-and-grids/"
local bn4_title_banner_paths = ui_element_paths.."title-banners-bn4/"

local CONSTANTS = {
    bracket_background_path = {
        blue_bn4 = { gradient_texture=backgrounds_and_grids_path.."blue-bn4/gradient.png", grid_texture=backgrounds_and_grids_path.."blue-bn4/grid.png" },
        green_bn4 = { gradient_texture=backgrounds_and_grids_path.."green-bn4/gradient.png", grid_texture=backgrounds_and_grids_path.."green-bn4/grid.png" },
        pink_yellow_bn4 = { gradient_texture=backgrounds_and_grids_path.."pink-yellow-bn4/gradient.png", grid_texture=backgrounds_and_grids_path.."pink-yellow-bn4/grid.png" },
        pink_bn4 = { gradient_texture=backgrounds_and_grids_path.."pink-bn4/gradient.png", grid_texture=backgrounds_and_grids_path.."pink-bn4/grid.png" },
        lemon_lime_bn4 = { gradient_texture=backgrounds_and_grids_path.."lemon-lime-bn4/gradient.png", grid_texture=backgrounds_and_grids_path.."lemon-lime-bn4/grid.png" },
        green_blue_white_bn4 = { gradient_texture=backgrounds_and_grids_path.."green-blue-white-bn4/gradient.png", grid_texture=backgrounds_and_grids_path.."green-blue-white-bn4/grid.png" },
        red_orange_bn4 = { gradient_texture=backgrounds_and_grids_path.."red-orange-bn4/gradient.png", grid_texture=backgrounds_and_grids_path.."red-orange-bn4/grid.png" },
    },

    title_banners = {
        free_tourney = bn4_title_banner_paths.."free-tourney.png",
        red_sun = bn4_title_banner_paths.."red-sun.png",
        den_battle = bn4_title_banner_paths.."den-battle.png",
        eagle = bn4_title_banner_paths.."eagle.png",
    },

    default_mug_frame = {
        texture_path = ui_element_paths.."mini-mug-frame.png",
        anim_path = ui_element_paths.."mini-mug-frame-anim",
        anim_states = { "ACTIVE", "INACTIVE", "BATTLING" },
    },

    bracket_bm_bn4 = ui_element_paths.."bracket-bm.png",
    bracket_rs_bn4 = ui_element_paths.."bracket-rs.png",
    default_bracket_anim_path_bn4 = ui_element_paths.."bracket.anim",
    default_background_anim_path_bn4 = ui_element_paths.."gradient.anim",
    default_grid_anim_path_bn4 = ui_element_paths.."grid.anim",
    default_mug_anim = ui_element_paths.."mug.anim",
    crown_texture_path = ui_element_paths.."crown.png",
    crown_anim_path = ui_element_paths.."crown.anim",
    champion_topper_bn4 = ui_element_paths.."champion-topper-bn4.png",
    champion_topper_bn45 = ui_element_paths.."champion-topper-bn45.png",
    champion_topper_bn4_anim = ui_element_paths.."champion-topper-bn4.anim",
    champion_topper_bn45_anim = ui_element_paths.."champion-topper-bn45.anim",
    default_title_banner_anim = bn4_title_banner_paths.."title-banner.anim",
}

CONSTANTS.BRACKET_TEXTURES = {
    DEFAULT  = ui_element_paths.."bracket_default.png",
    ADVANCED = ui_element_paths.."bracket_advanced.png",
}

CONSTANTS.MUGSHOT_FRAMES = {
    ROUND_1  = ui_element_paths.."mugshot_frame_r1.png",
    ROUND_2  = ui_element_paths.."mugshot_frame_r2.png",
    CHAMPION = ui_element_paths.."mugshot_frame_champ.png",
}

-- Optional debug tracer
function CONSTANTS.debug_trace_battle_events(event, label)
    print(string.format("[trace:%s] player_id=%s | ran=%s | health=%s | enemies=%s",
        label,
        tostring(event.player_id),
        tostring(event.ran),
        tostring(event.health),
        event.enemies and #event.enemies or "nil"
    ))
end

return CONSTANTS
