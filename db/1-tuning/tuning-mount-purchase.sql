-- ---------------------------------------------------------------------------------------
-- Make tier-1 mounts buyable and usable at level 20, and keep the 150% tier at 60.
--
-- Run against tw_world. IDEMPOTENT. Requires a mangosd RESTART (item_template has no
-- .reload in this core).
--
-- Companion to tuning-riding-tiers.sql. That script got the SPEEDS right but gated the
-- wrong ITEMS - see the correction note below.
--
-- ---------------------------------------------------------------------------------------
-- WHAT TURTLE ACTUALLY DOES WITH MOUNTS (and why the first pass missed)
--
--   Turtle does not use vanilla's "one item casts one mount spell" model. Every real mount
--   item is class 15 subclass 4 and its spellid_1 is the SAME spell for all of them:
--   46499 "Add Mount to Collection", whose effect1 is SPELL_EFFECT_DUMMY (3), handled by
--   the `spell_turtle_mount_collection` script (src/scripts/spells/spells_turtle.cpp:1169).
--
--   The item->summon-spell mapping lives in the `collection_mount` table (itemId, spellId),
--   418 rows. Using the mount casts that spellId, which is where the speed aura lives.
--
--   Consequence for the first pass: joining item_template on the summon spell via
--   spellid_1..3 matched only 15 rows, nearly all "Deprecated ..." leftovers, because real
--   mount items reference 46499 rather than their own summon spell. Those 15 rows got
--   required_level 20 for nothing - harmless (none is sold or obtainable) and left as is.
--
--   The SPEED half of that script was unaffected and is correct: 409 of the 418 collection
--   mounts summon a spell that was retuned (174 from 60% -> 50%, 235 from 100% -> 150%).
--   So this file only fixes item gating; it does not touch spell_effect_mod.
--
-- REPUTATION IS ALREADY A NON-ISSUE
--   Every mount item has required_reputation_faction = 0 and required_reputation_rank = 0.
--   Turtle already removed vanilla's Exalted-with-your-own-faction requirement, so the
--   BUY_ERR_REPUTATION_REQUIRE check in Player::BuyItemFromVendor (Player.cpp:20537) can
--   never fire for these. Nothing to change.
--
-- LEVEL NEVER BLOCKED BUYING IN THE FIRST PLACE
--   BuyItemFromVendor checks reputation, honor rank and money - not required_level. So a
--   level 20 could always BUY a mount; required_level is what stopped them USING it. That
--   is exactly the gate being moved here.
--
-- THE VENDORS ARE ALREADY REACHABLE
--   Tier-1 mounts are sold by the classic racial vendors in or beside the capitals -
--   Veron Amberstill (Kharanos), Milli Featherwhistle (Dun Morogh), Lelanai (Darnassus),
--   Ogunaro Wolfrunner (Orgrimmar), Zjolnir (Durotar), Harb Clawhoof (Thunder Bluff),
--   Zachariah Post (Undercity), Unger Statforth, Zachariah Post, Nadia Geringt.
--   A level 20 can reach their own faction's capital, so no new vendor is needed.
-- ---------------------------------------------------------------------------------------

USE tw_world;

-- ---------------------------------------------------------------------------------------
-- 0. Resolve the real mount items through collection_mount, tagged by their ORIGINAL
--    summon speed (from the snapshot, so this is stable no matter how often it re-runs).
-- ---------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_real_mount;
CREATE TEMPORARY TABLE tmp_real_mount (
  item  MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY,
  speed INT NOT NULL,
  KEY (speed)
) ENGINE=MEMORY;

INSERT IGNORE INTO tmp_real_mount (item, speed)
SELECT cm.itemId, o.speed
FROM collection_mount cm
JOIN tuning_mount_speed_original o ON o.spell = cm.spellId
WHERE o.speed IN (60, 100);

-- ---------------------------------------------------------------------------------------
-- 1. TIER 1 -> level 20.
--    The 60%-group mounts currently gated at level 40 with riding 75. The skill rank is
--    left alone: Apprentice Riding now trains at 20 and grants exactly 75, so the skill
--    gate already lines up with the new level gate.
-- ---------------------------------------------------------------------------------------
UPDATE item_template it
JOIN tmp_real_mount m ON m.item = it.entry AND m.speed = 60
SET it.required_level = 20
WHERE it.required_level = 40
  AND it.required_skill = 762;

