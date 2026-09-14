-- ---------------------------------------------------------------------------------------
-- Remove repair entirely: nothing takes durability damage, nothing ever breaks,
-- nothing ever needs a repair vendor or a repair bot.
--
-- Run against tw_world AND tw_char (two sections below - note the USE statements).
-- IDEMPOTENT: absolute targets, so re-running changes nothing.
-- Requires a mangosd RESTART - no `.reload item_template` in this core.
--
-- WHY max_durability = 0 IS THE COMPLETE FIX
--   Every durability loss funnels through Player::DurabilityLoss (Player.cpp:6235),
--   which opens with:
--
--       uint32 pMaxDurability = item->GetUInt32Value(ITEM_FIELD_MAXDURABILITY);
--       if (!pMaxDurability)
--           return;
--
--   So a max durability of 0 turns every loss path into a no-op. That includes the
--   10% loss on death, which is HARDCODED at Player.cpp:1290 and has no config knob:
--
--       DurabilityLossAll(0.10f, false);
--
--   This is why the DurabilityLossChance.* settings in mangosd.conf are not enough on
--   their own - they cover combat hits, absorbs, parries and blocks, but not dying.
--
--   And items can never read as broken, because Item.h:296 requires a nonzero maximum:
--       bool IsBroken() const { return MAXDURABILITY > 0 && DURABILITY == 0; }
--   With the maximum at 0 that is false forever, so equipped gear keeps working and the
--   client draws no durability bar at all.
-- ---------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------
-- 1. WORLD: no item has a durability maximum any more.
-- ---------------------------------------------------------------------------------------
USE tw_world;

UPDATE item_template
SET max_durability = 0
WHERE max_durability > 0;

-- ---------------------------------------------------------------------------------------
-- 2. CHARACTERS: zero the stored durability on items that already exist.
--
--    This step is not cosmetic, it avoids a real bug. Player::DurabilityPointsLoss
--    (Player.cpp:6254) clamps the new value to the maximum:
--
--        else if (pNewDurability > pMaxDurability)
--            pNewDurability = pMaxDurability;
--
--    An already-equipped item carrying, say, 80/120 would now clamp from 80 straight
--    down to 0 on its first damage tick. That crosses this branch:
--
--        if (pNewDurability == 0 && pOldDurability > 0 && item->IsEquipped())
--            _ApplyItemMods(item, item->GetSlot(), false);
--
--    ...which UNAPPLIES the item's stats while you are still wearing it. Setting the
--    stored durability to 0 up front means pOldDurability is already 0, the value never
--    changes, and that branch is never reached.
-- ---------------------------------------------------------------------------------------
USE tw_char;

UPDATE item_instance
SET durability = 0
WHERE durability > 0;

-- ---------------------------------------------------------------------------------------
-- 3. Belt and braces: stop the combat loss rolls at the source too.
--    Not strictly needed once max_durability is 0, but it means that if you ever restore
--    durability maximums (see revert below) you do not silently get repair costs back.
--    These are CONFIG values, not SQL - set them by hand in server/mangosd.conf:
--
--        DurabilityLossChance.Damage = 0
--        DurabilityLossChance.Absorb = 0
--        DurabilityLossChance.Parry  = 0
--        DurabilityLossChance.Block  = 0
--
--    (Currently 0.5 / 0.5 / 0.05 / 0.05.)
-- ---------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------
-- TO REVERT
--   There is no saved copy of the original maximums - unlike the bag script, this one
--   does not snapshot, because durability maximums are recoverable from the DBC/world
--   source by re-importing item_template. If you want a revert path, take a copy first:
--
--     CREATE TABLE tuning_durability_original AS
--       SELECT entry, max_durability FROM item_template WHERE max_durability > 0;
--
--   Run that BEFORE section 1, or it captures nothing but zeroes.
--
--   Note that reverting will not restore per-item current durability - every existing
--   item was zeroed in section 2, so restored gear would come back broken. Repair it,
--   or set item_instance.durability back to the item's maximum on revert.
-- ---------------------------------------------------------------------------------------
