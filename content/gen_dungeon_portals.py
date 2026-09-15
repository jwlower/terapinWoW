"""Dungeon portals for the Adventuring skill.

Writes three things from one list, so they cannot drift apart:

    dungeon_portals.py                  the data, imported by content.py for the client DBC
    sql/37-dungeon-portals.sql          spells, destinations and skill lines
    lua_scripts/dungeon_portal_targets.lua   the same list for the server script

HOW A PORTAL IS EARNED
  You use the meeting stone outside the dungeon. That is the summoning stone, and clicking it
  is a thing players already do - so the portal is earned by having stood at the door, exactly
  as an inn teleport is earned by having stood in the inn.

  GAMEOBJECT_EVENT_ON_USE (14) is bridged, and GameObject::Use calls sScriptMgr.OnGameObjectUse
  at GameObject.cpp:1496 - BEFORE the switch on object type at 1509. So the hook is reached for
  a meeting stone (type 23) even though nothing else in the core treats it as usable solo.

WHERE YOU LAND: OUTSIDE THE DOOR, NOT INSIDE THE INSTANCE
  areatrigger_teleport carries the position INSIDE the instance, and teleporting straight in
  would skip the instance's own entry handling. The AreaTrigger.dbc position for the same
  trigger id is the doorway in the outside world, which is where the portal drops you. You
  still walk in, and a group can still gather.

WHICH DUNGEONS
  map_template.map_type = 1, the server's own definition of a dungeon, and the same filter
  gen_scaling.py uses - so the dungeons you can scale into are exactly the ones you can travel
  to. Raids are deliberately not included.

THE LEVEL IS MIN(required_level), NOT MAX
  Turtle puts Grim Batol on map 43, the same map as Wailing Caverns, requiring level 61 against
  Wailing Caverns' 10. MAX made Wailing Caverns look like a level 61 dungeon. See the same note
  in gen_scaling.py, where that was a live scaling bug.
"""

import os
import struct
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import dbc      # noqa: E402
import mpyq     # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CLIENT_DATA = r"D:\Games\turtlewow\client\Data"
MYSQL = r"D:\Games\turtlewow\tortoise-oneclick-compiler\DB\bin\mysql.exe"
SERVER_LUA = r"D:\Games\turtlewow\TortoiseNew\TortoiseCompiledNew\server\lua_scripts"
SEARCH = ["patch-6.mpq", "patch-5.mpq", "patch-4.mpq", "patch-3.mpq",
          "patch-2.mpq", "patch.mpq", "dbc.MPQ"]

SPELL_BASE = 44300          # inns hold 44200-44262; 44300+ is clear
SLA_BASE = 8000
CLONE_SPELL = 3561          # Teleport: Stormwind - 10s cast, breaks on damage, no cooldown
PORTAL_ICON = 237           # Spell_Arcane_PortalStormwind
STONE_RANGE = 1000.0        # yards from a stone to the door it belongs to

SKILL_ADVENTURING = 795


def q(sql):
    r = subprocess.run([MYSQL, "-h127.0.0.1", "-P3307", "-umangos", "-pmangos", "-N", "-B",
                        "-e", sql], capture_output=True, text=True, encoding="utf-8")
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


def sq(s):
    return s.replace("'", "''")


