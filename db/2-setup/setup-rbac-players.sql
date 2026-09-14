-- ---------------------------------------------------------------------------------------
-- Give EVERY player a free, anywhere, self-service talent reset.
--
-- Run against tw_logon. Idempotent (REPLACE / INSERT IGNORE), safe to re-run - and you
-- SHOULD re-run it after creating accounts for new friends, because RBAC grants are
-- per-account-id and there is no wildcard.
--
-- Requires a mangosd RESTART: RBAC is loaded once at startup (World.cpp calls
-- ChatHandler::LoadRbacPermissions), and there is no reload command for it.
--
-- WHY A SECOND PERMISSION ID
--   Permission 1 ('tester_commands') carries the full admin set - additem, levelup, tele,
--   modify, npc, gobject. That is fine for your own account and wrong for guests.
--   Permission 2 is deliberately minimal: exactly the commands a normal player should be
--   able to run on themselves, nothing else.
--
-- WHY NOT AN ITEM OR A CUSTOM SPELL
--   There is no SPELL_EFFECT that resets talents in this core, so no item can do it. And a
--   genuinely custom spell would need a new Spell.dbc row, which every client would have to
--   have patched in. A macro containing a chat command needs neither.
--
-- HOW THE PLAYER USES IT
--   One macro, any name, body:  .reset talents
--   Clicking it wipes their talents free of charge, anywhere in the world, no trainer.
--   HandleResetTalentsCommand with no argument targets the caller and passes
--   no_cost = true, so it never charges and never scales in price.
-- ---------------------------------------------------------------------------------------

-- 1. The permission bit. Ids are a uint32 bitmask, so 0-31 only.
REPLACE INTO rbac_permissions (id, name) VALUES (2, 'player_selfservice');

-- 2. The commands it unlocks. FULL command paths - tagging a parent does NOT cover its
--    subcommands, because Chat.cpp:1616 checks isAvailable() on the resolved leaf, and each
--    leaf carries its own PermissionMask.
REPLACE INTO rbac_command_permissions (command, permission_id) VALUES
    ('reset',         2),   -- the parent, harmless: it has no handler of its own
    ('reset talents', 2);   -- the leaf that actually does the work

-- 3. Grant it to every real account (bot filler accounts excluded).
INSERT IGNORE INTO rbac_account_permissions (account_id, permission_id, granted)
SELECT a.id, 2, 1
FROM account a
WHERE a.username NOT LIKE 'RNDBOT%';
