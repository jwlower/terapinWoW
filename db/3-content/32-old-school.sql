-- ---------------------------------------------------------------------------------------
-- "Old School" - one brutal death challenge, replacing Fragile and Butterfingers.
--
-- Run against tw_world (and tw_char). IDEMPOTENT.
-- Needs a mangosd RESTART, a rebuilt patch-6.mpq, and lua_scripts/old_school.lua.
-- ---------------------------------------------------------------------------------------
--
-- WHAT IT DOES
--   Die, and you lose EVERYTHING - every item in every bag, and everything you were wearing.
--
--   Then a choice. Take the spirit healer and you also lose all progress toward your next
--   level. Walk back to your body instead and you recover FOUR random pieces of the gear you
--   were wearing.
--
--   So death is never free, but the long walk is worth making.
--
-- WHY IT REPLACES THE OTHER TWO
--   Fragile (38720) and Butterfingers (38721) were separate, milder challenges that dropped
--   one item or a fifth of your bags into a chest. Old School subsumes both, and three
--   overlapping death penalties would be confusing rather than interesting. Both spells and
--   their quests are removed here, including from characters that already took them.
--
-- RESURRECTION SICKNESS IS GONE SERVER-WIDE
--   Not part of this challenge - it applies to everyone. Set in mangosd.conf:
--       Death.SicknessLevel = 100
--   Player.cpp:5947 only applies sickness when GetLevel() >= that value, so anything above
--   the level cap disables it. Old School is the penalty for dying now; a ten-minute stat
--   debuff on top of it would just be tedious.
--
-- WHY THE PREVIOUS ATTEMPT SILENTLY DID NOTHING
--   Worth recording. The corpse chest never appeared, and it was not the GameObject hook -
--   it was `Eluna.UseUnsafeMethods = false` in mangosd.conf. CharDBQuery is flagged unsafe,
--   so the script aborted the moment it touched the database and failed quietly in game,
--   with the only trace in ElunaErrors.log. That config is now true.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. Retire Fragile and Butterfingers.
-- ---------------------------------------------------------------------------------------
DELETE FROM spell_template            WHERE entry IN (38720, 38721);
DELETE FROM quest_template            WHERE entry IN (80500, 80501);
DELETE FROM creature_questrelation    WHERE quest IN (80500, 80501);
DELETE FROM creature_involvedrelation WHERE quest IN (80500, 80501);
DELETE FROM tw_char.character_spell   WHERE spell IN (38720, 38721);
DELETE FROM tw_char.character_queststatus WHERE quest IN (80500, 80501);

-- ---------------------------------------------------------------------------------------
-- 2. The marker spell. Passive and visible, so you can see in your spellbook that you are
--    carrying it - it is bought from a questgiver, not a hidden flag.
-- ---------------------------------------------------------------------------------------
DELETE FROM spell_template     WHERE entry = 38725;
DELETE FROM skill_line_ability WHERE spell_id = 38725;

DROP TEMPORARY TABLE IF EXISTS tmp_os;
CREATE TEMPORARY TABLE tmp_os LIKE spell_template;
INSERT INTO tmp_os SELECT * FROM spell_template WHERE entry = 13262;   -- Disenchant, as usual
UPDATE tmp_os SET
  entry = 38725, name = 'Old School', nameSubtext = '',
  description = 'On death you lose every item you carry and everything you wear. Resurrect at a spirit healer and you also lose all progress toward your next level. Return to your body instead and you recover four random pieces of your gear.',
  effect1 = 0, effect2 = 0, effect3 = 0,
  effectItemType1 = 0, effectTriggerSpell1 = 0,
  Targets = 0, effectImplicitTargetA1 = 1, effectImplicitTargetB1 = 0,
  spellLevel = 1, baseLevel = 1, manaCost = 0, powerType = 0,
  RecoveryTime = 0, categoryRecoveryTime = 0,
  reagent1 = 0, reagentCount1 = 0, reagent2 = 0, reagentCount2 = 0,
  EquippedItemClass = -1, RequiresSpellFocus = 0,
  Attributes = 64,              -- PASSIVE, visible
  spellIconId = 1662;           -- INV_Misc_Bone_HumanSkull_01
INSERT INTO spell_template SELECT * FROM tmp_os;
DROP TEMPORARY TABLE tmp_os;

-- ---------------------------------------------------------------------------------------
-- 3. The quest that grants it.
--
--    A quest reward, not a trainer: a spell with no skill_line_ability row lives in the
--    GENERAL tab, and the client drops trainer entries filed under no skill line. Turtle
--    grants Hardcore the same way (quest 80388, RewSpell 50006). See sql/29.
-- ---------------------------------------------------------------------------------------
DELETE FROM quest_template WHERE entry = 80502;

DROP TEMPORARY TABLE IF EXISTS tmp_q;
CREATE TEMPORARY TABLE tmp_q LIKE quest_template;
INSERT INTO tmp_q SELECT * FROM quest_template WHERE entry = 80388;   -- Turtle's Hardcore quest
UPDATE tmp_q SET
  entry = 80502,
  Title = 'Old School',
  Details = 'You want it the way it used to be. Nothing held back, nothing softened.$B$BSwear to this and every death takes all of it - the contents of your bags, the gear on your back, all of it gone where you fell.$B$BAnd then you choose. Let the spirit healer pull you back and you will find the road to your next level has gone with everything else. Or walk. Find your body. Four pieces of what you wore will still be there.$B$BMost do not walk. Most should.',
  Objectives = 'Accept the Old School challenge from the Challenge Master.',
  OfferRewardText = 'Then it is sworn, and there is no taking it back by asking me.$B$BIf you ever want out, the words are yours: |cff33ff99!oldschool|r',
  RequestItemsText = 'Still certain?',
  EndText = '',
  RewSpell = 38725,
  RewSpellCast = 0,
  QuestLevel = 1, MinLevel = 1,
  RewXP = 0, RewOrReqMoney = 0,
  ZoneOrSort = -344,
  QuestFlags = 8;
INSERT INTO quest_template SELECT * FROM tmp_q;
DROP TEMPORARY TABLE tmp_q;

DELETE FROM creature_questrelation    WHERE id = 2600401;
DELETE FROM creature_involvedrelation WHERE id = 2600401;
INSERT INTO creature_questrelation    (id, quest) VALUES (2600401, 80502);
INSERT INTO creature_involvedrelation (id, quest) VALUES (2600401, 80502);

-- ---------------------------------------------------------------------------------------
-- 4. Storage for what is waiting at your corpse.
--
--    Reuses the table created by sql/24. One row per recoverable item, plus the death
--    position so the script can tell a corpse run from a spirit healer.
-- ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tw_char.terapin_corpse_chest (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  player_guid INT UNSIGNED NOT NULL,
  item_entry  INT UNSIGNED NOT NULL,
  item_count  INT UNSIGNED NOT NULL DEFAULT 1,
  map         INT UNSIGNED NOT NULL,
  pos_x       FLOAT NOT NULL,
  pos_y       FLOAT NOT NULL,
  pos_z       FLOAT NOT NULL,
  created     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_player (player_guid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Nothing pending from the old design should survive the switch.
DELETE FROM tw_char.terapin_corpse_chest;

SELECT entry, name, Attributes FROM spell_template WHERE entry IN (38720, 38721, 38725);
SELECT entry, Title, RewSpell FROM quest_template WHERE entry IN (80500, 80501, 80502);
SELECT 'offers' AS rel, COUNT(*) n FROM creature_questrelation WHERE id = 2600401
UNION ALL SELECT 'accepts', COUNT(*) FROM creature_involvedrelation WHERE id = 2600401;
