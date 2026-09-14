-- ---------------------------------------------------------------------------------------
-- New spell: Expeditious Retreat (38000) - warrior escape
--
--   +50% movement speed for 6 seconds. Ends early if you attack. 3 minute cooldown.
--
-- Run against tw_world. IDEMPOTENT. Requires:
--   * LoadSpellsFromSql = 1 in mangosd.conf   (see below)
--   * patch-6.mpq installed client-side       (built by TurtleMod/build.py)
--   * a mangosd RESTART
--
-- BOTH HALVES ARE REQUIRED
--   A spell has to exist on both sides and they read different files. The client needs its
--   Spell.dbc row for the name, icon, tooltip and to let you cast it at all; the server
--   needs the mechanics. Install only one and the spell either does not appear or does
--   nothing.
--
-- WHY LoadSpellsFromSql MATTERS
--   By default (World.cpp:1485) the server reads its own dbc/Spell.dbc and ignores
--   spell_template entirely, so this INSERT would have no effect. Flipping the switch
--   makes spell_template authoritative.
--
--   That is also a small net improvement on its own: the server's DBC has 27,916 spells
--   while spell_template has 27,923, so nothing is lost by the switch.
--
--   World.cpp:2008 carries a caution about load ordering, but read carefully it says the
--   risk lies in the DBC branch - "With LoadSpellsFromSql = 1 the DBC branch never runs
--   and the difference is dormant." Flipping TO SQL is the safe direction.
--
-- HOW THE "ENDS IF YOU ATTACK" PART WORKS
--   AuraInterruptFlags = 0x1000 (AURA_INTERRUPT_FLAG_MELEE_ATTACK). Verified implemented:
--   Unit.cpp:2561 calls RemoveAurasWithInterruptFlags(AURA_INTERRUPT_FLAG_MELEE_ATTACK)
--   on `this` - the ATTACKER - at the end of AttackerStateUpdate, so the buff drops from
--   whoever swung rather than from the target.
--
--   AURA_INTERRUPT_FLAG_SPELL_ATTACK (0x2000) exists in the enum but has NO implementation
--   anywhere in the source, so it is deliberately not used - it would look correct in the
--   data and silently do nothing.
--
-- BUILT BY CLONING SPRINT
--   Sprint (2983) is already an instant, self-targeted +50% speed aura, so it carries the
--   right values in 160-odd fields we have no reason to think about.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM spell_template WHERE entry = 38000;

DROP TEMPORARY TABLE IF EXISTS tmp_spell;
CREATE TEMPORARY TABLE tmp_spell LIKE spell_template;
INSERT INTO tmp_spell SELECT * FROM spell_template WHERE entry = 2983;   -- Sprint rank 1

UPDATE tmp_spell SET
  entry                   = 38000,
  name                    = 'Expeditious Retreat',
  nameSubtext             = '',
  description             = 'Increases movement speed by $s1% for $d. The effect ends if you attack.',
  DurationIndex           = 32,          -- SpellDuration.dbc ID 32 = 6000 ms
  AuraInterruptFlags      = 4096,        -- 0x1000 AURA_INTERRUPT_FLAG_MELEE_ATTACK
  effect1                 = 6,           -- SPELL_EFFECT_APPLY_AURA
  effectApplyAuraName1    = 31,          -- SPELL_AURA_MOD_INCREASE_SPEED
  effectBasePoints1       = 49,          -- aura amount is basePoints + 1 -> +50%
  effectImplicitTargetA1  = 1,           -- TARGET_UNIT_CASTER
  effect2 = 0, effectApplyAuraName2 = 0, effectBasePoints2 = 0,
  effect3 = 0, effectApplyAuraName3 = 0, effectBasePoints3 = 0,
  SpellFamilyName         = 4,           -- SPELLFAMILY_WARRIOR
  spellLevel              = 10,
  baseLevel               = 10,
  RecoveryTime            = 180000,      -- 3 minutes
  categoryRecoveryTime    = 180000,
  manaCost                = 0,
  powerType               = 1;           -- rage, so it never shows a mana cost

INSERT INTO spell_template SELECT * FROM tmp_spell;

-- ---------------------------------------------------------------------------------------
-- Teach it. Put it on the Warrior Master so it is learnable like any other warrior ability.
-- ---------------------------------------------------------------------------------------
DELETE FROM npc_trainer WHERE entry = 2600200 AND spell = 38000;
INSERT INTO npc_trainer (entry, spell, spellcost, reqskill, reqskillvalue, reqlevel)
VALUES (2600200, 38000, 1000, 0, 0, 10);

SELECT entry, name, DurationIndex, AuraInterruptFlags, effect1,
       effectApplyAuraName1, effectBasePoints1, effectImplicitTargetA1,
       RecoveryTime, SpellFamilyName
FROM spell_template WHERE entry = 38000;

SELECT 'taught by' AS what, ct.name, nt.spellcost, nt.reqlevel
FROM npc_trainer nt JOIN creature_template ct ON ct.entry = nt.entry
WHERE nt.spell = 38000;

-- ---------------------------------------------------------------------------------------
-- TO REMOVE
--   DELETE FROM spell_template WHERE entry = 38000;
--   DELETE FROM npc_trainer    WHERE spell = 38000;
--   and rebuild patch-6.mpq without it (remove from TurtleMod/content.py)
-- ---------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------
-- File it under the warrior Protection skill line.
--
-- NOT cosmetic. Without this row the spell never appeared in the TRAINER window at all.
-- The server side was correct throughout - the npc_trainer row loaded, GetTrainerSpellState
-- returns GREEN at level 10, and the packet was sent - but the client groups trainer
-- entries by skill line, and a spell in no skill line has nowhere to be drawn. It is
-- dropped silently, with nothing logged on either side.
--
-- Diagnosed by diffing against a teacher that DID work (38150 Arms Buff): the two teacher
-- rows were identical apart from level, trigger and text, so the difference had to be in
-- what the trigger spell was filed under. 38100 had a skill_line_ability row; 38000 did not.
--
-- The client reads SkillLineAbility.dbc, the server reads this table, so both need the row
-- (patch-6.mpq carries the DBC side, built from TurtleMod/content.py).
-- ---------------------------------------------------------------------------------------
DELETE FROM skill_line_ability WHERE spell_id = 38000;
INSERT INTO skill_line_ability
  (id, skill_id, spell_id, race_mask, class_mask, req_skill_value,
   superseded_by_spell, learn_on_get_skill, max_value, min_value, req_train_points)
VALUES (7250, 257, 38000, 0, 1, 0, 0, 0, 0, 0, 0);

SELECT 'filed under' AS what, skill_id, spell_id, class_mask
FROM skill_line_ability WHERE spell_id = 38000;
