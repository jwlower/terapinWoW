-- ---------------------------------------------------------------------------------------
-- Challenge Master (2600401) - an NPC that hands out Terapin's own challenges.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.
-- ---------------------------------------------------------------------------------------
--
-- WHY THESE ARE NOT IN THE CHARACTER-CREATION CHALLENGE MENU
--   That menu lists Turtle's ten built-in challenges and nothing else. They are bits in a
--   mask the CLIENT sends at character creation (CharacterHandler.cpp:382), read back at
--   login, and turned into spells there. The bit list is compiled in - there is no data
--   table to add an eleventh entry to, and no challenge strings exist in WoW.exe at all.
--
--   So Fragile and Butterfingers are ordinary spells instead. That is a better fit anyway:
--   Turtle's are CANT_CANCEL and permanent, whereas these can be picked up and dropped.
--
-- WHY A TRAINER AND NOT A GOSSIP MENU
--   Neither OnGossipHello nor OnGossipSelect is bridged to Eluna on this build, so a
--   scripted gossip NPC is not available. A TRAINER needs no scripting at all - the client
--   builds the window from npc_trainer plus its own Spell.dbc.
--
-- WHY THE MARKERS STOP BEING HIDDEN
--   38720/38721 were PASSIVE|HIDDEN_CLIENTSIDE, which suited a pure flag. A trainer-taught
--   challenge should be visible: you want to see in your spellbook which ones you are
--   carrying, and a hidden spell is a poor thing to render in a trainer list. They are now
--   passive but visible. 38722 "Unrestrained" stays hidden - it is an opt-OUT toggled by
--   chat, not something you buy.
--
-- DROPPING A CHALLENGE
--   Trainers can only teach. The chat toggles in death_challenges.lua are the way back out:
--       !fragile          !butterfingers
--   which is also how !scale already works for dungeon scaling.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. Make the two markers visible (passive, but no longer hidden).
-- ---------------------------------------------------------------------------------------
UPDATE spell_template SET Attributes = 64 WHERE entry IN (38720, 38721);   -- PASSIVE only

-- ---------------------------------------------------------------------------------------
-- 2. Teaching wrappers. npc_trainer.spell MUST be a LEARN_SPELL spell whose trigger is the
--    real one - pointing a trainer at an ability is rejected at load with
--    "has non-learning spell, ignore". Cloned from 2754, a REAL trainer wrapper, never from
--    a "Plans:" spell - those target the caster and make the NPC teach itself.
-- ---------------------------------------------------------------------------------------
DELETE FROM spell_template WHERE entry IN (38723, 38724);

DROP TEMPORARY TABLE IF EXISTS tmp_cm;
CREATE TEMPORARY TABLE tmp_cm LIKE spell_template;

INSERT INTO tmp_cm SELECT * FROM spell_template WHERE entry = 2754;
UPDATE tmp_cm SET entry = 38723, name = 'Fragile', nameSubtext = '',
  description = 'Take on the Fragile challenge: on death, one random piece of equipped gear falls to your corpse.',
  effect1 = 36, effectTriggerSpell1 = 38720,
  effect2 = 0, effect3 = 0, effectItemType1 = 0,
  spellIconId = 1662;
INSERT INTO spell_template SELECT * FROM tmp_cm;
TRUNCATE tmp_cm;

INSERT INTO tmp_cm SELECT * FROM spell_template WHERE entry = 2754;
UPDATE tmp_cm SET entry = 38724, name = 'Butterfingers', nameSubtext = '',
  description = 'Take on the Butterfingers challenge: on death, a share of the items in your bags falls to your corpse.',
  effect1 = 36, effectTriggerSpell1 = 38721,
  effect2 = 0, effect3 = 0, effectItemType1 = 0,
  spellIconId = 1662;
INSERT INTO spell_template SELECT * FROM tmp_cm;
DROP TEMPORARY TABLE tmp_cm;

-- ---------------------------------------------------------------------------------------
-- 3. The NPC. Cloned from 21002 like every other custom NPC: faction 35 (friendly to
--    everyone), level 1, no unit flags.
--
--    npc_flags 17 = GOSSIP (0x01) + TRAINER (0x10). trainer_type 2 is the same value the
--    profession masters use, which is what makes SendTrainerList render properly - it comes
--    from TrainerSpellData, not from creature_template, and getting it wrong is what made
--    custom trainers show a generic face for every entry.
--
--    trainer_class 0 and trainer_spell 0 so nothing is gated: any class, any profession.
-- ---------------------------------------------------------------------------------------
DELETE FROM creature_template WHERE entry = 2600401;
DROP TEMPORARY TABLE IF EXISTS tmp_npc;
CREATE TEMPORARY TABLE tmp_npc LIKE creature_template;
INSERT INTO tmp_npc SELECT * FROM creature_template WHERE entry = 21002;
UPDATE tmp_npc SET
  entry         = 2600401,
  name          = 'Challenge Master',
  subname       = 'Trials & Hardship',
  npc_flags     = 17,
  trainer_type  = 2,
  trainer_class = 0,
  trainer_spell = 0,
  display_id1   = 21042;
INSERT INTO creature_template SELECT * FROM tmp_npc;
DROP TEMPORARY TABLE tmp_npc;

-- ---------------------------------------------------------------------------------------
-- 4. What it teaches. Free: the cost of a challenge is the challenge.
-- ---------------------------------------------------------------------------------------
DELETE FROM npc_trainer WHERE entry = 2600401;
INSERT INTO npc_trainer (entry, spell, spellcost, reqskill, reqskillvalue, reqlevel) VALUES
  (2600401, 38723, 0, 0, 0, 1),
  (2600401, 38724, 0, 0, 0, 1);

SELECT entry, name, subname, npc_flags, trainer_type FROM creature_template WHERE entry = 2600401;
SELECT entry, name, effect1, effectTriggerSpell1 FROM spell_template WHERE entry IN (38723, 38724);
SELECT entry, name, Attributes FROM spell_template WHERE entry IN (38720, 38721, 38722);
SELECT COUNT(*) AS trainer_rows FROM npc_trainer WHERE entry = 2600401;
