-- ---------------------------------------------------------------------------------------
-- Every new character starts with four 36-slot bags, already equipped.
--
-- Run against tw_world. IDEMPOTENT (INSERT IGNORE + a fixed amount).
-- Requires a mangosd RESTART - playercreateinfo_item is read at startup.
--
-- WHY THIS EXISTS: THE BACKPACK ITSELF CANNOT BE RESIZED
--   The 16-slot backpack is not an item_template row, so there is no field to change. It
--   is a fixed block of player update fields, and the bank begins immediately after it
--   with no gap (UpdateFields.h:202-208):
--
--       PLAYER_FIELD_INV_SLOT_HEAD,   // Size:46          <- 19 equipment + 4 bag slots
--       PLAYER_FIELD_PACK_SLOT_1,     // Size:2 Count:16  <- the backpack
--       PLAYER_FIELD_BANK_SLOT_1,     // Size:48
--
--   The slot indices agree (Player.h:619-625):
--       INVENTORY_SLOT_ITEM_START = 23, INVENTORY_SLOT_ITEM_END = 39,
--       BANK_SLOT_ITEM_START      = 39
--
--   Growing the backpack past 16 would run straight into the bank's fields, and the client
--   reads these at fixed offsets - it would interpret backpack slot 17 as bank slot 1.
--   This is a structural limit like the 20-slot quest log, NOT a data limit.
--
--   Contrast with bags, which CAN be resized: each bag is its own container object with
--   its own 36-slot field block, and container_slots is data the client learns from the
--   item query. That is why tuning-bag-sizes.sql worked and this cannot.
--
--   Net capacity: 16 backpack + 4 x 36 = 160 slots, up from 16 + 4 x 16 = 80 typical.
--
-- WHY THE BAGS ARRIVE EQUIPPED
--   Player::StoreNewItemInBestSlots tries equipping before storing, one item per pass:
--       while (amount > 0) { CanEquipNewItem(NULL_SLOT, eDest, itemId, false); ... --amount; }
--   For a bag, CanEquipNewItem resolves NULL_SLOT to a free bag slot, so amount = 4 fills
--   all four bag slots rather than dropping four bags into the backpack.
--
--   The stack shortcut inside that loop is skipped because bags have stackable = 1:
--       if ((amount > 1) && (amount <= pItem->GetProto()->GetMaxStackSize()))
--   4 <= 1 is false, so it keeps looping and creates four distinct bags. Verified that
--   tuning-stacks-and-binding.sql left every container at stackable = 1 (it only touched
--   rows with stackable > 1), so this holds.
--
-- WHY ITEM 50003
--   Loremaster's Backpack: 36 slots, common quality, bonding = 0, bag_family = 0 (holds
--   anything), display_id 6430, flags = 0, extra_flags = 0.
--
--   NOT item 1977 "20-slot Bag", which is also 36 slots after the doubling but is a
--   deprecated test item: flags = 16 is ITEM_FLAG_DEPRECATED ("appears red icon, like
--   when item durability == 0") and extra_flags = 4 is ITEM_EXTRA_NOT_OBTAINABLE.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- Clear any earlier attempt so the amount is authoritative rather than accumulating.
DELETE FROM playercreateinfo_item WHERE itemid = 50003;

INSERT IGNORE INTO playercreateinfo_item (race, class, itemid, amount)
SELECT pci.race, pci.class, 50003, 4
FROM playercreateinfo pci;

SELECT COUNT(*) AS combos_granted, SUM(amount) AS bags_total
FROM playercreateinfo_item WHERE itemid = 50003;

-- ---------------------------------------------------------------------------------------
-- EXISTING CHARACTERS
--   Nothing here touches them. Grant yourself the same in-game:
--       .additem 50003 4
--   then drag each bag into a bag slot. `additem` is already in your tester_commands
--   permission, so no RBAC change is needed.
--
-- A COSMETIC WART FROM THE DOUBLING
--   Bag names now understate capacity across the board - "Small Brown Pouch" holds 12,
--   and item 1977 "20-slot Bag" holds 36. Only the names are wrong; the capacity the
--   client enforces comes from container_slots in the item query. Left alone rather than
--   mass-renaming, which would fight any future world re-import.
-- ---------------------------------------------------------------------------------------
