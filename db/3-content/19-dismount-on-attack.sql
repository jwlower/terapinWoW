-- ---------------------------------------------------------------------------------------
-- Auto-dismount when YOU go to attack something - not when something attacks you.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.
-- ---------------------------------------------------------------------------------------
--
-- SUPERSEDES lua_scripts/mount_combat.lua, which has been retired.
--   That script hooked PLAYER_EVENT_ON_ENTER_COMBAT (33), which fires from
--   Unit::SetInCombatState (Unit.cpp:6767) in BOTH directions - attacking and being
--   attacked - with no way to tell them apart. The result was that a mob aggroing you threw
--   you off your horse, which kills mounted escape. Wrong trigger.
--
-- THE RIGHT TRIGGER
--   AURA_INTERRUPT_FLAG_MELEE_ATTACK (0x1000). Unit.cpp:2561, the last line of
--   Unit::AttackerStateUpdate:
--
--       pVictim->AttackedBy(this);
--       RemoveAurasWithInterruptFlags(AURA_INTERRUPT_FLAG_MELEE_ATTACK);
--
--   `this` is the unit doing the swinging, so the flag fires on the ATTACKER only. Being
--   hit does nothing. That is precisely "I went to attack something".
--
--   Removing the aura is a real dismount, not a dropped buff icon: Aura::HandleAuraMounted
--   (SpellAuras.cpp:2131) calls target->Unmount(true) on removal.
--
-- HOSTILE SPELLS ARE ALREADY COVERED
--   Spell.cpp:5971 dismounts for any cast lacking SPELL_ATTR_CASTABLE_WHILE_MOUNTED, so
--   opening with an ability or a shot already dismounts. Between that and this flag, every
--   way of starting a fight dismounts you - and nothing else does.
--
-- PRECEDENT
--   Turtle's own Gnome and Goblin Racing Cars (50061, 50062) already ship with 0x1000 set,
--   so the flag is known to work for mounts on this client.
--
-- OR, NOT ASSIGN
--   Three mounts carry non-zero flags already (0x400000 teleport, 0x481000 on the cars).
--   `| 4096` keeps those and is idempotent on re-run.
-- ---------------------------------------------------------------------------------------

USE tw_world;

SELECT 'BEFORE' AS stage, AuraInterruptFlags, COUNT(*) AS n
FROM spell_template
WHERE effectApplyAuraName1 = 78 OR effectApplyAuraName2 = 78 OR effectApplyAuraName3 = 78
GROUP BY AuraInterruptFlags ORDER BY n DESC;

UPDATE spell_template
SET AuraInterruptFlags = AuraInterruptFlags | 4096   -- AURA_INTERRUPT_FLAG_MELEE_ATTACK
WHERE effectApplyAuraName1 = 78                      -- SPELL_AURA_MOUNTED, any effect slot
   OR effectApplyAuraName2 = 78
   OR effectApplyAuraName3 = 78;

SELECT 'AFTER' AS stage,
       SUM(AuraInterruptFlags & 4096 > 0) AS with_flag,
       COUNT(*) AS total
FROM spell_template
WHERE effectApplyAuraName1 = 78 OR effectApplyAuraName2 = 78 OR effectApplyAuraName3 = 78;
