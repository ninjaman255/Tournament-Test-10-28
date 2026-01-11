--=====================================================
-- prog_bank_prompt_red.lua
-- "Funny bank" version of prog_vert_prompt_red:
-- - Yes/No open prompt
-- - Vertical menu of 99 deposits: +100 .. +9900
-- - Confirm -> on YES, grants money using Net functions
-- - Debug: terminal-only
--=====================================================

local Talk = require("scripts/net-games/npcs/talk")

local BANK_DEBUG = true

local function dbg(player_id, msg)
  if not BANK_DEBUG then return end
  print(("[BANKDBG p=%s] %s"):format(tostring(player_id), msg))
end

local function build_bank_options()
  -- IDs will be 1..99 (numeric), text shows actual deposit amount.
  local opts = {}
  for i = 1, 999 do
    opts[#opts + 1] = {
      id = i,
      text = ("Withdrawal %d$"):format(i * 100),
    }
  end
  opts[#opts + 1] = { id = "exit", text = "Exit" }
  return opts
end

local function get_money(player_id)
  if not (Net and Net.get_player_money) then
    return nil, "Missing Net.get_player_money"
  end
  return tonumber(Net.get_player_money(player_id)) or 0
end

local function set_money(player_id, amount)
  if not (Net and Net.set_player_money) then
    return false, "Missing Net.set_player_money"
  end
  Net.set_player_money(player_id, amount)
  return true
end

Talk.npc({
  area_id = "default",
  object  = "ProgBankRed", -- add this object name in Tiled
  name    = "RED BANK PROG",

  texture_path   = "/server/assets/ow/prog/prog_ow_red.png",
  animation_path = "/server/assets/ow/prog/prog_ow.animation",

  preset = "prog_prompt",
  frame  = "red",
  mug    = "prog_red",
  nameplate = "prog",

  on_interact = function(player_id, _bot_id, bot_name)
    Talk.vert_menu(player_id, bot_name, {
      area_id = "default",
      object  = "ProgBankRed",
      preset  = "prog_prompt",
      frame   = "red",
      mug     = "prog_red",
      nameplate = "prog",
    }, {
      options = build_bank_options(),

      texts = {
        open_question = "Wanna check out the bank?",
        intro_text    = "Withdrawal menu:{p_0.5} pick an amount.",
        decline_open  = "Alright.{p_0.5} Keep your monies safe out there.",

        confirm_format = 'Withdrawal via "%s"?',
        post_select_format = 'Done: "%s".',

        after_yes    = "Anything else you'd like to deposit?",
        after_no     = "No worries. Want a different amount?",
        exit_goodbye = "Pleasure doing extremely legitimate business.",
      },

      sfx = "card_desc",
      flow = "prog_prompt",
      layout = "prog_prompt",

      on_select = function(ctx)
        if ctx.choice_id == "exit" then
          return
        end

        local n = tonumber(ctx.choice_id)
        if not n then
          dbg(ctx.player_id, "choice_id not numeric: " .. tostring(ctx.choice_id))
          return { post_text = "That option is busted." }
        end

        local add_amount = n * 100

        local cur, err = get_money(ctx.player_id)
        if cur == nil then
          dbg(ctx.player_id, "cannot read money: " .. tostring(err))
          return { post_text = "Bank systems offline (no money API)." }
        end

        local ok, set_err = set_money(ctx.player_id, cur + add_amount)
        if not ok then
          dbg(ctx.player_id, "cannot set money: " .. tostring(set_err))
          return { post_text = "Bank systems offline (can't set money)." }
        end

        local new_total = cur + add_amount
        dbg(ctx.player_id, ("withdrawal=%d old=%d new=%d"):format(add_amount, cur, new_total))

        -- The flow already prints post_select text; this overrides it with something better.
        return { post_text = ("Took out %d$! Total: %d$"):format(add_amount, new_total) }
      end,
    })
  end,
})
