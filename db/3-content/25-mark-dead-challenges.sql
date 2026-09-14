-- ---------------------------------------------------------------------------------------
-- Mark the challenge modes that do nothing on this build.
--
-- Run against tw_world. IDEMPOTENT.
-- ---------------------------------------------------------------------------------------
--
-- Traveling Craftmaster (57738) and Path of the Brewmaster (57746) are offered at character
-- creation and then do NOTHING. Verified by reading every reference in the source:
--
--   CHALLENGE_CRAFTMASTER  appears twice - the login grant table, and one line excluding it
--                          from battleground XP. "Equip only what you craft" is unenforced.
--   CHALLENGE_BREWMASTER   appears ONCE, in the login grant table. Nothing else references
--                          it anywhere. "No experience unless drunk" is unenforced.
--
-- WHY THEY ARE NOT DELETED
--   The checkbox lives in the CLIENT's character-creation screen, and the mask is sent to
--   the server (CharacterHandler.cpp:382) which stores it verbatim. Deleting the spells
--   would not remove the option - a player would still tick it, still believe they had
--   taken a challenge, and get an even quieter no-op.
--
--   So the tooltip is made to tell the truth instead. If you want the server to actively
--   refuse those bits, that is a one-line core change at CharacterHandler.cpp:382 masking
--   them out of challengeMask - say so and it can go in the next build.
--
-- Level One Lunatic (57736) is deliberately NOT touched. It is partial rather than absent:
-- nothing keeps you at level one, but it does relax level-gated area triggers and satisfy
-- CONDITION_LUNATIC, so it is scaffolding that works - just not a complete challenge.
-- ---------------------------------------------------------------------------------------

USE tw_world;

UPDATE spell_template
SET description = CONCAT('|cffff2020[NOT IMPLEMENTED ON THIS SERVER - this challenge has no effect]|r ',
                         'Equip only what you craft. True power comes from your own hands.')
WHERE entry = 57738;

UPDATE spell_template
SET description = CONCAT('|cffff2020[NOT IMPLEMENTED ON THIS SERVER - this challenge has no effect]|r ',
                         'You gain no experience unless you are completely smashed.')
WHERE entry = 57746;

SELECT entry, name, LEFT(description, 70) AS description FROM spell_template
WHERE entry IN (57736, 57738, 57746) ORDER BY entry;
