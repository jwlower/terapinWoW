-- ---------------------------------------------------------------------------------------
-- Salvage (38600) - break a weapon or piece of armour down into materials.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART, a rebuilt patch-6.mpq, and
-- lua_scripts/salvage.lua.
--
-- UNIVERSAL AND FREE
--   Every class, every race, known from level 1. No profession requirement, no reagent, no
--   power cost. Granted the same way as the free teleports: playercreateinfo_spell for new
--   characters plus a one-off grant to existing ones.
--
-- HOW IT WORKS
--   The spell is a DUMMY effect that targets an ITEM (Targets = 16, TARGET_FLAG_ITEM) -
--   exactly how Disenchant is shaped, so the client gives the same item-targeting cursor.
--   The server does nothing with the dummy; lua_scripts/salvage.lua watches
--   PLAYER_EVENT_ON_SPELL_CAST, reads Spell:GetTarget(), and decides what to return.
--
--   Cloned from Disenchant (13262) so the targeting, range and cast shape are inherited
--   rather than guessed, then the effect is switched from DISENCHANT (99) to DUMMY (3).
--
-- NO skill_line_ability ROW ON PURPOSE
--   That places it in the GENERAL spellbook tab and leaves it ungated by class. The
--   trade-off is that it can never be sold by a trainer - the client drops trainer entries
--   filed under no skill line - which is fine because it is granted, not taught. See sql/03.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM spell_template WHERE entry = 38600;

DROP TEMPORARY TABLE IF EXISTS tmp_sal;
CREATE TEMPORARY TABLE tmp_sal LIKE spell_template;
INSERT INTO tmp_sal SELECT * FROM spell_template WHERE entry = 13262;   -- Disenchant

UPDATE tmp_sal SET
  entry                  = 38600,
  name                   = 'Salvage',
  nameSubtext            = '',
  description            = 'Breaks a weapon or piece of armour down into raw materials. Better items yield more. The item is destroyed.',
  effect1                = 3,          -- SPELL_EFFECT_DUMMY (the Lua script does the work)
  effect2 = 0, effect3 = 0,
  effectItemType1        = 0,
  effectTriggerSpell1    = 0,
  Targets                = 16,         -- TARGET_FLAG_ITEM - same as Disenchant
  spellLevel             = 1,
  baseLevel              = 1,
  manaCost               = 0,
  powerType              = 0,
  RecoveryTime           = 0,
  categoryRecoveryTime   = 0,
  reagent1 = 0, reagentCount1 = 0,
  reagent2 = 0, reagentCount2 = 0,
  EquippedItemClass      = -1,         -- no equipped-item requirement
  spellIconId            = 1,
  RequiresSpellFocus     = 0;

INSERT INTO spell_template SELECT * FROM tmp_sal;
DROP TEMPORARY TABLE tmp_sal;

-- Never filed under a skill line - see the header.
DELETE FROM skill_line_ability WHERE spell_id = 38600;

-- ---------------------------------------------------------------------------------------
-- Known from character creation, for every race/class combination that exists.
-- ---------------------------------------------------------------------------------------
DELETE FROM playercreateinfo_spell WHERE spell = 38600;
INSERT INTO playercreateinfo_spell (race, class, spell, note)
SELECT DISTINCT race, class, 38600, 'TurtleMod: salvage' FROM playercreateinfo;

-- Existing characters too - playercreateinfo_spell only fires at creation.
INSERT IGNORE INTO tw_char.character_spell (guid, spell, active, disabled)
SELECT guid, 38600, 1, 0 FROM tw_char.characters;

SELECT entry, name, effect1, Targets, manaCost, spellLevel FROM spell_template WHERE entry = 38600;
SELECT 'creation rows' AS what, COUNT(*) AS n FROM playercreateinfo_spell WHERE spell = 38600;
SELECT 'characters granted' AS what, COUNT(*) AS n FROM tw_char.character_spell WHERE spell = 38600;
