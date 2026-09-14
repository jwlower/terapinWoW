-- ---------------------------------------------------------------------------------------
-- Death challenges: drop gear or bag contents at your corpse, and go get them back.
--
-- Run against tw_world (and tw_char for the storage table). IDEMPOTENT.
-- Needs a mangosd RESTART, a rebuilt patch-6.mpq, and lua_scripts/death_challenges.lua.
-- ---------------------------------------------------------------------------------------
--
-- WHAT THIS ADDS
--   38720  Fragile        on death, ONE random equipped item falls to your corpse
--   38721  Butterfingers  on death, a share of your carried items falls to your corpse
--   2600500  Spilled Belongings   the chest that holds them until you return
--
--   Neither spell is granted automatically - these are opt-in. Take one with:
--       .learn 38720
--   and drop it again with `.unlearn`. Unlike Turtle's own challenges (see the wiki) these
--   are ordinary spells, not entries in the PendingChallengeMask system, so they are not
--   locked in and do not need a relog to apply.
--
-- WHY A CHEST AND NOT JUST DESTROYING THE ITEMS
--   Losing gear outright is a punishment. Losing it *somewhere you can walk back to* is a
--   decision - do you risk the corpse run now, or come back with a friend? The chest sits
--   exactly where you died, and only you can open it.
--
-- WHY GAMEOBJECT_EVENT_ON_USE WORKS HERE
--   It is not bridged through ElunaGameObjectScript - that class only forwards AddWorld,
--   RemoveWorld and Update. The use hook arrives by a different route entirely:
--   GameObject::Use (GameObject.cpp:1496) calls sScriptMgr.OnGameObjectUse, and ScriptMgr
--   (ScriptMgr.cpp:2279) forwards to Eluna when no C++ script claims the object. So
--   RegisterGameObjectEvent(2600500, 14, fn) fires, keyed on the GO entry. No core change.
--
-- WHY THE CONTENTS LIVE IN THE DATABASE
--   An in-memory Lua table would lose every pending chest on a server restart, and these
--   are real player items. tw_char.terapin_corpse_chest survives restarts, and the script
--   re-spawns a chest on login if one is still owed.
--
-- THE CHEST IS TYPE 3 (CHEST) WITH NO LOOT AND NO LOCK
--   data0 (lockId) = 0 and data1 (lootId) = 0. The script returns true from the use hook,
--   which stops GameObject::Use before it ever tries to build a loot window, so the empty
--   loot template never matters.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. The chest.
-- ---------------------------------------------------------------------------------------
DELETE FROM gameobject_template WHERE entry = 2600500;
DROP TEMPORARY TABLE IF EXISTS tmp_go;
CREATE TEMPORARY TABLE tmp_go LIKE gameobject_template;
INSERT INTO tmp_go SELECT * FROM gameobject_template WHERE entry = 2843;  -- Battered Chest
UPDATE tmp_go SET
  entry     = 2600500,
  name      = 'Spilled Belongings',
  displayId = 259,     -- the standard wooden chest model
  data0     = 0,       -- no lock: anyone can click it, the script decides who may open it
  data1     = 0;       -- no loot template: the script hands the items back directly
INSERT INTO gameobject_template SELECT * FROM tmp_go;
DROP TEMPORARY TABLE tmp_go;

-- ---------------------------------------------------------------------------------------
-- 2. The two challenge spells. Passive markers - they are never cast, only checked with
--    Player:HasSpell, the same way Turtle's own challenges work.
-- ---------------------------------------------------------------------------------------
DELETE FROM spell_template     WHERE entry IN (38720, 38721);
DELETE FROM skill_line_ability WHERE spell_id IN (38720, 38721);

DROP TEMPORARY TABLE IF EXISTS tmp_s;
CREATE TEMPORARY TABLE tmp_s LIKE spell_template;

-- 38720 Fragile
INSERT INTO tmp_s SELECT * FROM spell_template WHERE entry = 13262;  -- Disenchant, as usual
UPDATE tmp_s SET
  entry = 38720, name = 'Fragile', nameSubtext = '',
  description = 'On death, one random piece of equipped gear falls to your corpse. Retrieve it before it rots away.',
  effect1 = 0, effect2 = 0, effect3 = 0,
  effectItemType1 = 0, effectTriggerSpell1 = 0,
  Targets = 0, effectImplicitTargetA1 = 1, effectImplicitTargetB1 = 0,
  spellLevel = 1, baseLevel = 1, manaCost = 0, powerType = 0,
  RecoveryTime = 0, categoryRecoveryTime = 0,
  reagent1 = 0, reagentCount1 = 0, reagent2 = 0, reagentCount2 = 0,
  EquippedItemClass = -1, RequiresSpellFocus = 0,
  Attributes = 64 | 128,       -- PASSIVE | HIDDEN_CLIENTSIDE: a marker, not a button
  spellIconId = 1662;          -- INV_Misc_Bone_HumanSkull_01
INSERT INTO spell_template SELECT * FROM tmp_s;
TRUNCATE tmp_s;

-- 38721 Butterfingers
INSERT INTO tmp_s SELECT * FROM spell_template WHERE entry = 13262;
UPDATE tmp_s SET
  entry = 38721, name = 'Butterfingers', nameSubtext = '',
  description = 'On death, a share of the items in your bags falls to your corpse. Bags themselves are spared.',
  effect1 = 0, effect2 = 0, effect3 = 0,
  effectItemType1 = 0, effectTriggerSpell1 = 0,
  Targets = 0, effectImplicitTargetA1 = 1, effectImplicitTargetB1 = 0,
  spellLevel = 1, baseLevel = 1, manaCost = 0, powerType = 0,
  RecoveryTime = 0, categoryRecoveryTime = 0,
  reagent1 = 0, reagentCount1 = 0, reagent2 = 0, reagentCount2 = 0,
  EquippedItemClass = -1, RequiresSpellFocus = 0,
  Attributes = 64 | 128,
  spellIconId = 1662;
INSERT INTO spell_template SELECT * FROM tmp_s;
DROP TEMPORARY TABLE tmp_s;

-- ---------------------------------------------------------------------------------------
-- 3. Storage for what is waiting in a chest.
--
--    One row per item stack. The position is stored per player rather than per row so a
--    chest is always a single place, and so the script can re-spawn it on login.
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

SELECT entry, name, type, displayId FROM gameobject_template WHERE entry = 2600500;
SELECT entry, name, Attributes, spellIconId FROM spell_template WHERE entry IN (38720, 38721);
SELECT 'pending chest rows' AS what, COUNT(*) AS n FROM tw_char.terapin_corpse_chest;
