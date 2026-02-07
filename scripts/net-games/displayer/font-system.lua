-- Font System for Timer Display (Following example_sprites pattern)
FontSystem = {}
FontSystem.__index = FontSystem

-- Add SpriteManager integration at the top
local SpriteManager_ok, SpriteManager = pcall(require, "scripts/net-games/sprites-api/sprite-manager")
local SpriteConstants_ok, SpriteConstants = pcall(require, "scripts/net-games/sprites-api/sprite-constants")

if not SpriteManager_ok then
    print("[FontSystem] WARNING: SpriteManager not available. Font rendering will be limited.")
    SpriteManager = nil
end

if not SpriteConstants_ok then
    print("[FontSystem] WARNING: SpriteConstants not available.")
    SpriteConstants = nil
end

-- Optional helper: merge sprite draw properties (rotation/tint/opacity/etc.)
local prepare_draw_params
do
    local ok, mh = pcall(require, "scripts/net-games/math-helpers")
    if ok and type(mh) == "table" and mh.prepare_draw_params then
        prepare_draw_params = mh.prepare_draw_params
    end
end

local function _props_without_xy(props)
    if type(props) ~= "table" then return nil end
    local out = {}
    local has = false
    for k, v in pairs(props) do
        if k ~= "x" and k ~= "y" and k ~= "X" and k ~= "Y" then
            out[k] = v
            has = true
        end
    end
    if not has then return nil end
    return out
end

local function _merge_draw_params(base, props)
    if prepare_draw_params then
        return prepare_draw_params(base, props)
    end
    if type(props) == "table" then
        for k, v in pairs(props) do
            base[k] = v
        end
    end
    return base
end

local function _props_sig(props)
    if type(props) ~= "table" then return "" end
    local opacity = props.opacity
    if opacity == nil then opacity = props.a end
    local ro = props.ro or props.rotation
    return table.concat({
        tostring(ro or ""),
        tostring(props.ox or ""),
        tostring(props.oy or ""),
        tostring(props.r or ""),
        tostring(props.g or ""),
        tostring(props.b or ""),
        tostring(opacity or ""),
        tostring(props.color_mode or "")
    }, "|")
end

