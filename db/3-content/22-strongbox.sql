-- ---------------------------------------------------------------------------------------
-- Strongbox (38601) - open your bank from anywhere.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART, a rebuilt patch-6.mpq, and
-- lua_scripts/bank.lua.
-- ---------------------------------------------------------------------------------------
--
-- WHY THIS EXISTS
--   Carried inventory tops out at 160 slots - a 16-slot backpack that CANNOT be resized,
--   plus four bag slots at the 36-slot bag ceiling. All three are fixed ranges of player
--   update fields (Player.h:613-621), mirrored by compiled-in offsets in the client, so
--   none of them can be widened from here. The bank's 240 slots can simply be reached
--   instead.
--
-- NO CORE CHANGE NEEDED - THE MODE ALREADY EXISTS
--   WorldSession::CanUseBank (ItemHandler.cpp:1393):
--
--       bool isUsingBankCommand = (bankerGUID == GetPlayer()->GetObjectGuid() &&
--                                  bankerGUID == m_currentBankerGUID);
--       if (!isUsingBankCommand)
--       {
--           Creature* creature = GetPlayer()->GetNPCIfCanInteractWith(bankerGUID,
--                                                                     UNIT_NPC_FLAG_BANKER);
--           if (!creature) return false;
--       }
--
--   When the banker guid IS the player, the "is a real banker nearby" check is skipped
--   outright. That is exactly how the .bank GM command works (Commands.cpp:3664), and
--   Eluna already exposes Player:SendShowBank(worldobject) - so bank.lua just passes the
--   player themselves. Every subsequent bank operation re-checks CanUseBank() and passes
--   the same way, so deposits and withdrawals work, not merely the window.
--
-- UNIVERSAL AND FREE, like the teleports and Salvage - every class, known from level 1,
-- no reagent, no cost, no skill_line_ability row so it sits in the GENERAL tab.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM spell_template WHERE entry = 38601;

DROP TEMPORARY TABLE IF EXISTS tmp_bank;
CREATE TEMPORARY TABLE tmp_bank LIKE spell_template;
INSERT INTO tmp_bank SELECT * FROM spell_template WHERE entry = 13262;   -- Disenchant

UPDATE tmp_bank SET
  entry                  = 38601,
  name                   = 'Strongbox',
  nameSubtext            = '',
  description            = 'Opens your bank from anywhere.',
  effect1                = 3,          -- SPELL_EFFECT_DUMMY (bank.lua does the work)
  effect2 = 0, effect3 = 0,
  effectItemType1        = 0,
  effectTriggerSpell1    = 0,
  Targets                = 0,          -- takes no target at all
  effectImplicitTargetA1 = 1,          -- TARGET_UNIT_CASTER
  effectImplicitTargetB1 = 0,
  spellLevel             = 1,
  baseLevel              = 1,
  manaCost               = 0,
  powerType              = 0,
  RecoveryTime           = 0,
  categoryRecoveryTime   = 0,
  reagent1 = 0, reagentCount1 = 0,
  reagent2 = 0, reagentCount2 = 0,
  EquippedItemClass      = -1,
  spellIconId            = 2311,       -- INV_Misc_Bag_08
  RequiresSpellFocus     = 0;

INSERT INTO spell_template SELECT * FROM tmp_bank;
DROP TEMPORARY TABLE tmp_bank;

-- General tab, ungated by class - see sql/17 for why no skill_line_ability row.
DELETE FROM skill_line_ability WHERE spell_id = 38601;

DELETE FROM playercreateinfo_spell WHERE spell = 38601;
INSERT INTO playercreateinfo_spell (race, class, spell, note)
SELECT DISTINCT race, class, 38601, 'TurtleMod: strongbox' FROM playercreateinfo;

-- Existing characters too - playercreateinfo_spell only fires at creation.
INSERT IGNORE INTO tw_char.character_spell (guid, spell, active, disabled)
SELECT guid, 38601, 1, 0 FROM tw_char.characters;

SELECT entry, name, effect1, effectImplicitTargetA1, Targets, manaCost, spellLevel
FROM spell_template WHERE entry = 38601;
SELECT 'creation rows' AS what, COUNT(*) AS n FROM playercreateinfo_spell WHERE spell = 38601;
SELECT 'characters granted' AS what, COUNT(*) AS n FROM tw_char.character_spell WHERE spell = 38601;
