"""Generate sql/33-craftable-gear.sql from gear.py. Do not edit the SQL by hand.

    python gen_gear.py

Picks a real clone source per (armour type, slot, item level) out of the live database so
ARMOUR values sit on the curve the game already uses, then overrides quality, level, stats and
name. Refuses to run if a name clashes with an existing item.
"""
import os, sys, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gear as G

HERE = os.path.dirname(os.path.abspath(__file__))
MYSQL = r"D:\Games\turtlewow\tortoise-oneclick-compiler\DB\bin\mysql.exe"
OUT = os.path.join(HERE, "sql", "33-craftable-gear.sql")

# Which NPC teaches which profession's recipes.
MASTER = {G.SKILL_BS: 2600300, G.SKILL_LW: 2600301, G.SKILL_TAILOR: 2600303}


def q(sql):
    r = subprocess.run([MYSQL, "-h127.0.0.1", "-P3307", "-umangos", "-pmangos", "-N", "-B",
                        "-e", sql], capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("mysql failed: " + r.stderr.strip())
    return [l.split("\t") for l in r.stdout.strip().splitlines() if l.strip()]


rows = G.grid()
print("items to generate: %d" % len(rows))

# ---------------------------------------------------------------------------------------
# 1. No duplicate names.
# ---------------------------------------------------------------------------------------
names = sorted({r["name"] for r in rows})
quoted = ",".join("'" + n.replace("'", "''") + "'" for n in names)
clash = q("SELECT entry, name FROM tw_world.item_template WHERE name IN (%s) "
          "AND entry NOT BETWEEN %d AND %d;" % (quoted, G.ITEM_BASE, G.ITEM_BASE + len(rows)))
if clash:
    for e, n in clash[:10]:
        print("  NAME CLASH: %s already exists as item %s" % (n, e))
    raise SystemExit("%d name clash(es) - rename a flavour or slot in gear.py" % len(clash))
print("names: %d distinct, none clash" % len(names))

# ---------------------------------------------------------------------------------------
# 2. Clone sources, for armour value and model.
# ---------------------------------------------------------------------------------------
# THE CLONE PICKS THE MODEL. THE ARMOUR VALUE IS MEASURED SEPARATELY, and the two are not the
# same job.
#
#   Picking the single nearest item by item level and taking whatever armour it happened to
#   carry is a lottery among ties. It put a mail chest at ilvl 56 on 433 armour where its real
#   peers average 320, and a cloth helm at ilvl 71 on 141 against a real 107 - 35% out, in both
#   directions, purely on which row the sort happened to land on. `Deprecated` rows were
#   eligible too, and they sit on an older, lower curve.
#
#   So armour is now the MEDIAN of every real peer of the same type and slot within a window
#   around the target item level. A median ignores the one weird quest reward that a mean or a
#   nearest-neighbour pick would swallow whole. The window starts tight and widens only when
#   there is genuinely nothing nearby - mail and leather helms have no on-curve peer at all
#   near item level 22, which is exactly the hole in the low bands this grid exists to fill.
ARMOUR_WINDOW_START = 5
ARMOUR_WINDOW_MAX   = 30
ARMOUR_MIN_PEERS    = 3


def median(xs):
    xs = sorted(xs)
    n = len(xs)
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) // 2


sources, far, armour_of, widened = {}, [], {}, []
cache = {}
for r in rows:
    key = (r["subclass"], r["inv"])
    if key not in cache:
        cache[key] = [(int(e), n, int(il), int(a)) for e, n, il, a in
                      q("SELECT entry, name, item_level, armor FROM tw_world.item_template "
                        "WHERE class = 4 AND subclass = %d AND inventory_type = %d "
                        "AND entry < 60000 AND item_level > 0 AND armor > 0 "
                        "AND Quality > 0 AND name NOT LIKE 'Deprecated%%' "
                        "ORDER BY item_level;" % (r["subclass"], r["inv"]))]
    cand = cache[key]
    if not cand:
        raise SystemExit("no clone source for subclass %d slot %d" % (r["subclass"], r["inv"]))

    # Model: the nearest real piece, so it looks like something that belongs at this level.
    best = min(cand, key=lambda c: abs(c[2] - r["ilvl"]))
    sources[r["item"]] = best[:3]
    if abs(best[2] - r["ilvl"]) > 8:
        far.append((r["name"], r["ilvl"], best[1], best[2]))

    # Armour: the median of the real curve at this level.
    win = ARMOUR_WINDOW_START
    while True:
        peers = [c[3] for c in cand if abs(c[2] - r["ilvl"]) <= win]
        if len(peers) >= ARMOUR_MIN_PEERS or win >= ARMOUR_WINDOW_MAX:
            break
        win += 5
    if not peers:                      # nothing at any distance; fall back to the model's own
        peers = [best[3]]
    if win > ARMOUR_WINDOW_START:
        widened.append((r["armour_name"], r["slot"], r["ilvl"], win, len(peers)))
    armour_of[r["item"]] = median(peers)

