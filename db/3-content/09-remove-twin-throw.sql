-- ---------------------------------------------------------------------------------------
-- Remove Twin Throw (38401, its hidden half 38402, and teacher 38411).
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART.
--
-- WHY IT WAS DROPPED
--   The design was two SPELL_EFFECT_TRIGGER_SPELL effects pointing at one hidden damage
--   spell, so each cast would roll its own crit and give two chances at warrior on-crit
--   effects (Deep Wounds does accept ranged procs - procFlags 69972 includes
--   DEAL_RANGED_ABILITY - so the goal was sound).
--
--   In practice it produced NO damage numbers at all. Two TRIGGER_SPELL effects firing the
--   same spell in one cast evidently do not both resolve here. Making it work would mean
--   either a script, or a proc-driven second hit, which is more machinery than the ability
--   is worth. Heavy Throw and Crippling Throw cover the intent.
--
--   Keep 38401/38402/38411 reserved rather than reused, so any character who learned it
--   during testing does not end up holding some unrelated future spell.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM spell_template     WHERE entry    IN (38401, 38402, 38411);
DELETE FROM npc_trainer        WHERE spell    IN (38401, 38402, 38411);
DELETE FROM skill_line_ability WHERE spell_id IN (38401, 38402, 38411);

-- Scrub it from anyone who learned it while testing, or it lingers in the spellbook as a
-- spell the server no longer knows.
DELETE FROM tw_char.character_spell WHERE spell IN (38401, 38402, 38411);

SELECT 'remaining thrown abilities' AS what, entry, name
FROM spell_template WHERE entry IN (38400, 38401, 38402, 38403) ORDER BY entry;
