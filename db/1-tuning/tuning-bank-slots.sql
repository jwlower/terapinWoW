-- ---------------------------------------------------------------------------------------
-- Open all 6 bank bag slots on every character.
--
-- Run against tw_char. IDEMPOTENT (absolute target). Offline characters only.
-- Takes effect on next login; no restart needed for this half.
--
-- WHAT IS AND IS NOT LOCKED
--   The bank has 24 ITEM slots that are free from the start (BANK_SLOT_ITEM_START 39 ..
--   BANK_SLOT_ITEM_END 63, Player.h:625). Only the 6 BAG slots are bought
--   (BANK_SLOT_BAG_START 63 .. BANK_SLOT_BAG_END 69). Six is the hard maximum - it is a
--   fixed player-field range, exactly like the 16-slot backpack, so there is no way to
--   have more than 6 regardless of what we do here.
--
-- WHERE THE COUNT LIVES
--   Player.h:1330-1331:
--       uint8 GetBankBagSlotCount() const { return GetByteValue(PLAYER_BYTES_2, 2); }
--       void SetBankBagSlotCount(uint8 count) { SetByteValue(PLAYER_BYTES_2, 2, count); }
--
--   Byte offset 2 of a little-endian uint32 is bits 16-23, and `characters.playerBytes2`
--   is a real column rather than part of a blob, so it can be set directly. Verified
--   against live data before writing: Gigachad read back as 3, matching the slots bought.
--
-- ONLINE CHARACTERS ARE SKIPPED
--   Their field lives in memory and is written back over this on logout.
-- ---------------------------------------------------------------------------------------

USE tw_char;

UPDATE characters
SET playerBytes2 = (playerBytes2 & 0xFF00FFFF) | (6 << 16)
WHERE online = 0
  AND ((playerBytes2 >> 16) & 0xFF) <> 6;

SELECT (playerBytes2 >> 16) & 0xFF AS bank_bag_slots, COUNT(*) AS chars_, SUM(online) AS online_
FROM characters GROUP BY bank_bag_slots ORDER BY bank_bag_slots;
