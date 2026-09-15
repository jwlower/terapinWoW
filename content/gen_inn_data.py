"""Builds inns.py - every inn in the world, with where it is and what lives around it.

Run this when the world database changes. It writes inns.py, which content.py imports for the
client DBC and gen_inns.py turns into SQL, so the two sides cannot disagree.

WHERE EACH PIECE COMES FROM, AND WHY NOT SOMEWHERE EASIER

  the inn list      areatrigger_tavern (65 rows). These are the triggers that make you
                    "rested", so they ARE the game's own definition of an inn - no guessing.
                    Their names are already curated in the exact shape we want:
                        "Elwynn Forest - Goldshire - Lion's Pride Inn"

  coordinates       AreaTrigger.dbc. areatrigger_tavern carries id and name and NOTHING else -
                    the position lives client-side. We already read DBCs out of the MPQ chain
                    for Spell.dbc, so this is the same machinery.

  landing spot      The nearest Innkeeper NPC spawn, when one is within LANDING_RANGE. You
                    arrive beside the innkeeper rather than in a doorway. 48 innkeepers cover
                    most of the list; the rest land on the trigger itself.

  zone and town     Parsed from the curated tavern name. Where the name is only a zone -
                    "The Barrens" appears three times - the nearest game_tele entry supplies
                    the town, which is where names like TheCrossroads and TarrenMill come from.

  level range       The 15th and 85th percentile of hostile spawn levels within LEVEL_RADIUS.

                    NOT AreaTable.dbc's explorationLevel, which is 0 for every outdoor zone
                    and only set for cities. NOT the nearest graveyard's zone either - that was
                    the first attempt and it was badly wrong, because dungeon graveyards sit at
                    their instance entrance: it put Goldshire's inn in "Stormwind Vault" and
                    Silverpine's in "Shadowfang Keep".

                    Percentiles rather than min and max, because a single level 55 rare wandering
                    past Southshore would otherwise report the zone as 24-55.
"""

import os
import re
import struct
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import dbc      # noqa: E402
import mpyq     # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CLIENT_DATA = r"D:\Games\turtlewow\client\Data"
MYSQL = r"D:\Games\turtlewow\tortoise-oneclick-compiler\DB\bin\mysql.exe"
SEARCH = ["patch-6.mpq", "patch-5.mpq", "patch-4.mpq", "patch-3.mpq",
          "patch-2.mpq", "patch.mpq", "dbc.MPQ"]

SPELL_BASE = 44200          # 44200.. one per inn; 44200-44400 is empty, checked
LANDING_RANGE = 60.0        # yards; beyond this we land on the trigger, not the innkeeper
LEVEL_RADIUS = 300.0        # yards to look for hostile spawns
MIN_SAMPLE = 8              # fewer hostiles than this and we report no level range

# Faction ids that are never "the local wildlife": friendly/neutral townsfolk and critters.
BORING_FACTIONS = (35, 7, 31, 12, 1, 2, 3, 4, 5, 6)


