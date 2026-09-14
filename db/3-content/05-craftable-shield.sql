-- ---------------------------------------------------------------------------------------
-- Make the Runed Copper Shield craftable by Blacksmithing, and drop its random suffix.
--
-- Run against tw_world. IDEMPOTENT. Requires a mangosd RESTART and the rebuilt
-- patch-6.mpq (which carries the client-side Spell.dbc and SkillLineAbility.dbc rows).
--
-- THE THREE-PART PATTERN FOR A CRAFTABLE ITEM
--   1. a CRAFT spell   - SPELL_EFFECT_CREATE_ITEM (24), makes the item, consumes reagents
--   2. a TEACH spell   - SPELL_EFFECT_LEARN_SPELL (36), what a trainer or Plans item sells
--   3. a skill_line_ability row - ties the craft spell to the profession and skill tier
--
--   Part 3 is what actually puts it in the Blacksmithing window under Shields. Without it
--   the spell exists and can be learned, but never appears in the crafting UI.
--
--   Learned the hard way: the first attempt made the shield vendor-sold with NO recipe at
--   all, so looking for it in the blacksmithing window found nothing - correctly.
--
-- WHY BOTH SQL AND DBC FOR THE SKILL LINK
--   The SERVER reads skill_line_ability from SQL - ObjectMgr::LoadSkillLineAbility does
--   `SELECT * FROM skill_line_ability` and SkillLineAbility.dbc is never loaded server-side.
--   The CLIENT reads only its DBC. So the same row has to exist in both places, which is
--   why patch-6.mpq now carries SkillLineAbility.dbc as well as Spell.dbc.
--
-- RANDOM SUFFIX REMOVED
--   The shield was cloned from Soldier's Shield, which has random_property = 1998 - the
--   "of the Bear" style random enchant roll. Cloning inherited it. Set to 0 so the item is
--   exactly the +3 Agility / +3 Stamina it is defined as.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. No more random suffix on the shield.
-- ---------------------------------------------------------------------------------------
UPDATE item_template SET random_property = 0 WHERE entry = 90100;

-- ---------------------------------------------------------------------------------------
-- 2. The craft spell (38002), cloned from the Runed Copper Breastplate recipe so it
--    inherits the right cast time, the anvil requirement (RequiresSpellFocus) and the
--    dozens of fields we have no reason to set by hand.
-- ---------------------------------------------------------------------------------------
DELETE FROM spell_template WHERE entry IN (38002, 38003);

DROP TEMPORARY TABLE IF EXISTS tmp_craft;
CREATE TEMPORARY TABLE tmp_craft LIKE spell_template;
INSERT INTO tmp_craft SELECT * FROM spell_template WHERE entry = 2667;

UPDATE tmp_craft SET
  entry               = 38002,
  name                = 'Runed Copper Shield',
  nameSubtext         = '',
  description         = 'Forges a Runed Copper Shield.',
  effect1             = 24,        -- SPELL_EFFECT_CREATE_ITEM
  effectItemType1     = 90100,
  effect2 = 0, effect3 = 0,
  effectTriggerSpell1 = 0,
  reagent1            = 2840, reagentCount1 = 10,   -- Copper Bar
  reagent2            = 774,  reagentCount2 = 1,    -- Malachite
  reagent3 = 0, reagentCount3 = 0,
  reagent4 = 0, reagentCount4 = 0;

INSERT INTO spell_template SELECT * FROM tmp_craft;

-- ---------------------------------------------------------------------------------------
-- 3. The teaching spell (38003). A trainer row must point at one of these, never at the
--    craft spell directly - npc_trainer rejects non-learning spells at load.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_teach2;
CREATE TEMPORARY TABLE tmp_teach2 LIKE spell_template;
INSERT INTO tmp_teach2 SELECT * FROM spell_template WHERE entry = 2754;   -- a real TRAINER
-- wrapper. 2760 "Plans: ..." is cast by the recipe ITEM and targets the CASTER, so a
-- trainer casting it teaches itself. See sql/09.

UPDATE tmp_teach2 SET
  entry               = 38003,
  name                = 'Runed Copper Shield',
  nameSubtext         = '',
  description         = 'Teaches you how to make a Runed Copper Shield.',
  effect1             = 36,        -- SPELL_EFFECT_LEARN_SPELL
  effectTriggerSpell1 = 38002,
  effectImplicitTargetA1 = 0,
  effect2 = 0, effect3 = 0;

INSERT INTO spell_template SELECT * FROM tmp_teach2;

-- ---------------------------------------------------------------------------------------
-- 4. File the craft spell under Blacksmithing so it shows in the crafting window.
--    Values match the Runed Copper Breastplate tier: usable at 90, grey at 160.
-- ---------------------------------------------------------------------------------------
DELETE FROM skill_line_ability WHERE spell_id = 38002;
INSERT INTO skill_line_ability
  (id, skill_id, spell_id, race_mask, class_mask, req_skill_value,
   superseded_by_spell, learn_on_get_skill, max_value, min_value, req_train_points)
VALUES (7211, 164, 38002, 0, 0, 90, 0, 0, 160, 120, 0);

-- ---------------------------------------------------------------------------------------
-- 5. Sell the plans at the Blacksmithing Master, and stop vendoring the finished shield -
--    it is craftable now, which is the point.
-- ---------------------------------------------------------------------------------------
DELETE FROM npc_trainer WHERE spell IN (38002, 38003);
INSERT INTO npc_trainer (entry, spell, spellcost, reqskill, reqskillvalue, reqlevel)
VALUES (2600300, 38003, 500, 164, 90, 0);

DELETE FROM npc_vendor WHERE entry = 2600300 AND item = 90100;

-- ---------------------------------------------------------------------------------------
-- 6. Report.
-- ---------------------------------------------------------------------------------------
SELECT st.entry, st.name, st.effect1, st.effectItemType1 AS makes,
       st.effectTriggerSpell1 AS teaches, st.reagent1, st.reagentCount1,
       st.reagent2, st.reagentCount2
FROM spell_template st WHERE st.entry IN (38002, 38003);

SELECT 'skill link' AS what, skill_id, spell_id, req_skill_value, min_value, max_value
FROM skill_line_ability WHERE spell_id = 38002;

SELECT 'taught by' AS what, ct.name, nt.spellcost, nt.reqskill, nt.reqskillvalue
FROM npc_trainer nt JOIN creature_template ct ON ct.entry = nt.entry WHERE nt.spell = 38003;

SELECT 'shield random suffix (want 0)' AS what, random_property FROM item_template WHERE entry = 90100;
