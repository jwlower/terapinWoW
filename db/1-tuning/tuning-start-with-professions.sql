-- #######################################################################################
-- SUPERSEDED - DO NOT RUN THIS ON ITS OWN.
--
-- This script grants the APPRENTICE rank of each profession, which pins the skill ceiling
-- at 75 (EffectLearnSkill computes max = step * 75, and Apprentice is step 1).
--
-- tuning-profession-ranks.sql replaced these grants with the ARTISAN rank (step 4 -> 300).
-- Re-running the script below will undo that fix and put the 75 cap back.
--
-- If you re-import the world database, run this first and THEN tuning-profession-ranks.sql,
-- which swaps the Apprentice grants out for Artisan ones.
-- #######################################################################################

-- ---------------------------------------------------------------------------------------
-- Every new character starts knowing every profession.
--
-- Run against tw_world. IDEMPOTENT (INSERT IGNORE on the full primary key), so it is safe
-- to re-run. Re-apply after any world re-import.
--
-- Takes effect for NEWLY CREATED characters only - playercreateinfo_spell is read at
-- character creation. Existing characters use `.learn all_trainer` instead.
--
-- Requires a mangosd RESTART: playercreateinfo_spell is loaded at startup.
--
-- WHY THIS WORKS WITHOUT SCRIPTING
--   playercreateinfo_spell(race, class, spell) is the core's own "grant this spell at
--   character creation" table. Adding a row per race/class per profession is exactly how
--   the starting Heroic Strike / Dodge / weapon proficiencies are granted, so professions
--   granted this way behave identically to trained ones.
--
-- WHICH SPELL IDS
--   These are the APPRENTICE-RANK spells - the ones a trainer sells - NOT the underlying
--   skill spells. For blacksmithing the trainer sells 2020 "Apprentice Blacksmith", which
--   has SPELL_EFFECT_LEARN_SPELL -> 2018 "Blacksmithing" (the skill itself) plus
--   SPELL_EFFECT_SKILL_STEP for skill 164. Granting 2018 directly would NOT set up the
--   skill correctly; 2020 is the right one.
--
-- PRIMARY PROFESSION LIMIT
--   Nine of these are primary professions. MaxPrimaryTradeSkill must be >= 9 or the
--   character will not be able to keep them all - it is set to 10 in mangosd.conf.
-- ---------------------------------------------------------------------------------------

DROP TEMPORARY TABLE IF EXISTS tmp_prof_spells;
CREATE TEMPORARY TABLE tmp_prof_spells (spell MEDIUMINT UNSIGNED PRIMARY KEY, note VARCHAR(64));

INSERT INTO tmp_prof_spells (spell, note) VALUES
    -- primary professions (9) - these consume MaxPrimaryTradeSkill slots
    (2020,  'Apprentice Blacksmith'),
    (2155,  'Apprentice Leatherworking'),
    (2275,  'Apprentice Alchemist'),
    (2372,  'Apprentice Herbalist'),
    (2581,  'Apprentice Miner'),
    (3911,  'Apprentice Tailor'),
    (4039,  'Apprentice Engineer'),
    (7414,  'Apprentice Enchanting'),
    (8615,  'Apprentice Skinning'),
    -- secondary professions - no slot cost
    (2551,  'Apprentice Cook'),
    (3279,  'Apprentice First Aid'),
    (7733,  'Apprentice Fishing'),
    -- Turtle WoW custom professions
    (30219, 'Apprentice Jewelcrafter'),
    (46051, 'Apprentice Survivalist');

-- Grant every profession to every race/class combination the server actually offers.
-- Cross-joining playercreateinfo (59 combos) against 14 professions = 826 rows.
INSERT IGNORE INTO playercreateinfo_spell (race, class, spell, note)
SELECT pci.race, pci.class, p.spell, p.note
FROM playercreateinfo pci
CROSS JOIN tmp_prof_spells p;

DROP TEMPORARY TABLE IF EXISTS tmp_prof_spells;