print("clone sources chosen for %d items" % len(sources))
if far:
    print("\n%d item(s) cloned from a source more than 8 item levels away:" % len(far))
    for nm, want, src, got in far[:10]:
        print("    %-30s ilvl %-3d <- %s (ilvl %d)" % (nm, want, src[:30], got))
seen = set()
for aname, slot, ilvl, win, n in widened:
    k = (aname, slot, ilvl)
    if k in seen:
        continue
    seen.add(k)
    print("    widened armour window: %-8s %-11s ilvl %-3d -> +/-%d (%d peers)"
          % (aname, slot, ilvl, win, n))

# ---------------------------------------------------------------------------------------
# 3. Emit
# ---------------------------------------------------------------------------------------
L = []
w = L.append
w("""-- ---------------------------------------------------------------------------------------
-- Craftable armour for Blacksmithing, Leatherworking and Tailoring.
--
-- GENERATED by gen_gear.py from gear.py. Do not edit by hand.
-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.
-- ---------------------------------------------------------------------------------------
--
-- THE GAP THIS FILLS, measured before writing it - by the skill at which a recipe becomes
-- useful, since req_skill_value is 1 on 309 of these and gates nothing:
--
--       band      want     BS had      LW had      Tailor had
--       1-75      greens   1 green     2 green     3 green
--       76-150    blues    0 BLUE      2 blue      1 blue
--       151-225   epics    0 EPIC      0 EPIC      0 EPIC
--       226+      epics    28 epic     35 epic     23 epic
--
--   The top band was well served; everything below it was nearly empty, and NO profession had
--   a single epic below skill 226 - so a level 40 had nothing to chase.
--
-- %d ITEMS: 4 armour types x 8 slots x 2-4 bands x 2-3 stat flavours.
--
-- ONE ARMOUR TYPE PER PROFESSION
--   Blacksmithing plate and mail, Leatherworking leather, Tailoring cloth. Stock data has
--   Blacksmithing AND Leatherworking both making mail, which is the kind of overlap that
--   makes two professions feel like one.
--
-- PLATE ONLY EXISTS IN THE TOP TWO BANDS
--   Plate proficiency arrives at level 40, so a green plate helm requiring level 16 is
--   something nobody could wear. The database agrees - there is no plate below item level 32
--   at all, so there was nothing on-curve to clone armour values from. Blacksmithing covers
--   the early bands with mail, which is what a low-level warrior actually wears.
--
-- STATS ARE PAID FOR IN MATERIALS
--       band  quality  ilvl  budget  materials                cost     points / 1000c
--       A     green     22     12    10 x tier-1                500c       24.0
--       B     blue      40     32    12 x tier-2               2400c       13.3
--       C     epic      56     59    16 x tier-3 + 2 rare      7200c        8.2
--       D     epic      71     89    20 x tier-4 + 4 rare     13600c        6.5
--
--   Seven times the stats for twenty-seven times the cost. Higher skill buys a far better
--   item, and epics are deliberately poor value per copper - that is what makes them epic.
--
-- ARMOUR VALUES ARE CLONED, NOT INVENTED
--   Each item clones the closest real armour piece of the same type, slot and item level, so
--   its armour rating and model sit on the existing curve. Only quality, level, stats and
--   name are overridden. Same approach shields.py and the white weapons take.
-- ---------------------------------------------------------------------------------------

USE tw_world;
""" % len(rows))

items = ",".join(str(r["item"]) for r in rows)
crafts = ",".join(str(r["craft"]) for r in rows)
teachs = ",".join(str(r["teach"]) for r in rows)

w("-- Clean slate, so a re-run cannot leave a half-updated grid behind.")
w("DELETE FROM item_template      WHERE entry    IN (%s);" % items)
w("DELETE FROM spell_template     WHERE entry    IN (%s);" % crafts)
w("DELETE FROM spell_template     WHERE entry    IN (%s);" % teachs)
w("DELETE FROM skill_line_ability WHERE spell_id IN (%s);" % crafts)
w("DELETE FROM npc_trainer        WHERE spell    IN (%s);" % teachs)
w("")

for r in rows:
    src_entry, src_name, src_ilvl = sources[r["item"]]
    w("-- %-34s %-7s band %s  ilvl %-3d req %-3d  <- clone %d (%s)"
      % (r["name"], r["armour_name"], r["band"], r["ilvl"], r["req"], src_entry, src_name[:26]))
    w("DROP TEMPORARY TABLE IF EXISTS tmp_g;")
    w("CREATE TEMPORARY TABLE tmp_g LIKE item_template;")
    w("INSERT INTO tmp_g SELECT * FROM item_template WHERE entry = %d;" % src_entry)
    w("UPDATE tmp_g SET")
    w("  entry = %d, name = '%s'," % (r["item"], r["name"].replace("'", "''")))
    w("  Quality = %d, item_level = %d, required_level = %d," % (r["quality"], r["ilvl"], r["req"]))
    w("  stat_type1 = %d, stat_value1 = %d," % (r["stat_a"], r["val_a"]))
    w("  stat_type2 = %d, stat_value2 = %d," % (r["stat_b"], r["val_b"]))
    w("  stat_type3 = 0, stat_value3 = 0, stat_type4 = 0, stat_value4 = 0,")
    w("  stat_type5 = 0, stat_value5 = 0,")
    w("  armor = %d,                            -- median of the real curve, not one clone's own" % armour_of[r["item"]])
    w("  random_property = 0, bonding = 1,      -- binds on pickup: these are the good ones")
    w("  spellid_1 = 0, spellid_2 = 0;          -- no on-use or proc effects")
    w("INSERT INTO item_template SELECT * FROM tmp_g;")
    w("DROP TEMPORARY TABLE tmp_g;")
    w("")

