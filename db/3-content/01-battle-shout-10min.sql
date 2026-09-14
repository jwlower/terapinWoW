-- ---------------------------------------------------------------------------------------
-- Battle Shout lasts 10 minutes instead of 2.
--
-- Run against tw_world. IDEMPOTENT. Requires a mangosd RESTART (spell_mod loads at start,
-- or use `.reload spell_mod` once that command is granted).
--
-- HOW, WITHOUT TOUCHING ANY DBC
--   A spell's duration is not stored on the spell - it is an INDEX into SpellDuration.dbc.
--   Battle Shout's ranks use DurationIndex 4, which is 120000 ms:
--       ID=4  base=120000  ->  2.0 min
--
--   SpellDuration.dbc already contains a 10 minute entry:
--       ID=6  base=600000  ->  10.0 min
--
--   So no new duration is needed. `spell_mod` has a DurationIndex column, and SpellModMgr
--   patches the in-memory SpellEntry after the DBC load, so repointing rank ranks at
--   index 6 is a pure SQL change. No client patch, no new DBC rows.
--
-- WHICH ROWS
--   Only the ranks that actually apply the buff - the ones with DurationIndex 4 and
--   effect 6 (APPLY_AURA). The DurationIndex 0 rows named "Battle Shout" are effect 36
--   (LEARN_SPELL), i.e. the trainer entries, and have no duration to change.
--   24438 / 25101 / 26043 / 26099 are NPC and event variants and are left alone.
--
-- THE TOOLTIP WILL STILL SAY 2 MINUTES
--   The client reads duration from its own SpellDuration.dbc for display. The actual aura
--   length is server-side, so the buff really will last 10 minutes - only the tooltip text
--   is stale. Same situation as the retuned mount speeds.
-- ---------------------------------------------------------------------------------------

USE tw_world;

INSERT INTO spell_mod (Id, DurationIndex, Comment)
SELECT entry, 6, 'Battle Shout 2min -> 10min (TurtleMod 01)'
FROM spell_template
WHERE name = 'Battle Shout'
  AND DurationIndex = 4
  AND effect1 = 6
ON DUPLICATE KEY UPDATE
  DurationIndex = VALUES(DurationIndex), Comment = VALUES(Comment);

SELECT sm.Id, st.name, st.DurationIndex AS was, sm.DurationIndex AS now_,
       'ranks repointed to the existing 10-minute entry' AS note
FROM spell_mod sm JOIN spell_template st ON st.entry = sm.Id
WHERE sm.Comment LIKE '%TurtleMod 01%' ORDER BY sm.Id;

-- ---------------------------------------------------------------------------------------
-- TO REVERT
--   DELETE FROM spell_mod WHERE Comment LIKE '%TurtleMod 01%';
--   Then restart - removing the row does not undo the in-memory patch.
-- ---------------------------------------------------------------------------------------