function FontSystem:init()
    -- Font sprite definitions now use SpriteConstants
    self.font_sprites = {}
    
    -- Only proceed if SpriteConstants is available
    if SpriteConstants then
        for font_name, _ in pairs(SpriteConstants.FONTS) do
            local sprite_id = SpriteConstants:get_font_sprite_id(font_name)
            self.font_sprites[font_name] = {
                sprite_id = sprite_id,
                texture_path = "/server/assets/net-games/fonts/fonts_compressed.png",
                anim_path = "/server/assets/net-games/fonts/fonts_compressed.animation",
                anim_state = font_name .. "_0"
            }
            
            -- Handle dark variants
            if not font_name:match("_BLACK$") then
                local black_name = font_name .. "_BLACK"
                local black_sprite_id = SpriteConstants:get_font_sprite_id(black_name)
                self.font_sprites[black_name] = {
                    sprite_id = black_sprite_id,
                    texture_path = "/server/assets/net-games/fonts/fonts_dark_compressed.png",
                    anim_path = "/server/assets/net-games/fonts/fonts_dark_compressed.animation",
                    anim_state = font_name .. "_0"  -- Same animation state names
                }
            end
        end
    else
        -- Fallback font definitions if SpriteConstants not available
        local fallback_fonts = {
            "THICK", "BATTLE", "THIN", "TINY", "WIDE", "GRADIENT", 
            "GRADIENT_GOLD", "GRADIENT_TALL", "GRADIENT_GREEN", "GRADIENT_ORANGE"
        }
        
        for _, font_name in ipairs(fallback_fonts) do
            self.font_sprites[font_name] = {
                sprite_id = "font_" .. font_name,
                texture_path = "/server/assets/net-games/fonts/fonts_compressed.png",
                anim_path = "/server/assets/net-games/fonts/fonts_compressed.animation",
                anim_state = font_name .. "_0"
            }
            
            local black_name = font_name .. "_BLACK"
            self.font_sprites[black_name] = {
                sprite_id = "font_" .. black_name,
                texture_path = "/server/assets/net-games/fonts/fonts_dark_compressed.png",
                anim_path = "/server/assets/net-games/fonts/fonts_dark_compressed.animation",
                anim_state = font_name .. "_0"
            }
        end
    end
    
    -- Character width data (unchanged from original)
    self.char_widths = {
        THICK = {
            ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6, ["4"] = 6, ["5"] = 6,
            ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6, [":"] = 6, ["."] = 6,
            ["-"] = 6, [" "] = 6, ["A"] = 6, ["B"] = 6, ["C"] = 6, ["D"] = 6,
            ["E"] = 6, ["F"] = 6, ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6,
            ["K"] = 6, ["L"] = 6, ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6,
            ["Q"] = 6, ["R"] = 6, ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6,
            ["W"] = 6, ["X"] = 6, ["Y"] = 6, ["Z"] = 6, ["a"] = 6, ["b"] = 6,
            ["c"] = 6, ["d"] = 6, ["e"] = 6, ["f"] = 6, ["g"] = 6, ["h"] = 6,
            ["i"] = 6, ["j"] = 6, ["k"] = 6, ["l"] = 6, ["m"] = 6, ["n"] = 6,
            ["o"] = 6, ["p"] = 6, ["q"] = 6, ["r"] = 6, ["s"] = 6, ["t"] = 6,
            ["u"] = 6, ["v"] = 6, ["w"] = 6, ["x"] = 6, ["y"] = 6, ["z"] = 6,
            ["!"] = 6, ["@"] = 6, ["#"] = 6, ["$"] = 6, ["%"] = 6, ["^"] = 6,
            ["&"] = 6, ["*"] = 6, ["("] = 6, [")"] = 6, ["_"] = 6, ["+"] = 6,
            ["="] = 6, ["["] = 6, ["]"] = 6, ["{"] = 6, ["}"] = 6, ["|"] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, [","] = 6, ["?"] = 6
        },
        GRADIENT_GOLD = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_TALL = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_GREEN = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_ORANGE = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["+"] = 7
        },
        BATTLE = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, [" "] = 7,
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, ["!"] = 7, ["_"] = 7, ["<"] = 7, [">"] = 7
        },
        THIN = {
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, [":"] = 5, ["&"] = 7, ["'"] = 6, ["="] = 7,
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["a"] = 7, ["b"] = 7,
            ["c"] = 7, ["d"] = 7, ["e"] = 7, ["f"] = 6, ["g"] = 7, ["h"] = 7,
            ["i"] = 4, ["j"] = 7, ["k"] = 7, ["l"] = 4, ["m"] = 7, ["n"] = 7,
            ["o"] = 7, ["p"] = 7, ["q"] = 7, ["r"] = 6, ["s"] = 7, ["t"] = 7,
            ["u"] = 7, ["v"] = 7, ["w"] = 7, ["x"] = 7, ["y"] = 7, ["z"] = 7,
            ["-"] = 7, ["!"] = 4, ["/"] = 7, ["."] = 5, ["?"] = 7, [","] = 5,
            ['"'] = 7, ["_"] = 7, ["$"] = 7, ["("] = 7, [")"] = 7, ["["] = 7,
            ["]"] = 7, ["*"] = 7, ["~"] = 7, ["`"] = 7, ["^"] = 7, ["+"] = 7,
            ["#"] = 7, ["%"] = 7, ["@"] = 7, ["<"] = 7, [">"] = 7, ["{"] = 7,
            ["}"] = 7, [";"] = 5
            },
        TINY = {
            ["A"] = 5, ["B"] = 5, ["C"] = 5, ["D"] = 5, ["E"] = 5, ["F"] = 5,
            ["G"] = 5, ["H"] = 5, ["I"] = 5, ["J"] = 5, ["K"] = 5, ["L"] = 5,
            ["M"] = 5, ["N"] = 5, ["O"] = 5, ["P"] = 5, ["Q"] = 5, ["R"] = 5,
            ["S"] = 5, ["T"] = 5, ["U"] = 5, ["V"] = 5, ["W"] = 5, ["X"] = 5,
            ["Y"] = 5, ["Z"] = 5, ["a"] = 5, ["b"] = 5, ["c"] = 5, ["d"] = 5,
            ["e"] = 5, ["f"] = 5, ["g"] = 5, ["h"] = 5, ["i"] = 5, ["j"] = 5,
            ["k"] = 5, ["l"] = 5, ["m"] = 5, ["n"] = 5, ["o"] = 5, ["p"] = 5,
            ["q"] = 5, ["r"] = 5, ["s"] = 5, ["t"] = 5, ["u"] = 5, ["v"] = 5,
            ["w"] = 5, ["x"] = 5, ["y"] = 5, ["z"] = 5, ["0"] = 5, ["1"] = 5,
            ["2"] = 5, ["3"] = 5, ["4"] = 5, ["5"] = 5, ["6"] = 5, ["7"] = 5,
            ["8"] = 5, ["9"] = 5, ["("] = 5, [")"] = 5, ["_"] = 5, ["-"] = 5,
            ["+"] = 5, ["="] = 5, ["\\"] = 5, ["/"] = 5, ["<"] = 5, [">"] = 5,
            ["?"] = 5, [","] = 5, ["."] = 5, ["!"] = 5, ["@"] = 5, ["#"] = 5,
            ["$"] = 5, ["%"] = 5, ["^"] = 5, ["&"] = 5, ["*"] = 5, ["'"] = 5,
            ['"'] = 5, [":"] = 5, [";"] = 5, [" "] = 5

        },
        WIDE = {
            ["A"] = 7, ["B"] = 6, ["C"] = 6, ["D"] = 6, ["E"] = 6, ["F"] = 6,
            ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6, ["K"] = 6, ["L"] = 6,
            ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6, ["Q"] = 7, ["R"] = 6,
            ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6, ["W"] = 6, ["X"] = 6,
            ["Y"] = 6, ["Z"] = 6, ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6,
            ["4"] = 6, ["5"] = 6, ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6,
            ["("] = 6, [")"] = 6, ["_"] = 6, ["-"] = 6, ["+"] = 6, ["="] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, ["?"] = 6, [","] = 6,
            ["."] = 6, ["!"] = 6, ["@"] = 7, ["#"] = 6, ["$"] = 6, ["%"] = 6,
            ["^"] = 6, ["&"] = 6, ["*"] = 6, ["'"] = 6, ['"'] = 6, [":"] = 6,
            [";"] = 6
        },
        THICK_BLACK = {
            ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6, ["4"] = 6, ["5"] = 6,
            ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6, [":"] = 6, ["."] = 6,
            ["-"] = 6, [" "] = 6, ["A"] = 6, ["B"] = 6, ["C"] = 6, ["D"] = 6,
            ["E"] = 6, ["F"] = 6, ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6,
            ["K"] = 6, ["L"] = 6, ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6,
            ["Q"] = 6, ["R"] = 6, ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6,
            ["W"] = 6, ["X"] = 6, ["Y"] = 6, ["Z"] = 6, ["a"] = 6, ["b"] = 6,
            ["c"] = 6, ["d"] = 6, ["e"] = 6, ["f"] = 6, ["g"] = 6, ["h"] = 6,
            ["i"] = 6, ["j"] = 6, ["k"] = 6, ["l"] = 6, ["m"] = 6, ["n"] = 6,
            ["o"] = 6, ["p"] = 6, ["q"] = 6, ["r"] = 6, ["s"] = 6, ["t"] = 6,
            ["u"] = 6, ["v"] = 6, ["w"] = 6, ["x"] = 6, ["y"] = 6, ["z"] = 6,
            ["!"] = 6, ["@"] = 6, ["#"] = 6, ["$"] = 6, ["%"] = 6, ["^"] = 6,
            ["&"] = 6, ["*"] = 6, ["("] = 6, [")"] = 6, ["_"] = 6, ["+"] = 6,
            ["="] = 6, ["["] = 6, ["]"] = 6, ["{"] = 6, ["}"] = 6, ["|"] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, [","] = 6, ["?"] = 6
        },
        GRADIENT_GOLD_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_TALL_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_GREEN_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_ORANGE_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["+"] = 7
        },
        BATTLE_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, [" "] = 7,
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, ["!"] = 7, ["_"] = 7, ["<"] = 7, [">"] = 7
        },
        THIN_BLACK = {
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, [":"] = 5, ["&"] = 7, ["'"] = 6, ["="] = 7,
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["a"] = 7, ["b"] = 7,
            ["c"] = 7, ["d"] = 7, ["e"] = 7, ["f"] = 6, ["g"] = 7, ["h"] = 7,
            ["i"] = 4, ["j"] = 7, ["k"] = 7, ["l"] = 4, ["m"] = 7, ["n"] = 7,
            ["o"] = 7, ["p"] = 7, ["q"] = 7, ["r"] = 6, ["s"] = 7, ["t"] = 7,
            ["u"] = 7, ["v"] = 7, ["w"] = 7, ["x"] = 7, ["y"] = 7, ["z"] = 7,
            ["-"] = 7, ["!"] = 4, ["/"] = 7, ["."] = 5, ["?"] = 7, [","] = 5,
            ['"'] = 7, ["_"] = 7, ["$"] = 7, ["("] = 7, [")"] = 7, ["["] = 7,
            ["]"] = 7, ["*"] = 7, ["~"] = 7, ["`"] = 7, ["^"] = 7, ["+"] = 7,
            ["#"] = 7, ["%"] = 7, ["@"] = 7, ["<"] = 7, [">"] = 7, ["{"] = 7,
            ["}"] = 7, [";"] = 5
            },
        TINY_BLACK = {
            ["A"] = 5, ["B"] = 5, ["C"] = 5, ["D"] = 5, ["E"] = 5, ["F"] = 5,
            ["G"] = 5, ["H"] = 5, ["I"] = 5, ["J"] = 5, ["K"] = 5, ["L"] = 5,
            ["M"] = 5, ["N"] = 5, ["O"] = 5, ["P"] = 5, ["Q"] = 5, ["R"] = 5,
            ["S"] = 5, ["T"] = 5, ["U"] = 5, ["V"] = 5, ["W"] = 5, ["X"] = 5,
            ["Y"] = 5, ["Z"] = 5, ["a"] = 5, ["b"] = 5, ["c"] = 5, ["d"] = 5,
            ["e"] = 5, ["f"] = 5, ["g"] = 5, ["h"] = 5, ["i"] = 5, ["j"] = 5,
            ["k"] = 5, ["l"] = 5, ["m"] = 5, ["n"] = 5, ["o"] = 5, ["p"] = 5,
            ["q"] = 5, ["r"] = 5, ["s"] = 5, ["t"] = 5, ["u"] = 5, ["v"] = 5,
            ["w"] = 5, ["x"] = 5, ["y"] = 5, ["z"] = 5, ["0"] = 5, ["1"] = 5,
            ["2"] = 5, ["3"] = 5, ["4"] = 5, ["5"] = 5, ["6"] = 5, ["7"] = 5,
            ["8"] = 5, ["9"] = 5, ["("] = 5, [")"] = 5, ["_"] = 5, ["-"] = 5,
            ["+"] = 5, ["="] = 5, ["\\"] = 5, ["/"] = 5, ["<"] = 5, [">"] = 5,
            ["?"] = 5, [","] = 5, ["."] = 5, ["!"] = 5, ["@"] = 5, ["#"] = 5,
            ["$"] = 5, ["%"] = 5, ["^"] = 5, ["&"] = 5, ["*"] = 5, ["'"] = 5,
            ['"'] = 5, [":"] = 5, [";"] = 5, [" "] = 5
        },
        WIDE_BLACK = {
            ["A"] = 7, ["B"] = 6, ["C"] = 6, ["D"] = 6, ["E"] = 6, ["F"] = 6,
            ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6, ["K"] = 6, ["L"] = 6,
            ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6, ["Q"] = 7, ["R"] = 6,
            ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6, ["W"] = 6, ["X"] = 6,
            ["Y"] = 6, ["Z"] = 6, ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6,
            ["4"] = 6, ["5"] = 6, ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6,
            ["("] = 6, [")"] = 6, ["_"] = 6, ["-"] = 6, ["+"] = 6, ["="] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, ["?"] = 6, [","] = 6,
            ["."] = 6, ["!"] = 6, ["@"] = 7, ["#"] = 6, ["$"] = 6, ["%"] = 6,
            ["^"] = 6, ["&"] = 6, ["*"] = 6, ["'"] = 6, ['"'] = 6, [":"] = 6,
            [";"] = 6
        }
    }
    
    --=====================================================
    -- Alias *_BLACK width tables to their non-black equivalents
    -- This keeps glyph support checks (lowercase, punctuation, etc.)
    -- consistent across light/dark textures.
    --=====================================================
    local function alias_widths(black_name)
        local base = black_name:gsub("_BLACK$", "")
        if self.char_widths[base] and not self.char_widths[black_name] then
            self.char_widths[black_name] = self.char_widths[base]
        end
    end

    for font_name, _ in pairs(self.font_sprites) do
        if font_name:match("_BLACK$") then
            alias_widths(font_name)
        end
    end
    
    self.player_fonts = {}
    
    Net:on("player_join", function(event)
        self:setupPlayerFonts(event.player_id)
    end)
    
    Net:on("player_disconnect", function(event)
        self:cleanupPlayerFonts(event.player_id)
    end)
    
    return self
