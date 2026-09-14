-- ---------------------------------------------------------------------------------------
-- Gathering tuning: more herb/ore nodes available, and faster turnover.
--
-- Run against tw_world. Fully IDEMPOTENT: every statement sets an absolute target computed
-- from the data, never a relative multiplier, so running it twice changes nothing the second
-- time. Run it as often as you like.
--
-- Re-apply this AFTER any re-run of compile-tortoise-wow.ps1, because the world import in
-- that script re-creates these tables from sql\base and will wipe these edits.
--
-- Backups of the affected rows are written by the wrapper that ran this; to undo, restore
-- from those, or re-import sql\base and re-run the migrations.
--
-- Requires a mangosd restart: pool_template and gameobject spawn data are read at startup.
-- ---------------------------------------------------------------------------------------

-- Collect the gameobject_template entries that are gathering nodes.
-- type = 3 is GAMEOBJECT_TYPE_CHEST, which is what vanilla uses for herbs and veins.
-- This fork keeps lock/skill data in Lock.dbc rather than a lock_template table, so the
-- nodes cannot be identified by a SQL join on required skill - match on name instead.
DROP TEMPORARY TABLE IF EXISTS tmp_node_entries;
CREATE TEMPORARY TABLE tmp_node_entries (entry INT UNSIGNED PRIMARY KEY);

INSERT INTO tmp_node_entries (entry)
SELECT entry FROM gameobject_template
WHERE type = 3
  AND (
        name LIKE '%Vein%'
     OR name LIKE '%Deposit%'
     OR name IN (
          'Peacebloom','Silverleaf','Earthroot','Mageroyal','Briarthorn','Bruiseweed',
          'Wild Steelbloom','Grave Moss','Kingsblood','Liferoot','Fadeleaf','Goldthorn',
          "Khadgar's Whisker",'Wintersbite','Firebloom','Purple Lotus',"Arthas' Tears",
          'Sungrass','Blindweed','Ghost Mushroom','Gromsblood','Golden Sansam','Dreamfoil',
          'Mountain Silversage','Plaguebloom','Icecap','Black Lotus','Sorrowmoss'
        )
  );

-- ---------------------------------------------------------------------------------------
-- 1. MORE NODES AT ONCE. This is the lever that actually increases how many nodes exist.
--
-- Most node spawns belong to a spawn pool, and the pool's max_limit caps how many of its
-- member spawn points are active simultaneously - 666 node pools ship with max_limit = 1,
-- so 1 node out of every pool regardless of respawn speed.
--
-- Target HALF of each pool's spawn points active at once, floor of 2, and never more than
-- the pool actually has: mangos logs an error and ignores a pool whose max_limit exceeds its
-- member count. Half is a deliberate choice - it roughly doubles vanilla density while
-- leaving spare spawn points so nodes still move around instead of being fixed furniture.
--
-- This is an ABSOLUTE target derived from member count, not "multiply what is there", which
-- is what makes the file safe to re-run. Adjust the 0.5 to taste: 1.0 lights up every spawn
-- point simultaneously (maximum nodes, zero variety in placement).
-- ---------------------------------------------------------------------------------------
UPDATE pool_template pt
JOIN (
    SELECT pg.pool_entry, COUNT(*) AS members
    FROM pool_gameobject pg
    JOIN gameobject g ON g.guid = pg.guid
    WHERE g.id IN (SELECT entry FROM tmp_node_entries)
    GROUP BY pg.pool_entry
) m ON m.pool_entry = pt.entry
SET pt.max_limit = LEAST(m.members, GREATEST(2, ROUND(m.members * 0.5)));

-- ---------------------------------------------------------------------------------------
-- 2. FASTER TURNOVER. Respawn is randomised between spawntimesecsmin and spawntimesecsmax,
-- and the shipped data has maxes of 604800 (7 days) and even 99999999 on some veins, which
-- is why a gathered node can feel like it never returns. Floor the min at 60s and cap the
-- max at 900s (15 min) so the random range stays sane.
-- ---------------------------------------------------------------------------------------
UPDATE gameobject g
SET g.spawntimesecsmin = GREATEST(60, LEAST(g.spawntimesecsmin, 300)),
    g.spawntimesecsmax = GREATEST(120, LEAST(g.spawntimesecsmax, 900))
WHERE g.id IN (SELECT entry FROM tmp_node_entries);

DROP TEMPORARY TABLE IF EXISTS tmp_node_entries;
