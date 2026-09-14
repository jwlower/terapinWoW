-- ---------------------------------------------------------------------------------------
-- Point the warrior thrown abilities at their new custom icon art.
--
-- Run against tw_world. IDEMPOTENT. Needs the rebuilt patch-6.mpq, which carries both the
-- BLP images and the SpellIcon.dbc rows that name them.
--
-- The CLIENT is what renders icons, so this SQL is only here to keep spell_template in
-- step - a silent disagreement between the two halves is the failure mode that has bitten
-- this project repeatedly.
--
--   2900  Terapin_ShatteringThrow    <- Abilities/ShatteringThrow.png
--   2901  Terapin_ChilledToTheBone   <- Abilities/ChilledToTheBone.png
--
-- Both were confirmed absent from the client's SpellIcon.dbc before being minted, so no
-- existing icon is displaced.
-- ---------------------------------------------------------------------------------------

USE tw_world;

UPDATE spell_template SET spellIconId = 2900 WHERE entry IN (38400, 38410);  -- Heavy Throw
UPDATE spell_template SET spellIconId = 2901 WHERE entry IN (38403, 38412);  -- Crippling Throw

SELECT entry, name, spellIconId FROM spell_template
WHERE entry IN (38400, 38410, 38403, 38412) ORDER BY entry;