end

function FontSystem:setupPlayerFonts(player_id)
    self.player_fonts[player_id] = {
        active_displays = {},
        next_obj_id = 10000  -- Start with high ID to avoid conflicts
    }
    
    -- Only initialize sprite manager if available
    if SpriteManager then
        -- Initialize sprite manager for this player
        SpriteManager.init_player(player_id)
        
        -- Get sprite manager for this player
        local sprite_manager = SpriteManager.get_player_manager(player_id)
        
        -- Allocate sprites for each font type
        for font_name, sprite_data in pairs(self.font_sprites) do
            sprite_manager:strict_alloc_sprite(sprite_data.sprite_id, {
                texture_path = sprite_data.texture_path,
                anim_path = sprite_data.anim_path,
                anim_state = sprite_data.anim_state
            })
        end
    end
end

function FontSystem:cleanupPlayerFonts(player_id)
    local player_data = self.player_fonts[player_id]
    if player_data then
        -- Erase all active displays using sprite manager
        for display_id, display in pairs(player_data.active_displays) do
            self:eraseTextDisplay(player_id, display_id)
        end
        
        -- Only deallocate if SpriteManager is available
        if SpriteManager then
            -- Deallocate all font sprites using sprite manager
            local sprite_manager = SpriteManager.get_player_manager(player_id)
            for font_name, sprite_data in pairs(self.font_sprites) do
                sprite_manager:dealloc_sprite(sprite_data.sprite_id)
            end
            
            -- Clean up sprite manager for this player
            SpriteManager.cleanup_player(player_id)
        end
        
        self.player_fonts[player_id] = nil
    end
