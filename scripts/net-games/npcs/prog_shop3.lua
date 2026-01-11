--=====================================================
-- prog_shop3.lua
-- Sapphire PROG shop NPC (Talk.vert_menu + shop skin)
-- Sells HPMem items with real money checks + live money UI updates
-- Econ adapter version (optional EZlibs)
--=====================================================

local Talk    = require("scripts/net-games/npcs/talk")
local Presets = require("scripts/net-games/npcs/talk_presets")

local Econ = require("scripts/net-games/compat/econ")

local PRICE_PER = 250
local ERROR_SFX_PATH = "/server/assets/net-games/sfx/card_error.ogg"

-- Terminal-only debug toggle
local ECON_DEBUG = true

local function play_error_sfx(player_id)
  Net.provide_asset_for_player(player_id, ERROR_SFX_PATH)
  if Net.play_sound_for_player then
    pcall(function() Net.play_sound_for_player(player_id, ERROR_SFX_PATH) end)
  elseif Net.play_sound then
    pcall(function() Net.play_sound(player_id, ERROR_SFX_PATH) end)
  end
end

local function fmt_m(n)
  -- IMPORTANT: Econ.get_money should be a number. If it ever comes back as a string,
  -- this still tries to parse it. If parsing fails, you’ll see 0$ (same as your old behavior).
  local money = tonumber(n)
  if not money then
    return "0$"
  end

  if money < 0 then money = 0 end

  local MILLION = 1000000
  local BILLION = 1000000000
  local HUNDRED_MILLION = 100 * MILLION

  -- floor to 3 decimals (no rounding up)
  local function floor3(x)
    return math.floor(x * 1000) / 1000
  end

  if money >= BILLION then
    local b = floor3(money / BILLION)
    return string.format("%.3fB$", b)
  end

  if money >= HUNDRED_MILLION then
    local m = floor3(money / MILLION)
    return string.format("%.3fM$", m)
  end

  -- default: raw, with $ suffix
  return tostring(math.floor(money)) .. "$"
end


local function econ_debug_dump(player_id, label)
  if not ECON_DEBUG then return end

  local has_ez = false
  if Econ.has_ezlibs then
    has_ez = Econ.has_ezlibs()
  end

  local money = Econ.get_money(player_id)
  local hp_mem = 0
  if Econ.get_hp_mem then
    hp_mem = Econ.get_hp_mem(player_id)
  end

  print(("[net-games][EconDBG]%s player=%s ezlibs=%s money=%s hp_mem=%s")
    :format(label or "", tostring(player_id), tostring(has_ez), tostring(money), tostring(hp_mem)))
end

local function qty_from_choice_id(choice_id)
  local n = tostring(choice_id):match("^HPMEM_(%d+)$")
  return tonumber(n) or 0
end

local function build_hpmem_options()
  local opts = {}
  for i = 1, 999 do
    local opt = {
      id = ("HPMEM_%d"):format(i),
      text = ("HPMEM%-2d %d$"):format(i, PRICE_PER * i),
    }

    if i == 14 then
      opt.image   = "/server/assets/net-games/ui/bewd.png"
      opt.image_w = 40
      opt.image_h = 40
    end

    if i == 1 then opt.image = "/server/assets/net-games/ui/card_shop_hpmem1.png" end
    if i == 2 then opt.image = "/server/assets/net-games/ui/card_shop_hpmem2.png" end
    if i == 3 then opt.image = "/server/assets/net-games/ui/card_shop_hpmem3.png" end

    table.insert(opts, opt)
  end

  table.insert(opts, { id = "exit", text = "Exit" })
  return opts
end

Talk.npc({
  area_id = "default",
  object  = "ProgShop3",
  name    = "SAPPHIRE PROG",

  texture_path   = "/server/assets/ow/prog/prog_ow_sapphire.png",
  animation_path = "/server/assets/ow/prog/prog_ow.animation",

  on_interact = function(player_id, _bot_id, bot_name)
    econ_debug_dump(player_id, " (on_interact)")

    local layout = Presets.get_vert_menu_layout("prog_prompt_shop")
    layout.monies_amount_text = fmt_m(Econ.get_money(player_id))
    layout.frame = Presets.frames.sapphire

    local assets = {
      menu_bg       = "/server/assets/net-games/ui/prompt_vert_menu_shop_an.png",
      menu_bg_anim  = "/server/assets/net-games/ui/prompt_vert_menu_an.animation",
      menu_bg_frame = "/server/assets/net-games/ui/prompt_vert_menu_shop_an_frame.png",
      highlight     = "/server/assets/net-games/ui/highlight_shop.png",
    }

    Talk.vert_menu(player_id, bot_name, {
      mug = "prog_sapphire",
      nameplate = "prog",
      frame = "sapphire",
    }, {
      open_question = "Hey!{p_1} Wanna check out my shop?!",
      intro_text    = "Just let me know if you see anything you like.",
      texts = {
        decline_open = "Alright!{p_0.5} Come back if you change your mind!",
      },

      options = build_hpmem_options(),
      sfx   = "card_desc",
      flow  = "prog_prompt",
      assets = assets,
      layout = layout,

      on_select = function(ctx)
        if ctx.choice_id == "exit" then return end

        local qty = qty_from_choice_id(ctx.choice_id)
        if qty <= 0 then
          return { post_text = "Huh? That item is busted." }
        end

        local cost = PRICE_PER * qty
        local money = Econ.get_money(ctx.player_id)

        if money < cost then
          play_error_sfx(ctx.player_id)
          econ_debug_dump(ctx.player_id, (" (insufficient need=%d have=%d)"):format(cost, money))

          return {
            post_text = "Sorry pal,{p_0.5} you don't have enough monies!",
            suppress_confirm_sfx = true,
            after_branch = "no",
          }
        end

        local ok = Econ.try_spend_money(ctx.player_id, cost)
        if not ok then
          play_error_sfx(ctx.player_id)
          econ_debug_dump(ctx.player_id, (" (spend_failed cost=%d)"):format(cost))

          return {
            post_text = "Woah— your monies changed.{p_0.5} Try again!",
            suppress_confirm_sfx = true,
            after_branch = "no",
          }
        end

        if Econ.add_hp_mem then
          Econ.add_hp_mem(ctx.player_id, qty)
        end

        -- Refresh money display immediately
        local new_money = Econ.get_money(ctx.player_id)
        if ctx.menu and ctx.menu.layout then
          ctx.menu.layout.monies_amount_text = fmt_m(new_money)
          if ctx.menu.render_menu_contents then
            ctx.menu:render_menu_contents(true)
          end
        end

        econ_debug_dump(ctx.player_id, (" (purchase_ok qty=%d cost=%d)"):format(qty, cost))
        return { post_text = ("Bought %dx HPMem!"):format(qty) }
      end,
    })
  end,
})
