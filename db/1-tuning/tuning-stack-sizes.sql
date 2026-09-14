-- ---------------------------------------------------------------------------------------
-- Raise every stackable item to a 99 stack.
--
-- Run against tw_world. IDEMPOTENT: the WHERE clause stops matching once applied, so
-- re-running changes nothing.
--
-- Re-apply after any re-run of compile-tortoise-wow.ps1 (the world import rebuilds
-- item_template). There is NO `.reload item_template` command in this core - only
-- item_enchantment_template and item_loot_template are reloadable - so a mangosd RESTART
-- is required for this to take effect.
--
-- Why this works client-side: the client does not carry its own stack limit. It learns an
-- item's max stack from the server's item query response, so a server-side change is
-- enough - no client patching, no DBC edit, no desync.
--
-- SCOPE (measured on this database before applying):
--   23,433 items have stackable = 1  -> equipment and uniques, DELIBERATELY UNTOUCHED.
--                                       Raising these would let you stack weapons/armour.
--    2,911 items have stackable 2..98 -> raised to 99. Trade goods, herbs, ore, cloth,
--                                       potions, food, reagents, quest items.
--      199 items have stackable >= 99 -> LEFT ALONE. Ammo sits at 200/250 and some items
--                                       at 100; this never REDUCES a stack size.
-- ---------------------------------------------------------------------------------------

UPDATE item_template
SET stackable = 99
WHERE stackable > 1
  AND stackable < 99;
