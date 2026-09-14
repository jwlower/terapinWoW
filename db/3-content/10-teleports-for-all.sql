-- ---------------------------------------------------------------------------------------
-- Free city teleports for every class, in the General tab, known from level 1.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.
--
-- WHAT CHANGES
--   * cost 120 mana + 1 Rune of Teleportation (17031)  ->  free, no reagent
--   * required level 20-30                             ->  1
--   * mage-only (skill_line_ability class_mask 128)    ->  everyone
--   * Arcane spellbook tab                             ->  General
--   * learned from a trainer                           ->  known from character creation
--
-- WHY DELETING THE skill_line_ability ROW IS THE WHOLE TRICK
--   "General" is not a skill line of its own - it is the ABSENCE of one. A spell with no
--   skill_line_ability row lands in General, and loses its class_mask gating at the same
--   time. So one deletion does both jobs.
--
--   The client reads SkillLineAbility.dbc and the server reads this table, so the row has
--   to go from both. patch-6.mpq handles the DBC side (content.SKILL_LINE_ABILITY_REMOVE).
--
--   Caveat this creates: with no skill line these can never be offered by a TRAINER again -
--   the client groups trainer entries by skill line and silently drops anything filed under
--   none. That is fine here precisely because they are pre-trained instead. See sql/03.
--
-- WHY GRANTING THEM TO ANY CLASS IS SAFE
--   Player::IsSpellFitByClassAndRace is only consulted on the trainer path (Player.cpp:5397).
--   Nothing purges "unfitting" spells at load, so a warrior who knows a mage teleport keeps
--   it across logins.
--
-- FACTION SPLIT
--   Alliance races 1,3,4,7,10 (Human, Dwarf, Night Elf, Gnome, High Elf)
--   Horde    races 2,5,6,8,9  (Orc, Undead, Tauren, Troll, Goblin)
--   Each side gets its own capitals. Handing a level 1 Horde character Teleport: Stormwind
--   would be a one-way trip into a hostile city, so the sets are kept apart on purpose -
--   say so if you want them crossed over anyway.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. Strip the costs and the level requirement.
--    Matched BY ID, not by name: "Teleport: Stormwind" is the name of both the teleport
--    (3561) and its LEARN_SPELL wrapper (665).
-- ---------------------------------------------------------------------------------------
UPDATE spell_template
SET manaCost = 0, reagent1 = 0, reagentCount1 = 0, spellLevel = 1, baseLevel = 1
WHERE entry IN (3561, 3562, 3565, 49361,      -- Alliance: Stormwind, Ironforge, Darnassus, Theramore
                3567, 3563, 3566, 49358);     -- Horde:    Orgrimmar, Undercity, Thunder Bluff, Stonard

-- ---------------------------------------------------------------------------------------
-- 2. Move them to General and drop the mage gating.
-- ---------------------------------------------------------------------------------------
DELETE FROM skill_line_ability
WHERE spell_id IN (3561, 3562, 3565, 49361, 3567, 3563, 3566, 49358);

-- ---------------------------------------------------------------------------------------
-- 3. Known from character creation, for every race/class combination that exists.
--    Built from playercreateinfo so only valid combos are inserted.
-- ---------------------------------------------------------------------------------------
DELETE FROM playercreateinfo_spell
WHERE spell IN (3561, 3562, 3565, 49361, 3567, 3563, 3566, 49358);

INSERT INTO playercreateinfo_spell (race, class, spell, note)
SELECT DISTINCT pci.race, pci.class, t.spell, 'TurtleMod: free teleport'
FROM playercreateinfo pci
JOIN (
    SELECT 3561 AS spell, 'A' AS side UNION ALL SELECT 3562,'A' UNION ALL
    SELECT 3565,'A' UNION ALL SELECT 49361,'A' UNION ALL
    SELECT 3567,'H' UNION ALL SELECT 3563,'H' UNION ALL
    SELECT 3566,'H' UNION ALL SELECT 49358,'H'
) t ON t.side = IF(pci.race IN (1,3,4,7,10), 'A', 'H');

-- ---------------------------------------------------------------------------------------
-- 4. Existing characters too - playercreateinfo_spell only fires at creation.
--    INSERT IGNORE so re-running cannot duplicate a row, and so a mage who already knows
--    its own teleports is left alone.
-- ---------------------------------------------------------------------------------------
INSERT IGNORE INTO tw_char.character_spell (guid, spell, active, disabled)
SELECT c.guid, t.spell, 1, 0
FROM tw_char.characters c
JOIN (
    SELECT 3561 AS spell, 'A' AS side UNION ALL SELECT 3562,'A' UNION ALL
    SELECT 3565,'A' UNION ALL SELECT 49361,'A' UNION ALL
    SELECT 3567,'H' UNION ALL SELECT 3563,'H' UNION ALL
    SELECT 3566,'H' UNION ALL SELECT 49358,'H'
) t ON t.side = IF(c.race IN (1,3,4,7,10), 'A', 'H');

-- ---------------------------------------------------------------------------------------
-- 5. Report.
-- ---------------------------------------------------------------------------------------
SELECT entry, name, manaCost, reagent1, spellLevel
FROM spell_template
WHERE entry IN (3561,3562,3565,49361,3567,3563,3566,49358) ORDER BY entry;

SELECT 'skill line rows left (want 0)' AS what, COUNT(*) AS n
FROM skill_line_ability WHERE spell_id IN (3561,3562,3565,49361,3567,3563,3566,49358);

SELECT 'playercreateinfo_spell rows' AS what, COUNT(*) AS n
FROM playercreateinfo_spell WHERE spell IN (3561,3562,3565,49361,3567,3563,3566,49358);

SELECT 'existing characters granted' AS what, COUNT(DISTINCT guid) AS n
FROM tw_char.character_spell WHERE spell IN (3561,3562,3565,49361,3567,3563,3566,49358);
