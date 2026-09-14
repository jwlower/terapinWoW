-- ---------------------------------------------------------------------------------------
-- Three riding tiers: 50% at level 20, 100% at level 40, 150% at level 60.
--
-- Run against tw_world. IDEMPOTENT (absolute values + ON DUPLICATE KEY UPDATE).
-- Spell changes can be applied live with `.reload spell_mod`.
-- The item and trainer changes need a mangosd restart.
--
-- ---------------------------------------------------------------------------------------
-- THE MECHANISM THAT MAKES THIS WORK
--
--   Mounted speed takes the HIGHEST matching aura, not the sum (Unit.cpp:7778):
--       if (IsMounted())
--           main_speed_mod = GetMaxPositiveAuraModifier(SPELL_AURA_MOD_INCREASE_MOUNTED_SPEED);
--
--   GetMax..., not GetTotal... That single detail is what allows a THIRD tier on a client
--   that only ships two kinds of mount. Speed can come from the player instead of from
--   the mount, and whichever is larger wins.
--
--   The carrier is the riding skill itself. `33389 Apprentice Riding` is the trainer spell;
--   what it actually teaches (via SPELL_EFFECT_LEARN_SPELL) is `33388 Riding`, a PERMANENT
--   PASSIVE - its attributes value 16777424 includes 0x40, SPELL_ATTR_PASSIVE. Same for
--   `33392 Journeyman Riding` -> `33391 Riding`.
--
--   Both passives have a completely empty third effect slot (effect3, aura, base points,
--   dice and targets are all 0), so there is a free slot to hang a mounted-speed aura on
--   without displacing anything. Passives are re-cast on every login, so the aura is
--   permanent and needs no per-character maintenance.
--
--   Note the aura is only consulted inside `if (IsMounted())`, so carrying it while on
--   foot does nothing at all.
--
-- WHY spell_effect_mod AND NOT spell_template
--   Spells load from Spell.dbc on this server: LoadSpellsFromSql defaults to false
--   (World.cpp:1485) and is not set in mangosd.conf, so World.cpp:1974-1980 takes the DBC
--   branch. Editing spell_template would therefore change NOTHING.
--
--   `spell_effect_mod` is the supported way to patch DBC-loaded spells: SpellModMgr
--   applies it at World.cpp:2043, after the spell load, writing straight onto the
--   in-memory SpellEntry. A column value of -1 means "leave this field alone"
--   (ModInt32ValueIfExplicit: if f.GetInt32() != -1 then value = f.GetInt32()).
--   Verified that none of the 330 rows already in that table touch any spell used here.
--
-- HOW THE NUMBERS BECOME PERCENTAGES
--   WorldObject::CalculateSpellDamage (Object.cpp:4434):
--       int32 randomPoints = int32(EffectDieSides + level * EffectDicePerLevel);
--       switch (randomPoints) { case 0: case 1: basePoints += baseDice; break; ... }
--   With EffectDieSides = 0 and EffectBaseDice = 0 it lands on `case 0`, adds nothing, and
--   the value is EffectBasePoints verbatim. So every row below sets dice and die-sides to
--   0 explicitly and puts the literal percentage in EffectBasePoints - deterministic
--   regardless of what the DBC happens to hold in those fields.
--
--   (Stock mounts express 60% as basePoints 59 + baseDice 1. We do not rely on that.)
--
--   EffectRealPointsPerLevel and EffectDicePerLevel are pinned to 0 too, so the aura does
--   not scale with level behind our back via basePoints += int32(level * basePointsPerLevel).
--
-- THE RESULTING LADDER
--   level 20, Apprentice Riding (riding 75), any normal mount .... max(50, 50)  =  50%
--   level 40, Journeyman Riding (riding 150), normal mount ....... max(100, 50) = 100%
--   level 60, epic mount ......................................... max(100,150) = 150%
--   level 60, normal mount ....................................... max(100, 50) = 100%
--
--   Your cheap mount gets faster on its own at 40, which is the point of putting the speed
--   on the skill. The 150% step is the epic mount, which stays gated at level 60.
--
-- WHAT IS NOT POSSIBLE
--   A third riding SKILL rank. Only two rank spells exist for skill 762 (33389 step 1 -> 75,
--   33392 step 2 -> 150); there is no Expert Riding in this client's Spell.dbc, and a
--   genuinely new spell needs a client patch. A third rank would be cosmetic anyway, since
--   the speed now comes from the tier you are on rather than from the rank number.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 0. Classify every mount spell: which effect index carries the speed aura, and how fast.
--    Signature is aura 32 (MOD_INCREASE_MOUNTED_SPEED) together with aura 78 (MOUNTED) -
--    the second condition keeps non-mount speed effects out (a -15% debuff, a couple of
--    quest items).
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_mount;
CREATE TEMPORARY TABLE tmp_mount (
  spell MEDIUMINT UNSIGNED NOT NULL,
  idx   TINYINT NOT NULL,
  speed INT NOT NULL,
  PRIMARY KEY (spell), KEY (speed)
) ENGINE=MEMORY;

