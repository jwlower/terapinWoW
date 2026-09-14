-- ---------------------------------------------------------------------------------------
-- Every new character starts trained in every weapon their class can ever learn.
--
-- Run against tw_world (and tw_char for existing characters). IDEMPOTENT.
-- Requires a mangosd RESTART - playercreateinfo_spell is read at startup.
-- ---------------------------------------------------------------------------------------
--
-- WHY THIS IS SAFE TO DERIVE RATHER THAN HAND-LIST
--   skill_line_ability.class_mask already says exactly which classes may learn each weapon
--   proficiency, as a bitmask over class ids: bit = 1 << (class - 1). Measured examples:
--
--       One-Handed Axes   (196)  class_mask 79   = Warrior|Paladin|Hunter|Rogue|Shaman
--       Staves            (227)  class_mask 1493 = Warrior|Hunter|Priest|Shaman|Mage|
--                                                   Warlock|Druid
--       Two-Handed Swords (202)  class_mask 7    = Warrior|Paladin|Hunter
--
--   So joining playercreateinfo against that mask grants each class precisely the set a
--   weapon master would have taught it, and nothing it was never allowed to hold. No list to
--   maintain, and it cannot drift if Turtle changes a proficiency.
--
-- WHAT IS INCLUDED
--   The 16 weapon skill lines in SkillLine.dbc category 6, minus the three that are not
--   weapons: Defense (95), Unarmed (162) and Dual Wield (118).
--
--   The "Shoot X" entries (2480 Shoot Bow, 7918 Shoot Gun, 7919 Shoot Crossbow, 5019 Shoot,
--   2764 Throw) come along too - they share the same skill lines and are the auto-attack
--   spells that make a ranged weapon actually usable. Granting the proficiency without them
--   would equip the weapon but leave you unable to fire it.
--
-- DUAL WIELD IS DELIBERATELY NOT INCLUDED
--   It is a skill, not a weapon, and it is normally a level gate rather than a trainer gate.
--   Add 674 to the list below if you want it from level 1.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DROP TEMPORARY TABLE IF EXISTS tmp_wpn;
CREATE TEMPORARY TABLE tmp_wpn (spell MEDIUMINT UNSIGNED NOT NULL, class_mask INT UNSIGNED NOT NULL,
                                PRIMARY KEY (spell)) ENGINE=MEMORY;

-- Every proficiency (and its matching auto-attack) from the weapon skill lines.
INSERT INTO tmp_wpn (spell, class_mask)
SELECT sla.spell_id, sla.class_mask
FROM skill_line_ability sla
WHERE sla.skill_id IN (43,44,45,46,54,55,136,160,172,173,176,226,227,228,229,473)
  AND sla.class_mask > 0
GROUP BY sla.spell_id, sla.class_mask;

-- Clear any previous run so the set is authoritative rather than accumulating.
DELETE FROM playercreateinfo_spell WHERE note = 'TurtleMod: weapon skills';

-- ---------------------------------------------------------------------------------------
-- Grant each race/class combination every proficiency its class_mask allows.
--   bit for class C is 1 << (C - 1)
-- ---------------------------------------------------------------------------------------
INSERT IGNORE INTO playercreateinfo_spell (race, class, Spell, Note)
SELECT DISTINCT p.race, p.class, w.spell, 'TurtleMod: weapon skills'
FROM playercreateinfo p
JOIN tmp_wpn w ON (w.class_mask & (1 << (p.class - 1))) > 0;

-- ---------------------------------------------------------------------------------------
-- Existing characters too - playercreateinfo_spell only fires at creation.
-- ---------------------------------------------------------------------------------------
INSERT IGNORE INTO tw_char.character_spell (guid, spell, active, disabled)
SELECT c.guid, w.spell, 1, 0
FROM tw_char.characters c
JOIN tmp_wpn w ON (w.class_mask & (1 << (c.class - 1))) > 0;

SELECT 'proficiency spells' AS what, COUNT(*) AS n FROM tmp_wpn;
SELECT 'creation grants' AS what, COUNT(*) AS n
FROM playercreateinfo_spell WHERE note = 'TurtleMod: weapon skills';

SELECT c.class,
       COUNT(DISTINCT w.spell) AS weapons_granted
FROM tw_char.characters c
JOIN tmp_wpn w ON (w.class_mask & (1 << (c.class - 1))) > 0
GROUP BY c.class ORDER BY c.class;

DROP TEMPORARY TABLE tmp_wpn;
