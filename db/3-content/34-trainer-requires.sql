-- ---------------------------------------------------------------------------------------
-- The "Requires Jewelcrafting (295)" line, for every custom gear recipe that was missing it.
--
-- Run against tw_world. IDEMPOTENT. No restart needed - npc_trainer is read per gossip.
-- ---------------------------------------------------------------------------------------
--
-- WHAT WAS WRONG
--   The client builds the grey "Requires <profession> (<n>)" line under a trainer entry from
--   npc_trainer.reqskill and .reqskillvalue, NOT from the spell. Nine custom Jewelcrafting
--   recipes on the Jewelcrafting Master (2600306) were inserted with both columns at 0, so
--   they listed with no requirement at all while every vanilla recipe beside them showed one.
--
--   sql/27 (white weapons) and sql/33 (craftable armour) already write both columns. This
--   backfills everything else and, being a derivation rather than a list, closes the gap for
--   any future recipe added to these trainers as well.
--
-- WHERE THE NUMBER COMES FROM
--   skill_line_ability.req_skill_value is 1 on essentially every recipe in this database and
--   gates nothing - the real gate is min_value. Measured on the nine:
--
--       Gemkeeper's Folio     req_skill_value 1   min_value 235
--       Twilight Opal Cascade req_skill_value 1   min_value 320
--
--   So min_value is what the requirement line should read.
--
-- WHY IT IS CLAMPED TO 300
--   Two of the nine carry a min_value above the profession cap (315 and 320). Gating a recipe
--   at a skill level no character can reach would hide it from the trainer forever. Existing
--   Jewelcrafting rows in this database top out at 280, so 300 is the ceiling.
--
-- WHY ONLY effect1 = 24
--   The join is restricted to taught spells that CREATE AN ITEM. "Apprentice Blacksmith" and
--   the other rank-learning entries sit on these same trainers with reqskill 0, and that is
--   correct - gating the spell that grants a profession behind skill in that profession would
--   make it unlearnable. Only real recipes get a requirement.
-- ---------------------------------------------------------------------------------------

USE tw_world;

UPDATE npc_trainer t
JOIN spell_template teach ON teach.entry = t.spell
JOIN spell_template craft ON craft.entry = teach.effectTriggerSpell1
JOIN skill_line_ability sla ON sla.spell_id = craft.entry
SET t.reqskill      = sla.skill_id,
    t.reqskillvalue = LEAST(GREATEST(sla.min_value, 1), 300)
WHERE t.entry BETWEEN 2600300 AND 2600399   -- the profession masters only
  AND t.reqskill = 0
  AND craft.effect1 = 24                    -- SPELL_EFFECT_CREATE_ITEM: real recipes only
  AND sla.min_value > 1;

-- Verification: every remaining reqskill = 0 row on a profession master should be a
-- rank-learning entry (Apprentice/Expert/Artisan/Master <profession>), never a recipe.
SELECT t.entry, t.spell, s.name, t.reqskill, t.reqskillvalue
FROM npc_trainer t JOIN spell_template s ON s.entry = t.spell
WHERE t.entry BETWEEN 2600300 AND 2600399 AND t.reqskill = 0
ORDER BY t.entry, t.spell;