end

-- Returns the animation prefix for a font.
-- Dark fonts reuse the SAME animation state names as their base font.
local function anim_prefix_for_font(font_name)
    -- strip ONLY a trailing "_BLACK"
    return (font_name and font_name:gsub("_BLACK$", "")) or font_name
end

-- Smart punctuation normalization (FontSystem needs this too; nameplates use FontSystem directly)
local function normalize_glyph(raw)
    if not raw or raw == "" then return nil end
    if raw == " " then return " " end

    -- single quotes
    if raw == "�" or raw == "�" then raw = "'" end

    -- double quotes
    if raw == "�" or raw == "�" then raw = '"' end

    -- dashes
    if raw == "�" or raw == "�" then raw = "-" end

    return raw
end

-- Normalize punctuation into ASCII BEFORE we iterate by bytes.
local function normalize_text(text)
    if not text or text == "" then return text end

    text = text:gsub("\r", "")
    text = text:gsub("\239\187\191", "") -- UTF-8 BOM
    text = text:gsub("\194\160", " ")    -- NBSP

    -- UTF-8 smart punctuation
    text = text:gsub("�", "'"):gsub("�", "'")
    text = text:gsub("�", '"'):gsub("�", '"')
    text = text:gsub("�", "-"):gsub("�", "-")
    text = text:gsub("�", "...")

    -- CP1252 smart punctuation bytes (Windows-1252)
    local b = string.char
    text = text:gsub(b(0x91), "'"):gsub(b(0x92), "'")
    text = text:gsub(b(0x93), '"'):gsub(b(0x94), '"')
    text = text:gsub(b(0x96), "-"):gsub(b(0x97), "-")
    text = text:gsub(b(0x85), "...")

    return text
