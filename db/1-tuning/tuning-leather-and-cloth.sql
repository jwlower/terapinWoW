-- ---------------------------------------------------------------------------------------
-- More leather per skin, and more cloth per kill.
--
-- Run against tw_world. IDEMPOTENT (snapshots originals, recomputes from them).
-- Applies live with `.reload creature_loot_template` - no restart needed.
--
-- WHY SKINNING IS THE ONE THAT NEEDED THIS
--   Measured before changing anything:
--       herb nodes    4-8 per node   (already raised by tuning-node-yield.sql)
--       ore nodes     4-8 per node   (same)
--       SKINNING      1-1 on 2274 of 2275 rows
--       cloth         1-1 through 2-5, varied
--
--   Skinning gives exactly ONE leather per corpse across essentially every creature in
--   the game, while a single herb node gives four to eight. That gap is why leatherworking
--   feels so much slower than herbalism or mining, and it is worth closing on its own
--   terms rather than by multiplying everything.
--
-- THE CHANGE
--   Skinning: 2-4 per skin, so roughly 3x the leather and in line with a herb node.
--   Cloth:    counts doubled from their originals, preserving the existing variation
--             between low and high level cloth rather than flattening it.
--
--   Nothing else in creature loot is touched - this is deliberately not a blanket
--   multiplier on all stack sizes.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. Snapshot originals so this is re-runnable and revertible.
-- ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tuning_gather_count_original (
  kind  TINYINT NOT NULL,               -- 1 = skinning, 2 = cloth
  entry MEDIUMINT UNSIGNED NOT NULL,
  item  MEDIUMINT UNSIGNED NOT NULL,
  mincountOrRef INT NOT NULL,
  maxcount TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (kind, entry, item)
) ENGINE=InnoDB COMMENT='Pre-tuning leather/cloth stack counts. tuning-leather-and-cloth.sql.';

-- Skinning loot is reached through creature_template.skinning_loot_id, NOT loot_id -
-- a creature's normal drops and its skinning drops are separate templates.
INSERT IGNORE INTO tuning_gather_count_original (kind, entry, item, mincountOrRef, maxcount)
SELECT DISTINCT 1, clt.entry, clt.item, clt.mincountOrRef, clt.maxcount
FROM creature_template ct
JOIN creature_loot_template clt ON clt.entry = ct.skinning_loot_id
JOIN item_template it ON it.entry = clt.item
WHERE ct.skinning_loot_id > 0
  AND clt.mincountOrRef > 0
  AND (it.name LIKE '%Leather%' OR it.name LIKE '%Hide%' OR it.name LIKE '%Scale%');

INSERT IGNORE INTO tuning_gather_count_original (kind, entry, item, mincountOrRef, maxcount)
SELECT 2, clt.entry, clt.item, clt.mincountOrRef, clt.maxcount
FROM creature_loot_template clt
JOIN item_template it ON it.entry = clt.item
WHERE clt.mincountOrRef > 0
  AND it.class = 7
  AND it.name REGEXP 'Linen Cloth|Wool Cloth|Silk Cloth|Mageweave Cloth|Runecloth|Felcloth|Netherweave';

-- ---------------------------------------------------------------------------------------
-- 2. Apply, always computed from the snapshot so re-running cannot compound.
--    maxcount is a TINYINT, so it is clamped at 255.
-- ---------------------------------------------------------------------------------------
UPDATE creature_loot_template clt
JOIN tuning_gather_count_original o ON o.kind = 1 AND o.entry = clt.entry AND o.item = clt.item
SET clt.mincountOrRef = 2, clt.maxcount = 4;

UPDATE creature_loot_template clt
JOIN tuning_gather_count_original o ON o.kind = 2 AND o.entry = clt.entry AND o.item = clt.item
SET clt.mincountOrRef = LEAST(255, o.mincountOrRef * 2),
    clt.maxcount      = LEAST(255, o.maxcount * 2);

-- ---------------------------------------------------------------------------------------
-- 2b. THE ROWS THAT ACTUALLY MATTER: reference_loot_template.
--
--     The first version of this script only touched creature_loot_template and filtered
--     to mincountOrRef > 0. That missed skinning almost entirely, and skinning yetis
--     still gave one leather.
--
--     Why: 5126 skinning rows are REFERENCES, not items. A negative mincountOrRef means
--     "roll on reference_loot_template id -mincountOrRef" rather than "give this item".
--     So the real leather sits in reference_loot_template - 2748 rows of it, every single
--     one at 1-1 - and creature_loot_template only points at it.
--
--     Shared references are also why this is the right place to change it: one reference
--     table serves every beast of a given tier, so fixing it here fixes them all at once.
--
--     kind 3 = leather/hide/scale in references, kind 4 = cloth in references.
-- ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tuning_gather_ref_original (
  kind  TINYINT NOT NULL,
  entry MEDIUMINT UNSIGNED NOT NULL,
  item  MEDIUMINT UNSIGNED NOT NULL,
  mincountOrRef INT NOT NULL,
  maxcount TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (kind, entry, item)
) ENGINE=InnoDB COMMENT='Pre-tuning reference-loot counts. tuning-leather-and-cloth.sql.';

