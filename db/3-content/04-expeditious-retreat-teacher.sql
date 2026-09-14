-- ---------------------------------------------------------------------------------------
-- The TEACHING spell for Expeditious Retreat (38001), and repointing the trainer at it.
--
-- Run against tw_world. IDEMPOTENT. Requires a mangosd RESTART.
--
-- WHY THIS EXISTS
--   The first attempt put the ability (38000) straight into npc_trainer, and the server
--   rejected it at load:
--       ERROR: Table `npc_trainer` for trainer (Entry: 2600200) has non-learning
--              spell 38000, ignore
--
--   npc_trainer.spell must be a TEACHING spell - one with SPELL_EFFECT_LEARN_SPELL (36)
--   whose effectTriggerSpell1 is the real ability. This is the same two-spell pattern the
--   riding skill uses: 33389 "Apprentice Riding" is what the trainer sells, and it teaches
--   33388 "Riding", the passive you actually keep.
--
--   So every new trainable ability needs a pair: the ability, and a teacher for it.
--
-- Cloned from 5243, the Battle Shout rank-2 teaching spell, which is exactly this shape:
--   entry 5243  effect1 36 (LEARN_SPELL)  effectTriggerSpell1 5242 (the real Battle Shout)
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM spell_template WHERE entry = 38001;

DROP TEMPORARY TABLE IF EXISTS tmp_teach;
CREATE TEMPORARY TABLE tmp_teach LIKE spell_template;
INSERT INTO tmp_teach SELECT * FROM spell_template WHERE entry = 5243;

UPDATE tmp_teach SET
  entry                  = 38001,
  name                   = 'Expeditious Retreat',
  nameSubtext            = '',
  description            = 'Teaches Expeditious Retreat.',
  effect1                = 36,        -- SPELL_EFFECT_LEARN_SPELL
  effectTriggerSpell1    = 38000,     -- the ability it grants
  effect2 = 0, effect3 = 0,
  effectApplyAuraName1 = 0, effectApplyAuraName2 = 0, effectApplyAuraName3 = 0,
  effectBasePoints1 = 0,
  SpellFamilyName        = 4,         -- SPELLFAMILY_WARRIOR
  spellLevel             = 10,
  baseLevel              = 10,
  DurationIndex          = 0,
  AuraInterruptFlags     = 0,
  RecoveryTime           = 0,
  manaCost               = 0;

INSERT INTO spell_template SELECT * FROM tmp_teach;

-- Point the Warrior Master at the TEACHER, not the ability.
DELETE FROM npc_trainer WHERE spell IN (38000, 38001);
INSERT INTO npc_trainer (entry, spell, spellcost, reqskill, reqskillvalue, reqlevel)
VALUES (2600200, 38001, 1000, 0, 0, 10);

SELECT st.entry, st.name, st.effect1, st.effectTriggerSpell1 AS teaches,
       t.name AS taught_ability
FROM spell_template st LEFT JOIN spell_template t ON t.entry = st.effectTriggerSpell1
WHERE st.entry IN (38000, 38001);

SELECT 'trainer now offers' AS what, nt.spell, ct.name
FROM npc_trainer nt JOIN creature_template ct ON ct.entry = nt.entry
WHERE nt.spell IN (38000, 38001);
