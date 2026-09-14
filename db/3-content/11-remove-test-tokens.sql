-- ---------------------------------------------------------------------------------------
-- Remove the per-profession "Test Token" recipes.
--
-- Run against tw_world. IDEMPOTENT.
--
-- They did their job: they proved a recipe could be added to every profession, land in the
-- right crafting window at the right skill, and be taught by the right master. Now that
-- real content exists there is no reason to leave 11 junk items in the game.
--
-- The 27 class specialization buffs from the same test batch are deliberately KEPT - only
-- the profession tokens are removed.
--
--   items   90101-90111
--   craft   38200-38210
--   teacher 38220-38230
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM item_template      WHERE entry    BETWEEN 90101 AND 90111;
DELETE FROM spell_template     WHERE entry    BETWEEN 38200 AND 38210;
DELETE FROM spell_template     WHERE entry    BETWEEN 38220 AND 38230;
DELETE FROM npc_trainer        WHERE spell    BETWEEN 38200 AND 38230;
DELETE FROM skill_line_ability WHERE spell_id BETWEEN 38200 AND 38230;

-- Anyone who learned one during testing keeps a recipe the server no longer knows, and it
-- lingers in the crafting window doing nothing.
DELETE FROM tw_char.character_spell WHERE spell BETWEEN 38200 AND 38230;

-- Tokens already crafted into bags. Leaving them would orphan the item ids.
DELETE FROM tw_char.character_inventory
WHERE item IN (SELECT guid FROM tw_char.item_instance WHERE itemEntry BETWEEN 90101 AND 90111);
DELETE FROM tw_char.item_instance WHERE itemEntry BETWEEN 90101 AND 90111;

SELECT 'items left (want 0)'   AS what, COUNT(*) AS n FROM item_template  WHERE entry BETWEEN 90101 AND 90111;
SELECT 'spells left (want 0)'  AS what, COUNT(*) AS n FROM spell_template WHERE entry BETWEEN 38200 AND 38230;
SELECT 'trainer rows (want 0)' AS what, COUNT(*) AS n FROM npc_trainer    WHERE spell BETWEEN 38200 AND 38230;
SELECT 'class buffs KEPT'      AS what, COUNT(*) AS n FROM spell_template WHERE entry BETWEEN 38100 AND 38126;
