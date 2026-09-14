-- ---------------------------------------------------------------------------------------
-- Warrior thrown abilities: Heavy Throw, Twin Throw, Crippling Throw.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.
--
-- ALL THREE REQUIRE A THROWN WEAPON EQUIPPED
--   Every one is cloned from Throw (2764), which already carries
--       EquippedItemClass = 2         (weapon)
--       EquippedItemSubClassMask = 65536  (1 << 16 = thrown)
--   so the requirement is inherited rather than set by hand, and the client shows the
--   correct "Requires Thrown" line for free. Throw's SpellFamilyName is 8 (rogue), so that
--   IS overridden to 4 (warrior).
--
-- WHY TWIN THROW TRIGGERS A SEPARATE SPELL TWICE
--   The goal is two chances to crit, so warrior on-crit effects have two rolls. Two
--   SPELL_EFFECT_WEAPON_DAMAGE effects on one spell would NOT do that - mangos accumulates
--   them into a single damage event with a single attack roll. Two SPELL_EFFECT_TRIGGER_SPELL
--   effects pointing at the same hidden spell (38402) cast it twice, and each cast rolls its
--   own crit.
--
-- WHICH ON-CRIT TALENTS ACTUALLY FIRE (decoded from spell_proc_event + spell_template)
--   Deep Wounds  procFlags 69972 = DEAL_HARMFUL_SPELL | DEAL_HARMFUL_ABILITY |
--                DEAL_RANGED_ABILITY (0x100) | DEAL_RANGED_ATTACK (0x40) |
--                DEAL_MELEE_ABILITY | DEAL_MELEE_SWING,  procEx 2 (CRITICAL_HIT)
--                -> DOES include ranged, so a thrown crit CAN apply Deep Wounds.
--   Flurry       procFlags 4116 = DEAL_HARMFUL_ABILITY | DEAL_MELEE_ABILITY |
--                DEAL_MELEE_SWING
--                -> melee only, so thrown crits will NOT proc Flurry.
--   Enrage       procFlags 139944 are all TAKE_* flags; it fires when you are hit, so it is
--                unrelated either way.
--
--   There is no "always crit" or per-spell crit bonus in 1.12 spell data - crit chance comes
--   from the character, not the spell. Two rolls is the honest way to raise the odds.
--
-- RAGE COSTS: powerType 1, and the cost is stored x10 (Hamstring's 100 = 10 rage).
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM spell_template     WHERE entry    IN (38400,38401,38402,38403,38410,38411,38412);
DELETE FROM npc_trainer        WHERE spell    IN (38400,38401,38402,38403,38410,38411,38412);
DELETE FROM skill_line_ability WHERE spell_id IN (38400,38401,38402,38403,38410,38411,38412);

-- ---------------------------------------------------------------------------------------
-- 38400  Heavy Throw - a hard single throw.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_s;
CREATE TEMPORARY TABLE tmp_s LIKE spell_template;
INSERT INTO tmp_s SELECT * FROM spell_template WHERE entry = 2764;
UPDATE tmp_s SET entry = 38400,
  name = 'Heavy Throw', nameSubtext = '',
  description = 'Hurls your thrown weapon with great force, causing weapon damage plus $s1. Requires a thrown weapon.',
  effect1 = 58,                 -- SPELL_EFFECT_WEAPON_DAMAGE
  effectBasePoints1 = 29,       -- +30 on top of thrown weapon damage (amount is points+1)
  effect2 = 0, effect3 = 0,
  SpellFamilyName = 4,          -- warrior (Throw is family 8, rogue)
  spellLevel = 20, baseLevel = 20,
  RecoveryTime = 8000, categoryRecoveryTime = 0,
  powerType = 1, manaCost = 150;   -- 15 rage
INSERT INTO spell_template SELECT * FROM tmp_s;
DROP TEMPORARY TABLE tmp_s;

-- ---------------------------------------------------------------------------------------
-- 38402  Twin Throw (hit) - the hidden half. Not trainable, not in any skill line; it
--        exists only to be cast twice by 38401 so each cast rolls its own crit.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_s;
CREATE TEMPORARY TABLE tmp_s LIKE spell_template;
INSERT INTO tmp_s SELECT * FROM spell_template WHERE entry = 2764;
UPDATE tmp_s SET entry = 38402,
  name = 'Twin Throw', nameSubtext = '',
  description = 'A thrown weapon strike.',
  effect1 = 58,
  effectBasePoints1 = 9,        -- +10 per throw
  effect2 = 0, effect3 = 0,
  SpellFamilyName = 4,
  spellLevel = 24, baseLevel = 24,
  RecoveryTime = 0, powerType = 1, manaCost = 0;
INSERT INTO spell_template SELECT * FROM tmp_s;
DROP TEMPORARY TABLE tmp_s;

-- ---------------------------------------------------------------------------------------
-- 38401  Twin Throw - throws twice. Two TRIGGER_SPELL effects, both pointing at 38402.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_s;
CREATE TEMPORARY TABLE tmp_s LIKE spell_template;
INSERT INTO tmp_s SELECT * FROM spell_template WHERE entry = 2764;
UPDATE tmp_s SET entry = 38401,
  name = 'Twin Throw', nameSubtext = '',
  description = 'Hurls two thrown weapons at once. Each strikes separately and can critically hit, giving two chances to trigger effects that respond to critical strikes. Requires a thrown weapon.',
  effect1 = 64, effectTriggerSpell1 = 38402,   -- SPELL_EFFECT_TRIGGER_SPELL
  effect2 = 64, effectTriggerSpell2 = 38402,   -- ...again: two casts, two crit rolls
  effectBasePoints1 = 0, effectBasePoints2 = 0,
  effect3 = 0,
  SpellFamilyName = 4,
  spellLevel = 24, baseLevel = 24,
  RecoveryTime = 12000, categoryRecoveryTime = 0,
  powerType = 1, manaCost = 200;   -- 20 rage
INSERT INTO spell_template SELECT * FROM tmp_s;
DROP TEMPORARY TABLE tmp_s;

-- ---------------------------------------------------------------------------------------
-- 38403  Crippling Throw - light damage plus a slow. Slow values copied from Hamstring
--        (aura 33 SPELL_AURA_MOD_DECREASE_SPEED), deepened to -50% over a shorter 8s.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_s;
CREATE TEMPORARY TABLE tmp_s LIKE spell_template;
INSERT INTO tmp_s SELECT * FROM spell_template WHERE entry = 2764;
UPDATE tmp_s SET entry = 38403,
  name = 'Crippling Throw', nameSubtext = '',
  description = 'Hurls your thrown weapon at the target''s legs, causing weapon damage plus $s1 and slowing movement by $s2% for $d. Requires a thrown weapon.',
  effect1 = 58,
  effectBasePoints1 = 4,        -- +5
  effect2 = 6,                  -- SPELL_EFFECT_APPLY_AURA
  effectApplyAuraName2 = 33,    -- SPELL_AURA_MOD_DECREASE_SPEED
  effectBasePoints2 = -51,      -- -50%
  effectImplicitTargetA2 = 6,   -- same enemy target as the damage
  effect3 = 0,
  DurationIndex = 31,           -- SpellDuration.dbc 31 = 8000 ms
  SpellFamilyName = 4,
  spellLevel = 22, baseLevel = 22,
  RecoveryTime = 15000, categoryRecoveryTime = 0,
  powerType = 1, manaCost = 100;   -- 10 rage
INSERT INTO spell_template SELECT * FROM tmp_s;
DROP TEMPORARY TABLE tmp_s;

-- ---------------------------------------------------------------------------------------
-- Teachers. npc_trainer rejects anything that is not a LEARN_SPELL wrapper.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_t;
CREATE TEMPORARY TABLE tmp_t LIKE spell_template;
INSERT INTO tmp_t SELECT * FROM spell_template WHERE entry = 5243;
UPDATE tmp_t SET entry = 38410, name = 'Heavy Throw', nameSubtext = '',
  description = 'Teaches Heavy Throw.', effect1 = 36, effectTriggerSpell1 = 38400,
  effect2 = 0, effect3 = 0, effectApplyAuraName1 = 0, effectBasePoints1 = 0,
  SpellFamilyName = 4, spellLevel = 20, baseLevel = 20,
  DurationIndex = 0, RecoveryTime = 0, manaCost = 0;
INSERT INTO spell_template SELECT * FROM tmp_t;
UPDATE tmp_t SET entry = 38411, name = 'Twin Throw',
  description = 'Teaches Twin Throw.', effectTriggerSpell1 = 38401,
  spellLevel = 24, baseLevel = 24;
INSERT INTO spell_template SELECT * FROM tmp_t;
UPDATE tmp_t SET entry = 38412, name = 'Crippling Throw',
  description = 'Teaches Crippling Throw.', effectTriggerSpell1 = 38403,
  spellLevel = 22, baseLevel = 22;
INSERT INTO spell_template SELECT * FROM tmp_t;
DROP TEMPORARY TABLE tmp_t;

-- ---------------------------------------------------------------------------------------
-- File them under Fury so they appear on that spellbook tab. 38402 is deliberately absent:
-- it is the hidden half of Twin Throw and must never show up anywhere.
--
-- Without a skill_line_ability row a spell is invisible in the TRAINER window too - the
-- client groups trainer entries by skill line and drops anything filed under none. That is
-- exactly how Expeditious Retreat went missing. See sql/03.
-- ---------------------------------------------------------------------------------------
INSERT INTO skill_line_ability
  (id, skill_id, spell_id, race_mask, class_mask, req_skill_value,
   superseded_by_spell, learn_on_get_skill, max_value, min_value, req_train_points)
VALUES
  (7280, 256, 38400, 0, 1, 0, 0, 0, 0, 0, 0),   -- Fury
  (7281, 256, 38401, 0, 1, 0, 0, 0, 0, 0, 0),
  (7282, 256, 38403, 0, 1, 0, 0, 0, 0, 0, 0);

INSERT INTO npc_trainer (entry, spell, spellcost, reqskill, reqskillvalue, reqlevel)
VALUES
  (2600200, 38410, 2000, 0, 0, 20),
  (2600200, 38412, 2500, 0, 0, 22),
  (2600200, 38411, 3000, 0, 0, 24);

-- ---------------------------------------------------------------------------------------
-- Report.
-- ---------------------------------------------------------------------------------------
SELECT entry, name, effect1, effectTriggerSpell1 AS trig1, effect2, effectTriggerSpell2 AS trig2,
       effectApplyAuraName2 AS aura2, effectBasePoints2 AS pts2, DurationIndex AS dur,
       EquippedItemClass AS eqcls, EquippedItemSubClassMask AS eqsub,
       RecoveryTime AS cd, manaCost AS rage_x10, SpellFamilyName AS fam
FROM spell_template WHERE entry IN (38400,38401,38402,38403) ORDER BY entry;

SELECT 'filed under Fury' AS what, skill_id, spell_id, class_mask
FROM skill_line_ability WHERE spell_id IN (38400,38401,38403);

SELECT 'taught by' AS what, ct.name, nt.spell, nt.reqlevel, nt.spellcost
FROM npc_trainer nt JOIN creature_template ct ON ct.entry = nt.entry
WHERE nt.spell IN (38410,38411,38412) ORDER BY nt.reqlevel;
