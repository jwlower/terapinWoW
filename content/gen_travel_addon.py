"""Builds the TerapinTravel addon: every inn and dungeon you have found, pinned on the map.

WHY AN ADDON AT ALL, WHEN EVERYTHING ELSE HERE IS SERVER-SIDE
  The world map is drawn entirely by the client and there is no packet that says "put a pin
  here". A map pin is the one part of the Adventuring skill that cannot be done from the
  server at any price.

WHY IT RIDES ON pfQuest INSTEAD OF DRAWING A MAP LAYER
  pfQuest is already installed and already solves the hard half: pfMap:AddNode(meta) takes a
  zone and a percentage coordinate and handles the world map, the minimap, clustering,
  tooltips and redraws on zone change. Reimplementing that would be a large addon with a lot
  of surface area - and the last addon in this project that reached into client internals
  (hooking TurnOrActionStart for right-click dismount) disabled camera panning for the entire
  game. Adding nodes to someone else's node list touches nothing.

HOW THE ADDON KNOWS WHAT YOU HAVE FOUND - NO SERVER MESSAGING
  The teleports ARE the record. Every discovered inn or dungeon is a spell in the Adventuring
  spellbook tab, so the addon walks that tab with GetSpellName() and matches by name against
  the table below. Nothing has to be sent, saved, or kept in sync: learn a spell and the pin
  appears on the next SPELLS_CHANGED.

  That is also why the names in this table must match the spell names exactly. Both come from
  the same generated lists (inns.py, dungeon_portals.py), so they cannot drift.

THE COORDINATE CONVERSION, AND HOW IT WAS CHECKED
  pfQuest stores nodes as (AreaTable zone id, x%, y%) while the server knows only world
  coordinates, so every point is converted here using WorldMapArea.dbc:

      x = (locLeft - worldY) / (locLeft - locRight) * 100     <- pfQuest x is EAST-WEST
      y = (locTop  - worldX) / (locTop  - locBottom) * 100    <- pfQuest y is NORTH-SOUTH

  Note the axes cross over: the world's Y is the map's X. Getting that backwards produces
  coordinates that look completely plausible and are simply transposed, which is exactly what
  the first attempt did.

  The conversion was validated against pfQuest's OWN spawn data - convert a creature's server
  position and compare with the coordinates pfQuest already lists for it. Ten creatures across
  six zones agreed to within 0.24%. Where a point falls inside several map areas, the smallest
  wins, so a city reads as the city rather than the continent.
"""

import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import dbc      # noqa: E402
import mpyq     # noqa: E402

import dungeon_portals      # noqa: E402
import inns                 # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CLIENT_DATA = r"D:\Games\turtlewow\client\Data"
ADDON_DIR = r"D:\Games\turtlewow\client\Interface\AddOns\TerapinTravel"
SEARCH = ["patch-6.mpq", "patch-5.mpq", "patch-4.mpq", "patch-3.mpq",
          "patch-2.mpq", "patch.mpq", "dbc.MPQ"]


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


def lq(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def build_areas():
    wma = load_dbc("WorldMapArea.dbc")
    # [id, mapId, areaId, name, locLeft, locRight, locTop, locBottom]
    return [(r[2], r[1], f32(r[4]), f32(r[5]), f32(r[6]), f32(r[7])) for r in wma.records]


def convert(areas, mp, wx, wy):
    """World position -> (zone area id, x%, y%). Smallest containing map area wins."""
    best = None
    for area, m, left, right, top, bottom in areas:
        if m != mp or top == bottom or left == right:
            continue
        if not (min(bottom, top) <= wx <= max(bottom, top)):
            continue
        if not (min(left, right) <= wy <= max(left, right)):
            continue
        size = abs(top - bottom) * abs(left - right)
        x = (left - wy) / (left - right) * 100.0
        y = (top - wx) / (top - bottom) * 100.0
        if best is None or size < best[0]:
            best = (size, area, x, y)
    if best is None:
        return None
    return best[1], best[2], best[3]


def main():
    areas = build_areas()
    rows, missed = [], []

    for r in inns.grid():
        c = convert(areas, r["map"], r["x"], r["y"])
        if not c:
            missed.append(("inn", r["inn"], r["map"]))
            continue
        zone, x, y = c
        where = ", ".join(v for v in (r["town"], r["zone"]) if v and v != r["inn"])
        note = ("levels %d-%d" % (r["lo"], r["hi"])) if r["lo"] else ""
        rows.append(("inn", r["inn"], where or r["zone"], note, zone, x, y))

    for d in dungeon_portals.grid():
        c = convert(areas, d["door_map"], d["x"], d["y"])
        if not c:
            missed.append(("dungeon", d["name"], d["door_map"]))
            continue
        zone, x, y = c
        rows.append(("dungeon", d["name"], "Dungeon entrance",
                     "requires level %d" % d["req"], zone, x, y))

    if not os.path.isdir(ADDON_DIR):
        os.makedirs(ADDON_DIR)

    L = ["-- Every inn and dungeon door, in pfQuest map coordinates.",
         "-- GENERATED by TurtleMod/gen_travel_addon.py - do not edit by hand.",
         "--",
         "-- name must match the teleport SPELL name exactly: that is how the addon tells what",
         "-- you have discovered. Both come from the same generated lists, so they cannot drift.",
         "",
         "TerapinTravelData = {"]
    for kind, name, where, note, zone, x, y in rows:
        L.append("    {kind = %s, name = %s, where = %s, note = %s, zone = %d, x = %.2f, y = %.2f},"
                 % (lq(kind), lq(name), lq(where), lq(note), zone, x, y))
    L += ["}", ""]
    with open(os.path.join(ADDON_DIR, "data.lua"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L))

    inn_n = sum(1 for r in rows if r[0] == "inn")
    dun_n = sum(1 for r in rows if r[0] == "dungeon")
    print("wrote %s" % os.path.join(ADDON_DIR, "data.lua"))
    print("  %d inns, %d dungeon doors, across %d zones"
          % (inn_n, dun_n, len(set(r[4] for r in rows))))
    for kind, name, mp in missed:
        print("  NO MAP AREA: %-8s %-30s (map %d)" % (kind, name, mp))


if __name__ == "__main__":
    main()
