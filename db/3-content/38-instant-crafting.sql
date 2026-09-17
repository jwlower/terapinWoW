-- ---------------------------------------------------------------------------------------
-- Instant crafting: the "casting..." bar under Create is now 0ms for every recipe.
--
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq -
-- the client has its own copy of castingTimeIndex and both sides must agree or the client
-- shows one duration while the server enforces another.
-- ---------------------------------------------------------------------------------------
--
-- WHAT CHANGES AND WHAT DOES NOT
--   castingTimeIndex is an INDEX into SpellCastTimes.dbc, not milliseconds. id=1 is the row
--   every already-instant spell in the game uses: base=0, perLevel=0, minimum=0. That is the
--   entire trick - the same field the client's "casting..." progress bar times.
--
--   NOTHING ELSE MOVES. Category, RecoveryTime and categoryRecoveryTime are untouched:
--     - 2698 of 2727 craft spells already have Category 0 (no shared/global cooldown).
--     - The 28 that carry a real cooldown are exactly the ones batch_crafting.lua refuses
--       to batch - Transmute: Arcanite (48h), the Salt Shaker (72h). The cooldown IS the
--       recipe; this removes the few seconds of "casting...", not the 48 hours after it.
--     - Category 31/310 on conjures and transmutes are per-family throttles, unrelated to
--       cast time, and are left exactly as they are.
--
-- ONLY REAL RECIPES: effect1 = 24 (SPELL_EFFECT_CREATE_ITEM) with an item target. This
-- excludes trainer LEARN_SPELL wrappers (effect 36) and enchant-item spells (effect 53) -
-- neither has a crafting cast bar to begin with.
-- ---------------------------------------------------------------------------------------

USE tw_world;

UPDATE spell_template
SET castingTimeIndex = 1
WHERE effect1 = 24
  AND effectItemType1 > 0
  AND entry < 60000
  AND castingTimeIndex <> 1;

SELECT ROW_COUNT() AS changed_this_run;

SELECT COUNT(*) AS total_instant_craft_spells
FROM spell_template
WHERE effect1 = 24 AND effectItemType1 > 0 AND entry < 60000 AND castingTimeIndex = 1;
