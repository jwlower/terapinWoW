-- ---------------------------------------------------------------------------------------
-- Interact with world objects while mounted - the DATA half.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART. No client patch needed.
-- ---------------------------------------------------------------------------------------
--
-- GameObject::Use (GameObject.cpp:1493) is the single gate:
--
--     if (!m_goInfo->IsUsableMounted())
--         user->RemoveSpellsCausingAura(SPELL_AURA_MOUNTED);
--
-- and IsUsableMounted() (GameObject.h:374) reads a per-type `allowMounted` field for four
-- object types. Those are DATA, so this file is all that is needed for them:
--
--     questgiver   data8    495 of 505 dismounted you
--     text         data3    159 of 159
--     goober       data17   279 of 279
--     spellcaster  data3     15 of 16
--
-- Chests (ore veins, herbs, treasure - 1043 of them) have no such field; all 16 slots in
-- the chest struct are spoken for. They are handled in terapin-core.patch instead, which
-- makes GAMEOBJECT_TYPE_CHEST return true outright.
--
-- IsUsableMounted() has exactly ONE caller - the line above - so flipping these fields
-- changes nothing except whether the object throws you off your mount.
--
-- NOT A NEW MECHANISM
--   Stock data already ships 10 questgivers and 1 spellcaster with allowMounted set (the
--   bounty boards, the guild vaults, the Karazhan portal), so this is using the field as
--   intended rather than inventing behaviour.
--
-- REVERTING
--   This only ever sets 0 -> 1, so a revert is "back to 0, except the entries that shipped
--   as 1". Those are, measured before this file first ran:
--     questgiver  180448, 1000167, 1000168, 1000300, 1000302, 1000333, 1000334,
--                 1000075, 1000076, 1000223
--     spellcaster 181146
-- ---------------------------------------------------------------------------------------

USE tw_world;

SELECT 'BEFORE' AS stage,
       SUM(type=2  AND data8=0)  AS questgiver,
       SUM(type=9  AND data3=0)  AS txt,
       SUM(type=10 AND data17=0) AS goober,
       SUM(type=22 AND data3=0)  AS spellcaster
FROM gameobject_template;

UPDATE gameobject_template SET data8  = 1 WHERE type = 2  AND data8  = 0;   -- questgiver
UPDATE gameobject_template SET data3  = 1 WHERE type = 9  AND data3  = 0;   -- text
UPDATE gameobject_template SET data17 = 1 WHERE type = 10 AND data17 = 0;   -- goober
UPDATE gameobject_template SET data3  = 1 WHERE type = 22 AND data3  = 0;   -- spellcaster

SELECT 'AFTER' AS stage,
       SUM(type=2  AND data8=0)  AS questgiver,
       SUM(type=9  AND data3=0)  AS txt,
       SUM(type=10 AND data17=0) AS goober,
       SUM(type=22 AND data3=0)  AS spellcaster
FROM gameobject_template;
