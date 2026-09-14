-- ---------------------------------------------------------------------------------------
-- REVERTED BY DESIGN - new characters do NOT start with bags.
--
-- Run against tw_world. IDEMPOTENT. Requires a mangosd RESTART.
-- ---------------------------------------------------------------------------------------
--
-- This file used to grant every new character four 36-slot Loremaster's Backpacks. It was
-- written, never actually applied, found unapplied much later, applied - and then reverted
-- as soon as it was seen in game. Finding and making bags is part of the fun, and handing
-- out 144 slots at character creation removes a whole thread of early progression.
--
-- The file is KEPT rather than deleted so that db/apply-all.ps1 actively REMOVES the grant
-- on any database that had already run the old version. Deleting it would leave those
-- databases stuck with the bags and no migration to undo them.
--
-- The bag ITEM itself (50003, Loremaster's Backpack, 36 slots) is left in place. It is a
-- perfectly good bag and something else may want to award it - it just is not free at
-- level 1 any more.
--
-- The backpack is 16 slots and cannot be resized; see tuning-bag-sizes.sql for why that is
-- a hard limit rather than a choice.
-- ---------------------------------------------------------------------------------------

USE tw_world;

DELETE FROM playercreateinfo_item WHERE itemid = 50003;

SELECT 'starting bag grants remaining' AS check_, COUNT(*) AS n
FROM playercreateinfo_item WHERE itemid = 50003;
