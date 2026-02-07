-- scripts/net-games/sprite-constants.lua
-- Constants for sprite management across the displayer system

local SpriteConstants = {}

-- Sprite ID prefixes by category
SpriteConstants.PREFIXES = {
    FONT = "font_",
    BACKDROP = "backdrop_",
    CURSOR = "cursor_",
    TEXTBOX_PANEL = "textbox_panel_",
    TEXTBOX_FRAME = "textbox_frame_",
    MUGSHOT = "mugshot_",
    UI = "ui_"
}

-- Font sprite IDs (must match font-system.lua font names)
SpriteConstants.FONTS = {
    THICK = "THICK",
    THIN = "THIN",
    WIDE = "WIDE",
    TINY = "TINY",
    BATTLE = "BATTLE",
    GRADIENT = "GRADIENT",
    GRADIENT_GOLD = "GRADIENT_GOLD",
    GRADIENT_ORANGE = "GRADIENT_ORANGE",
    GRADIENT_GREEN = "GRADIENT_GREEN",
    GRADIENT_TALL = "GRADIENT_TALL",
    THICK_BLACK = "THICK_BLACK",
    THIN_BLACK = "THIN_BLACK",
    WIDE_BLACK = "WIDE_BLACK",
    TINY_BLACK = "TINY_BLACK",
    BATTLE_BLACK = "BATTLE_BLACK",
    GRADIENT_BLACK = "GRADIENT_BLACK",
    GRADIENT_GOLD_BLACK = "GRADIENT_GOLD_BLACK",
    GRADIENT_ORANGE_BLACK = "GRADIENT_ORANGE_BLACK",
    GRADIENT_GREEN_BLACK = "GRADIENT_GREEN_BLACK",
    GRADIENT_TALL_BLACK = "GRADIENT_TALL_BLACK"
}

-- System sprite IDs
SpriteConstants.SYSTEM = {
    BACKDROP = 5000,
    CURSOR = 5100,
    TEXTBOX_PANEL = 5201,
    TEXTBOX_FRAME = 5202,
    MUGSHOT_BASE = 5300
}

-- Asset paths that should always be provided/allocated on player join
SpriteConstants.AUTO_ALLOC_ASSETS = {
    -- Font assets are handled by font-system.lua
    CURSOR = {
        sprite_id = 5100,
        texture_path = "/server/assets/net-games/textbox_next.png",
        anim_path = nil
    },
    TEXTBOX_PANEL = {
        sprite_id = 5201,
        texture_path = "/server/assets/net-games/displayer/textbox.png",
        anim_path = "/server/assets/net-games/displayer/textbox.animation"
    },
    TEXTBOX_FRAME = {
        sprite_id = 5202,
        texture_path = "/server/assets/net-games/displayer/textbox_frame_gray.png",
        anim_path = "/server/assets/net-games/displayer/textbox.animation"  -- Same animation as panel
    }
}

-- Helper function to get namespaced sprite IDs
function SpriteConstants:get_font_sprite_id(font_name)
    return self.PREFIXES.FONT .. font_name
end

function SpriteConstants:get_system_sprite_id(category, subtype)
    if subtype then
        return self.PREFIXES[category] .. tostring(subtype)
    end
    return self.PREFIXES[category] .. "default"
end

-- Helper to check if a sprite ID is a font
function SpriteConstants:is_font_sprite(sprite_id)
    -- Convert to string first to handle both string and number sprite IDs
    local str_id = tostring(sprite_id)
    return str_id:sub(1, #self.PREFIXES.FONT) == self.PREFIXES.FONT
end

-- Helper to extract font name from sprite ID
function SpriteConstants:font_name_from_sprite(sprite_id)
    if self:is_font_sprite(sprite_id) then
        local str_id = tostring(sprite_id)
        return str_id:sub(#self.PREFIXES.FONT + 1)
    end
    return nil
end

return SpriteConstants