-- ---------------------------------------------------------------------------------------
-- Double every bag's capacity, capped at the core's hard ceiling of 36 slots.
--
-- Run against tw_world. IDEMPOTENT - see "HOW THIS STAYS IDEMPOTENT" below.
-- Requires a mangosd RESTART; there is no `.reload item_template` in this core.
--
-- WHY 36 IS THE CEILING
--   Bag.h:
--     // Maximum 36 Slots in 1.12
--     #define MAX_BAG_SIZE ((CONTAINER_END - CONTAINER_FIELD_SLOT_1)/2)
--   The container's slot list is a fixed 72-field block (36 slots x 2 fields for the
--   item GUID). Asking for more than 36 would write past the end of the update-field
--   block. This is the same class of hard limit as the 20-slot quest log.
--
-- WHY WE KNOW THE CLIENT RENDERS 36
--   Turtle already ships three 36-slot bags, and several at 28/30/32. So the bag UI is
--   already proven to draw well past vanilla's 20-slot maximum. This is not a guess.
--
-- WHAT DOES NOT CHANGE
--   - The BACKPACK stays 16 slots. It is not an item_template row; it is a fixed range of
--     player update fields (INVENTORY_SLOT_ITEM_START..END), so it cannot be resized
--     server-side.
--   - You still get 4 bag slots, not more. The number of slots you can hang bags in is
--     likewise a fixed player field range.
--   So the gain is "4 bags that each hold twice as much", not "more bags".
--
-- HOW THIS STAYS IDEMPOTENT
--   `container_slots = container_slots * 2` is NOT safe to re-run: a second pass would
--   double again. And we cannot tell 8-slots-originally from 4-slots-already-doubled,
--   because both read as 8.
--
--   So the first run records each bag's ORIGINAL size in a side table, and every run
--   (including the first) computes the new value from that recorded original. Re-running
--   is then a no-op, and the side table also gives you a clean revert path.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- 1. Remember the original sizes. Not TEMPORARY - it has to outlive the session.
CREATE TABLE IF NOT EXISTS tuning_bag_original (
  entry           MEDIUMINT UNSIGNED NOT NULL,
  container_slots TINYINT UNSIGNED   NOT NULL,
  PRIMARY KEY (entry)
) ENGINE=InnoDB COMMENT='Pre-tuning bag capacities. Used by tuning-bag-sizes.sql.';

-- INSERT IGNORE is what makes this idempotent: on the first run it captures the true
-- originals; on later runs the rows already exist and are left untouched, so the
-- already-doubled values never get recorded as if they were originals.
INSERT IGNORE INTO tuning_bag_original (entry, container_slots)
SELECT entry, container_slots
FROM item_template
WHERE container_slots > 0;

-- 2. Apply: double the ORIGINAL, clamp to the 36-slot field limit.
UPDATE item_template it
JOIN tuning_bag_original o ON o.entry = it.entry
SET it.container_slots = LEAST(36, o.container_slots * 2)
WHERE it.container_slots <> LEAST(36, o.container_slots * 2);

-- 3. Report what the mapping now is.
SELECT o.container_slots AS was_, it.container_slots AS now_, COUNT(*) AS bags
FROM tuning_bag_original o
JOIN item_template it ON it.entry = o.entry
GROUP BY o.container_slots, it.container_slots
ORDER BY o.container_slots;

-- ---------------------------------------------------------------------------------------
-- TO REVERT
--   UPDATE item_template it JOIN tuning_bag_original o ON o.entry = it.entry
--   SET it.container_slots = o.container_slots;
--
-- SHRINKING A BAG IS NOT SAFE WHILE IT HOLDS ITEMS
--   If you revert while items sit in the slots beyond the smaller size, those items are
--   in slots the bag no longer has. Empty your bags before reverting.
-- ---------------------------------------------------------------------------------------
