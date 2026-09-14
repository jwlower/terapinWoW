-- Summonable services: your class trainer, and a banker.
--
-- One spell per class (38700-38708) plus a shared banker call (38710). Which NPC a spell
-- summons is fixed here; WHO may cast it is decided by the grant in sql/23 - each class
-- spell is only ever taught to its own class, so there is nothing to check at cast time.
--
-- WHY THE NPC IS A TEMPORARY SUMMON
--   TEMPSUMMON_TIMED_DESPAWN (3) with a 5 minute timer. The alternative - a permanent
--   creature spawn - would litter the world with trainers, one per cast, forever.
--
-- SAFE TO RUN INLINE, unlike salvage.lua
--   PLAYER_EVENT_ON_SPELL_CAST fires part way through Spell::prepare, so anything that
--   FREES an object the running spell still points at will crash the server. This spawns a
--   new creature and touches nothing the spell owns, so there is nothing to defer.

local DESPAWN_MS = 300000    -- 5 minutes
local SPAWN_DIST = 2.0       -- yards in front of the caster
local TEMPSUMMON_TIMED_DESPAWN = 3

local SUMMONS = {
    [38700] = 2600200,   -- Warrior Master
    [38701] = 2600201,   -- Paladin Master
    [38702] = 2600202,   -- Hunter Master
    [38703] = 2600203,   -- Rogue Master
    [38704] = 2600204,   -- Priest Master
    [38705] = 2600205,   -- Shaman Master
    [38706] = 2600206,   -- Mage Master
    [38707] = 2600207,   -- Warlock Master
    [38708] = 2600208,   -- Druid Master
    [38710] = 2600400,   -- Banker (custom, faction 35 - usable by both sides)
}

local function OnSpellCast(event, player, spell, skipCheck)
    local entry = SUMMONS[spell:GetEntry()]
    if not entry then
        return
    end

    -- Two yards ahead, turned to face the caster.
    local x, y, z = player:GetRelativePoint(SPAWN_DIST, 0)
    local o = player:GetO() + math.pi

    player:SpawnCreature(entry, x, y, z, o, TEMPSUMMON_TIMED_DESPAWN, DESPAWN_MS)
end

RegisterPlayerEvent(5, OnSpellCast)   -- 5 = PLAYER_EVENT_ON_SPELL_CAST

print("[Terapin] summon_services.lua loaded - " .. "10 service summons")