w("-- ---------------------------------------------------------------------------------------")
w("-- Recipes, trainer wrappers and skill lines.")
w("--")
w("-- npc_trainer.spell must be a LEARN_SPELL wrapper, never the craft spell itself - the core")
w("-- rejects that at load. Cloned from 2754, a real trainer wrapper, never a 'Plans:' spell,")
w("-- which targets the caster and makes the NPC teach itself.")
w("-- ---------------------------------------------------------------------------------------")
for r in rows:
    rc2 = "reagent2 = %d, reagentCount2 = %d," % (r["rare"][0], r["rare"][1]) if r["rare"] else "reagent2 = 0, reagentCount2 = 0,"
    w("DROP TEMPORARY TABLE IF EXISTS tmp_c;")
    w("CREATE TEMPORARY TABLE tmp_c LIKE spell_template;")
    w("INSERT INTO tmp_c SELECT * FROM spell_template WHERE entry = 2660;")
    w("UPDATE tmp_c SET entry = %d, name = '%s', nameSubtext = ''," % (r["craft"], r["name"].replace("'", "''")))
    w("  description = 'Creates %s.'," % r["name"].replace("'", "''"))
    w("  effect1 = 24, effectItemType1 = %d," % r["item"])
    w("  effect2 = 0, effect3 = 0, effectTriggerSpell1 = 0,")
    w("  reagent1 = %d, reagentCount1 = %d, %s" % (r["reagent"], r["count"], rc2))
    w("  reagent3 = 0, reagentCount3 = 0,")
    w("  totem1 = 0, totem2 = 0, requiresSpellFocus = 0,   -- no tools, no workbench")
    w("  spellIconId = 1;")
    w("INSERT INTO spell_template SELECT * FROM tmp_c;")
    w("DROP TEMPORARY TABLE tmp_c;")
    w("DROP TEMPORARY TABLE IF EXISTS tmp_t;")
    w("CREATE TEMPORARY TABLE tmp_t LIKE spell_template;")
    w("INSERT INTO tmp_t SELECT * FROM spell_template WHERE entry = 2754;")
    w("UPDATE tmp_t SET entry = %d, name = '%s', nameSubtext = ''," % (r["teach"], r["name"].replace("'", "''")))
    w("  description = 'Teaches you how to make %s.'," % r["name"].replace("'", "''"))
    w("  effect1 = 36, effectTriggerSpell1 = %d," % r["craft"])
    w("  effect2 = 0, effect3 = 0, effectItemType1 = 0,")
    w("  totem1 = 0, totem2 = 0, requiresSpellFocus = 0,")
    w("  spellIconId = 1;")
    w("INSERT INTO spell_template SELECT * FROM tmp_t;")
    w("DROP TEMPORARY TABLE tmp_t;")
    w("INSERT INTO skill_line_ability (id, skill_id, spell_id, req_skill_value, max_value, min_value)")
    w("  VALUES (%d, %d, %d, %d, %d, %d);"
      % (r["sla"], r["skill"], r["craft"], r["gate"],
         min(r["gate"] + 50, 300), min(r["gate"] + 20, 300)))
    w("")

w("-- Each profession master teaches its own.")
w("INSERT INTO npc_trainer (entry, spell, spellcost, reqskill, reqskillvalue, reqlevel) VALUES")
# reqlevel = 0, not r["req"] (the level you must be to WEAR the item). Measured against the
# real game: across every profession's real recipes (939 Blacksmithing, 1111 Tailoring, 627
# Leatherworking, ...) reqlevel is 0 on effectively all of them - a trainer gates purely on
# skill, never on character level. Wear-level and learn-level are not the same question, and
# vanilla only ever asks the first one.
vals = ["  (%d, %d, %d, %d, %d, 0)"
        % (MASTER[r["skill"]], r["teach"], r["cost"], r["skill"], r["gate"])
        for r in rows]
w(",\n".join(vals) + ";")
w("")
w("SELECT COUNT(*) AS gear_items   FROM item_template   WHERE entry IN (%s);" % items)
w("SELECT COUNT(*) AS craft_spells FROM spell_template  WHERE entry IN (%s);" % crafts)
w("SELECT COUNT(*) AS trainer_rows FROM npc_trainer     WHERE spell IN (%s);" % teachs)

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(L) + "\n")
print("\nwrote %s (%d items, %d spells)" % (OUT, len(rows), len(rows) * 2))
