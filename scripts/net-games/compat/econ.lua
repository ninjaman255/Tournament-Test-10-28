-- scripts/net-games/compat/econ.lua
-- Econ adapter for NetGames NPCs:
--   - Uses EZlibs ezmemory if present
--   - Otherwise uses Net money API if present
--   - Otherwise falls back to non-persistent stubs (with warnings)

local Econ = {}

local function safe_require(mod)
  local ok, lib = pcall(require, mod)
  if ok then return lib end
  return nil
end

--=====================================================
-- EZlibs detection (REAL module path)
--=====================================================
local EzMemory =
  safe_require("scripts/ezlibs-scripts/ezmemory") or
  safe_require("scripts/ezlibs-scripts/ezmemory.lua") -- (belt + suspenders, harmless)

local HAS_EZLIBS = (EzMemory ~= nil)

--=====================================================
-- Non-persistent fallback storage
--=====================================================
local _stub_money = {}
local _stub_hp_mem = {}

local function warn_once(key, msg)
  _G.__NG_WARN_ONCE = _G.__NG_WARN_ONCE or {}
  if _G.__NG_WARN_ONCE[key] then return end
  _G.__NG_WARN_ONCE[key] = true
  print(msg)
end

--=====================================================
-- Money
--=====================================================
function Econ.get_money(player_id)
  -- Prefer authoritative runtime money if available
  if Net and Net.get_player_money then
    return tonumber(Net.get_player_money(player_id)) or 0
  end

  -- If EZlibs is present but Net.get_player_money isn't, try memory table (not ideal but works)
  if EzMemory and EzMemory.get_player_memory then
    local ok, helpers = pcall(require, "scripts/ezlibs-scripts/helpers")
    if ok and helpers and helpers.get_safe_player_secret then
      local safe_secret = helpers.get_safe_player_secret(player_id)
      local mem = EzMemory.get_player_memory(safe_secret)
      return tonumber(mem.money) or 0
    end
  end

  warn_once("econ_no_money_api",
    "[net-games][Econ] No Net.get_player_money; using non-persistent stub money.")
  return _stub_money[player_id] or 0
end

function Econ.set_money(player_id, amount)
  amount = math.max(0, math.floor(tonumber(amount) or 0))

  if EzMemory and EzMemory.set_player_money then
    EzMemory.set_player_money(player_id, amount)
    return true
  end

  if Net and Net.set_player_money then
    Net.set_player_money(player_id, amount)
    return true
  end

  warn_once("econ_no_set_money_api",
    "[net-games][Econ] No EZlibs set_player_money and no Net.set_player_money; using stub.")
  _stub_money[player_id] = amount
  return true
end

function Econ.add_money(player_id, delta)
  delta = math.floor(tonumber(delta) or 0)
  return Econ.set_money(player_id, Econ.get_money(player_id) + delta)
end

function Econ.try_spend_money(player_id, cost)
  cost = math.max(0, math.floor(tonumber(cost) or 0))

  -- Use EZlibs atomic-ish spend if available
  if EzMemory and EzMemory.spend_player_money then
    return EzMemory.spend_player_money(player_id, cost) == true
  end

  -- Otherwise do it ourselves
  local have = Econ.get_money(player_id)
  if have < cost then return false end
  Econ.set_money(player_id, have - cost)
  return true
end

--=====================================================
-- HP Memory (store as actual EZlibs item "HPMem" when available)
--=====================================================
function Econ.get_hp_mem(player_id)
  if EzMemory and EzMemory.count_player_item then
    return tonumber(EzMemory.count_player_item(player_id, "HPMem")) or 0
  end

  warn_once("econ_no_hpmem_api",
    "[net-games][Econ] No EZlibs HP mem; using non-persistent stub HP mem.")
  return _stub_hp_mem[player_id] or 0
end

function Econ.add_hp_mem(player_id, delta)
  delta = math.floor(tonumber(delta) or 0)
  if delta == 0 then return true end

  if EzMemory and EzMemory.give_player_item then
    -- NOTE: EZlibs ezmemory.give_player_item("HPMem") also applies HP logic in that system.
    -- That’s consistent with EZlibs behavior and persists correctly.
    EzMemory.give_player_item(player_id, "HPMem", delta)
    return true
  end

  _stub_hp_mem[player_id] = (Econ.get_hp_mem(player_id) + delta)
  return true
end

--=====================================================
-- Capability / detection flags
--=====================================================
function Econ.has_ezlibs()
  return HAS_EZLIBS
end

function Econ._ezmemory()
  return EzMemory
end

return Econ
