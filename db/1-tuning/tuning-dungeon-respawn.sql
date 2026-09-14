-- ---------------------------------------------------------------------------------------
-- Make dungeon bosses respawn, and stop every boss kill stamping a 7-day instance lockout.
--
-- Run against tw_world. IDEMPOTENT (snapshots originals, always computes from them).
-- Requires a mangosd RESTART - creature spawn data is read at startup.
--
-- ---------------------------------------------------------------------------------------
-- THE MECHANISM: THE LOCKOUT IS DERIVED FROM THE RESPAWN TIME
--
--   These are not two separate problems. When you kill something in a dungeon,
--   Unit.cpp:1552 runs:
--
--       pCreatureVictim->GetMap()->BindToInstanceOrRaid(
--           playerKiller, pCreatureVictim->GetRespawnTimeEx(), ...);
--
--   and Map::BindToInstanceOrRaid (Map.cpp:3529) does:
--
--       time_t resettime = objectResetTime + 2 * HOUR;
--       if (save->GetResetTime() < resettime)
--           save->SetResetTime(resettime);
--
--   GetRespawnTimeEx() is the ABSOLUTE time that creature will return. So killing a boss
--   whose respawn is 604800s (7 days) sets the instance to reset in 7 days + 2 hours.
--   Measured against the live data: Stockades instance 100 was stamped 2026-09-15 14:15,
--   which is 6.74 days out - exactly 7d+2h from the kill.
--
--   So the "2 hours" is a buffer added on top, never the total. Waiting 2 hours does
--   nothing while a 7-day respawn is feeding it.
--
--   Note `if (save->GetResetTime() < resettime)` - the lockout only ever EXTENDS. Once a
--   7-day stamp is on an instance it cannot shrink, which is why this file cannot rescue an
--   already-bound instance. See "EXISTING INSTANCES" below.
--
-- WHY 30 MINUTES, AND WHY ONLY THE LONG TIMERS
--   Threshold is 1 day: anything at or above it drops to 1800s. That catches the boss-scale
--   timers (7-day and 1-day) and deliberately leaves dungeon trash alone, which sits at
--   18000s (5 hours) - the value that stops trash repopulating behind you mid-clear.
--
--   Consequences of 1800s on bosses:
--     - Inside a live instance, a boss is back 30 minutes after it dies. Because you stay
--       bound to the same instance, this is what actually lets you re-farm; you do not need
--       a fresh instance at all.
--     - A boss kill now stamps a 2.5-hour lockout instead of 7 days.
--     - Trash still drives a ~7-hour lockout (18000 + 2h), but that no longer matters,
--       since returning to the same bound instance now finds the bosses alive.
--
-- SCOPE
--   map NOT IN (0, 1) - instances and battlegrounds only. This deliberately spares the
--   outdoor world bosses (Azuregos, Lord Kazzak), which live on maps 0 and 1 and are
--   supposed to have multi-day timers.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 1. Snapshot the originals once, so this stays re-runnable and revertible.
--    Keyed by guid - the individual spawn - not by creature entry, because the same
--    creature can be spawned with different timers in different places.
-- ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tuning_dungeon_respawn_original (
  guid             INT UNSIGNED NOT NULL PRIMARY KEY,
  spawntimesecsmin INT UNSIGNED NOT NULL,
  spawntimesecsmax INT UNSIGNED NOT NULL
) ENGINE=InnoDB COMMENT='Pre-tuning dungeon respawn times. Used by tuning-dungeon-respawn.sql.';

INSERT IGNORE INTO tuning_dungeon_respawn_original (guid, spawntimesecsmin, spawntimesecsmax)
SELECT guid, spawntimesecsmin, spawntimesecsmax
FROM creature
WHERE map NOT IN (0, 1)
  AND (spawntimesecsmin >= 86400 OR spawntimesecsmax >= 86400);

-- ---------------------------------------------------------------------------------------
-- 2. Apply. Selected from the SNAPSHOT, never from current values, so re-running is inert.
-- ---------------------------------------------------------------------------------------
UPDATE creature c
JOIN tuning_dungeon_respawn_original o ON o.guid = c.guid
SET c.spawntimesecsmin = 1800,
    c.spawntimesecsmax = 1800
WHERE c.spawntimesecsmin <> 1800 OR c.spawntimesecsmax <> 1800;

-- ---------------------------------------------------------------------------------------
-- 3. Report.
-- ---------------------------------------------------------------------------------------
SELECT 'spawns retimed to 30 min' AS what, COUNT(*) AS n FROM tuning_dungeon_respawn_original
UNION ALL
SELECT 'of those, elite or boss rank', COUNT(*) FROM tuning_dungeon_respawn_original o
  JOIN creature c ON c.guid = o.guid JOIN creature_template ct ON ct.entry = c.id WHERE ct.rank > 0
UNION ALL
SELECT 'any long timers left on instance maps (want 0)', COUNT(*) FROM creature
  WHERE map NOT IN (0,1) AND (spawntimesecsmin >= 86400 OR spawntimesecsmax >= 86400)
UNION ALL
SELECT 'world bosses on maps 0/1 left alone', COUNT(*) FROM creature
  WHERE map IN (0,1) AND spawntimesecsmax >= 86400;

-- Stockades bosses, as a spot check.
SELECT ct.name, c.spawntimesecsmin AS respawn_secs, ct.rank
FROM creature c JOIN creature_template ct ON ct.entry = c.id
WHERE c.map = 34 AND ct.rank > 0 AND ct.name NOT LIKE 'Defias%'
ORDER BY ct.name;

-- ---------------------------------------------------------------------------------------
-- EXISTING INSTANCES ARE NOT FIXED BY THIS
--   Two reasons, both needing a one-off action from you:
--
--   1. An instance's reset stamp only ever extends (the `<` check above), so instance 100
--      keeps its 2026-09-15 date regardless of this change.
--   2. Respawns already queued are absolute timestamps in character_respawn tables. There
--      were 32 rows for instance 100, the latest stamped 2026-09-15, and lowering the
--      template does not reschedule them.
--
--   Clear both by unbinding once, in game:
--       .instance unbind all
--   Then re-enter for a fresh instance that picks up the new timers. Every instance made
--   after this change behaves correctly without further intervention.
--
-- TO REVERT
--   UPDATE creature c JOIN tuning_dungeon_respawn_original o ON o.guid = c.guid
--   SET c.spawntimesecsmin = o.spawntimesecsmin, c.spawntimesecsmax = o.spawntimesecsmax;
-- ---------------------------------------------------------------------------------------