def q(sql):
    r = subprocess.run([MYSQL, "-h127.0.0.1", "-P3307", "-umangos", "-pmangos", "-N", "-B",
                        "-e", sql], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit("mysql failed: %s" % r.stderr.strip()[:400])
    return [l.split("\t") for l in r.stdout.strip().split("\n") if l]


def load_dbc(name):
    for arch in SEARCH:
        p = os.path.join(CLIENT_DATA, arch)
        if not os.path.exists(p):
            continue
        try:
            raw = mpyq.MPQArchive(p, listfile=False).read_file("DBFilesClient\\" + name)
        except Exception:
            continue
        if raw:
            return dbc.Dbc(raw)
    raise SystemExit("%s not found in the client MPQ chain" % name)


def f32(v):
    return struct.unpack("<f", struct.pack("<I", v))[0]


def spaced(camel):
    """TheCrossroads -> The Crossroads. game_tele names have no spaces."""
    return re.sub(r"(?<=[a-z])(?=[A-Z])", " ", camel).strip()


def main():
    at = load_dbc("AreaTrigger.dbc")
    pos = {r[0]: (r[1], f32(r[2]), f32(r[3]), f32(r[4])) for r in at.records}

    taverns = [(int(i), n) for i, n in q(
        "SELECT id, name FROM tw_world.areatrigger_tavern ORDER BY id")]

    innkeepers = [(int(m), float(x), float(y), float(z), float(o), nm) for nm, m, x, y, z, o in q(
        "SELECT t.name, c.map, c.position_x, c.position_y, c.position_z, c.orientation "
        "FROM tw_world.creature c JOIN tw_world.creature_template t ON t.entry = c.id "
        "WHERE t.name LIKE 'Innkeeper %'")]

    teles = [(int(m), float(x), float(y), nm) for nm, m, x, y in q(
        "SELECT name, map, position_x, position_y FROM tw_world.game_tele")]

    # One pass over every hostile spawn, bucketed by map. 71k rows beats 65 round trips.
    mobs = {}
    for m, x, y, lv in q(
            "SELECT c.map, c.position_x, c.position_y, ct.level_min "
            "FROM tw_world.creature c JOIN tw_world.creature_template ct ON ct.entry = c.id "
            "WHERE ct.npc_flags = 0 AND ct.level_min > 2 "
            "AND ct.faction NOT IN (%s)" % ",".join(str(x) for x in BORING_FACTIONS)):
        mobs.setdefault(int(m), []).append((float(x), float(y), int(lv)))

    rows, skipped = [], []
    for tid, raw_name in taverns:
        if tid not in pos:
            skipped.append((tid, raw_name, "no AreaTrigger.dbc row"))
            continue
        mp, tx, ty, tz = pos[tid]

        # --- name, town, zone -------------------------------------------------------
        parts = [p.strip() for p in raw_name.split(" - ")]
        if len(parts) >= 3:
            zone, town, inn = parts[0], parts[1], " - ".join(parts[2:])
        elif len(parts) == 2:
            zone, town, inn = parts[0], None, parts[1]
        else:
            zone, town, inn = parts[0], None, None

        near_tele = min(((tx - x) ** 2 + (ty - y) ** 2, nm)
                        for m, x, y, nm in teles if m == mp) if any(
                            m == mp for m, _, _, _ in teles) else None
        if inn is None:
            # Zone-only name: borrow the town from the nearest teleport landmark.
            town = spaced(near_tele[1]) if near_tele else None
            inn = ("%s Inn" % town) if town else ("%s Inn" % zone)

        # --- landing spot -----------------------------------------------------------
        cand = [(((tx - x) ** 2 + (ty - y) ** 2 + (tz - z) ** 2) ** 0.5, x, y, z, o)
                for m, x, y, z, o, _ in innkeepers if m == mp]
        if cand and min(cand)[0] <= LANDING_RANGE:
            d, lx, ly, lz, lo = min(cand)
            landing = "innkeeper"
        else:
            lx, ly, lz, lo = tx, ty, tz, 0.0
            landing = "trigger"

        # --- level range ------------------------------------------------------------
        lv = sorted(l for x, y, l in mobs.get(mp, [])
                    if (x - tx) ** 2 + (y - ty) ** 2 < LEVEL_RADIUS ** 2)
        if len(lv) >= MIN_SAMPLE:
            lo_lvl, hi_lvl = lv[int(len(lv) * 0.15)], lv[int(len(lv) * 0.85)]
        else:
            lo_lvl = hi_lvl = 0

        rows.append({
            "trigger": tid, "spell": SPELL_BASE + len(rows),
            "inn": inn, "town": town, "zone": zone,
            "map": mp, "x": lx, "y": ly, "z": lz, "o": lo,
            "lo": lo_lvl, "hi": hi_lvl, "landing": landing,
        })

    # Names must be unique - they become spell names, and two "Barrens Inn" entries in one
    # spellbook tab would be indistinguishable.
    seen = {}
    for r in rows:
        key = r["inn"].lower()
        if key in seen:
            r["inn"] = "%s (%s)" % (r["inn"], r["town"] or r["zone"])
        seen[key] = True

    out = [
        '"""Every inn in the world. GENERATED by gen_inn_data.py - do not edit by hand.',
        "",
        "Each row is one teleport destination for the Adventuring skill. See gen_inn_data.py",
        "for where each field comes from and why.",
        "",
        "    inn/town/zone   display text, from the curated areatrigger_tavern name",
        "    map/x/y/z/o     where you land - beside the innkeeper where there is one",
        "    lo/hi           hostile levels around the inn, 0 when there was no sample",
        '"""',
        "",
        "# Skill line 795, category 9 - the same category as First Aid and Survival.",
        "# NOT category 11: primary professions are capped at two per character, and",
        "# Adventuring must never cost anyone a Blacksmithing slot.",
        "SKILL_ADVENTURING = 795",
        "SKILL_CATEGORY = 9",
        "SPELL_BASE = %d" % SPELL_BASE,
        "",
        "INNS = [",
    ]
    for r in rows:
        out.append("    {"
                   "'spell': %d, 'trigger': %d, 'inn': %r, 'town': %r, 'zone': %r, "
                   "'map': %d, 'x': %.2f, 'y': %.2f, 'z': %.2f, 'o': %.2f, "
                   "'lo': %d, 'hi': %d}," % (
                       r["spell"], r["trigger"], r["inn"], r["town"], r["zone"],
                       r["map"], r["x"], r["y"], r["z"], r["o"], r["lo"], r["hi"]))
    out.append("]")
    out.append("")
    out.append("")
    out.append("def grid():")
    out.append("    return INNS")
    out.append("")

    path = os.path.join(HERE, "inns.py")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))

    by_landing = {}
    for r in rows:
        by_landing[r["landing"]] = by_landing.get(r["landing"], 0) + 1
    no_level = sum(1 for r in rows if r["lo"] == 0)
    print("wrote %s" % path)
    print("  %d inns  (%d land beside an innkeeper, %d on the trigger)"
          % (len(rows), by_landing.get("innkeeper", 0), by_landing.get("trigger", 0)))
    print("  %d with no level range (too few hostiles nearby)" % no_level)
    print("  spell ids %d..%d" % (SPELL_BASE, SPELL_BASE + len(rows) - 1))
    for tid, nm, why in skipped:
        print("  SKIPPED %d %-40s %s" % (tid, nm[:40], why))


if __name__ == "__main__":
    main()