INSERT IGNORE INTO tmp_mount (spell, idx, speed)
SELECT entry,
  CASE WHEN effectApplyAuraName1=32 THEN 0
       WHEN effectApplyAuraName2=32 THEN 1 ELSE 2 END,
  CASE WHEN effectApplyAuraName1=32 THEN CAST(effectBasePoints1 AS SIGNED)+CAST(effectBaseDice1 AS SIGNED)
       WHEN effectApplyAuraName2=32 THEN CAST(effectBasePoints2 AS SIGNED)+CAST(effectBaseDice2 AS SIGNED)
       ELSE CAST(effectBasePoints3 AS SIGNED)+CAST(effectBaseDice3 AS SIGNED) END
FROM spell_template
WHERE (effectApplyAuraName1=32 OR effectApplyAuraName2=32 OR effectApplyAuraName3=32)
  AND (effectApplyAuraName1=78 OR effectApplyAuraName2=78 OR effectApplyAuraName3=78);
-- CAST to SIGNED matters: effectBasePoints can be negative while effectBaseDice is
-- unsigned, and MySQL otherwise throws "BIGINT UNSIGNED value is out of range".

-- Snapshot the untouched speeds once, so this stays re-runnable and revertible.
CREATE TABLE IF NOT EXISTS tuning_mount_speed_original (
  spell MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY,
  idx   TINYINT NOT NULL,
  speed INT NOT NULL
) ENGINE=InnoDB COMMENT='Pre-tuning mount speeds. Used by tuning-riding-tiers.sql.';
INSERT IGNORE INTO tuning_mount_speed_original SELECT spell, idx, speed FROM tmp_mount;

-- ---------------------------------------------------------------------------------------
-- 1. The two riding passives gain a mounted-speed aura in their free third effect slot.
--    EffectIndex is 0-based, so effect3 is index 2.
--      Effect 6                = SPELL_EFFECT_APPLY_AURA
--      EffectApplyAuraName 32  = SPELL_AURA_MOD_INCREASE_MOUNTED_SPEED
--      EffectImplicitTargetA 1 = TARGET_UNIT_CASTER
-- ---------------------------------------------------------------------------------------
INSERT INTO spell_effect_mod
  (Id, EffectIndex, Effect, EffectApplyAuraName, EffectImplicitTargetA,
   EffectBasePoints, EffectBaseDice, EffectDieSides,
   EffectRealPointsPerLevel, EffectDicePerLevel, Comment)
VALUES
  (33388, 2, 6, 32, 1,  50, 0, 0, 0, 0, 'Riding rank 1: +50% mounted speed (tuning-riding-tiers)'),
  (33391, 2, 6, 32, 1, 100, 0, 0, 0, 0, 'Riding rank 2: +100% mounted speed (tuning-riding-tiers)')
ON DUPLICATE KEY UPDATE
  Effect=VALUES(Effect), EffectApplyAuraName=VALUES(EffectApplyAuraName),
  EffectImplicitTargetA=VALUES(EffectImplicitTargetA),
  EffectBasePoints=VALUES(EffectBasePoints), EffectBaseDice=VALUES(EffectBaseDice),
  EffectDieSides=VALUES(EffectDieSides),
  EffectRealPointsPerLevel=VALUES(EffectRealPointsPerLevel),
  EffectDicePerLevel=VALUES(EffectDicePerLevel), Comment=VALUES(Comment);

-- ---------------------------------------------------------------------------------------
-- 2. Retune the mounts themselves.
--    Normal (60%) -> 50, so a tier-1 rider gets exactly 50 and not the mount's old 60.
--    Epic  (100%) -> 150, the level-60 tier.
--    Selected from the ORIGINAL snapshot, never from current values, so re-running cannot
--    walk the numbers.
-- ---------------------------------------------------------------------------------------
INSERT INTO spell_effect_mod
  (Id, EffectIndex, EffectBasePoints, EffectBaseDice, EffectDieSides,
   EffectRealPointsPerLevel, EffectDicePerLevel, Comment)
