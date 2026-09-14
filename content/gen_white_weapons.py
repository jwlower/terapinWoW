"""Generate sql/27-white-weapons.sql from white_weapons.py. Do not edit the SQL by hand.

    python gen_white_weapons.py

Picks a real clone source per (weapon type, item level) out of the live database so damage
and speed sit on the curve the game already uses, then reports any case where the nearest
source was far enough away that the damage had to be scaled.
"""
import os, sys, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import white_weapons as W

HERE = os.path.dirname(os.path.abspath(__file__))
MYSQL = r"D:\Games\turtlewow\tortoise-oneclick-compiler\DB\bin\mysql.exe"
OUT = os.path.join(HERE, "sql", "27-white-weapons.sql")


def q(sql):
    r = subprocess.run([MYSQL, "-h127.0.0.1", "-P3307", "-umangos", "-pmangos", "-N", "-B",
                        "-e", sql], capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("mysql failed: " + r.stderr.strip())
    return [l.split("\t") for l in r.stdout.strip().splitlines() if l.strip()]


rows = W.grid()

# ---------------------------------------------------------------------------------------
# 1. Refuse to ship a name that already exists. A duplicate name is not fatal to the server
#    but it is miserable in game - two different "Bronze Spear" in a trainer list.
# ---------------------------------------------------------------------------------------
names = sorted({r["name"] for r in rows})
quoted = ",".join("'" + n.replace("'", "''") + "'" for n in names)
# Exclude our OWN id range, or a partially-applied previous run makes every name look
# like a clash with itself.
clash = q("SELECT entry, name FROM tw_world.item_template WHERE name IN (%s) AND entry NOT BETWEEN %d AND %d;" % (quoted, W.ITEM_BASE, W.ITEM_BASE + len(rows)))
if clash:
    for e, n in clash:
        print("  NAME CLASH: %s already exists as item %s" % (n, e))
    raise SystemExit("%d name clash(es) - rename them in white_weapons.py" % len(clash))
print("names: %d, none clash with existing items" % len(names))

# ---------------------------------------------------------------------------------------
# 2. Pick a clone source per (subclass, target item level): the real weapon of that type
#    whose item level is closest to the target.
# ---------------------------------------------------------------------------------------
sources = {}
scaled = []
curves = {}
for sub in sorted({r["subclass"] for r in rows}):
    cand = q("SELECT entry, name, item_level, dmg_min1, dmg_max1, delay FROM tw_world.item_template "
             "WHERE class = 2 AND subclass = %d AND Quality BETWEEN 1 AND 2 "
             "AND entry < 60000 AND item_level > 0 AND dmg_max1 > 0 ORDER BY item_level;" % sub)
    if not cand:
        raise SystemExit("no clone source at all for subclass %d" % sub)
    parsed = [(int(e), n, int(il), float(dmin), float(dmax), int(d)) for e, n, il, dmin, dmax, d in cand]
    curves[sub] = [(il, ((dmin + dmax) / 2.0) / (d / 1000.0)) for _, _, il, dmin, dmax, d in parsed if d > 0]
    for r in rows:
        if r["subclass"] != sub:
            continue
        best = min(parsed, key=lambda c: abs(c[2] - r["ilvl"]))
        sources[r["item"]] = best

print("clone sources chosen for %d items" % len(sources))
if scaled:
    print("\n%d item(s) had no close source and will have damage SCALED:" % len(scaled))
    for nm, want, src, got, dps in scaled[:14]:
        print("    %-26s ilvl %-3d  curve dps %5.1f  (nearest real: %s, ilvl %d)"
              % (nm, want, dps, src[:26], got))
    if len(scaled) > 14:
        print("    ... and %d more" % (len(scaled) - 14))



def curve_dps(family, ilvl, two_handed):
    """Average DPS of every real weapon in this FAMILY near this item level.

    Pooled by family rather than by individual weapon type, deliberately. Per-type curves
    left polearms at 3.5 dps where every other two-hander of the same tier was 5.9-6.4,
    because this database has no polearm at all below item level 21 and the per-type lookup
    had to reach a long way to find anything.

    Pooling also matches how vanilla works: weapons of a class do comparable DPS at a given
    level and differ in SPEED, which is preserved separately from the clone source.
    """
    subs = [sc for sc, _, _, _, fam in W.TYPES if fam == family]
    pts = [p for sc in subs for p in curves.get(sc, [])]
    for window in (3, 6, 10, 15):
        near = [d for il, d in pts if abs(il - ilvl) <= window]
        if near:
            return sum(near) / len(near)
    return 1.0 + ilvl * (1.1 if two_handed else 0.75)   # last resort

# ---------------------------------------------------------------------------------------
# 2b. Freeze one DPS value per (family, band) and force the ladder to never go DOWN.
#
# The raw windowed average is noisy where a family is thin - this database has 8 thrown and
# 1 low-level crossbow - which produced a Crossbow that got WEAKER from required level 20 to
# 25. A player will never accept a higher-tier craftable that hits softer, so the curve is
# clamped to non-decreasing per family.
# ---------------------------------------------------------------------------------------
DPS_BY_BAND = {}
for fam in sorted({r["family"] for r in rows}):
    th = next(t for _, _, _, t, f in W.TYPES if f == fam)
    prev = 0.0
    for req, _tier, _bar, _prefix, _skill in W.BANDS:
        ilvl = req + W.ILVL_OFFSET
        d = curve_dps(fam, ilvl, th)
        if d < prev * 1.02:          # never flat or falling: each tier must be a step up
            d = prev * 1.08
        DPS_BY_BAND[(fam, req)] = d
        prev = d

# ---------------------------------------------------------------------------------------
# 3. Emit
# ---------------------------------------------------------------------------------------
L = []
w = L.append
w("""-- ---------------------------------------------------------------------------------------
-- White (common) Blacksmithing weapons - one per weapon type per 5 levels.
--
-- GENERATED by gen_white_weapons.py from white_weapons.py. Do not edit by hand.
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.
-- ---------------------------------------------------------------------------------------
--
-- THE GAP THIS FILLS
--   Measured before writing this: Blacksmithing could make 186 green, 88 blue and 45 epic
--   items, but only 13 WHITE weapons - all below level 25, with nothing at all for polearms,
--   thrown or crossbows. The plain make-it-yourself tier stopped existing almost immediately.
--
--   11 weapon types x 12 level bands = %d items, required level 5 through 60.
--
-- DAMAGE IS CLONED, NOT INVENTED
--   Each item clones the closest REAL weapon of the same subclass and item level, then has
--   its stats stripped and quality forced to white. Damage and speed therefore sit on the
--   curve the game already uses. Same approach shields.py takes for armour and block.
--
--   Where no close source exists - this database has NO polearm below item level 21 - the
--   damage is scaled by the item-level ratio instead. gen_white_weapons.py prints every such
--   case when it runs.
--
-- WHY WHITE MEANS NO STATS
--   That is what separates a white from a green here. stat_type1..5 are zeroed, so these are
--   pure damage-and-speed weapons: cheap, craftable, and a sensible salvage source. They are
--   deliberately NOT competitive with the green craftables in sql/07 and sql/15.
-- ---------------------------------------------------------------------------------------

USE tw_world;
""" % len(rows))

items  = ",".join(str(r["item"]) for r in rows)
crafts = ",".join(str(r["craft"]) for r in rows)
teachs = ",".join(str(r["teach"]) for r in rows)

w("-- Clean slate, so re-running cannot leave a half-updated grid behind.")
w("DELETE FROM item_template        WHERE entry    IN (%s);" % items)
w("DELETE FROM spell_template       WHERE entry    IN (%s);" % crafts)
w("DELETE FROM spell_template       WHERE entry    IN (%s);" % teachs)
w("DELETE FROM skill_line_ability   WHERE spell_id IN (%s);" % crafts)
w("DELETE FROM npc_trainer          WHERE spell    IN (%s);" % teachs)
w("")

for r in rows:
    src_entry, src_name, src_ilvl, dmin, dmax, delay = sources[r["item"]]

    # Damage comes from the real DPS CURVE for this weapon type at this item level, not from
    # scaling one distant weapon. Ratio-scaling was the first attempt and it produced a
    # Copper Halberd at 35 DPS for a level 5 character - it had been scaled x10 off a
    # Farmer's Pitchfork (item level 1), and the ladder was not even monotonic.
    dps = DPS_BY_BAND[(r["family"], r["req"])]
    speed = delay / 1000.0
    nmin = max(1.0, round(dps * speed * 0.8))
    nmax = max(nmin + 1.0, round(dps * speed * 1.2))
    if abs(src_ilvl - r["ilvl"]) > 4:
        scaled.append((r["name"], r["ilvl"], src_name, src_ilvl, dps))

    w("-- %-28s ilvl %-3d req %-3d  <- clone %d (%s)"
      % (r["name"], r["ilvl"], r["req"], src_entry, src_name[:30]))
    w("DROP TEMPORARY TABLE IF EXISTS tmp_w;")
    w("CREATE TEMPORARY TABLE tmp_w LIKE item_template;")
    w("INSERT INTO tmp_w SELECT * FROM item_template WHERE entry = %d;" % src_entry)
    w("UPDATE tmp_w SET")
    w("  entry = %d, name = '%s'," % (r["item"], r["name"].replace("'", "''")))
    w("  Quality = 1, item_level = %d, required_level = %d," % (r["ilvl"], r["req"]))
    w("  dmg_min1 = %.0f, dmg_max1 = %.0f, delay = %d," % (nmin, nmax, delay))
    w("  stat_type1 = 0, stat_value1 = 0, stat_type2 = 0, stat_value2 = 0,")
    w("  stat_type3 = 0, stat_value3 = 0, stat_type4 = 0, stat_value4 = 0,")
    w("  stat_type5 = 0, stat_value5 = 0,")
    w("  random_property = 0, bonding = 0,   -- not soulbound: these are meant to be sold and traded")
    w("  spellid_1 = 0, spellid_2 = 0;       -- no on-use or proc effects on a white")
    w("INSERT INTO item_template SELECT * FROM tmp_w;")
    w("DROP TEMPORARY TABLE tmp_w;")
    w("")

w("-- ---------------------------------------------------------------------------------------")
w("-- The craft spells, their trainer wrappers, and the skill lines.")
w("--")
w("-- A trainer entry cannot point at a craft spell directly - npc_trainer.spell must be a")
w("-- LEARN_SPELL wrapper - so every recipe needs a pair. Cloned from 2754 (a real trainer")
w("-- wrapper), never from a `Plans:` spell, which targets the caster and makes the NPC teach")
w("-- itself. See sql/03 and docs/SPELL-IDS.md.")
w("-- ---------------------------------------------------------------------------------------")
for r in rows:
    w("DROP TEMPORARY TABLE IF EXISTS tmp_c;")
    w("CREATE TEMPORARY TABLE tmp_c LIKE spell_template;")
    w("INSERT INTO tmp_c SELECT * FROM spell_template WHERE entry = 2660;   -- Rough Sharpening Stone (a real BS craft)")
    w("UPDATE tmp_c SET entry = %d, name = '%s', nameSubtext = '',"
      % (r["craft"], r["name"].replace("'", "''")))
    w("  description = 'Forges %s.'," % r["name"].replace("'", "''"))
    w("  effect1 = 24, effectItemType1 = %d," % r["item"])          # CREATE_ITEM
    w("  effect2 = 0, effect3 = 0, effectTriggerSpell1 = 0,")
    w("  reagent1 = %d, reagentCount1 = %d," % (r["bar"], r["bars"]))
    w("  reagent2 = 0, reagentCount2 = 0, reagent3 = 0, reagentCount3 = 0,")
    w("  spellIconId = 1;")
    w("INSERT INTO spell_template SELECT * FROM tmp_c;")
    w("DROP TEMPORARY TABLE tmp_c;")
    w("DROP TEMPORARY TABLE IF EXISTS tmp_t;")
    w("CREATE TEMPORARY TABLE tmp_t LIKE spell_template;")
    w("INSERT INTO tmp_t SELECT * FROM spell_template WHERE entry = 2754;   -- a real trainer wrapper")
    w("UPDATE tmp_t SET entry = %d, name = '%s', nameSubtext = '',"
      % (r["teach"], r["name"].replace("'", "''")))
    w("  description = 'Teaches you how to make %s.'," % r["name"].replace("'", "''"))
    w("  effect1 = 36, effectTriggerSpell1 = %d," % r["craft"])     # LEARN_SPELL
    w("  effect2 = 0, effect3 = 0, effectItemType1 = 0,")
    w("  spellIconId = 1;")
    w("INSERT INTO spell_template SELECT * FROM tmp_t;")
    w("DROP TEMPORARY TABLE tmp_t;")
    w("INSERT INTO skill_line_ability (id, skill_id, spell_id, req_skill_value, max_value, min_value)")
    w("  VALUES (%d, %d, %d, %d, %d, %d);"
      % (r["sla"], W.SKILL_BS, r["craft"], r["skill"],
         min(r["skill"] + 40, 300), min(r["skill"] + 15, 300)))
    w("")

w("-- Every Blacksmithing Master teaches the lot.")
w("INSERT INTO npc_trainer (entry, spell, spellcost, reqskill, reqskillvalue, reqlevel) VALUES")
vals = []
for r in rows:
    vals.append("  (2600300, %d, %d, %d, %d, %d)"
                % (r["teach"], r["req"] * 100, W.SKILL_BS, r["skill"], r["req"]))
w(",\n".join(vals) + ";")
w("")
w("SELECT COUNT(*) AS white_weapons FROM item_template WHERE entry IN (%s);" % items)
w("SELECT COUNT(*) AS craft_spells  FROM spell_template WHERE entry IN (%s);" % crafts)
w("SELECT COUNT(*) AS trainer_rows  FROM npc_trainer WHERE spell IN (%s);" % teachs)

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(L) + "\n")
print("\nwrote %s (%d items, %d spells)" % (OUT, len(rows), len(rows) * 2))
