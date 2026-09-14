-- ---------------------------------------------------------------------------------------
-- Loot rebalance: fewer recipes, more bags, more uncommon gear.
--
-- Run against tw_world. IDEMPOTENT (snapshots originals, always recomputes from them).
-- Applies live with `.reload creature_loot_template` - no restart needed.
--
-- ---------------------------------------------------------------------------------------
-- WHAT WENT WRONG THE FIRST TIME
--   The previous version put a flat 0.5% FLOOR on every recipe row. That was the wrong
--   instrument, because recipe rows are enormously numerous per creature:
--
--       Blackwing Technician    546 recipe rows  ->  273% aggregate
--       Lord Kazzak              97 recipe rows  ->  392% aggregate
--       Ossirian                 35 recipe rows  ->  326% aggregate
--
--   A per-row floor multiplies by the row count, so several bosses ended up guaranteeing
--   multiple recipes per kill. Average aggregate across all creatures hit 15.4%.
--
--   It also explains the "not many general items" complaint. In a GROUP only one item
--   drops, so inflated recipes were winning group rolls and displacing everything else.
--   Cutting recipes back returns those slots to ordinary loot.
--
--   Fix: recipes get a plain multiplier with NO floor, plus a cap on the per-creature
--   AGGREGATE so a table with hundreds of recipe rows cannot stack past a sane total.
--
-- ---------------------------------------------------------------------------------------
-- THE TUNING
--       kind 1  Recipe     x2, no floor, aggregate per creature capped at 30%
--       kind 2  Bag        x3, floor 1.5%      (was 0.19% originally, still felt absent)
--       kind 3  Rare/Epic  x2                  (q3+; unchanged, no complaints)
--       kind 4  Uncommon   x3, floor 1.0%      (q2 greens - "less common items, more often")
--
--   Every value derives from tuning_loot_boost_original, so re-running never compounds and
--   retuning is just editing the numbers below.
--
-- THE GROUP TRAP (unchanged from before, still enforced)
--   Rows with groupid > 0 do not roll independently. LootTemplate::LootGroup::Roll
--   (LootMgr.cpp:1151) subtracts each chance from ONE random number:
--
--       float Roll = rand_chance_f();
--       for (const auto& i : ExplicitlyChanced) {
--           if (i.chance >= 100.0f) return &i;
--           Roll -= i.chance * (...) / 100.0f;
--           if (Roll < 0) return &i;
--       }
--
--   At most one item per group, chances cumulative. Once the running total passes 100 the
--   remaining entries become unreachable, silently. So grouped rows are only touched where
--   the group's ORIGINAL total was <= 45; 1,139 riskier groups are left alone.
--
--   chance = 0 rows are the EqualChanced pool, picked at random when explicit rolls miss.
--   They are excluded: giving them a chance would pull them out of that pool entirely.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. Eligible groups, decided once from ORIGINAL totals.
-- ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tuning_loot_boost_groups (
  entry   MEDIUMINT UNSIGNED NOT NULL,
  groupid TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (entry, groupid)
) ENGINE=InnoDB COMMENT='Loot groups whose original total was <= 45. tuning-loot-boost.sql.';

INSERT IGNORE INTO tuning_loot_boost_groups (entry, groupid)
SELECT entry, groupid FROM (
  SELECT entry, groupid, SUM(ChanceOrQuestChance) AS tot
  FROM creature_loot_template WHERE groupid > 0 AND mincountOrRef > 0
  GROUP BY entry, groupid) g
WHERE tot <= 45;

-- ---------------------------------------------------------------------------------------
-- 2. Snapshot originals. INSERT IGNORE, so rows captured on an earlier run keep their
--    true pre-boost value and only genuinely new rows (the q2 greens) are added now.
-- ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tuning_loot_boost_original (
  entry  MEDIUMINT UNSIGNED NOT NULL,
  item   MEDIUMINT UNSIGNED NOT NULL,
  chance FLOAT NOT NULL,
  kind   TINYINT NOT NULL,
  PRIMARY KEY (entry, item)
) ENGINE=InnoDB COMMENT='Pre-boost loot chances. tuning-loot-boost.sql.';

