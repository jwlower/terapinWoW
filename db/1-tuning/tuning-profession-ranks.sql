-- ---------------------------------------------------------------------------------------
-- Fix professions being stuck at a 75 cap.
--
-- IDEMPOTENT: absolute targets throughout. Requires a mangosd RESTART for the
-- playercreateinfo_spell half to take effect.
--
-- THE BUG
--   tuning-start-with-professions.sql granted the APPRENTICE rank spell for each of the
--   14 professions. Spell::EffectLearnSkill (SpellEffects.cpp:2771) computes the ceiling
--   straight from the rank:
--
--       uint16 step = uint16(damage);
--       uint16 current = std::max(uint16(1), target->GetSkillValuePure(skillid));
--       uint16 max = (step * 75);
--       target->SetSkill(skillid, current, max, step);
--
--   Apprentice is step 1, so max = 75. Artisan is step 4, so max = 300.
--
--   Note `current` is preserved. That is why Gigachad ended up with values ABOVE the
--   ceiling (165/75 blacksmithing, 181/75 alchemy) - those professions had been levelled
--   legitimately with a proper cap, and casting the Apprentice spell reset only the
--   ceiling, keeping the progress.
--
--   It also explains why `.learn all_recipes <prof>` looked broken. Its last act is:
--       uint16 maxLevel = target->GetSkillMaxPure(targetSkillInfo->id);
--       target->SetSkill(targetSkillInfo->id, maxLevel, maxLevel);
--   It sets your skill to your current max - which was 75. The command was fine; the
--   ceiling was wrong.
--
-- WHY GRANTING ONLY THE ARTISAN RANK IS ENOUGH
--   Each rank spell is self-contained: it carries SPELL_EFFECT_LEARN_SPELL (36) teaching
--   that rank's trade-skill spell, plus SPELL_EFFECT_SKILL_STEP (44) setting the ceiling.
--       Apprentice Blacksmith 2020 -> teaches 2018 Blacksmithing, step 1
--       Artisan    Blacksmith 9786 -> teaches 9785 Blacksmithing, step 4
--   So Artisan alone gives both the trade window and the 300 ceiling. There are no
--   spell_learn_spell rows involved and no prerequisite chain to satisfy.
--
--   Player::addSpell (Player.cpp:4594) CASTS any spell carrying SKILL_STEP rather than
--   just filing it, which is what makes a playercreateinfo_spell grant apply the skill:
--       else if (spellInfo->HasEffect(SPELL_EFFECT_SKILL_STEP))
--       { CastSpell(this, spell_id, true); return false; }
--
-- DO NOT GRANT BOTH RANKS
--   Both would be cast at creation and the LAST one to land wins. If Apprentice went
--   second you would be back to 75. Hence REPLACE below, not INSERT.
-- ---------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------
-- 1. WORLD: new characters get the Artisan rank instead of the Apprentice rank.
-- ---------------------------------------------------------------------------------------
USE tw_world;

-- Rank map, so the swap is readable and re-runnable.
DROP TEMPORARY TABLE IF EXISTS tmp_prof_rank;
CREATE TEMPORARY TABLE tmp_prof_rank (
  skill       SMALLINT UNSIGNED NOT NULL,
  apprentice  MEDIUMINT UNSIGNED NOT NULL,
  artisan     MEDIUMINT UNSIGNED NOT NULL,
  label       VARCHAR(32) NOT NULL,
  PRIMARY KEY (skill)
) ENGINE=MEMORY;

INSERT INTO tmp_prof_rank (skill, apprentice, artisan, label) VALUES
  (129,  3279, 10847, 'First Aid'),
  (142, 46051, 46057, 'Survivalist'),   -- Turtle custom profession
  (164,  2020,  9786, 'Blacksmithing'),
  (165,  2155, 10663, 'Leatherworking'),
  (171,  2275, 11612, 'Alchemy'),
  (182,  2372, 11994, 'Herbalism'),
  (185,  2551, 18261, 'Cooking'),
  (186,  2581, 10249, 'Mining'),
  (197,  3911, 12181, 'Tailoring'),
  (202,  4039, 12657, 'Engineering'),
  (333,  7414, 13921, 'Enchanting'),
  (356,  7733, 18249, 'Fishing'),
  (393,  8615, 10769, 'Skinning'),
  (755, 30219, 30227, 'Jewelcrafting');

-- Add the Artisan grant for every race/class combo that currently has the Apprentice one,
-- so we inherit exactly the same coverage rather than re-deriving it from playercreateinfo.
INSERT IGNORE INTO playercreateinfo_spell (race, class, Spell, Note)
SELECT pcs.race, pcs.class, r.artisan, CONCAT('Artisan ', r.label, ' (start with professions)')
FROM playercreateinfo_spell pcs
JOIN tmp_prof_rank r ON r.apprentice = pcs.Spell;

-- Remove the Apprentice grants. This is the half that actually fixes the cap.
DELETE pcs FROM playercreateinfo_spell pcs
JOIN tmp_prof_rank r ON r.apprentice = pcs.Spell;

-- ---------------------------------------------------------------------------------------
-- 2. CHARACTERS: lift the ceiling on characters that already exist.
--
--    Only `max` needs changing. The skill "step" is NOT persisted - Player::_LoadSkills
--    stores just the id, value and max:
--        SetUInt32Value(PLAYER_SKILL_INDEX(count), skill);
--        SetUInt32Value(PLAYER_SKILL_VALUE_INDEX(count), MAKE_SKILL_VALUE(value, max));
--    and professions fall through GetSkillRangeType's `default:` branch, so the max read
--    from the database is used verbatim rather than being recomputed from level.
--
--    `value` is deliberately left alone - this lifts the ceiling, it does not hand you
--    300 in everything. Use `.learn all_recipes <profession>` per profession to max one
--    out and pick up its recipes.
--
--    ONLINE CHARACTERS ARE SKIPPED. Their skills live in memory and would be written back
--    over this on logout. Log out and re-run, or fix them live in-game (see notes below).
-- ---------------------------------------------------------------------------------------
USE tw_char;

UPDATE character_skills cs
JOIN characters c ON c.guid = cs.guid
SET cs.max = 300
WHERE cs.skill IN (129,142,164,165,171,182,185,186,197,202,333,356,393,755)
  AND cs.max < 300
  AND c.online = 0;

-- Report anything still capped, so a skipped online character is visible rather than silent.
SELECT c.name, c.online, cs.skill, cs.value, cs.max
FROM character_skills cs JOIN characters c ON c.guid = cs.guid
WHERE cs.skill IN (129,142,164,165,171,182,185,186,197,202,333,356,393,755)
  AND cs.max < 300
ORDER BY c.name, cs.skill;

-- ---------------------------------------------------------------------------------------
-- FIXING AN ONLINE CHARACTER LIVE
--   Target nothing (or yourself) and run one .learn per profession. This casts the Artisan
--   rank, which lifts the cap to 300 and grants the Artisan trade-skill spell, preserving
--   your current value:
--     .learn 10847   .learn 46057   .learn 9786    .learn 10663
--     .learn 11612   .learn 11994   .learn 18261   .learn 10249
--     .learn 12181   .learn 12657   .learn 13921   .learn 18249
--     .learn 10769   .learn 30227
--
--   `.learn all_recipes` needs a profession NAME and a player target. ChatHandler::
--   GetSelectedPlayer falls back to you only when nothing at all is selected; with a mob
--   selected it returns nullptr and you get "Player not found". So:
--     .learn all_recipes blacksmithing     <- correct
--     .learn all_recipes                   <- fails, no profession named
-- ---------------------------------------------------------------------------------------
