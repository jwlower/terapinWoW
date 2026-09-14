-- ---------------------------------------------------------------------------------------
-- Bosses drop two guaranteed good items on top of their normal loot.
--
-- Run against tw_world. IDEMPOTENT (drops and rebuilds its own groups each run).
-- Applies live with `.reload creature_loot_template` - no restart needed.
--
-- ---------------------------------------------------------------------------------------
-- THE TRICK: THE EQUAL-CHANCED POOL GUARANTEES A DROP WITH NO ARITHMETIC
--
--   LootTemplate::LootGroup::Roll (LootMgr.cpp:1151) ends with:
--
--       if (!ExplicitlyChanced.empty()) { ...roll, maybe return... }
--       if (!EqualChanced.empty())
--           return &EqualChanced[irand(0, EqualChanced.size() - 1)];
--       return nullptr;
--
--   Rows with ChanceOrQuestChance = 0 land in EqualChanced. A group made ENTIRELY of
--   chance-0 rows has an empty ExplicitlyChanced list, so the first block is skipped and
--   the second always returns something. That is a guaranteed drop, uniformly chosen,
--   without having to make the chances sum to exactly 100 - and with no risk of the
--   cumulative-overflow bug that silently kills entries past the 100 mark.
--
--   So each new group yields exactly one random rare-or-better item from that boss's own
--   table. Two groups, two guaranteed items, enough to hand something to two or three
--   people per kill.
--
-- WHY DUPLICATING ITEMS IS LEGAL HERE
--   The primary key of creature_loot_template is (entry, item, groupid) - three columns,
--   not two. The same item may therefore appear in several groups of one template, which
--   is exactly what makes this approach possible. Worth checking before relying on it;
--   a two-column key would have blocked it entirely.
--
-- WHICH CREATURES COUNT AS BOSSES
--   Reused from tuning-dungeon-respawn.sql: any creature with a spawn recorded in
--   tuning_dungeon_respawn_original, i.e. something that originally had a respawn of a day
--   or more on an instance map. That is a far better boss test than creature_template.rank,
--   because rank 1 (elite) covers most dungeon TRASH too - the Stockades Defias Inmates are
--   rank 1. 576 loot templates qualify.
--
-- GROUP IDS 50 AND 51
--   The highest groupid in the shipped data is 23 and the column is TINYINT UNSIGNED, so
--   50 and 51 are free and clearly ours. Anything in those two groups was created by this
--   script and is safe to delete.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. Boss loot templates.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_boss_loot;
CREATE TEMPORARY TABLE tmp_boss_loot (loot_id MEDIUMINT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;

INSERT IGNORE INTO tmp_boss_loot (loot_id)
SELECT DISTINCT ct.loot_id
FROM tuning_dungeon_respawn_original o
JOIN creature c ON c.guid = o.guid
JOIN creature_template ct ON ct.entry = c.id
WHERE ct.loot_id > 0;

-- ---------------------------------------------------------------------------------------
-- 2. The good items each boss can already drop: rare and better, real items only.
--    Deliberately sourced from the boss's OWN table, so nothing drops loot it should not.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_boss_good;
CREATE TEMPORARY TABLE tmp_boss_good (
  entry MEDIUMINT UNSIGNED NOT NULL,
  item  MEDIUMINT UNSIGNED NOT NULL,
  mincountOrRef INT NOT NULL,
  maxcount TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (entry, item)
) ENGINE=MEMORY;

INSERT IGNORE INTO tmp_boss_good (entry, item, mincountOrRef, maxcount)
SELECT clt.entry, clt.item, clt.mincountOrRef, clt.maxcount
FROM creature_loot_template clt
JOIN tmp_boss_loot b ON b.loot_id = clt.entry
JOIN item_template it ON it.entry = clt.item
WHERE clt.mincountOrRef > 0        -- real items, not template references
  AND clt.groupid NOT IN (50, 51)  -- never re-clone our own groups
  AND it.Quality >= 3;             -- rare, epic, legendary

-- ---------------------------------------------------------------------------------------
-- 3. Rebuild the two guaranteed groups. Delete-then-insert is what makes this re-runnable.
--    chance 0 puts every row in the equal-chanced pool - see the header.
-- ---------------------------------------------------------------------------------------
DELETE FROM creature_loot_template WHERE groupid IN (50, 51);

INSERT INTO creature_loot_template
  (entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount, condition_id)
SELECT g.entry, g.item, 0, 50, g.mincountOrRef, g.maxcount, 0 FROM tmp_boss_good g;

INSERT INTO creature_loot_template
  (entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount, condition_id)
SELECT g.entry, g.item, 0, 51, g.mincountOrRef, g.maxcount, 0 FROM tmp_boss_good g;

-- ---------------------------------------------------------------------------------------
-- 4. Report.
-- ---------------------------------------------------------------------------------------
SELECT 'boss loot templates considered' AS what, COUNT(*) AS n FROM tmp_boss_loot
UNION ALL
SELECT 'of those, having any rare+ item', COUNT(DISTINCT entry) FROM tmp_boss_good
UNION ALL
SELECT 'guaranteed-drop rows created', COUNT(*) FROM creature_loot_template WHERE groupid IN (50,51);

SELECT good_items_in_pool, COUNT(*) AS bosses FROM (
  SELECT entry, COUNT(*) AS good_items_in_pool FROM tmp_boss_good GROUP BY entry) x
GROUP BY good_items_in_pool ORDER BY good_items_in_pool LIMIT 10;

-- ---------------------------------------------------------------------------------------
-- NOTE ON SMALL POOLS
--   A boss whose table holds only one rare item will drop that same item twice. That is
--   the honest consequence of "guarantee two good drops" on a thin loot table, not a bug.
--   The distribution above shows how many bosses are in that position.
--
-- TO REVERT
--   DELETE FROM creature_loot_template WHERE groupid IN (50, 51);
--   Then `.reload creature_loot_template`.
-- ---------------------------------------------------------------------------------------
