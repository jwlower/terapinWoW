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

-- TERAPIN_SUMMONS comes from summon_targets.lua, generated from TurtleMod/summons.py by
-- gen_summons.py - the same file that writes sql/23, so the spell-to-NPC mapping cannot
-- drift between the client DBC, the server SQL and this script.
--
-- READ LAZILY, NOT AT LOAD TIME. ElunaLoader.cpp:338 sorts scripts by filepath, and
-- "summon_services" sorts BEFORE "summon_targets" - so the data file loads second and the
-- global does not exist yet while this file is being run. (dungeon_scaling.lua can read its
-- table at load time only because "dungeon_levels" happens to sort before it.)
local SUMMONS = nil

local function OnSpellCast(event, player, spell, skipCheck)
    SUMMONS = SUMMONS or TERAPIN_SUMMONS
    if not SUMMONS then
        return              -- summon_targets.lua did not load; nothing we can do
    end

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

print("[Terapin] summon_services.lua loaded")
