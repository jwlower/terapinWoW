-- ---------------------------------------------------------------------------------------
-- One summonable quest-giver NPC per dungeon.
--
-- Run against tw_world. IDEMPOTENT (INSERT IGNORE / REPLACE), safe to re-run.
-- Re-apply after any world re-import. Requires a mangosd RESTART - creature_template and
-- the quest relation tables are loaded at startup.
--
-- HOW IT WORKS
--   For each dungeon zone, a custom creature_template is cloned from entry 21002
--   ("Squire Boltfling": faction 35 = friendly to everyone, no unit flags, level 1) with
--   npc_flags = 3 (gossip + questgiver). Then every quest whose quest_template.ZoneOrSort
--   equals that dungeon's zone id is attached twice:
--     creature_questrelation    -> the NPC OFFERS the quest
--     creature_involvedrelation -> the NPC ACCEPTS the turn-in
--   so one NPC both hands out and completes that dungeon's quests.
--
-- WHY ZoneOrSort
--   It is how the game itself files a quest under a dungeon, and it gives realistic counts
--   (The Deadmines: 9). Matching on "items that drop inside" instead over-matches wildly -
--   common drops like Linen Cloth are required by dozens of unrelated world quests, which
--   produced 45 for Deadmines and 239 for Dire Maul.
--
-- QUEST PREREQUISITES STILL APPLY
--   Attaching a quest here does not bypass its level, class, race or prior-quest
--   requirements - the core checks those when deciding what to show. A quest the character
--   cannot take simply will not appear in the NPC's list.
--
-- SUMMONING
--   `.npc summon <entry>` is a TEMPORARY spawn (the handler is commented ".npc add but
--   temp"), so these never litter the world. Requires the `npc summon` command, granted by
--   setup-rbac-dungeonquests.sql.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DROP TEMPORARY TABLE IF EXISTS tmp_qg;
CREATE TEMPORARY TABLE tmp_qg LIKE creature_template;

-- Ahn'Qiraj  (zone 3428, map 531, 79 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600001,
                  name = 'Ahn''Qiraj Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600001, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3428;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600001, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3428;

-- Alterac Valley  (zone 2597, map 30, 84 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600002,
                  name = 'Alterac Valley Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600002, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2597;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600002, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2597;

-- Arathi Basin  (zone 3358, map 529, 58 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600003,
                  name = 'Arathi Basin Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600003, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3358;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600003, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3358;

-- Blackfathom Deeps  (zone 719, map 48, 12 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600004,
                  name = 'Blackfathom Deeps Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600004, q.entry FROM quest_template q WHERE q.ZoneOrSort = 719;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600004, q.entry FROM quest_template q WHERE q.ZoneOrSort = 719;

-- Blackwing Lair  (zone 2677, map 469, 4 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600005,
                  name = 'Blackwing Lair Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600005, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2677;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600005, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2677;

-- Blood Ring  (zone 4014, map 26, 4 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600006,
                  name = 'Blood Ring Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600006, q.entry FROM quest_template q WHERE q.ZoneOrSort = 4014;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600006, q.entry FROM quest_template q WHERE q.ZoneOrSort = 4014;

-- Crescent Grove  (zone 5077, map 802, 5 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600007,
                  name = 'Crescent Grove Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600007, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5077;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600007, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5077;

-- Deeprun Tram  (zone 2257, map 369, 2 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600008,
                  name = 'Deeprun Tram Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600008, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2257;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600008, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2257;

-- Dire Maul  (zone 2557, map 429, 46 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600009,
                  name = 'Dire Maul Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600009, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2557;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600009, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2557;

-- Dragonmaw Retreat  (zone 5601, map 816, 10 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600010,
                  name = 'Dragonmaw Retreat Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600010, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5601;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600010, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5601;

-- Frostmane Hollow  (zone 5734, map 822, 5 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600011,
                  name = 'Frostmane Hollow Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600011, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5734;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600011, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5734;

-- Gnomeregan  (zone 721, map 90, 2 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600012,
                  name = 'Gnomeregan Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600012, q.entry FROM quest_template q WHERE q.ZoneOrSort = 721;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600012, q.entry FROM quest_template q WHERE q.ZoneOrSort = 721;

-- Hateforge Quarry  (zone 5098, map 808, 7 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600013,
                  name = 'Hateforge Quarry Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600013, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5098;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600013, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5098;

-- Maraudon  (zone 2100, map 349, 13 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600014,
                  name = 'Maraudon Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600014, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2100;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600014, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2100;

-- Molten Core  (zone 2717, map 409, 9 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600015,
                  name = 'Molten Core Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600015, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2717;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600015, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2717;

-- Naxxramas  (zone 3456, map 533, 91 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600016,
                  name = 'Naxxramas Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600016, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3456;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600016, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3456;

-- Ragefire Chasm  (zone 2437, map 389, 6 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600017,
                  name = 'Ragefire Chasm Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600017, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2437;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600017, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2437;

-- Razorfen Downs  (zone 722, map 129, 10 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600018,
                  name = 'Razorfen Downs Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600018, q.entry FROM quest_template q WHERE q.ZoneOrSort = 722;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600018, q.entry FROM quest_template q WHERE q.ZoneOrSort = 722;

-- Ruins of Ahn'Qiraj  (zone 3429, map 509, 1 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600019,
                  name = 'Ruins of Ahn''Qiraj Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600019, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3429;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600019, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3429;

-- Scarlet Monastery  (zone 796, map 189, 12 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600020,
                  name = 'Scarlet Monastery Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600020, q.entry FROM quest_template q WHERE q.ZoneOrSort = 796;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600020, q.entry FROM quest_template q WHERE q.ZoneOrSort = 796;

-- Scholomance  (zone 2057, map 289, 12 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600021,
                  name = 'Scholomance Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600021, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2057;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600021, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2057;

-- Shadowfang Keep  (zone 209, map 33, 7 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600022,
                  name = 'Shadowfang Keep Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600022, q.entry FROM quest_template q WHERE q.ZoneOrSort = 209;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600022, q.entry FROM quest_template q WHERE q.ZoneOrSort = 209;

-- Stormwind Vault  (zone 5087, map 35, 6 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600023,
                  name = 'Stormwind Vault Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600023, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5087;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600023, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5087;

-- Stormwrought Ruins  (zone 5628, map 818, 13 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600024,
                  name = 'Stormwrought Ruins Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600024, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5628;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600024, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5628;

-- Stratholme  (zone 2017, map 329, 18 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600025,
                  name = 'Stratholme Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600025, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2017;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600025, q.entry FROM quest_template q WHERE q.ZoneOrSort = 2017;

-- Sunken Temple  (zone 1417, map 109, 9 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600026,
                  name = 'Sunken Temple Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600026, q.entry FROM quest_template q WHERE q.ZoneOrSort = 1417;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600026, q.entry FROM quest_template q WHERE q.ZoneOrSort = 1417;

-- Sunnyglade Valley  (zone 5023, map 27, 2 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600027,
                  name = 'Sunnyglade Valley Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600027, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5023;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600027, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5023;

-- The Deadmines  (zone 1581, map 36, 9 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600028,
                  name = 'The Deadmines Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600028, q.entry FROM quest_template q WHERE q.ZoneOrSort = 1581;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600028, q.entry FROM quest_template q WHERE q.ZoneOrSort = 1581;

-- The Stockade  (zone 717, map 34, 7 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600029,
                  name = 'The Stockade Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600029, q.entry FROM quest_template q WHERE q.ZoneOrSort = 717;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600029, q.entry FROM quest_template q WHERE q.ZoneOrSort = 717;

-- Timbermaw Hold  (zone 5640, map 819, 27 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600030,
                  name = 'Timbermaw Hold Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600030, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5640;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600030, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5640;

-- Tower of Karazhan  (zone 3457, map 814, 15 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600031,
                  name = 'Tower of Karazhan Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600031, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3457;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600031, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3457;

-- Wailing Caverns  (zone 718, map 43, 14 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600032,
                  name = 'Wailing Caverns Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600032, q.entry FROM quest_template q WHERE q.ZoneOrSort = 718;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600032, q.entry FROM quest_template q WHERE q.ZoneOrSort = 718;

-- Warsong Gulch  (zone 3277, map 489, 59 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600033,
                  name = 'Warsong Gulch Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600033, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3277;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600033, q.entry FROM quest_template q WHERE q.ZoneOrSort = 3277;

-- Windhorn Canyon  (zone 5641, map 820, 4 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600034,
                  name = 'Windhorn Canyon Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600034, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5641;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600034, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5641;

-- Winter Veil Vale  (zone 5130, map 813, 26 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600035,
                  name = 'Winter Veil Vale Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600035, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5130;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600035, q.entry FROM quest_template q WHERE q.ZoneOrSort = 5130;

-- Zul'Gurub  (zone 1977, map 309, 48 quests)
DELETE FROM tmp_qg;
INSERT INTO tmp_qg SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_qg SET entry = 2600036,
                  name = 'Zul''Gurub Questgiver',
                  subname = 'Dungeon Quests',
                  npc_flags = 3,
                  ai_name = '',
                  movement_type = 0;
INSERT IGNORE INTO creature_template SELECT * FROM tmp_qg;

INSERT IGNORE INTO creature_questrelation (id, quest)
SELECT 2600036, q.entry FROM quest_template q WHERE q.ZoneOrSort = 1977;
INSERT IGNORE INTO creature_involvedrelation (id, quest)
SELECT 2600036, q.entry FROM quest_template q WHERE q.ZoneOrSort = 1977;

DROP TEMPORARY TABLE IF EXISTS tmp_qg;
