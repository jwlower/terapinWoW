-- ---------------------------------------------------------------------------------------
-- Questgivers for the dungeons that setup-dungeon-questgivers.sql MISSED.
--
-- Run against tw_world AFTER setup-dungeon-questgivers.sql. Idempotent, safe to re-run.
-- Requires a mangosd RESTART.
--
-- WHY A SECOND FILE
--   The first pass matched quests on quest_template.ZoneOrSort, which is how the game files
--   a quest under a dungeon. That works for dungeons with their own zone, but several
--   dungeons file their quests under the OUTDOOR zone containing the entrance instead -
--   Blackrock Depths and Blackrock Spire quests are sorted under "Blackrock Mountain",
--   Uldaman's under "Badlands", Zul'Farrak's under "Tanaris". Those zones are on continent
--   maps, so the first pass filtered them out and produced no questgiver.
--
-- THE RULE USED HERE
--   A quest belongs to dungeon map M if either:
--     (a) one of its kill/interact objectives is a creature spawned on M, or
--     (b) one of its required items drops from creatures on EXACTLY ONE dungeon map, and
--         that map is M.
--
--   (b)'s exclusivity check is the important part. A naive "item drops here" match gave
--   45 quests for Deadmines and 239 for Dire Maul, because common trade goods like Linen
--   Cloth drop in dungeons AND are required by dozens of unrelated outdoor quests.
--   Requiring the item to have a single dungeon source removes all of that noise while
--   keeping boss tokens and dungeon-specific quest items.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- creature spawns per dungeon map
DROP TEMPORARY TABLE IF EXISTS tmp_mc;
CREATE TEMPORARY TABLE tmp_mc (map SMALLINT UNSIGNED, entry MEDIUMINT UNSIGNED,
  PRIMARY KEY(map,entry), KEY(entry)) ENGINE=MEMORY;
INSERT IGNORE INTO tmp_mc SELECT c.map, c.id FROM creature c WHERE c.map NOT IN (0,1);

-- for each lootable item: how many dungeon maps drop it, and which one (if only one)
DROP TEMPORARY TABLE IF EXISTS tmp_item_maps;
CREATE TEMPORARY TABLE tmp_item_maps (item MEDIUMINT UNSIGNED, maps SMALLINT UNSIGNED,
  anymap SMALLINT UNSIGNED, PRIMARY KEY(item)) ENGINE=MEMORY;
INSERT IGNORE INTO tmp_item_maps
SELECT clt.item, COUNT(DISTINCT mc.map), MIN(mc.map)
FROM tmp_mc mc
JOIN creature_template ct ON ct.entry = mc.entry AND ct.loot_id > 0
JOIN creature_loot_template clt ON clt.entry = ct.loot_id
GROUP BY clt.item;

-- quest objectives flattened: kind 1 = creature/GO, kind 2 = required item
DROP TEMPORARY TABLE IF EXISTS tmp_qo;
CREATE TEMPORARY TABLE tmp_qo (quest MEDIUMINT UNSIGNED, kind TINYINT, id MEDIUMINT UNSIGNED,
  PRIMARY KEY(quest,kind,id), KEY(kind,id)) ENGINE=MEMORY;
INSERT IGNORE INTO tmp_qo
SELECT entry,1,ReqCreatureOrGOId1 FROM quest_template WHERE ReqCreatureOrGOId1>0
UNION ALL SELECT entry,1,ReqCreatureOrGOId2 FROM quest_template WHERE ReqCreatureOrGOId2>0
UNION ALL SELECT entry,1,ReqCreatureOrGOId3 FROM quest_template WHERE ReqCreatureOrGOId3>0
UNION ALL SELECT entry,1,ReqCreatureOrGOId4 FROM quest_template WHERE ReqCreatureOrGOId4>0
UNION ALL SELECT entry,2,ReqItemId1 FROM quest_template WHERE ReqItemId1>0
UNION ALL SELECT entry,2,ReqItemId2 FROM quest_template WHERE ReqItemId2>0
UNION ALL SELECT entry,2,ReqItemId3 FROM quest_template WHERE ReqItemId3>0
UNION ALL SELECT entry,2,ReqItemId4 FROM quest_template WHERE ReqItemId4>0;

