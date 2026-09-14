-- ---------------------------------------------------------------------------------------
-- New item: Runed Copper Shield (entry 90100)
--
-- Run against tw_world. IDEMPOTENT. Requires a mangosd RESTART - item_template has no
-- .reload in this core.
--
-- WHY A NEW ITEM NEEDS NO CLIENT PATCH
--   Unlike spells, the client does not carry item definitions in a DBC. It asks the server
--   for an item it has not seen (SMSG_ITEM_QUERY_SINGLE_RESPONSE) and believes the answer.
--   That is the same mechanism that let the 999 stack sizes and the no-soulbound change
--   work unpatched. So a brand new item just works.
--
--   The one constraint is display_id: that DOES index client art, so a new item must reuse
--   a model the client already has. 25955 is Soldier's Shield - a plain metal shield that
--   suits the Runed Copper look.
--
-- THERE IS NO "RUNED COPPER SET"
--   All five Runed Copper pieces have set_id = 0. It is a naming theme, not an item set,
--   so there are no set bonuses to join. Creating a real set means adding a row to
--   ItemSet.dbc, which is client-side - possible now that the patch pipeline works, but a
--   separate job. This item is instead built to MATCH the set: same armor class (mail),
--   same quality, same Agility/Stamina stat pair, and item level slotted between the
--   Gauntlets (12) and the Breastplate (18).
--
-- CALIBRATION against real shields of the tier:
--       Soldier's Shield   req 12  ilvl 17  armor 361  block 6
--       this shield        req 13  ilvl 18  armor 378  block 6  +3 Agi +3 Sta
--   Slightly ahead of a same-level drop because it is crafted, which is the direction you
--   asked for, without being a jump in power.
--
-- BUILT BY CLONING, NOT BY LISTING COLUMNS
--   item_template has well over a hundred columns in this core. Cloning a comparable
--   shield and correcting the handful that differ avoids enumerating them - the same
--   lesson as creature_template, where a hand-written column list broke on display_id1.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM item_template WHERE entry = 90100;

DROP TEMPORARY TABLE IF EXISTS tmp_item;
CREATE TEMPORARY TABLE tmp_item LIKE item_template;
INSERT INTO tmp_item SELECT * FROM item_template WHERE entry = 6560;  -- Soldier's Shield

UPDATE tmp_item SET
  entry          = 90100,
  name           = 'Runed Copper Shield',
  description    = '',
  display_id     = 25955,
  Quality        = 2,              -- green, matching the rest of the set
  class          = 4,              -- Armor
  subclass       = 6,              -- Shield
  required_level = 13,
  item_level     = 18,
  armor          = 378,
  block          = 6,
  stat_type1     = 4,  stat_value1 = 3,   -- Agility, as the set uses
  stat_type2     = 7,  stat_value2 = 3,   -- Stamina
  stat_type3     = 0,  stat_value3 = 0,
  stat_type4     = 0,  stat_value4 = 0,
  stat_type5     = 0,  stat_value5 = 0,
  max_durability = 0,              -- consistent with tuning-no-repair.sql
  bonding        = 0,              -- consistent with tuning-stacks-and-binding.sql
  set_id         = 0,              -- no Runed Copper set exists to join
  buy_price      = 0,
  sell_price     = 1200,
  max_count      = 0,
  stackable      = 1,
  flags          = 0,
  extra_flags    = 0,
  spellid_1 = 0, spelltrigger_1 = 0,
  spellid_2 = 0, spelltrigger_2 = 0;

INSERT INTO item_template SELECT * FROM tmp_item;

-- Stock it on the Blacksmithing Master so it is obtainable for testing before a recipe
-- exists. Remove this once it is craftable.
DELETE FROM npc_vendor WHERE entry = 2600300 AND item = 90100;
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, itemflags, condition_id)
VALUES (2600300, 500, 90100, 0, 0, 0, 0);

SELECT entry, name, Quality, class, subclass, armor, block, required_level, item_level,
       stat_type1, stat_value1, stat_type2, stat_value2, display_id
FROM item_template WHERE entry = 90100;

SELECT 'the Runed Copper family, for comparison' AS note;
SELECT entry, name, armor, required_level, item_level, stat_value1, stat_value2
FROM item_template WHERE name LIKE 'Runed Copper%' AND class = 4 ORDER BY item_level;

-- ---------------------------------------------------------------------------------------
-- TO REMOVE
--   DELETE FROM item_template WHERE entry = 90100;
--   DELETE FROM npc_vendor WHERE entry = 2600300 AND item = 90100;
-- ---------------------------------------------------------------------------------------
