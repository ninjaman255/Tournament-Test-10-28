local UI_DATA = {
    frame_names = {
    "MUG_FRAME_" .. 1,
    "MUG_FRAME_" .. 2,
    "MUG_FRAME_" .. 3,
    "MUG_FRAME_" .. 4, 
    "MUG_FRAME_" .. 5, 
    "MUG_FRAME_" .. 6,
    "MUG_FRAME_" .. 7, 
    "MUG_FRAME_" .. 8,
    "MUG_" .. 1, 
    "MUG_" .. 2, 
    "MUG_" .. 3,
    "MUG_" .. 4, 
    "MUG_" .. 5, 
    "MUG_" .. 6,
    "MUG_" .. 7, 
    "MUG_" .. 8, 
    "BOARD BG",
    "BRACKET",
    "BOARD GRID",
    "CHAMPION TOPPER",
    "TITLE BANNER",
    "CROWN_1", 
    "CROWN_2",
    
    "PROGESS_BAR_TIER1_1",
    "PROGESS_BAR_TIER1_2",
    "PROGESS_BAR_TIER1_3",
    "PROGESS_BAR_TIER1_4",
    "PROGESS_BAR_TIER1_5",
    "PROGESS_BAR_TIER1_6",
    "PROGESS_BAR_TIER1_7",
    "PROGESS_BAR_TIER1_8",
    "PROGESS_BAR_OVERLAY_TIER1_1",
    "PROGESS_BAR_OVERLAY_TIER1_2",
    "PROGESS_BAR_OVERLAY_TIER1_3",
    "PROGESS_BAR_OVERLAY_TIER1_4",
    "PROGESS_BAR_OVERLAY_TIER1_5",
    "PROGESS_BAR_OVERLAY_TIER1_6",
    "PROGESS_BAR_OVERLAY_TIER1_7",
    "PROGESS_BAR_OVERLAY_TIER1_8",
    
    "PROGESS_BAR_TIER2_1",
    "PROGESS_BAR_TIER2_2",
    "PROGESS_BAR_TIER2_3",
    "PROGESS_BAR_TIER2_4",
    "PROGESS_BAR_OVERLAY_TIER2_1",
    "PROGESS_BAR_OVERLAY_TIER2_2",
    "PROGESS_BAR_OVERLAY_TIER2_3",
    "PROGESS_BAR_OVERLAY_TIER2_4",

    "PROGESS_BAR_TIER3_1",
    "PROGESS_BAR_TIER3_2",
    "PROGESS_BAR_OVERLAY_TIER3_1",
    "PROGESS_BAR_OVERLAY_TIER3_2",
    },
    unmoving_ui_pos = {
        bg = {
            x = 0,
            y = 0,
            z = -2,
        },
        grid={
            x = 0,
            y = 0,
            z = -1,
        },
        title_banner = {
            x = 0,
            y = 0,
            z = 0,
        },
        bracket = {
            x = 0,
            y = 0,
            z = 0,
        },
        crown1 = { 
            x = 64, 
            y = 48,
            z = 0,
        }, 
        crown2 ={
            x = 176,
            y = 48,
            z = 0,
        },
        champion_topper_bn4 = {
            x = 80,
            y = 40,
            z = 1,
        }
    },
    -- 14 different spots for the progress bars to be placed.
    progress_bars = {
        -- Tier 1
        TIER1_1 = { x = 17,  y = 96, z = 1 },
        TIER1_2 = { x = 47,  y = 96, z = 1 },
        TIER1_3 = { x = 73,  y = 96, z = 1 },
        TIER1_4 = { x = 103, y = 96, z = 1 },
        TIER1_5 = { x = 137, y = 96, z = 1 },
        TIER1_6 = { x = 167, y = 96, z = 1 },
        TIER1_7 = { x = 193, y = 96, z = 1 },
        TIER1_8 = { x = 223, y = 96, z = 1 },

        -- Tier 2
        TIER2_1 = { x = 29,  y = 72, z = 1 },
        TIER2_2 = { x = 91,  y = 72, z = 1 },
        TIER2_3 = { x = 149, y = 72, z = 1 },
        TIER2_4 = { x = 211, y = 72, z = 1 },

        -- Tier 3
        TIER3_1 = { x = 57,  y = 56, z = 1 },
        TIER3_2 = { x = 183, y = 56, z = 1 },
    },
    progress_bar_overlays = {
        -- Tier 1 (Blue Moon)
        TIER1_1 = { x = 17,  y = 96, z = 2 },
        TIER1_2 = { x = 47,  y = 96, z = 2 },
        TIER1_3 = { x = 73,  y = 96, z = 2 },
        TIER1_4 = { x = 103, y = 96, z = 2 },
        TIER1_5 = { x = 137, y = 96, z = 2 },
        TIER1_6 = { x = 167, y = 96, z = 2 },
        TIER1_7 = { x = 193, y = 96, z = 2 },
        TIER1_8 = { x = 223, y = 96, z = 2 },

        -- Tier 2 (Blue Moon)
        TIER2_1 = { x = 29,  y = 72, z = 2 },
        TIER2_2 = { x = 91,  y = 72, z = 2 },
        TIER2_3 = { x = 149, y = 72, z = 2 },
        TIER2_4 = { x = 211, y = 72, z = 2 },

        -- Tier 3 (Blue Moon)
        TIER3_1 = { x = 57,  y = 56, z = 2 },
        TIER3_2 = { x = 183, y = 56, z = 2 },
    }
}

return UI_DATA