-- resulting quest <-> dungeon map pairs
DROP TEMPORARY TABLE IF EXISTS tmp_qm;
CREATE TEMPORARY TABLE tmp_qm (map SMALLINT UNSIGNED, quest MEDIUMINT UNSIGNED,
  PRIMARY KEY(map,quest)) ENGINE=MEMORY;
INSERT IGNORE INTO tmp_qm
SELECT mc.map, qo.quest FROM tmp_qo qo JOIN tmp_mc mc ON mc.entry = qo.id WHERE qo.kind = 1;
INSERT IGNORE INTO tmp_qm
SELECT im.anymap, qo.quest FROM tmp_qo qo JOIN tmp_item_maps im ON im.item = qo.id
WHERE qo.kind = 2 AND im.maps = 1;

DROP TEMPORARY TABLE IF EXISTS tmp_qg;
CREATE TEMPORARY TABLE tmp_qg LIKE creature_template;

-- Blackrock Spire  (map 229, ~67 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600037, name = 'Blackrock Spire Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600037, qm.quest FROM tmp_qm qm WHERE qm.map = 229;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600037, qm.quest FROM tmp_qm qm WHERE qm.map = 229;

-- Blackrock Depths  (map 230, ~26 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600038, name = 'Blackrock Depths Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600038, qm.quest FROM tmp_qm qm WHERE qm.map = 230;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600038, qm.quest FROM tmp_qm qm WHERE qm.map = 230;

-- Uldaman  (map 70, ~23 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600039, name = 'Uldaman Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600039, qm.quest FROM tmp_qm qm WHERE qm.map = 70;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600039, qm.quest FROM tmp_qm qm WHERE qm.map = 70;

-- Emerald Sanctum  (map 807, ~15 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600040, name = 'Emerald Sanctum Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600040, qm.quest FROM tmp_qm qm WHERE qm.map = 807;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600040, qm.quest FROM tmp_qm qm WHERE qm.map = 807;

-- Gilneas City  (map 815, ~14 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600041, name = 'Gilneas City Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600041, qm.quest FROM tmp_qm qm WHERE qm.map = 815;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600041, qm.quest FROM tmp_qm qm WHERE qm.map = 815;

-- Onyxia's Lair  (map 249, ~10 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600042, name = 'Onyxia''s Lair Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600042, qm.quest FROM tmp_qm qm WHERE qm.map = 249;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600042, qm.quest FROM tmp_qm qm WHERE qm.map = 249;

-- Razorfen Kraul  (map 47, ~9 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600043, name = 'Razorfen Kraul Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600043, qm.quest FROM tmp_qm qm WHERE qm.map = 47;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600043, qm.quest FROM tmp_qm qm WHERE qm.map = 47;

-- Zul'Farrak  (map 209, ~8 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600044, name = 'Zul''Farrak Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600044, qm.quest FROM tmp_qm qm WHERE qm.map = 209;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600044, qm.quest FROM tmp_qm qm WHERE qm.map = 209;

-- The Black Morass  (map 269, ~7 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600045, name = 'The Black Morass Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600045, qm.quest FROM tmp_qm qm WHERE qm.map = 269;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600045, qm.quest FROM tmp_qm qm WHERE qm.map = 269;

-- Lower Karazhan Halls  (map 532, ~6 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600046, name = 'Lower Karazhan Halls Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600046, qm.quest FROM tmp_qm qm WHERE qm.map = 532;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600046, qm.quest FROM tmp_qm qm WHERE qm.map = 532;

-- Karazhan Crypt  (map 800, ~1 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600047, name = 'Karazhan Crypt Questgiver', subname = 'Dungeon Quests',
                  npc_flags = 3, ai_name = '', movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600047, qm.quest FROM tmp_qm qm WHERE qm.map = 800;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600047, qm.quest FROM tmp_qm qm WHERE qm.map = 800;

DROP TEMPORARY TABLE IF EXISTS tmp_qg;
DROP TEMPORARY TABLE IF EXISTS tmp_qm;
DROP TEMPORARY TABLE IF EXISTS tmp_qo;
DROP TEMPORARY TABLE IF EXISTS tmp_item_maps;
DROP TEMPORARY TABLE IF EXISTS tmp_mc;