SELECT o.spell, o.idx,
       CASE o.speed WHEN 60 THEN 50 ELSE 150 END,
       0, 0, 0, 0,
       CASE o.speed WHEN 60 THEN 'Mount tier 1: 50% (tuning-riding-tiers)'
                    ELSE 'Mount tier 3: 150% (tuning-riding-tiers)' END
FROM tuning_mount_speed_original o
WHERE o.speed IN (60, 100)
ON DUPLICATE KEY UPDATE
  EffectBasePoints=VALUES(EffectBasePoints), EffectBaseDice=VALUES(EffectBaseDice),
  EffectDieSides=VALUES(EffectDieSides),
  EffectRealPointsPerLevel=VALUES(EffectRealPointsPerLevel),
  EffectDicePerLevel=VALUES(EffectDicePerLevel), Comment=VALUES(Comment);
-- The 40% group (12 spells) and the handful at 0/150/200% are left alone - they are
-- special cases rather than the two standard mount tiers.

-- ---------------------------------------------------------------------------------------
-- 3. Riding becomes trainable at 20 and 40 instead of 40 and 60.
--    Riding is taught from npc_trainer_template entry 1, not npc_trainer.
--
--    COST IS ALSO REDUCED, and this is a judgement call rather than something you asked
--    for: Apprentice Riding costs 900000 copper (90g), which a level 20 character cannot
--    remotely afford, so the tier would exist but be unreachable. Scaled to 10g / 90g.
--    To keep the original prices instead, drop this statement and run:
--      UPDATE npc_trainer_template SET spellcost=900000  WHERE spell=33389 AND entry=1;
--      UPDATE npc_trainer_template SET spellcost=9000000 WHERE spell=33392 AND entry=1;
-- ---------------------------------------------------------------------------------------
UPDATE npc_trainer_template SET reqlevel = 20, spellcost = 100000
  WHERE entry = 1 AND spell = 33389;
UPDATE npc_trainer_template SET reqlevel = 40, spellcost = 900000
  WHERE entry = 1 AND spell = 33392;

-- ---------------------------------------------------------------------------------------
-- 4. Tier-1 mount items become usable at 20. Tier-3 (epic) items stay at 60, which is
--    what makes the top tier a level-60 step rather than something a 40 can buy.
--    required_skill_rank is untouched: 75 comes with Apprentice at 20, 150 with
--    Journeyman at 40, so the skill gates already line up.
-- ---------------------------------------------------------------------------------------
UPDATE item_template it
JOIN tuning_mount_speed_original o
  ON o.speed = 60
 AND (it.spellid_1 = o.spell OR it.spellid_2 = o.spell OR it.spellid_3 = o.spell)
SET it.required_level = 20
WHERE it.required_level > 20;

-- ---------------------------------------------------------------------------------------
-- 5. Report.
-- ---------------------------------------------------------------------------------------
SELECT 'riding passives patched' AS what, COUNT(*) AS n
  FROM spell_effect_mod WHERE Id IN (33388,33391) AND EffectIndex = 2
UNION ALL
SELECT 'mount spells retuned to 50pct', COUNT(*) FROM spell_effect_mod
  WHERE Comment LIKE 'Mount tier 1%'
UNION ALL
SELECT 'mount spells retuned to 150pct', COUNT(*) FROM spell_effect_mod
  WHERE Comment LIKE 'Mount tier 3%'
UNION ALL
SELECT 'tier-1 mount items usable at 20', COUNT(*) FROM item_template it
  JOIN tuning_mount_speed_original o ON o.speed = 60
   AND (it.spellid_1=o.spell OR it.spellid_2=o.spell OR it.spellid_3=o.spell)
  WHERE it.required_level = 20;

SELECT spell, reqlevel, spellcost, reqskill FROM npc_trainer_template
WHERE entry = 1 AND spell IN (33389,33392);

-- ---------------------------------------------------------------------------------------
-- TO REVERT
--   DELETE FROM spell_effect_mod WHERE Comment LIKE '%tuning-riding-tiers%';
--   UPDATE item_template it JOIN tuning_mount_speed_original o ON o.speed=60
--     AND (it.spellid_1=o.spell OR it.spellid_2=o.spell OR it.spellid_3=o.spell)
--     SET it.required_level = 40 WHERE it.required_level = 20;
--   UPDATE npc_trainer_template SET reqlevel=40, spellcost=900000  WHERE entry=1 AND spell=33389;
--   UPDATE npc_trainer_template SET reqlevel=60, spellcost=9000000 WHERE entry=1 AND spell=33392;
--   Then RESTART - deleting a spell_effect_mod row does not undo the in-memory patch.
-- ---------------------------------------------------------------------------------------
