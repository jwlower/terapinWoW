-- ---------------------------------------------------------------------------------------
-- Silver, Gold and Truesilver as rare bonus drops from the common ore nodes.
--
-- Run against tw_world. IDEMPOTENT (absolute values via ON DUPLICATE KEY UPDATE).
-- Applies live with `.reload gameobject_loot_template` - no restart needed.
--
-- ---------------------------------------------------------------------------------------
-- WHY YOU CANNOT FIND SILVER OR GOLD NODES
--   They are genuinely scarce in the data, and it is not something the earlier gathering
--   tuning did. Spawn counts:
--
--       Copper Vein      1197        Silver Vein       108
--       Iron Deposit     1115        Gold Vein         227
--       Tin Vein          381        Truesilver Dep.   511
--       Mithril Deposit   470        Rich Thorium      643
--
--   Silver and Gold are the two rarest by a wide margin. That is vanilla-authentic: they
--   have few dedicated spawn points and mostly appear as bonus rolls sharing spawn points
--   with copper/tin/iron. Rather than fight that with spawn counts, this puts the precious
--   ore where you are already swinging a pick.
--
-- HOW NODE LOOT IS STRUCTURED
--   Mining nodes are gameobject_template type 3 (chest), where data1 is the loot id into
--   gameobject_loot_template. Existing rows look like:
--
--       entry    item  chance  groupid  min  max
--       5000052  2770  100     0        4    8     <- Copper Ore, the guaranteed yield
--       5000052  2835  100     0        2    5     <- Rough Stone, also guaranteed
--       5000052   774    1     1        1    1     <- Malachite  \
--       5000052   818    1     1        1    1     <- Tigerseye   > one gem group
--       5000052  1210    1     1        1    1     <- Shadowgem  /
--
--   groupid 0 entries roll INDEPENDENTLY at their own chance. groupid 1 is a single group
--   that yields at most one item. The new ore is added at groupid 0, so it is a separate
--   roll and does not compete with the gems or reduce their rate.
--
-- ONE LOOT ID COVERS EVERY VARIANT OF A NODE
--   Several gameobject entries share a loot id, so a single row reaches all of them:
--       5000052  Copper Vein 1731, 103713
--       5000051  Tin Vein 1732, 103711
--       5000087  Iron Deposit 1735, Ooze Covered Iron Deposit 73939
--       5000062  Mithril Deposit 2040, 176645, 150079, Ooze Covered Mithril 123310
--   That includes the Ooze Covered variants for free.
--
-- THE PROGRESSION
--   Each common node can yield the precious ore of roughly its own tier, and rarely the
--   one above it:
--
--       Copper   ->  Silver 5%
--       Tin      ->  Silver 8%,  Gold 3%
--       Iron     ->  Gold 6%,    Truesilver 3%
--       Mithril  ->  Truesilver 8%
--
--   Chances are per-node and independent. Tune by editing the numbers below and re-running;
--   nothing accumulates because every value is absolute.
--
--   Deliberately NOT touched: Silver Vein, Gold Vein, Truesilver Deposit and the Thorium
--   nodes. Those already drop the precious ore as their primary yield, and they are the
--   rare nodes this change exists to compensate for.
--
-- INTERACTION WITH tuning-node-yield.sql
--   That script rewrites the PRIMARY resource of each node (chance >= 80) to 4-8 and stone
--   to 2-5. Every row here is 3-8% chance, well under that threshold, so the two scripts do
--   not fight and can be re-run in either order.
-- ---------------------------------------------------------------------------------------

USE tw_world;

INSERT INTO gameobject_loot_template
  (entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount, condition_id)
VALUES
  -- Copper Vein -> Silver
  (5000052, 2775, 5, 0, 1, 2, 0),
  -- Tin Vein -> Silver, rarely Gold
  (5000051, 2775, 8, 0, 1, 2, 0),
  (5000051, 2776, 3, 0, 1, 1, 0),
  -- Iron Deposit -> Gold, rarely Truesilver
  (5000087, 2776, 6, 0, 1, 2, 0),
  (5000087, 7911, 3, 0, 1, 1, 0),
  -- Mithril Deposit -> Truesilver
  (5000062, 7911, 8, 0, 1, 2, 0)
ON DUPLICATE KEY UPDATE
  ChanceOrQuestChance = VALUES(ChanceOrQuestChance),
  groupid             = VALUES(groupid),
  mincountOrRef       = VALUES(mincountOrRef),
  maxcount            = VALUES(maxcount),
  condition_id        = VALUES(condition_id);

-- ---------------------------------------------------------------------------------------
-- Report: the full loot table of each touched node, so the additions can be seen in place.
-- ---------------------------------------------------------------------------------------
SELECT
  CASE glt.entry WHEN 5000052 THEN 'Copper Vein'
                 WHEN 5000051 THEN 'Tin Vein'
                 WHEN 5000087 THEN 'Iron Deposit'
                 WHEN 5000062 THEN 'Mithril Deposit' END AS node,
  it.name AS drops, glt.ChanceOrQuestChance AS pct, glt.groupid AS grp,
  CONCAT(glt.mincountOrRef, '-', glt.maxcount) AS qty
FROM gameobject_loot_template glt
JOIN item_template it ON it.entry = glt.item
WHERE glt.entry IN (5000052, 5000051, 5000087, 5000062)
  AND glt.mincountOrRef > 0
ORDER BY FIELD(glt.entry, 5000052, 5000051, 5000087, 5000062),
         glt.groupid, glt.ChanceOrQuestChance DESC;

-- ---------------------------------------------------------------------------------------
-- TO REVERT
--   DELETE FROM gameobject_loot_template
--   WHERE (entry, item) IN ((5000052,2775),(5000051,2775),(5000051,2776),
--                           (5000087,2776),(5000087,7911),(5000062,7911));
--   Then `.reload gameobject_loot_template`.
-- ---------------------------------------------------------------------------------------