-- ---------------------------------------------------------------------------------------
-- 2. TIER 3 STAYS AT 60.
--    17 mounts from the 100% group were gated at level 40 / riding 75. Left alone they
--    would hand a level 40 the full 150% and collapse the middle tier, so they are moved
--    up to the same gate as the rest of the epic group.
--
--    This is a judgement call beyond "make mounts available at 20": without it the ladder
--    you asked for does not hold. To keep them buyable at 40 instead, skip this statement
--    and accept that those particular 17 mounts are 150% from level 40.
-- ---------------------------------------------------------------------------------------
UPDATE item_template it
JOIN tmp_real_mount m ON m.item = it.entry AND m.speed = 100
SET it.required_level = 60, it.required_skill_rank = 150
WHERE it.required_level = 40
  AND it.required_skill = 762;

-- Engineering-only mounts (required_skill 202 rank 300, 950g) are deliberately untouched:
-- they are gated on a profession rather than on the riding ladder.

-- ---------------------------------------------------------------------------------------
-- 3. Report: what a level 20 can now buy and use, and from whom.
-- ---------------------------------------------------------------------------------------
SELECT 'tier-1 mounts usable at level 20' AS what, COUNT(*) AS n
FROM item_template it JOIN tmp_real_mount m ON m.item = it.entry AND m.speed = 60
WHERE it.required_level <= 20 AND it.required_skill = 762
UNION ALL
SELECT 'of those, actually sold by a vendor', COUNT(*)
FROM item_template it JOIN tmp_real_mount m ON m.item = it.entry AND m.speed = 60
WHERE it.required_level <= 20 AND it.required_skill = 762
  AND (EXISTS(SELECT 1 FROM npc_vendor nv WHERE nv.item = it.entry)
    OR EXISTS(SELECT 1 FROM npc_vendor_template nt WHERE nt.item = it.entry))
UNION ALL
SELECT '150% mounts still gated at 60', COUNT(*)
FROM item_template it JOIN tmp_real_mount m ON m.item = it.entry AND m.speed = 100
WHERE it.required_level >= 60
UNION ALL
SELECT '150% mounts reachable below 60 (want 0)', COUNT(*)
FROM item_template it JOIN tmp_real_mount m ON m.item = it.entry AND m.speed = 100
WHERE it.required_level < 60 AND it.required_skill = 762;

-- Price check: what the cheapest usable tier-1 mount costs per vendor.
SELECT ct.name AS vendor, ct.entry,
       MIN(ROUND(it.buy_price/10000)) AS cheapest_gold,
       COUNT(DISTINCT it.entry) AS tier1_mounts
FROM npc_vendor nv
JOIN tmp_real_mount m ON m.item = nv.item AND m.speed = 60
JOIN item_template it ON it.entry = nv.item AND it.required_level <= 20
JOIN creature_template ct ON ct.entry = nv.entry
GROUP BY ct.entry, ct.name
ORDER BY tier1_mounts DESC, ct.name;

-- ---------------------------------------------------------------------------------------
-- TO REVERT
--   UPDATE item_template it JOIN collection_mount cm ON cm.itemId=it.entry
--     JOIN tuning_mount_speed_original o ON o.spell=cm.spellId AND o.speed=60
--     SET it.required_level = 40 WHERE it.required_level = 20 AND it.required_skill = 762;
--   UPDATE item_template it JOIN collection_mount cm ON cm.itemId=it.entry
--     JOIN tuning_mount_speed_original o ON o.spell=cm.spellId AND o.speed=100
--     SET it.required_level = 40, it.required_skill_rank = 75
--     WHERE it.required_level = 60 AND it.required_skill = 762;
--   (The second one over-reverts: it cannot tell the 17 items it moved from the 71 that
--   were always at 60. Only run it if you want the whole epic group buyable at 40.)
-- ---------------------------------------------------------------------------------------
