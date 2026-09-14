-- ---------------------------------------------------------------------------------------
-- Make a gathering node give its whole yield in ONE loot instead of several.
--
-- Run against tw_world. IDEMPOTENT: sets absolute target counts, never multiplies, so
-- re-running changes nothing the second time.
--
-- Re-apply after any re-run of compile-tortoise-wow.ps1 (the world import rebuilds these
-- tables). Reload in game with:  .reload gameobject_loot_template   (needs SEC_ADMINISTRATOR,
-- so run it from the mangosd console, which is SEC_CONSOLE) - no restart required.
--
-- HOW NODE LOOTING WORKS (src/game/Handlers/LootHandler.cpp:541)
--   A vein has minSuccessOpens/maxSuccessOpens (gameobject_template.data3/data4, normally
--   1 and 2). Each mining action is one "use":
--       min_amount = data3 * Rate.Mining.Amount
--       max_amount = data4 * Rate.Mining.Amount
--   The node survives until its use count reaches max_amount. So Rate.Mining.Amount
--   multiplies the NUMBER OF CLICKS, not the ore per click - at Rate.Mining.Amount = 3 a
--   copper vein needs 3-6 mining actions. That is the opposite of "all at once".
--
--   The ore per action comes from gameobject_loot_template.mincountOrRef/maxcount, which
--   ship at 1/1 for the primary ore. That is what this file raises.
--
-- ALSO SET Rate.Mining.Amount = 1 in mangosd.conf, or the node still wants several clicks.
--
-- NOTE: mincountOrRef < 0 means "reference another loot template", NOT a count. Those rows
-- are excluded below - changing them would corrupt the reference.
-- ---------------------------------------------------------------------------------------

SET @MIN_YIELD = 4;   -- minimum of the primary resource per loot
SET @MAX_YIELD = 8;   -- maximum

-- The loot ids belonging to gathering nodes (same name-based identification as
-- tuning-gathering.sql, since this fork keeps lock/skill data in Lock.dbc, not SQL).
DROP TEMPORARY TABLE IF EXISTS tmp_node_loot;
CREATE TEMPORARY TABLE tmp_node_loot (loot_id INT UNSIGNED PRIMARY KEY);

INSERT IGNORE INTO tmp_node_loot (loot_id)
SELECT DISTINCT gt.data1
FROM gameobject_template gt
WHERE gt.type = 3
  AND gt.data1 > 0
  AND (
        gt.name LIKE '%Vein%'
     OR gt.name LIKE '%Deposit%'
     OR gt.name LIKE '%Wood Tree%'
     OR gt.name IN (
          'Peacebloom','Silverleaf','Earthroot','Mageroyal','Briarthorn','Bruiseweed',
          'Wild Steelbloom','Grave Moss','Kingsblood','Liferoot','Fadeleaf','Goldthorn',
          "Khadgar's Whisker",'Wintersbite','Firebloom','Purple Lotus',"Arthas' Tears",
          'Sungrass','Blindweed','Ghost Mushroom','Gromsblood','Golden Sansam','Dreamfoil',
          'Mountain Silversage','Plaguebloom','Icecap','Black Lotus','Sorrowmoss'
        )
  );

-- Raise the count on the near-guaranteed primary resource only (chance >= 80). The low-chance
-- bonus rows - gems, Blood Shard, Rough Stone - are left alone so they stay occasional
-- rather than becoming a windfall on every node.
UPDATE gameobject_loot_template glt
SET glt.mincountOrRef = @MIN_YIELD,
    glt.maxcount      = @MAX_YIELD
WHERE glt.entry IN (SELECT loot_id FROM tmp_node_loot)
  AND glt.mincountOrRef > 0            -- never touch negative = loot-template reference
  AND glt.ChanceOrQuestChance >= 80;


-- ---------------------------------------------------------------------------------------
-- STONE. Mining stone (Rough/Coarse/Heavy/Solid/Dense) ships as a LOW-CHANCE secondary
-- drop - as little as 0.97% on some rows, 3-4% on others - which is why veins feel like
-- they give ore but almost no stone. The first UPDATE above deliberately skipped these,
-- because it only touched rows at chance >= 80 to avoid turning gems into guaranteed loot.
--
-- Here stone is handled explicitly: made a guaranteed drop with its own count range.
-- Scoped to NODE loot templates only, so stone in unrelated chests is untouched.
-- ---------------------------------------------------------------------------------------
SET @STONE_MIN = 2;
SET @STONE_MAX = 5;

UPDATE gameobject_loot_template glt
SET glt.ChanceOrQuestChance = 100,
    glt.mincountOrRef       = @STONE_MIN,
    glt.maxcount            = @STONE_MAX
WHERE glt.entry IN (SELECT loot_id FROM tmp_node_loot)
  AND glt.mincountOrRef > 0          -- never touch negative = loot-template reference
  AND glt.item IN (
        2835,   -- Rough Stone
        2836,   -- Coarse Stone
        2838,   -- Heavy Stone
        7912,   -- Solid Stone
        12365   -- Dense Stone
      );

DROP TEMPORARY TABLE IF EXISTS tmp_node_loot;
