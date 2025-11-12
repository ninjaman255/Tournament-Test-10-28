local tblutils = require("scripts/table-utils")
local constants = require("scripts/constants")
local ui_data = require("scripts/ui-data")

local TEMPLATE_TOURNAMENT_TABLE = {
    tournament_id = 0,
    tournament_nickname = "Default Tournament",
    participant_count = 0,
    max_participants = 8,
    status = "INITIAL",
    participants = {},
    current_round = 0,
    matches = {},
    winners = {},
    round_1_results = {},
    round_2_results = {},
    round_3_results = {},
    area_id = "",
    board_id = 0,
    board_ui_information = {},
    created_time = 0,
    last_updated = 0
}

-- Helper function to build default UI information for a tournament board
local function build_default_ui_info()
    return {
        tournament_title = "Free Tournament",
        title_banner = {
            texture = constants.title_banners.free_tourney,
            animation = constants.default_title_banner_anim
        },
        board_background = {
            texture = constants.bracket_background_path.blue_bn4.gradient_texture,
            animation = constants.default_background_anim_path_bn4
        },
        board_grid = {
            texture = constants.bracket_background_path.blue_bn4.grid_texture,
            animation = constants.default_grid_anim_path_bn4
        },
        board_bracket = {
            texture = constants.bracket_bm_bn4,
            animation = constants.default_bracket_anim_path_bn4
        },
        crowns = {
            texture = constants.crown_texture_path,
            animation = constants.crown_anim_path,
            positions = {
                crown1 = ui_data.unmoving_ui_pos.crown1,
                crown2 = ui_data.unmoving_ui_pos.crown2
            }
        },
        champion_topper = {
            texture = constants.champion_topper_bn4,
            animation = constants.champion_topper_bn4_anim,
            position = ui_data.unmoving_ui_pos.champion_topper_bn4
        },
        mugshot_frame = {
            texture = constants.default_mug_frame.texture_path,
            animation = constants.default_mug_frame.anim_path
        },
        element_positions = {
            bg = ui_data.unmoving_ui_pos.bg,
            grid = ui_data.unmoving_ui_pos.grid,
            bracket = ui_data.unmoving_ui_pos.bracket,
            title_banner = ui_data.unmoving_ui_pos.title_banner
        }
    }
end

function TEMPLATE_TOURNAMENT_TABLE.create_from_template(tournament_nickname, area_id, board_id)
    local new_tournament = tblutils.shallow_copy(TEMPLATE_TOURNAMENT_TABLE)
    new_tournament.tournament_nickname = tournament_nickname or "New Tournament"
    new_tournament.area_id = area_id or ""
    new_tournament.board_id = board_id or 0
    new_tournament.created_time = os.time()
    new_tournament.last_updated = os.time()
    new_tournament.board_ui_information = build_default_ui_info()
    return new_tournament
end

function TEMPLATE_TOURNAMENT_TABLE.validate_participant(participant)
    return participant and
        participant.player_id and
        participant.player_mugshot and
        participant.player_mugshot.mug_texture and
        participant.player_mugshot.mug_animation
end

return TEMPLATE_TOURNAMENT_TABLE
