-- ---------------------------------------------------------------------------------------
-- 999 stacks on everything stackable, and no soulbinding.
--
-- Run against tw_world. IDEMPOTENT: absolute targets, so re-running changes nothing.
-- Re-apply after any world re-import. Requires a mangosd RESTART - there is no
-- `.reload item_template` in this core (only item_enchantment_template and
-- item_loot_template are reloadable).
--
-- WHY THIS WORKS WITHOUT TOUCHING THE CLIENT
--   The client does not carry its own stack limits or binding rules. It learns both from
--   the server's item query response. Same mechanism that let the earlier 99-stack change
--   work on an unmodified client.
--
-- EXISTING ITEMS
--   Stacks already in bags keep their current size until they merge with a new pickup.
--   Binding is re-read per item, so already-bound gear becomes tradeable immediately.
-- ---------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------
-- 1. STACK SIZE -> 999
--    Only touches things that already stack. stackable = 1 is equipment and uniques; making
--    those stack would let you pile up weapons and armour, so they are left alone.
-- ---------------------------------------------------------------------------------------
UPDATE item_template
SET stackable = 999
WHERE stackable > 1
  AND stackable <> 999;

-- ---------------------------------------------------------------------------------------
-- 2. REMOVE SOULBINDING
--    bonding: 0 = none, 1 = Bind on Pickup, 2 = Bind on Equip, 3 = Bind on Use,
--             4 = quest item, 5/6 = further special cases.
--
--    1, 2 and 3 are the three that actually bind gear to a character - those become 0.
--
--    4 (quest item) is DELIBERATELY LEFT ALONE. It is not really "soulbound" in the sense
--    you mean; it is the flag that marks an item as quest-related, and clearing it can
--    confuse quest item handling and turn-ins. Same reasoning for 5 and 6, which are rare
--    special cases rather than ordinary gear binding.
-- ---------------------------------------------------------------------------------------
UPDATE item_template
SET bonding = 0
WHERE bonding IN (1, 2, 3);
