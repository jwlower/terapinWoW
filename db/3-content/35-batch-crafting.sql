-- ---------------------------------------------------------------------------------------
-- Batch crafting: storage for the per-character quantity.
--
-- Run against tw_char. IDEMPOTENT.
-- Needs lua_scripts/batch_crafting.lua and a mangosd RESTART to load it.
-- ---------------------------------------------------------------------------------------
--
-- WHAT IT DOES
--   `!batch 5` and every recipe you cast makes five - one cast, one animation, the whole
--   batch at the end of it. `!batch 1` turns it off, `!batch` reports the setting.
--
--   This is the part vanilla's "Create All" does not do: Create All queues N separate casts
--   and you sit through N animations. Here the first craft runs normally and the remaining
--   N-1 are resolved server-side on the next tick.
--
-- WHY A TABLE AT ALL
--   The quantity is held in memory while you are online. Without this it would reset on every
--   logout, and a setting you have to re-enter each session is a setting you stop using. One
--   row per character, written only when the command is used.
--
-- NO CLIENT WORK, DELIBERATELY
--   The quantity box in the trade skill window belongs to Blizzard_TradeSkillUI. Driving it
--   would mean an addon hooking the craft button, and the last addon in this project that
--   hooked a protected client control disabled camera panning for the entire game. A chat
--   command cannot break anything the client already does.
--
-- BATCHING IS NOT A SHORTCUT
--   Every item in the batch rolls for a skill point on the same odds the core uses -
--   Player::SkillGainChance, Player.cpp:6933, reading SkillChance.Orange/Yellow/Green/Grey
--   from mangosd.conf. The script mirrors those values; if the config changes, the constants
--   at the top of batch_crafting.lua must change with it.
-- ---------------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS tw_char.terapin_batch (
  player_guid INT UNSIGNED NOT NULL,
  qty         TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (player_guid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

SELECT 'terapin_batch' AS table_, COUNT(*) AS rows_ FROM tw_char.terapin_batch;
