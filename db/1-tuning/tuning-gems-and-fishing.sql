-- ---------------------------------------------------------------------------------------
-- Triple gem drops from ore nodes and clams, and speed up fishing pool respawns.
--
-- Run against tw_world. IDEMPOTENT (snapshots originals, recomputes from them).
-- Loot applies live: `.reload gameobject_loot_template` and `.reload item_loot_template`.
-- The fishing pool respawn change needs a mangosd RESTART (gameobject spawn data).
--
-- WHY AN EXPLICIT GEM LIST
--   Gems cannot be selected by class. Every one of them - Malachite through Azerothian
--   Diamond, and the pearls - is class 7, subclass 0, quality 2, which is exactly what
--   Coarse Thread and Mild Spices are too. There is no flag separating them, so the list
--   below is written out. It is the complete vanilla set plus the pearls; Black Diamond is
--   class 15 rather than 7, which is another reason a class filter would have missed it.
--
-- GROUP SAFETY
--   Same trap as creature loot: within a group (groupid > 0) only one item drops and the
--   chances are cumulative, so pushing a group's total past 100 makes later entries
--   unreachable (LootTemplate::LootGroup::Roll, LootMgr.cpp:1151). Gem groups are tiny -
--   copper's three gems total 3% - so tripling is safe, but the guard is applied anyway:
--   a group is only tripled if its original total was <= 30.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DROP TEMPORARY TABLE IF EXISTS tmp_gems;
CREATE TEMPORARY TABLE tmp_gems (item MEDIUMINT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT INTO tmp_gems (item) VALUES
  (774),   -- Malachite
  (818),   -- Tigerseye
  (1206),  -- Moss Agate
  (1210),  -- Shadowgem
  (1529),  -- Jade
  (1705),  -- Lesser Moonstone
  (3864),  -- Citrine
  (7909),  -- Aquamarine
  (7910),  -- Star Ruby
  (12361), -- Blue Sapphire
  (12364), -- Huge Emerald
  (12799), -- Large Opal
  (12800), -- Azerothian Diamond
  (11754), -- Black Diamond   (class 15, not 7)
  (5498),  -- Small Lustrous Pearl
  (5500),  -- Iridescent Pearl
  (7971),  -- Black Pearl
  (13926); -- Golden Pearl

-- ---------------------------------------------------------------------------------------
-- 1. Snapshot original gem chances from both loot sources.
--    src 1 = gameobject_loot_template (ore/mining nodes), src 2 = item_loot_template (clams)
-- ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tuning_gem_original (
  src    TINYINT NOT NULL,
  entry  MEDIUMINT UNSIGNED NOT NULL,
  item   MEDIUMINT UNSIGNED NOT NULL,
  chance FLOAT NOT NULL,
  PRIMARY KEY (src, entry, item)
) ENGINE=InnoDB COMMENT='Pre-tuning gem drop chances. tuning-gems-and-fishing.sql.';

INSERT IGNORE INTO tuning_gem_original (src, entry, item, chance)
SELECT 1, g.entry, g.item, g.ChanceOrQuestChance
FROM gameobject_loot_template g JOIN tmp_gems x ON x.item = g.item
WHERE g.mincountOrRef > 0 AND g.ChanceOrQuestChance > 0
  AND (g.groupid = 0 OR (SELECT SUM(g2.ChanceOrQuestChance) FROM gameobject_loot_template g2
        WHERE g2.entry = g.entry AND g2.groupid = g.groupid) <= 30);

INSERT IGNORE INTO tuning_gem_original (src, entry, item, chance)
SELECT 2, i.entry, i.item, i.ChanceOrQuestChance
FROM item_loot_template i JOIN tmp_gems x ON x.item = i.item
WHERE i.mincountOrRef > 0 AND i.ChanceOrQuestChance > 0
  AND (i.groupid = 0 OR (SELECT SUM(i2.ChanceOrQuestChance) FROM item_loot_template i2
        WHERE i2.entry = i.entry AND i2.groupid = i.groupid) <= 30);

-- ---------------------------------------------------------------------------------------
-- 2. Triple, capped at 100. Always computed from the snapshot, so re-running is inert.
-- ---------------------------------------------------------------------------------------
UPDATE gameobject_loot_template g
JOIN tuning_gem_original o ON o.src = 1 AND o.entry = g.entry AND o.item = g.item
SET g.ChanceOrQuestChance = LEAST(100, o.chance * 3);

UPDATE item_loot_template i
JOIN tuning_gem_original o ON o.src = 2 AND o.entry = i.entry AND o.item = i.item
SET i.ChanceOrQuestChance = LEAST(100, o.chance * 3);

-- ---------------------------------------------------------------------------------------
-- 3. Fishing pools respawn faster.
--    Fishing spots are GAMEOBJECT_TYPE_FISHINGHOLE (25), not chests - which is why a
--    type 3 search finds nothing. Shipped timers run 180-3600s, and the Stonescale /
--    Oily Blackmouth / Firefin schools sit at 1800-3600s, so a fished-out spot can take
--    an hour to return. Floating Wreckage (the flotsam) is 180-3600 and 900-3600.
--
--    Retimed to 60-300s: a pool is back within one to five minutes.
-- ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tuning_fishing_respawn_original (
  guid             INT UNSIGNED NOT NULL PRIMARY KEY,
  spawntimesecsmin INT UNSIGNED NOT NULL,
  spawntimesecsmax INT UNSIGNED NOT NULL
) ENGINE=InnoDB COMMENT='Pre-tuning fishing pool respawns. tuning-gems-and-fishing.sql.';

INSERT IGNORE INTO tuning_fishing_respawn_original (guid, spawntimesecsmin, spawntimesecsmax)
SELECT g.guid, g.spawntimesecsmin, g.spawntimesecsmax
FROM gameobject g JOIN gameobject_template gt ON gt.entry = g.id
WHERE gt.type = 25;

UPDATE gameobject g
JOIN tuning_fishing_respawn_original o ON o.guid = g.guid
SET g.spawntimesecsmin = 60, g.spawntimesecsmax = 300
WHERE g.spawntimesecsmin <> 60 OR g.spawntimesecsmax <> 300;

-- ---------------------------------------------------------------------------------------
-- 4. Report.
-- ---------------------------------------------------------------------------------------
SELECT 'gem rows: ore nodes' AS what, COUNT(*) AS n,
       ROUND(AVG(o.chance),2) AS avg_before, ROUND(AVG(g.ChanceOrQuestChance),2) AS avg_after
FROM tuning_gem_original o JOIN gameobject_loot_template g
  ON g.entry=o.entry AND g.item=o.item WHERE o.src=1
UNION ALL
SELECT 'gem rows: clams / containers', COUNT(*),
       ROUND(AVG(o.chance),2), ROUND(AVG(i.ChanceOrQuestChance),2)
FROM tuning_gem_original o JOIN item_loot_template i
  ON i.entry=o.entry AND i.item=o.item WHERE o.src=2
UNION ALL
SELECT 'fishing pools retimed to 60-300s', COUNT(*), NULL, NULL
FROM tuning_fishing_respawn_original;

-- ---------------------------------------------------------------------------------------
-- TO REVERT
--   UPDATE gameobject_loot_template g JOIN tuning_gem_original o
--     ON o.src=1 AND o.entry=g.entry AND o.item=g.item SET g.ChanceOrQuestChance=o.chance;
--   UPDATE item_loot_template i JOIN tuning_gem_original o
--     ON o.src=2 AND o.entry=i.entry AND o.item=i.item SET i.ChanceOrQuestChance=o.chance;
--   UPDATE gameobject g JOIN tuning_fishing_respawn_original o ON o.guid=g.guid
--     SET g.spawntimesecsmin=o.spawntimesecsmin, g.spawntimesecsmax=o.spawntimesecsmax;
-- ---------------------------------------------------------------------------------------