end

local DEBUG_UNKNOWN_GLYPHS = false  -- Set to false by default to reduce noise

local function dbg_unknown(font_name, raw_byte, state, text, i)
    if not DEBUG_UNKNOWN_GLYPHS then return end
    local byte = string.byte(raw_byte)
    print(string.format("[FontSystem] unknown glyph: font=%s i=%d byte=0x%02X state=%s context=%q",
        tostring(font_name), i, byte, tostring(state), tostring(text)))
end

-- Table with each letter of the alphabet as separate strings
local alphabet = {
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
}

-- Function to check if a string is in the alphabet table
local function isInAlphabet(str)
    for _, letter in ipairs(alphabet) do
        if letter == str then
            return true
        end
    end
    return false
end

function FontSystem:drawTextWithId(player_id, text, x, y, font_name, scale, z_order, display_id, properties)
    font_name = font_name or "THICK"
    scale = scale or 2.0
    z_order = z_order or 100
    text = normalize_text(text)

    local anchor_x, anchor_y = x, y
    if type(properties) == "table" then
        if properties.x ~= nil then anchor_x = properties.x end
        if properties.X ~= nil then anchor_x = properties.X end
        if properties.y ~= nil then anchor_y = properties.y end
        if properties.Y ~= nil then anchor_y = properties.Y end
    end

    local glyph_props = _props_without_xy(properties)

    local player_data = self.player_fonts[player_id]
    if not player_data then return nil end

    local existing = player_data.active_displays[display_id]

    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local base_spacing = 1
    local scaled_spacing = base_spacing * scale

    local glyph_props = _props_without_xy(properties)
    local props_sig = _props_sig(glyph_props)

    local function build_and_draw(start_x, start_y)
        local current_x = start_x or 0
        local obj_i = 0

        -- ensure table exists
        if not existing then
            existing = {
                font = font_name,
                x = start_x, y = start_y,
                scale = scale,
                z_order = z_order,
                character_objects = {},
                text = "",
                props_sig = props_sig
            }
            player_data.active_displays[display_id] = existing
        end

        local prefix = anim_prefix_for_font(font_name)
        
        -- Only use SpriteManager if available
        if SpriteManager then
            local sprite_manager = SpriteManager.get_player_manager(player_id)
            local sprite_id = SpriteConstants and SpriteConstants:get_font_sprite_id(font_name) or "font_" .. font_name

            -- Draw/update glyph sprites in place using stable obj ids
            for i = 1, #text do
                local raw = text:sub(i, i)
                local char = normalize_glyph(raw) or raw

                if (font_name == "BATTLE" or font_name == "WIDE") and char:match("%a") then
                    char = char:upper()
                end

                local char_width = char_widths[char] or char_widths["A"] or 6
                local scaled_width = char_width * scale

                -- Space: advance only (no sprite)
                if char == " " then
                    current_x = current_x + scaled_width + scaled_spacing
                else
                    obj_i = obj_i + 1
                    local obj_id = display_id .. "_char_" .. (10000 + obj_i)

                    local state
                    if char == char:lower() and isInAlphabet(char) then
                        state = prefix .. "_LOWER_" .. char:upper()
                    else
                        state = prefix .. "_" .. char
                    end

                    local spr_opts = {
                        id = obj_id,
                        x = current_x,
                        y = start_y,
                        z = z_order,
                        sx = scale,
                        sy = scale,
                        anim_state = state,
                        ro = properties.ro,
                        -- IMPORTANT: always reset sprite opacity so "dim" doesn't stick
                        opacity = 255
                    }

                    _merge_draw_params(spr_opts, glyph_props)
                    -- Use SpriteManager to draw the sprite
                    sprite_manager:draw_sprite(sprite_id, obj_id, spr_opts)

                    existing.character_objects[obj_i] = { obj_id = obj_id, width = scaled_width }
                    current_x = current_x + scaled_width + scaled_spacing
                end
            end

            -- Erase any leftover glyph sprites from the previous longer string
            for j = obj_i + 1, #existing.character_objects do
                local tail = existing.character_objects[j]
                if tail and tail.obj_id then
                    sprite_manager:erase_sprite(tail.obj_id)
                end
                existing.character_objects[j] = nil
            end
        else
            -- Fallback: simple text rendering without sprites
            print("[FontSystem] WARNING: SpriteManager not available, text rendering limited")
        end

        existing.font = font_name
        existing.x = start_x
        existing.y = start_y
        existing.scale = scale
        existing.z_order = z_order
        existing.text = text
        existing.props_sig = props_sig

        return display_id
    end

    -- If same text/style and same position (and same properties): no-op
    if existing
        and existing.text == text
        and existing.font == font_name
        and existing.scale == scale
        and existing.z_order == z_order
        and existing.x == anchor_x
        and existing.y == anchor_y
        and existing.props_sig == props_sig
    then
        return display_id
    end

    -- If same text/style but moved: just redraw positions (still no erase)
    -- If text/style changed: update in place + trim tail
    return build_and_draw(anchor_x, anchor_y)
