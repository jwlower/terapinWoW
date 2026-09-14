-- ---------------------------------------------------------------------------------------
-- Let each profession master teach its own profession ranks (Apprentice .. Artisan).
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART.
--
-- WHY THIS IS THE ICON FIX
--   The custom masters showed placeholder icons while real trainers showed potions and
--   swords for the SAME recipes. The NPCs looked identical - trainer_type 2 on both - but
--   creature_template.trainer_type is not what gets sent:
--
--     SendTrainerList:   trainer_type = cSpells->trainerType   <- from the SPELL LIST
--     ObjectMgr.cpp:8167 if (IsProfessionSpell(trigger)) data.trainerType = 2;
--
--   TrainerSpellData.trainerType is 0 unless at least one taught spell is a PROFESSION
--   spell. Real trainers teach "Apprentice Blacksmith"; the custom masters taught only
--   recipes, so they announced themselves as type 0 - a CLASS trainer - and the client
--   renders class trainers with spell icons instead of item icons.
--
--   Adding the profession ranks flips trainerType to 2 and the icons come right.
--
--   (SPELL_EFFECT_SKILL is 118, not 44 - an earlier filter of mine checked 44,
--   SPELL_EFFECT_SKILL_STEP, which is why these never got added in the first place.)
--
-- IT IS ALSO SIMPLY CORRECT
--   A "Blacksmithing Master" that cannot teach you Blacksmithing was always odd. Now the
--   masters work like real trainers: learn the profession, upgrade its rank, buy recipes.
--
-- THE REQUIREMENTS ARE COPIED, NOT INVENTED
--   Cost, required skill and required level for each rank are taken from whatever real
--   trainer already teaches that exact spell, so Journeyman/Expert/Artisan gate exactly as
--   they do everywhere else.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- Which master handles which skill, derived from the recipes each already teaches rather
-- than hardcoded - so it stays correct if a master is added or re-pointed later.
DROP TEMPORARY TABLE IF EXISTS tmp_master_skill;
CREATE TEMPORARY TABLE tmp_master_skill (npc INT, skill INT, PRIMARY KEY (npc, skill));
INSERT IGNORE INTO tmp_master_skill (npc, skill)
SELECT DISTINCT entry, reqskill FROM npc_trainer
WHERE entry BETWEEN 2600300 AND 2600313 AND reqskill > 0;

-- Every profession-rank wrapper, with the skill it grants.
DROP TEMPORARY TABLE IF EXISTS tmp_ranks;
CREATE TEMPORARY TABLE tmp_ranks (wrapper INT, skill INT, PRIMARY KEY (wrapper));
INSERT IGNORE INTO tmp_ranks (wrapper, skill)
SELECT t.entry, c.effectMiscValue2
FROM spell_template t
JOIN spell_template c ON c.entry = t.effectTriggerSpell1
WHERE t.effect1 = 36 AND c.effect2 = 118;     -- SPELL_EFFECT_SKILL

-- The requirements a real trainer uses for each of those wrappers.
DROP TEMPORARY TABLE IF EXISTS tmp_reqs;
CREATE TEMPORARY TABLE tmp_reqs (spell INT, cost INT, reqskill INT, reqskillvalue INT,
                                 reqlevel INT, PRIMARY KEY (spell));
INSERT IGNORE INTO tmp_reqs (spell, cost, reqskill, reqskillvalue, reqlevel)
SELECT nt.spell, MIN(nt.spellcost), MIN(nt.reqskill), MIN(nt.reqskillvalue), MIN(nt.reqlevel)
FROM npc_trainer nt
JOIN tmp_ranks r ON r.wrapper = nt.spell
WHERE nt.entry < 2000000
GROUP BY nt.spell;

DELETE nt FROM npc_trainer nt
JOIN tmp_ranks r ON r.wrapper = nt.spell
WHERE nt.entry BETWEEN 2600300 AND 2600313;

INSERT IGNORE INTO npc_trainer (entry, spell, spellcost, reqskill, reqskillvalue, reqlevel)
SELECT ms.npc, r.wrapper,
       COALESCE(rq.cost, 0), COALESCE(rq.reqskill, 0),
       COALESCE(rq.reqskillvalue, 0), COALESCE(rq.reqlevel, 0)
FROM tmp_master_skill ms
JOIN tmp_ranks r ON r.skill = ms.skill
LEFT JOIN tmp_reqs rq ON rq.spell = r.wrapper;

-- ---------------------------------------------------------------------------------------
-- Report. Every master should now teach at least one profession spell, which is what
-- flips trainerType to 2.
-- ---------------------------------------------------------------------------------------
SELECT ct.entry, ct.name,
       SUM(c.effect2 = 118) AS profession_spells,
       COUNT(*) AS total_taught
FROM npc_trainer nt
JOIN creature_template ct ON ct.entry = nt.entry
JOIN spell_template t ON t.entry = nt.spell
LEFT JOIN spell_template c ON c.entry = t.effectTriggerSpell1
WHERE nt.entry BETWEEN 2600300 AND 2600313
GROUP BY ct.entry, ct.name ORDER BY ct.entry;
