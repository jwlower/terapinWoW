-- ---------------------------------------------------------------------------------------
-- Mount management
--   (a) gather while mounted    - data only, this file + Spell.dbc via build.py
--   (b) auto-dismount in combat - lua_scripts/mount_combat.lua
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.
-- ---------------------------------------------------------------------------------------
--
-- (a) WHY THIS IS ONE BIT
--   Spells/Spell.cpp:5971 is the only thing that dismounts a player for casting:
--
--     if (m_casterUnit->IsMounted() && m_casterUnit->IsPlayer() && !m_IsTriggeredSpell &&
--         !m_spellInfo->IsPassiveSpell() &&
--         !(m_spellInfo->Attributes & SPELL_ATTR_CASTABLE_WHILE_MOUNTED))
--     {
--         m_casterUnit->Unmount();
--         m_casterUnit->RemoveSpellsCausingAura(SPELL_AURA_MOUNTED);
--     }
--
--   SPELL_ATTR_CASTABLE_WHILE_MOUNTED is 0x01000000 (SpellDefines.h:748). With the bit
--   set the branch is skipped and the player simply stays mounted. Every other Unmount()
--   in src/game is a taxi landing, a GM command or a creature, and mount auras carry
--   AuraInterruptFlags = 0, so no aura-interrupt path strips the mount either.
--
--   Gathering IS a player spell cast - the client picks whichever rank of Mining / Herb
--   Gathering / Skinning it knows and casts it at the node - so this is the whole fix.
--
-- ALL RANKS ON PURPOSE
--   The client casts the highest rank known. Flagging only rank 1 would work until a
--   player trained Journeyman and then silently stop.
--
-- OR, NOT ASSIGN
--   The three professions start from different Attributes values (Mining 65680 and 128,
--   Herbalism 128, Skinning 16). `| 16777216` preserves whatever each already had and is
--   idempotent on re-run; `= 16777216` would have wiped them.
-- ---------------------------------------------------------------------------------------

USE tw_world;

SELECT 'BEFORE' AS stage, entry, name, Attributes, IF(Attributes & 16777216,'yes','no') AS mounted
FROM spell_template
WHERE entry IN (2575,2576,2577,2578,2579,3564,10248,
                2366,2368,2369,2371,3570,11993,
                8613,8617,8618,10768);

UPDATE spell_template
SET Attributes = Attributes | 16777216          -- SPELL_ATTR_CASTABLE_WHILE_MOUNTED
WHERE entry IN (2575,2576,2577,2578,2579,3564,10248,   -- Mining, all ranks
                2366,2368,2369,2371,3570,11993,        -- Herb Gathering, all ranks
                8613,8617,8618,10768);                 -- Skinning, all ranks

-- Refuse to pass silently if the id list has drifted from what the DB holds.
SELECT 'AFTER' AS stage, COUNT(*) AS flagged, 17 AS expected
FROM spell_template
WHERE entry IN (2575,2576,2577,2578,2579,3564,10248,
                2366,2368,2369,2371,3570,11993,
                8613,8617,8618,10768)
  AND Attributes & 16777216;
