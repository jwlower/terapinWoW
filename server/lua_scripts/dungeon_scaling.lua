-- Dungeon mentor scaling: walk into a dungeon well above its level and your power is held
-- back toward that dungeon. Leave, and it is gone.
--
-- A level 60 can run Ragefire Chasm with a level 15 friend without trivialising it. Their
-- gear, talents and abilities are all untouched - only the numbers coming out the other end
-- are level-appropriate.
--
-- WHAT IS REDUCED
--   damage done (aura 79), healing done (136) and maximum health (133), by percentage.
--
--   NOT stats. The obvious choice, MOD_TOTAL_STAT_PERCENTAGE (137), reduces TOTAL stats -
--   which includes everything the player's gear gives them. That makes good gear feel
--   worthless, which is the opposite of the point.
--
-- WHY A LADDER OF SPELLS
--   Eluna's Unit:AddAura applies a FIXED spell; there is no binding to set an aura's
--   magnitude at runtime. So the reduction is quantised into 5% steps (38730..38747) and we
--   pick the nearest one down. See TurtleMod/scaling.py.
--
-- WHY ON_UPDATE_ZONE AND NOT ON_MAP_CHANGE
--   PLAYER_EVENT_ON_MAP_CHANGE (28) is NOT bridged on this build - checked against every
--   e->On*() call in ElunaScriptBridge.cpp. ON_UPDATE_ZONE (27) is, at line 96, and dungeons
--   are their own zones, so entering and leaving both raise it.
--
--   It is also re-checked on login and on release, so the aura survives a death, a
--   disconnect or a summon into the middle of an instance.
--
-- THE TOGGLE
--   Typing  !scale  in say toggles it and the message is swallowed. It works by learning or
--   unlearning the marker spell 38722 "Unrestrained" - if you know it, scaling is skipped.
--   Default is therefore ON for everyone with nothing to grant.
--
--   A gossip option on the dungeon questgiver would be nicer, but neither OnGossipHello nor
--   OnGossipSelect is bridged to Eluna on this build, so chat is the available route.

local MARKER_SPELL   = 38722     -- known = opted OUT
local FIRST_SPELL    = 38730     -- 38730 = 5%, then +1 per 5%
local STEP           = 5
local MAX_REDUCTION  = 90
local TARGET_OFFSET  = 10        -- dungeon "real" level = required_level + this
local REDUCTION_CAP  = 85

local PLAYER_EVENT_ON_UPDATE_ZONE = 27
local PLAYER_EVENT_ON_LOGIN       = 3
local PLAYER_EVENT_ON_REPOP       = 35
local PLAYER_EVENT_ON_CHAT        = 18

-- TERAPIN_DUNGEON_LEVELS comes from dungeon_levels.lua, generated from
-- areatrigger_teleport.required_level. It loads first because the .toc-less lua_scripts
-- folder is read alphabetically and "dungeon_levels" sorts before "dungeon_scaling".
local LEVELS = TERAPIN_DUNGEON_LEVELS or {}

local function SpellForReduction(pct)
    if pct < STEP then
        return nil
    end
    if pct > MAX_REDUCTION then
        pct = MAX_REDUCTION
    end
    -- math.floor, not plain division: in Lua 5.2 `/` is float division, so this would
    -- hand AddAura a float id like 38731.0. Integral floats happen to survive the uint32
    -- check, but relying on that is asking for a sharp edge later.
    return FIRST_SPELL + math.floor(pct / STEP) - 1
end

local function ReductionFor(playerLevel, requiredLevel)
    local target = requiredLevel + TARGET_OFFSET
    if playerLevel <= target then
        return 0
    end
    local pct = math.floor(((playerLevel - target) * 100) / playerLevel)
    if pct > REDUCTION_CAP then
        pct = REDUCTION_CAP
    end
    return math.floor(pct / STEP) * STEP        -- quantise down to a step we have
end

local function ClearAll(player)
    for pct = STEP, MAX_REDUCTION, STEP do
        local s = SpellForReduction(pct)
        if s and player:HasAura(s) then
            player:RemoveAura(s)
        end
    end
end

-- The single place that decides what a player should have right now.
local function Apply(player)
    if player:HasSpell(MARKER_SPELL) then       -- opted out
        ClearAll(player)
        return
    end

    local required = LEVELS[player:GetMapId()]
    if not required then                        -- not in a scaled dungeon
        ClearAll(player)
        return
    end

    local want = SpellForReduction(ReductionFor(player:GetLevel(), required))
    if not want then
        ClearAll(player)
        return
    end

    if player:HasAura(want) then
        return                                  -- already correct, leave it alone
    end

    ClearAll(player)
    player:AddAura(want, player)
    player:SendBroadcastMessage(
        "|cffffcc00You hold back to suit this dungeon.|r Type |cff33ff99!scale|r to turn this off.")
end

local function OnZone(event, player, newZone, newArea)
    Apply(player)
end

local function OnLogin(event, player)
    Apply(player)
    if player:HasSpell(MARKER_SPELL) then
        player:SendBroadcastMessage(
            "|cffffcc00Dungeon scaling is OFF for you.|r Type |cff33ff99!scale|r to turn it back on.")
    end
end

-- Re-apply after a death: the aura is dropped on release, and a corpse run back into the
-- instance would otherwise leave the player unscaled.
local function OnRepop(event, player)
    Apply(player)
end

local function OnChat(event, player, msg, msgType, lang)
    if string.lower(msg) ~= "!scale" then
        return
    end

    if player:HasSpell(MARKER_SPELL) then
        player:RemoveSpell(MARKER_SPELL)
        player:SendBroadcastMessage("|cff33ff99Dungeon scaling ON.|r You will be held back in dungeons well below your level.")
    else
        player:LearnSpell(MARKER_SPELL)
        player:SendBroadcastMessage("|cffffcc00Dungeon scaling OFF.|r You will enter dungeons at full power.")
    end

    Apply(player)
    return false        -- swallow the message so "!scale" is not broadcast to the zone
end

RegisterPlayerEvent(PLAYER_EVENT_ON_UPDATE_ZONE, OnZone)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_REPOP, OnRepop)
RegisterPlayerEvent(PLAYER_EVENT_ON_CHAT, OnChat)

local n = 0
for _ in pairs(LEVELS) do n = n + 1 end

if n == 0 then
    -- Verified against ElunaLoader.cpp:338, which sorts scripts by filepath, so
    -- dungeon_levels.lua loads before dungeon_scaling.lua. If that ever stops being true
    -- this file would quietly scale nobody, so say so loudly rather than doing nothing.
    print("[Terapin] dungeon_scaling.lua: NO DUNGEON LEVELS LOADED - is dungeon_levels.lua "
          .. "present, and does it still sort before this file? Scaling is DISABLED.")
else
    print("[Terapin] dungeon_scaling.lua loaded - " .. n .. " dungeons, marker " .. MARKER_SPELL)
end
