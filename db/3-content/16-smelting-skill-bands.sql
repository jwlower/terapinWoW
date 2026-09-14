-- ---------------------------------------------------------------------------------------
-- Give the high smelting tiers a real skill-up band.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq
-- (the CLIENT colours the crafting window from its own SkillLineAbility.dbc, so both
-- halves must carry the same numbers).
--
-- THE PROBLEM
--   In skill_line_ability, min_value is where a recipe turns green and max_value is where
--   it turns grey. The low tiers have a proper band; five of the high tiers have
--   min_value == max_value, so they go grey the instant they become usable and grant no
--   skill-ups at all:
--
--       Smelt Copper       25 -> 70     fine
--       Smelt Tin          50 -> 75     fine
--       Smelt Bronze       65 -> 115    fine
--       Smelt Silver      100 -> 125    fine
--       Smelt Gold        170 -> 185    fine
--       Smelt Steel       165 -> 165    <- dead
--       Smelt Mithril     175 -> 175    <- dead
--       Smelt Truesilver  230 -> 230    <- dead
--       Smelt Dark Iron   230 -> 230    <- dead
--       Smelt Thorium     250 -> 250    <- dead
--       Dreamsteel        300 -> 300    <- dead
--
--   Mithril is the one that gets noticed, because it is where a miner naturally parks.
--
-- THE BANDS
--   Each tier now carries skill roughly to where the next one becomes worthwhile, matching
--   the spacing the working low tiers already use.
-- ---------------------------------------------------------------------------------------

USE tw_world;

UPDATE skill_line_ability SET max_value = 210 WHERE spell_id = 3569;    -- Smelt Steel      165 -> 210
UPDATE skill_line_ability SET max_value = 230 WHERE spell_id = 10097;   -- Smelt Mithril    175 -> 230
UPDATE skill_line_ability SET max_value = 250 WHERE spell_id = 10098;   -- Smelt Truesilver 230 -> 250
UPDATE skill_line_ability SET max_value = 270 WHERE spell_id = 14891;   -- Smelt Dark Iron  230 -> 270
UPDATE skill_line_ability SET max_value = 290 WHERE spell_id = 16153;   -- Smelt Thorium    250 -> 290
UPDATE skill_line_ability SET max_value = 320 WHERE spell_id = 57121;   -- Dreamsteel       300 -> 320

-- Iron greys at 140, only ten points above where it turns green. Widened to match the
-- spacing of the tiers either side of it.
UPDATE skill_line_ability SET max_value = 165 WHERE spell_id = 3307;    -- Smelt Iron       130 -> 165

SELECT s.name, sla.min_value AS green_from, sla.max_value AS grey_at
FROM skill_line_ability sla JOIN spell_template s ON s.entry = sla.spell_id
WHERE sla.skill_id = 186 AND s.effect1 = 24
ORDER BY sla.min_value;
