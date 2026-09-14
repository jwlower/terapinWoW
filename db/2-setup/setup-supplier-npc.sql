-- ---------------------------------------------------------------------------------------
-- One summonable NPC stocking every vendor-sold crafting reagent and profession tool.
--
-- Run against tw_world. IDEMPOTENT (rebuilds its own rows from scratch each run).
-- Requires a mangosd RESTART - creature_template and npc_vendor are read at startup.
--
-- Summon it the same way as the dungeon questgivers:
--     .npc summon 2600100
--
-- ---------------------------------------------------------------------------------------
-- IT FITS IN ONE NPC - JUST
--   A vendor can list at most 128 items. Creature.h:486:
--       #define MAX_VENDOR_ITEMS 128   // Limitation in item count field size in SMSG_LIST_INVENTORY
--   and ItemHandler.cpp:982 stops adding once `count >= MAX_VENDOR_ITEMS`, so anything past
--   128 is silently dropped from the list rather than erroring.
--
--   The set below is 92 items, leaving 36 slots of headroom. So no split by profession is
--   needed. If you later add enough that it crosses 128, the overflow will vanish quietly -
--   the report at the bottom prints the count against the cap so that stays visible.
--
-- WHAT IS INCLUDED
--   REAGENTS: every item of class 7 (Trade Goods) that ANY vendor in the world sells - 87
--   items. That is dyes, threads, vials, flux, salt, oils, powders and so on. It is scoped
--   to vendor-sold items on purpose: ores, herbs, leather and cloth are gathered or looted,
--   not bought, and dumping those on a vendor would flatten gathering entirely.
--
--   TOOLS: the 5 vendor-sold profession tools - Blacksmith Hammer, Mining Pick,
--   Skinning Knife, Fishing Pole, Strong Fishing Pole.
--
-- WHAT IS EXCLUDED
--   RECIPES (class 9). Vendors sell 442 of them, which alone would blow past the 128 cap
--   nearly four times over. They are also a different kind of thing - patterns you learn
--   once, not stock you re-buy. `.learn all_recipes <profession>` already covers those.
--
-- NPC FLAGS - NOTE THE VALUE
--   UNIT_NPC_FLAG_VENDOR is 0x04 in this core (UnitDefines.h:448), NOT the 0x80 that stock
--   MaNGOS uses. npc_flags = 5 is gossip (0x01) + vendor (0x04). Katie Hunter's 7 is
--   gossip + questgiver (0x02) + vendor, which corroborates it.
--
-- PRICING
--   Items keep their normal buy_price - all 92 are priced, none are free. Selling is
--   handled by the standard vendor path, so the reputation discount applies as usual.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. Build the item set.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_sold;
CREATE TEMPORARY TABLE tmp_sold (item MEDIUMINT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT IGNORE INTO tmp_sold SELECT item FROM npc_vendor;
INSERT IGNORE INTO tmp_sold SELECT item FROM npc_vendor_template;

DROP TEMPORARY TABLE IF EXISTS tmp_stock;
CREATE TEMPORARY TABLE tmp_stock (
  item MEDIUMINT UNSIGNED PRIMARY KEY,
  kind TINYINT NOT NULL          -- 1 = tool (listed first), 2 = reagent
) ENGINE=MEMORY;

-- tools first so they sit at the top of the list
INSERT IGNORE INTO tmp_stock (item, kind)
SELECT s.item, 1 FROM tmp_sold s JOIN item_template it ON it.entry = s.item
WHERE it.class NOT IN (7, 9)
  AND it.name REGEXP 'Fishing Pole|Blacksmith Hammer|Mining Pick|Skinning Knife|Spanner|Micro-Adjustor|Runed .*Rod|Salt Shaker|Sewing Needle';

-- Reagents: vendor-sold trade goods, MINUS anything that can be gathered.
--
-- The exclusion matters. Without it 28 of these are things you are meant to go and find -
-- Silverleaf, Peacebloom, Dreamfoil, Golden Sansam, the leather tiers, Felcloth, and gems
-- like Moss Agate, Shadowgem, Aquamarine and Large Opal. They qualify as "vendor-sold"
-- because some vendor somewhere stocks them, but putting them all on one convenient NPC
-- would gut herbalism, skinning and mining in one go - and would directly undercut the
-- Silver/Gold/Truesilver node drops added in tuning-precious-ore-drops.sql.
--
-- The test is "does this item come out of a gathering node or container", i.e. does it
-- appear in gameobject_loot_template. That is data-driven rather than a hand-written
-- blocklist, so it keeps working if the world database changes.
--
-- It also catches a few container drops that are not strictly gathered (Thieves' Tools,
-- Coarse Blasting Powder, the bronze/copper engineering parts). Those are deliberately
-- left out too - they are findable in the world, which is the property we are preserving.
INSERT IGNORE INTO tmp_stock (item, kind)
SELECT s.item, 2 FROM tmp_sold s JOIN item_template it ON it.entry = s.item
WHERE it.class = 7
  AND NOT EXISTS (
    SELECT 1 FROM gameobject_loot_template g
    WHERE g.item = s.item AND g.mincountOrRef > 0
  );

-- ---------------------------------------------------------------------------------------
-- 2. The NPC itself, cloned from template 21002 the same way the dungeon questgivers were.
--    Cloning rather than hand-writing a row means every column this core has - including
--    any Turtle-specific ones - gets a sane value without us needing to know about it.
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_npc;
CREATE TEMPORARY TABLE tmp_npc LIKE creature_template;
INSERT INTO tmp_npc SELECT * FROM creature_template WHERE entry = 21002;

UPDATE tmp_npc SET
  entry       = 2600100,
  name        = 'Master Supplier',
  subname     = 'Tools & Reagents',
  npc_flags   = 5,          -- gossip (0x01) + vendor (0x04)
  faction     = 35,         -- friendly to everyone, same as the questgivers
  level_min   = 1,
  level_max   = 1,
  vendor_id   = 0,          -- 0 = use npc_vendor rows keyed by this creature entry
  trainer_id  = 0;

DELETE FROM creature_template WHERE entry = 2600100;
INSERT INTO creature_template SELECT * FROM tmp_npc;

-- ---------------------------------------------------------------------------------------
-- 3. Stock it. maxcount 0 = unlimited, incrtime 0 = no restock timer.
--    Slots are assigned sequentially so the list reads tools-then-reagents rather than in
--    whatever order the join happened to produce.
-- ---------------------------------------------------------------------------------------
DELETE FROM npc_vendor WHERE entry = 2600100;

SET @slot := 0;
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, itemflags, condition_id)
SELECT 2600100, (@slot := @slot + 1), x.item, 0, 0, 0, 0
FROM (
  SELECT t.item
  FROM tmp_stock t
  JOIN item_template it ON it.entry = t.item
  ORDER BY t.kind, it.class, it.subclass, it.name
) x;

-- ---------------------------------------------------------------------------------------
-- 4. Report.
-- ---------------------------------------------------------------------------------------
SELECT 'items stocked' AS what, COUNT(*) AS n, 128 AS cap,
       IF(COUNT(*) > 128, 'OVER CAP - overflow will be silently dropped', 'within cap') AS status
FROM npc_vendor WHERE entry = 2600100;

SELECT IF(t.kind = 1, 'tool', 'reagent') AS kind, COUNT(*) AS n
FROM npc_vendor nv JOIN tmp_stock t ON t.item = nv.item
WHERE nv.entry = 2600100 GROUP BY t.kind ORDER BY t.kind;

SELECT nv.slot, it.name, ROUND(it.buy_price/100) AS silver
FROM npc_vendor nv JOIN item_template it ON it.entry = nv.item
WHERE nv.entry = 2600100 ORDER BY nv.slot LIMIT 12;

-- ---------------------------------------------------------------------------------------
-- TO REMOVE
--   DELETE FROM npc_vendor WHERE entry = 2600100;
--   DELETE FROM creature_template WHERE entry = 2600100;
--   Any already-summoned copy in the world stays until it despawns or is `.npc delete`d.
-- ---------------------------------------------------------------------------------------