end

function FontSystem:drawText(player_id, text_id, text, x, y, z_order, font_name, scale, properties)
    font_name = font_name or "THICK"
    scale = tonumber(scale) or 2.0
    z_order = z_order or 100
    text = normalize_text(text)

    local player_data = self.player_fonts[player_id]
    if not player_data then return nil end

    local display_id = text_id or ("text_" .. player_data.next_obj_id)
    player_data.next_obj_id = player_data.next_obj_id + 1

    local display_data = {
        font = font_name,
        x = x, y = y,
        scale = scale,
        z_order = z_order,
        character_objects = {},
        text = text
    }

    local current_x = x
    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local base_spacing = 1
    local scaled_spacing = base_spacing * scale

    -- Only use SpriteManager if available
    if SpriteManager then
        local sprite_manager = SpriteManager.get_player_manager(player_id)
        local sprite_id = SpriteConstants and SpriteConstants:get_font_sprite_id(font_name) or "font_" .. font_name

        for i = 1, #text do
            local raw = text:sub(i, i)
            local char = normalize_glyph(raw) or raw

            if (font_name == "BATTLE" or font_name == "WIDE") and char:match("%a") then
                char = char:upper()
            end

            local char_width = char_widths[char] or char_widths["A"] or 6
            local scaled_width = char_width * scale

            local obj_id = display_id .. "_char_" .. (10000 + i)

            local prefix = anim_prefix_for_font(font_name)
            local state
            if char == char:lower() and isInAlphabet(char) then
                state = prefix .. "_LOWER_" .. char:upper()
            else
                state = prefix .. "_" .. char
            end

            -- DEBUG: log any glyph that is not in the width table
            if char ~= " " and not char_widths[char] then
                dbg_unknown(font_name, raw, state, text, i)
            end

            -- Space: advance only (no sprite)
            if char == " " then
                current_x = current_x + scaled_width + scaled_spacing
                goto continue
            end

            local spr_opts = {
                id = obj_id,
                x = current_x, y = y, z = z_order,
                sx = scale, sy = scale,
                anim_state = state,
                opacity = 255
            }
            _merge_draw_params(spr_opts, properties)
            -- Use SpriteManager to draw the sprite
            sprite_manager:draw_sprite(sprite_id, obj_id, spr_opts)

            table.insert(display_data.character_objects, { obj_id = obj_id, width = scaled_width })
            current_x = current_x + scaled_width + scaled_spacing

            ::continue::
        end
    else
        print("[FontSystem] WARNING: SpriteManager not available, text rendering limited")
    end

    player_data.active_displays[display_id] = display_data
    return display_id