def lq(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def collect():
    at = load_dbc("AreaTrigger.dbc")
    pos = {r[0]: (r[1], f32(r[2]), f32(r[3]), f32(r[4])) for r in at.records}

    # Every entrance into a real dungeon, with the level its door demands.
    ent = [(int(tid), nm, int(tmap), int(rl), mapname) for tid, nm, tmap, rl, mapname in q(
        "SELECT at.id, at.name, at.target_map, at.required_level, m.map_name "
        "FROM tw_world.areatrigger_teleport at "
        "JOIN tw_world.map_template m ON m.entry = at.target_map "
        "WHERE m.map_type = 1 AND at.required_level > 0")]

    stones = [(int(m), float(x), float(y), float(z)) for m, x, y, z in q(
        "SELECT g.map, g.position_x, g.position_y, g.position_z "
        "FROM tw_world.gameobject g JOIN tw_world.gameobject_template t ON t.entry = g.id "
        "WHERE t.type = 23")]

    # One portal per dungeon. Where a dungeon has several doors, take the one with the LOWEST
    # required level - that is the entrance a player can actually walk through.
    per_map = {}
    for tid, nm, tmap, rl, mapname in ent:
        if tid not in pos:
            continue
        cur = per_map.get(tmap)
        if cur is None or rl < cur[3]:
            per_map[tmap] = (tid, nm, tmap, rl, mapname)

    rows = []
    for tmap in sorted(per_map):
        tid, nm, _, rl, mapname = per_map[tmap]
        m, x, y, z = pos[tid]
        near = [(((x - sx) ** 2 + (y - sy) ** 2 + (z - sz) ** 2) ** 0.5, sx, sy, sz)
                for sm, sx, sy, sz in stones if sm == m]
        d, stone = (min(near)[0], min(near)[1:]) if near else (None, None)
        rows.append({
            "spell": SPELL_BASE + len(rows),
            "map": tmap, "name": mapname, "req": rl,
            "door_map": m, "x": x, "y": y, "z": z,
            "stone_dist": d,
            "stone": stone if (d is not None and d <= STONE_RANGE) else None,
        })
    return rows


def main():
    rows = collect()
    ids = ",".join(str(r["spell"]) for r in rows)

    # ---- data module ----------------------------------------------------------------
    L = ['"""Dungeon portals. GENERATED by gen_dungeon_portals.py - do not edit by hand."""',
         "", "SKILL_ADVENTURING = %d" % SKILL_ADVENTURING,
         "SPELL_BASE = %d" % SPELL_BASE, "SLA_BASE = %d" % SLA_BASE, "", "DUNGEONS = ["]
    for r in rows:
        L.append("    {'spell': %d, 'map': %d, 'name': %r, 'req': %d, "
                 "'door_map': %d, 'x': %.2f, 'y': %.2f, 'z': %.2f},"
                 % (r["spell"], r["map"], r["name"], r["req"],
                    r["door_map"], r["x"], r["y"], r["z"]))
    L += ["]", "", "", "def grid():", "    return DUNGEONS", ""]
    with open(os.path.join(HERE, "dungeon_portals.py"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L))

    # ---- SQL ------------------------------------------------------------------------
    S = []
    w = S.append
    w("-- " + "-" * 85)
    w("-- Dungeon portals: one teleport per dungeon, earned at its summoning stone.")
    w("--")
    w("-- GENERATED by gen_dungeon_portals.py - do not edit by hand.")
    w("-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.")
    w("-- " + "-" * 85)
    w("--")
    w("-- Filed under Adventuring (%d), the same skill as the inn teleports, so travel collects"
      % SKILL_ADVENTURING)
    w("-- in one tab: inns are where you rest, dungeons are where you go.")
    w("--")
    w("-- YOU LAND OUTSIDE THE DOOR, NOT INSIDE. areatrigger_teleport holds the position inside")
    w("-- the instance; the AreaTrigger.dbc position for the same trigger is the doorway in the")
    w("-- outside world, and that is the destination here. You still walk in.")
    w("-- " + "-" * 85)
    w("")
    w("USE tw_world;")
    w("")
    w("DELETE FROM spell_template        WHERE entry    IN (%s);" % ids)
    w("DELETE FROM spell_target_position WHERE id       IN (%s);" % ids)
    w("DELETE FROM skill_line_ability    WHERE spell_id IN (%s);" % ids)
    w("")
    for i, r in enumerate(rows):
        desc = ("Teleport to the entrance of %s. The door requires level %d."
                % (r["name"], r["req"]))
        w("-- %-32s map %-5d requires level %d" % (r["name"][:32], r["map"], r["req"]))
        w("DROP TEMPORARY TABLE IF EXISTS tmp_d;")
        w("CREATE TEMPORARY TABLE tmp_d LIKE spell_template;")
        w("INSERT INTO tmp_d SELECT * FROM spell_template WHERE entry = %d;" % CLONE_SPELL)
        w("UPDATE tmp_d SET")
        w("  entry = %d," % r["spell"])
        w("  name = '%s'," % sq(r["name"]))
        w("  nameSubtext = 'Dungeon',")
        w("  description = '%s'," % sq(desc))
        w("  spellIconId = %d," % PORTAL_ICON)
        w("  manaCost = 0, manaCostPercentage = 0, powerType = 0,")
        w("  spellLevel = 1, baseLevel = 1;")
        w("INSERT INTO spell_template SELECT * FROM tmp_d;")
        w("DROP TEMPORARY TABLE tmp_d;")
        w("INSERT INTO spell_target_position")
        w("  (id, target_map, target_position_x, target_position_y, target_position_z,"
          " target_orientation)")
        w("  VALUES (%d, %d, %.4f, %.4f, %.4f, 0);"
          % (r["spell"], r["door_map"], r["x"], r["y"], r["z"]))
        w("INSERT INTO skill_line_ability")
        w("  (id, skill_id, spell_id, req_skill_value, max_value, min_value)")
        w("  VALUES (%d, %d, %d, 0, 0, 0);" % (SLA_BASE + i, SKILL_ADVENTURING, r["spell"]))
        w("")
    w("SELECT 'spells' AS what, COUNT(*) n FROM spell_template WHERE entry IN (%s)" % ids)
    w("UNION ALL SELECT 'destinations', COUNT(*) FROM spell_target_position WHERE id IN (%s)"
      % ids)
    w("UNION ALL SELECT 'skill lines', COUNT(*) FROM skill_line_ability WHERE spell_id IN (%s);"
      % ids)
    with open(os.path.join(HERE, "sql", "37-dungeon-portals.sql"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(S) + "\n")

    # ---- Lua ------------------------------------------------------------------------
    T = ["-- Dungeon portals. GENERATED by gen_dungeon_portals.py - do not edit by hand.",
         "--",
         "-- Read lazily by dungeon_portals.lua: ElunaLoader sorts by path, so",
         '-- "dungeon_portal_targets" loads AFTER "dungeon_portals" and the global is not',
         "-- there when that script's chunk first runs.",
         "",
         "TerapinDungeonPortals = {"]
    for r in rows:
        T.append("    {spell = %d, name = %s, req = %d, map = %d, x = %.2f, y = %.2f, "
                 "z = %.2f}," % (r["spell"], lq(r["name"]), r["req"],
                                 r["door_map"], r["x"], r["y"], r["z"]))
    T += ["}", ""]
    # THE USE HOOK IS KEYED BY GAMEOBJECT ENTRY, not registered globally:
    # Eluna::OnGameObjectUse does START_HOOK_WITH_RETVAL(..., pGameObject->GetEntry(), ...),
    # so a handler only ever fires for the entries it was registered against. Every meeting
    # stone template has to be listed, which is why this is generated rather than typed.
    stone_entries = [int(e) for (e,) in q(
        "SELECT entry FROM tw_world.gameobject_template WHERE type = 23 ORDER BY entry")]
    T += ["-- Every meeting stone template. The use hook is keyed by gameobject ENTRY",
          "-- (Eluna::OnGameObjectUse passes GetEntry() as the binding key), so each one must",
          "-- be registered individually - a global handler would never fire.",
          "TerapinMeetingStones = {%s}" % ", ".join(str(e) for e in stone_entries),
          ""]
    with open(os.path.join(SERVER_LUA, "dungeon_portal_targets.lua"), "w",
              encoding="utf-8") as fh:
        fh.write("\n".join(T))

    with_stone = sum(1 for r in rows if r["stone"])
    print("%d dungeons -> spells %d..%d" % (len(rows), SPELL_BASE, SPELL_BASE + len(rows) - 1))
    print("  %d have a meeting stone within %.0f yards" % (with_stone, STONE_RANGE))
    for r in rows:
        if not r["stone"]:
            d = "none on map" if r["stone_dist"] is None else "%.0f yd away" % r["stone_dist"]
            print("    NO STONE: %-28s (%s)" % (r["name"], d))
    print("wrote dungeon_portals.py, sql/37-dungeon-portals.sql, dungeon_portal_targets.lua")


if __name__ == "__main__":
    main()
