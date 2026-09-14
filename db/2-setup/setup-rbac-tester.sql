-- ---------------------------------------------------------------------------------------
-- RBAC: let a NORMAL (rank 0) account use selected GM commands.
--
-- Run against tw_logon. Idempotent - uses REPLACE, so re-running is safe.
--
-- Why this instead of just raising account.rank: a rank-3 account is a gamemaster. It is
-- hidden from /who (GM.InWhoList.Level = 3), appears in the GM list, and with
-- GM.LoginState = 1 it logs in with GM mode already active. An RBAC-granted rank-0 account
-- is an ordinary player in every visible respect, that happens to be allowed to run the
-- commands listed below.
--
-- How the core resolves it (src/game/Chat/Chat.cpp:1196):
--     if (GetAccessLevel() >= cmd.SecurityLevel)  -> allowed, unless BANNED by rbac
--     else                                        -> allowed only if GRANTED by rbac
-- So a grant lifts a specific command above the account's rank. A ban (granted = 0) does
-- the reverse: it removes a command from an account that would otherwise have it.
--
-- IMPORTANT: RBAC is loaded ONCE at startup (World.cpp:2432 calls LoadRbacPermissions).
-- There is no .reload for it - restart mangosd after changing these tables.
-- ---------------------------------------------------------------------------------------

-- 1. Define the permission bit. Ids are stored in a uint32 bitmask, so 0-31 ONLY;
--    the core logs "RBAC permission ids ... cannot exceed id 31" and skips anything higher.
REPLACE INTO rbac_permissions (id, name) VALUES (1, 'tester_commands');

-- 2. Tag the commands this permission unlocks. Each row is matched against the real command
--    table, so the name must be a command that actually exists - the core logs an error and
--    skips unknown ones. Tagging a PARENT command (e.g. 'learn') covers its subcommands.
--    Verified present in this build, with their normal required level:
--      learn     SEC_DEVELOPER     (.learn 2020, .learn all_trainer, .learn all_recipes ...)
--      unlearn   SEC_DEVELOPER
--      setskill  SEC_DEVELOPER
--      modify    SEC_DEVELOPER     (.modify money, .modify speed ...)
--      revive    SEC_DEVELOPER
--      gm        SEC_OBSERVER      (so the account can still toggle .gm on when it wants to)
--      tele      SEC_OBSERVER
--      gps       SEC_OBSERVER
--
-- CRITICAL: tagging a PARENT command does NOT cover its subcommands. Chat.cpp:1616 calls
-- isAvailable() on the RESOLVED LEAF command, and each leaf carries its own SecurityLevel
-- and its own PermissionMask. Granting 'learn' therefore only unlocks the bare
-- `.learn <spellid>` form - `.learn all_trainer` stays denied until 'learn all_trainer'
-- is tagged in its own right. Always list the FULL command path.
REPLACE INTO rbac_command_permissions (command, permission_id) VALUES
    ('learn',                1),   -- .learn <spellid>
    ('learn all_trainer',    1),   -- every non-class trainer: ALL professions + weapon skills + mounts
    ('learn all_myspells',   1),   -- every spell for your class
    ('learn all_recipes',    1),   -- .learn all_recipes <profession> - all recipes + maxes the skill
    ('learn all_items',      1),
    ('unlearn',              1),
    ('setskill',             1),
    ('modify',               1),
    ('revive',               1),
    ('gm',                   1),
    ('tele',                 1),
    ('gps',                  1),
    ('levelup',              1),
    ('maxskill',             1),
    ('additem',              1),
    ('lookup',               1),   -- parent; add 'lookup item' etc. if subcommands are needed
    ('lookup item',          1),
    ('lookup spell',         1),
    ('lookup skill',         1);

-- 3. Grant it to an account. granted = 1 grants, granted = 0 explicitly BANS.
--    Change the account id. 508 = KILLERKANADIAN; look ids up with:
--      SELECT id, username FROM account WHERE username NOT LIKE 'RNDBOT%';
REPLACE INTO rbac_account_permissions (account_id, permission_id, granted) VALUES
    (5000508, 1, 1);

-- To add more commands later: insert another rbac_command_permissions row with
-- permission_id 1 and restart. To revoke everything for an account, delete its
-- rbac_account_permissions row (or set granted = 0 to ban rather than merely not grant).