INSERT IGNORE INTO tuning_loot_boost_original (entry, item, chance, kind)
SELECT clt.entry, clt.item, clt.ChanceOrQuestChance,
       CASE WHEN it.class = 9 THEN 1
            WHEN it.class = 1 THEN 2
            WHEN it.Quality >= 3 THEN 3
            ELSE 4 END
FROM creature_loot_template clt
JOIN item_template it ON it.entry = clt.item
LEFT JOIN tuning_loot_boost_groups g ON g.entry = clt.entry AND g.groupid = clt.groupid
WHERE clt.mincountOrRef > 0
  AND clt.ChanceOrQuestChance > 0
  AND (it.class IN (1, 9) OR it.Quality >= 2)
  AND (clt.groupid = 0 OR g.entry IS NOT NULL);

-- ---------------------------------------------------------------------------------------
-- 3. Apply the per-kind formula.
-- ---------------------------------------------------------------------------------------
UPDATE creature_loot_template clt
JOIN tuning_loot_boost_original o ON o.entry = clt.entry AND o.item = clt.item
SET clt.ChanceOrQuestChance = LEAST(100, CASE o.kind
      WHEN 1 THEN o.chance * 2                      -- recipes: no floor
      WHEN 2 THEN GREATEST(o.chance * 3, 1.5)       -- bags
      WHEN 3 THEN o.chance * 2                      -- rare / epic
      ELSE      o.chance * 1.5                      -- uncommon greens: NO floor. The
                                                    -- floor was the flood - every green row
                                                    -- got >=1% and creatures have many.
    END);

-- ---------------------------------------------------------------------------------------
-- 4. Cap the AGGREGATE recipe chance per creature at 30%.
--    This is the part the floor version lacked. Without it, a loot table carrying hundreds
--    of recipe rows stacks to a guaranteed drop no matter how small each individual row is.
--    Scaling is proportional, so the relative odds between recipes on one creature are
--    preserved - only the total is reined in.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_recipe_sum;
CREATE TEMPORARY TABLE tmp_recipe_sum (
  entry MEDIUMINT UNSIGNED PRIMARY KEY,
  total FLOAT NOT NULL
) ENGINE=MEMORY;

INSERT INTO tmp_recipe_sum (entry, total)
SELECT clt.entry, SUM(clt.ChanceOrQuestChance)
FROM creature_loot_template clt
JOIN tuning_loot_boost_original o ON o.entry = clt.entry AND o.item = clt.item AND o.kind = 1
GROUP BY clt.entry
HAVING SUM(clt.ChanceOrQuestChance) > 30;

UPDATE creature_loot_template clt
JOIN tuning_loot_boost_original o ON o.entry = clt.entry AND o.item = clt.item AND o.kind = 1
JOIN tmp_recipe_sum r ON r.entry = clt.entry
SET clt.ChanceOrQuestChance = GREATEST(0.01, clt.ChanceOrQuestChance * 30 / r.total);

-- ---------------------------------------------------------------------------------------
-- 5. Report.
-- ---------------------------------------------------------------------------------------
SELECT CASE o.kind WHEN 1 THEN 'Recipe' WHEN 2 THEN 'Bag'
                   WHEN 3 THEN 'Rare/Epic+' ELSE 'Uncommon (green)' END AS kind,
       COUNT(*) AS rows_,
       ROUND(AVG(o.chance), 3) AS avg_before,
       ROUND(AVG(clt.ChanceOrQuestChance), 3) AS avg_after
FROM tuning_loot_boost_original o
JOIN creature_loot_template clt ON clt.entry = o.entry AND clt.item = o.item
GROUP BY o.kind ORDER BY o.kind;

SELECT 'aggregate recipe % per creature' AS what,
       ROUND(AVG(s), 1) AS avg_now, ROUND(MAX(s), 1) AS max_now FROM (
  SELECT clt.entry, SUM(clt.ChanceOrQuestChance) AS s
  FROM creature_loot_template clt JOIN item_template it ON it.entry = clt.item
  WHERE it.class = 9 AND clt.mincountOrRef > 0 GROUP BY clt.entry) a;

-- ---------------------------------------------------------------------------------------
-- TO REVERT EVERYTHING
--   UPDATE creature_loot_template clt
--   JOIN tuning_loot_boost_original o ON o.entry = clt.entry AND o.item = clt.item
--   SET clt.ChanceOrQuestChance = o.chance;
-- ---------------------------------------------------------------------------------------
