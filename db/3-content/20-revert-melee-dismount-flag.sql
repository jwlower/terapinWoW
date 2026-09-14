-- ---------------------------------------------------------------------------------------
-- Reverts sql/19 (AURA_INTERRUPT_FLAG_MELEE_ATTACK on mount auras).
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART.
-- ---------------------------------------------------------------------------------------
--
-- WHY 19 DID NOT WORK
--   The flag itself is processed on the attacker only (Unit.cpp:2561, at the end of
--   Unit::AttackerStateUpdate), which was the correct discriminator. But it was
--   UNREACHABLE: Unit::Attack (Unit.cpp:5265) read
--
--       // player cannot attack in mount state
--       if (IsPlayer() && IsMounted())
--           return false;
--
--   so a mounted player never started an attack, AttackerStateUpdate never ran, and the
--   flag never fired. In game this showed up as being unable to attack anything at all
--   while mounted - the click just did nothing.
--
--   That guard is now a dismount rather than a refusal (terapin-core.patch), which acts at
--   attack INITIATION - better timing than waiting for the first swing to land.
--
-- WHY REVERT RATHER THAN LEAVE IT
--   With the core fix a player can never be mounted while swinging, so the bit is dead
--   weight for players. RemoveAurasWithInterruptFlags applies to any Unit, so leaving it
--   set would risk dismounting CREATURES that carry a mount aura. No benefit, nonzero risk.
--
-- RESTORING, NOT BLANKET-CLEARING
--   sql/19 OR-ed the bit into all 484 mount spells, but 50061/50062 (Gnome and Goblin
--   Racing Cars) SHIPPED with it set. Clearing it everywhere would corrupt those two, so
--   they are excluded here.
--
--   Original distribution, measured before sql/19 ran:
--       0        x481
--       4194304  x1     (0x400000, TELEPORTED)
--       4724736  x2     (0x481000, the two racing cars - includes 0x1000)
--
-- The client side needs no SQL: build.py rebuilds Spell.dbc from the client's pristine
-- patch-5.mpq every time, so removing the MODIFY entry from content.py is the whole revert.
-- ---------------------------------------------------------------------------------------

USE tw_world;

UPDATE spell_template
SET AuraInterruptFlags = AuraInterruptFlags & ~4096
WHERE (effectApplyAuraName1 = 78 OR effectApplyAuraName2 = 78 OR effectApplyAuraName3 = 78)
  AND entry NOT IN (50061, 50062);          -- shipped with the bit; leave them alone

SELECT 'AFTER' AS stage, AuraInterruptFlags, COUNT(*) AS n
FROM spell_template
WHERE effectApplyAuraName1 = 78 OR effectApplyAuraName2 = 78 OR effectApplyAuraName3 = 78
GROUP BY AuraInterruptFlags ORDER BY n DESC;