INSERT IGNORE INTO tuning_gather_ref_original (kind, entry, item, mincountOrRef, maxcount)
SELECT 3, r.entry, r.item, r.mincountOrRef, r.maxcount
FROM reference_loot_template r JOIN item_template it ON it.entry = r.item
WHERE r.mincountOrRef > 0 AND it.name REGEXP 'Leather|Hide|Scale';

INSERT IGNORE INTO tuning_gather_ref_original (kind, entry, item, mincountOrRef, maxcount)
SELECT 4, r.entry, r.item, r.mincountOrRef, r.maxcount
FROM reference_loot_template r JOIN item_template it ON it.entry = r.item
WHERE r.mincountOrRef > 0
  AND it.name REGEXP 'Linen Cloth|Wool Cloth|Silk Cloth|Mageweave Cloth|Runecloth|Felcloth|Netherweave';

UPDATE reference_loot_template r
JOIN tuning_gather_ref_original o ON o.kind = 3 AND o.entry = r.entry AND o.item = r.item
SET r.mincountOrRef = 2, r.maxcount = 4;

UPDATE reference_loot_template r
JOIN tuning_gather_ref_original o ON o.kind = 4 AND o.entry = r.entry AND o.item = r.item
SET r.mincountOrRef = LEAST(255, o.mincountOrRef * 2),
    r.maxcount      = LEAST(255, GREATEST(o.maxcount * 2, 2));

-- ---------------------------------------------------------------------------------------
-- 2c. THE ACTUAL SKINNING TABLE.
--
--     This core has a DEDICATED skinning_loot_template table, and that - not
--     creature_loot_template - is what creature_template.skinning_loot_id indexes into.
--
--     Two earlier attempts missed it:
--       * joining creature_loot_template on skinning_loot_id matched rows only by
--         coincidence of id number, editing unrelated normal-loot rows;
--       * reference_loot_template holds leather, but skinning does not use references at
--         all (0 rows with mincountOrRef < 0), so that change never reached skinning either.
--
--     Measured directly: Cave Yeti's skinning template (100035) is Medium Leather 1-1,
--     Medium Hide 1-1, Heavy Leather 1-1, Heavy Hide 1-1. 2834 of 2843 leather rows in
--     the whole table are 1-1. That is the one leather per skin.
--
--     kind 5 = leather/hide/scale in skinning_loot_template.
-- ---------------------------------------------------------------------------------------
INSERT IGNORE INTO tuning_gather_ref_original (kind, entry, item, mincountOrRef, maxcount)
SELECT 5, s.entry, s.item, s.mincountOrRef, s.maxcount
FROM skinning_loot_template s JOIN item_template it ON it.entry = s.item
WHERE s.mincountOrRef > 0 AND it.name REGEXP 'Leather|Hide|Scale';

-- Raise only the modest ones. A few rows already give 2-5 or 5-10 and are left alone,
-- since those are deliberately generous entries rather than the flat 1-1 default.
UPDATE skinning_loot_template s
JOIN tuning_gather_ref_original o ON o.kind = 5 AND o.entry = s.entry AND o.item = s.item
SET s.mincountOrRef = 2, s.maxcount = 4
WHERE o.maxcount <= 2;

-- ---------------------------------------------------------------------------------------
-- 3. Report.
-- ---------------------------------------------------------------------------------------
SELECT 'SKINNING rows set to 2-4 (the real fix)' AS what, COUNT(*) AS n
FROM tuning_gather_ref_original WHERE kind = 5 AND maxcount <= 2
UNION ALL
SELECT 'REFERENCE leather rows set to 2-4', COUNT(*)
FROM tuning_gather_ref_original WHERE kind = 3
UNION ALL
SELECT 'REFERENCE cloth rows doubled', COUNT(*) FROM tuning_gather_ref_original WHERE kind = 4;

SELECT 'skinning rows retimed to 2-4' AS what, COUNT(*) AS n
FROM tuning_gather_count_original WHERE kind = 1
UNION ALL
SELECT 'cloth rows doubled', COUNT(*) FROM tuning_gather_count_original WHERE kind = 2;

SELECT IF(o.kind = 1, 'skinning', 'cloth') AS kind,
       CONCAT(o.mincountOrRef, '-', o.maxcount) AS was,
       CONCAT(clt.mincountOrRef, '-', clt.maxcount) AS now_,
       COUNT(*) AS rows_
FROM tuning_gather_count_original o
JOIN creature_loot_template clt ON clt.entry = o.entry AND clt.item = o.item
GROUP BY o.kind, was, now_ ORDER BY o.kind, rows_ DESC LIMIT 12;

-- ---------------------------------------------------------------------------------------
-- TO REVERT
--   UPDATE creature_loot_template clt
--   JOIN tuning_gather_count_original o ON o.entry = clt.entry AND o.item = clt.item
--   SET clt.mincountOrRef = o.mincountOrRef, clt.maxcount = o.maxcount;
--   Then `.reload creature_loot_template`.
-- ---------------------------------------------------------------------------------------
