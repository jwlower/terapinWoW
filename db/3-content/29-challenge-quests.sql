-- ---------------------------------------------------------------------------------------
-- Challenge Master, take two: QUESTS, not a trainer.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART.
-- ---------------------------------------------------------------------------------------
--
-- WHY THE TRAINER IN sql/28 DID NOT WORK
--   Its window came up completely empty, and the reason was already written down in
--   sql/17-salvage.sql:
--
--       "NO skill_line_ability ROW ON PURPOSE. That places it in the GENERAL spellbook tab
--        and leaves it ungated by class. The trade-off is that it can never be sold by a
--        trainer - the client drops trainer entries filed under no skill line."
--
--   Fragile (38720) and Butterfingers (38721) are General-tab spells with no skill line, so
--   the client discarded both trainer rows without a word. A trainer and a General-tab spell
--   are mutually exclusive on this client.
--
-- WHAT TURTLE ITSELF DOES
--   The Mysterious Stranger (81030), who hands out Hardcore, is npc_flags = 2 (QUESTGIVER).
--   Its challenge is quest 80388 "[DEPRECATED] Stay Awhile and Listen...", which carries
--   RewSpell = 50006 - the spell is granted as the quest REWARD.
--
--   That sidesteps the skill-line problem completely: a quest reward has no such
--   requirement, and it also gives somewhere to put the warning text, which a trainer entry
--   has no room for.
--
-- SO: two quests, repeatable-free, level 1, offered and turned in by the Challenge Master.
-- Accepting is the commitment; the reward is the challenge itself.
--
-- Dropping one later is still `!fragile` / `!butterfingers` in say - see
-- lua_scripts/death_challenges.lua. Quests cannot un-grant a spell.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. The NPC becomes a questgiver rather than a trainer.
--    npc_flags 3 = GOSSIP (0x01) + QUESTGIVER (0x02).
-- ---------------------------------------------------------------------------------------
DELETE FROM npc_trainer WHERE entry = 2600401;
UPDATE creature_template SET npc_flags = 3, trainer_type = 0 WHERE entry = 2600401;

-- The teaching wrappers from sql/28 are now dead weight - a quest grants the spell itself.
DELETE FROM spell_template WHERE entry IN (38723, 38724);

-- ---------------------------------------------------------------------------------------
-- 2. The quests. Cloned from 80388, the quest Turtle uses for Hardcore, so the flags and
--    method are known-good rather than guessed.
-- ---------------------------------------------------------------------------------------
DELETE FROM quest_template WHERE entry IN (80500, 80501);

DROP TEMPORARY TABLE IF EXISTS tmp_q;
CREATE TEMPORARY TABLE tmp_q LIKE quest_template;

INSERT INTO tmp_q SELECT * FROM quest_template WHERE entry = 80388;
UPDATE tmp_q SET
  entry = 80500,
  Title = 'The Fragile Path',
  Details = 'You want to feel the weight of a death, then.$B$BTake this oath and the next time you fall, one piece of what you carry on your body will stay behind with your corpse. It will not be destroyed - it will be waiting for you, in a chest, exactly where you died.$B$BWhether you go back for it is your business.',
  Objectives = 'Accept the Fragile challenge from the Challenge Master.',
  OfferRewardText = 'It is done. Tread carefully.$B$BShould you tire of it, the words to set it aside are yours to speak: |cff33ff99!fragile|r',
  RequestItemsText = 'Have you reconsidered?',
  EndText = '',
  RewSpell = 38720,
  RewSpellCast = 0,
  QuestLevel = 1, MinLevel = 1,
  RewXP = 0, RewOrReqMoney = 0,
  ZoneOrSort = -344,
  QuestFlags = 8;
INSERT INTO quest_template SELECT * FROM tmp_q;
TRUNCATE tmp_q;

INSERT INTO tmp_q SELECT * FROM quest_template WHERE entry = 80388;
UPDATE tmp_q SET
  entry = 80501,
  Title = 'Butterfingers',
  Details = 'A heavier burden, this one.$B$BSwear to it and every death will scatter a share of what you carry - a fifth of it, near enough - into a chest at your corpse.$B$BYour bags themselves will hold. So will anything a quest depends on. I am cruel, not stupid.',
  Objectives = 'Accept the Butterfingers challenge from the Challenge Master.',
  OfferRewardText = 'Sworn. Try not to die somewhere inconvenient.$B$BTo set it aside, speak: |cff33ff99!butterfingers|r',
  RequestItemsText = 'Changed your mind?',
  EndText = '',
  RewSpell = 38721,
  RewSpellCast = 0,
  QuestLevel = 1, MinLevel = 1,
  RewXP = 0, RewOrReqMoney = 0,
  ZoneOrSort = -344,
  QuestFlags = 8;
INSERT INTO quest_template SELECT * FROM tmp_q;
DROP TEMPORARY TABLE tmp_q;

-- ---------------------------------------------------------------------------------------
-- 3. The Challenge Master both OFFERS and ACCEPTS both quests - the same pattern the
--    dungeon questgivers use, so one NPC closes the loop.
-- ---------------------------------------------------------------------------------------
DELETE FROM creature_questrelation    WHERE id = 2600401;
DELETE FROM creature_involvedrelation WHERE id = 2600401;
INSERT INTO creature_questrelation    (id, quest) VALUES (2600401, 80500), (2600401, 80501);
INSERT INTO creature_involvedrelation (id, quest) VALUES (2600401, 80500), (2600401, 80501);

SELECT entry, name, npc_flags, trainer_type FROM creature_template WHERE entry = 2600401;
SELECT entry, Title, RewSpell, MinLevel, QuestFlags FROM quest_template WHERE entry IN (80500, 80501);
SELECT 'offers' AS rel, COUNT(*) n FROM creature_questrelation WHERE id = 2600401
UNION ALL SELECT 'accepts', COUNT(*) FROM creature_involvedrelation WHERE id = 2600401;