end

function FontSystem:eraseTextDisplay(player_id, display_id)
    local player_data = self.player_fonts[player_id]
    if player_data then
        local display = player_data.active_displays[display_id]
        if display then
            if SpriteManager then
                local sprite_manager = SpriteManager.get_player_manager(player_id)
                for _, char_data in ipairs(display.character_objects) do
                    sprite_manager:erase_sprite(char_data.obj_id)
                end
            end
            player_data.active_displays[display_id] = nil
        end
    end
end

function FontSystem:getTextWidth(text, font_name, scale)
    font_name = font_name or "THICK"
    scale = scale or 2.0
    text = normalize_text(text)

    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local total_width = 0
    
    -- FIXED: Calculate spacing that scales properly
    local base_spacing = 1  -- Base spacing at scale 1.0
    local scaled_spacing = base_spacing * scale
    
    for i = 1, #text do
        local raw = text:sub(i, i)
        local char = normalize_glyph(raw) or raw
        local char_width = char_widths[char] or char_widths["A"] or 6
        total_width = total_width + (char_width * scale) + scaled_spacing
    end
    
    -- Remove trailing spacing
    if #text > 0 then
        total_width = total_width - scaled_spacing
    end
    
    return total_width
end

local fontSystem = setmetatable({}, FontSystem)
fontSystem:init()

return fontSystem
