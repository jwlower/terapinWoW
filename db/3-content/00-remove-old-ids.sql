-- ---------------------------------------------------------------------------------------
-- Remove the first-attempt spells at 90200-90203.
--
-- Run against tw_world BEFORE 03/04/05. IDEMPOTENT.
--
-- WHY
--   Spell ids above 65535 are truncated to 16 bits by SMSG_INITIAL_SPELLS, so 90200 was
--   delivered to the client as 24664 - "Sleep". See TurtleMod/SPELL-IDS.md. Everything
--   moved to the reserved 38000-38999 block; these rows are dead weight and any character
--   who ran .learn on them is carrying a bogus spell.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM spell_template     WHERE entry    IN (90200, 90201, 90202, 90203);
DELETE FROM npc_trainer        WHERE spell    IN (90200, 90201, 90202, 90203);
DELETE FROM skill_line_ability WHERE spell_id IN (90200, 90201, 90202, 90203);

-- Scrub them from characters too, or they linger in the spellbook as Sleep / Frost Dam.
DELETE FROM tw_char.character_spell WHERE spell IN (90200, 90201, 90202, 90203);

-- The truncated ids the client was actually handed. Only remove these if the character
-- cannot legitimately know them - 24664 'Sleep' and 24666/24667 are not player spells,
-- so they are safe to clear.
DELETE FROM tw_char.character_spell WHERE spell IN (24664, 24665, 24666, 24667);

-- ---------------------------------------------------------------------------------------
-- Confirm the new block is actually free before 03/04/05 insert into it.
-- Expect ZERO rows. If anything comes back, pick a different id and update
-- TurtleMod/content.py and SPELL-IDS.md to match.
-- ---------------------------------------------------------------------------------------
SELECT 'OCCUPIED - pick another id' AS problem, entry, name
FROM spell_template WHERE entry BETWEEN 38000 AND 38003;
