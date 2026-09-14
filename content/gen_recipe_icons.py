"""Give every craft spell the icon of the item it creates.

    python gen_recipe_icons.py          # writes sql/12-recipe-icons.sql + recipe_icons.py

THE PROBLEM
  Not one profession in this database has meaningful per-recipe spell icons. Measured:

      Alchemy         teacher icon 41  DryadDispelMagic   craft icon 1   Temp
      Blacksmithing   teacher icon 1   Temp               craft icon 140 SealOfKings
      Tailoring       teacher icon 41                     craft icon 69  Ability_Ensnare
      Engineering     teacher icon 1   Temp               craft icon 1   Temp

  Every recipe in a profession shares one placeholder, so a trainer's list is a wall of
  identical icons instead of the potions and swords you would expect.

THE FIX
  A craft spell knows the item it makes (effectItemType1). The item knows its display id.
  ItemDisplayInfo.dbc maps that display id to an inventory icon texture name, and
  SpellIcon.dbc maps texture names back to spell icon ids. Chain those together and every
  recipe can carry the icon of the thing it produces:

      craft spell -> item -> display_id -> ItemDisplayInfo -> "INV_Potion_51" -> SpellIcon id

  Both the craft spell AND its trainer wrapper get it, because the trainer list draws the
  wrapper while the crafting window draws the craft spell.

  Enchanting is skipped: its recipes create no item (they apply an enchantment), so there is
  nothing to take an icon from and the existing ones are already meaningful.
"""
import io
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "tools"))
import dbc      # noqa: E402
import mpyq     # noqa: E402

DATA = r"D:\Games\turtlewow\client\Data"
MYSQL = r"D:\Games\turtlewow\tortoise-oneclick-compiler\DB\bin\mysql.exe"


def load(name):
    for arch in ("patch-6.mpq", "patch-5.mpq", "patch-4.mpq", "patch-3.mpq",
                 "patch-2.mpq", "patch-1.mpq", "patch.MPQ", "dbc.MPQ"):
        p = os.path.join(DATA, arch)
        if not os.path.exists(p):
            continue
        try:
            d = mpyq.MPQArchive(p, listfile=False).read_file("DBFilesClient" + chr(92) + name)
        except Exception:
            continue
        if d:
            return dbc.Dbc(d)
    raise SystemExit("%s not found in the client" % name)


idi = load("ItemDisplayInfo.dbc")
spellicon = load("SpellIcon.dbc")

# Find the ItemDisplayInfo column holding the inventory icon. Rather than hardcode an index,
# pick the column where the most values look like an icon name.
best_col, best_hits = None, 0
for col in range(idi.field_count):
    hits = 0
    for rec in idi.records[:4000]:
        s = idi.get_string(rec[col])
        if s and (s.startswith("INV_") or s.startswith("Inv_") or s.startswith("inv_")):
            hits += 1
    if hits > best_hits:
        best_col, best_hits = col, hits
print("ItemDisplayInfo icon column = %d (%d/4000 look like icon names)" % (best_col, best_hits))

display_icon = {}
for rec in idi.records:
    s = idi.get_string(rec[best_col])
    if s:
        display_icon[rec[0]] = s.lower()

# SpellIcon texture path -> icon id, keyed on the bare file name.
icon_id = {}
for rec in spellicon.records:
    tex = spellicon.get_string(rec[1])
    if tex:
        icon_id[tex.split(chr(92))[-1].lower()] = rec[0]
print("SpellIcon entries: %d   ItemDisplayInfo with icons: %d"
      % (len(icon_id), len(display_icon)))

SQL = """
SELECT c.entry, t.entry, i.display_id, c.name
FROM tw_world.npc_trainer nt
JOIN tw_world.spell_template t ON t.entry = nt.spell
JOIN tw_world.spell_template c ON c.entry = t.effectTriggerSpell1
JOIN tw_world.item_template i ON i.entry = c.effectItemType1
WHERE c.effect1 = 24 AND i.display_id > 0
GROUP BY c.entry, t.entry, i.display_id, c.name;
"""
out = subprocess.run([MYSQL, "-h127.0.0.1", "-P3307", "-umangos", "-pmangos", "-N", "-e", SQL],
                     capture_output=True, text=True).stdout

# SpellIcon.dbc holds only ~1463 textures while items reference tens of thousands, so most
# recipes have no existing spell icon matching their item's texture. Rather than settle for
# partial coverage - which looks worse than none, half the list right and half placeholder -
# MINT new SpellIcon rows for the missing textures. It is just another DBC we already write.
next_icon_id = max(r[0] for r in spellicon.records) + 1
new_icons = []          # (id, texture path) appended to SpellIcon.dbc by build.py

pairs, missed = [], 0
for line in out.strip().splitlines():
    p = line.split("\t")
    if len(p) != 4:
        continue
    craft, teacher, disp, name = int(p[0]), int(p[1]), int(p[2]), p[3]
    tex = display_icon.get(disp)
    if not tex:
        missed += 1
        continue
    iid = icon_id.get(tex)
    if not iid:
        iid = next_icon_id
        next_icon_id += 1
        icon_id[tex] = iid
        new_icons.append((iid, "Interface" + chr(92) + "Icons" + chr(92) + tex))
    pairs.append((craft, teacher, iid, name))

print("resolved %d recipes (%d needed a NEW SpellIcon row), %d had no item texture"
      % (len(pairs), len(new_icons), missed))

lines = ["-- " + "-" * 85,
         "-- Recipe icons - GENERATED by gen_recipe_icons.py. Do not edit by hand.",
         "--",
         "--   craft spell -> item -> display_id -> ItemDisplayInfo -> SpellIcon id",
         "--",
         "-- No profession in this database had meaningful per-recipe icons; every recipe in",
         "-- a profession shared one placeholder. This gives each the icon of the item it",
         "-- makes, on both the craft spell and its trainer wrapper.",
         "--",
         "-- %d recipes. Run against tw_world. IDEMPOTENT." % len(pairs),
         "-- " + "-" * 85,
         "",
         "USE tw_world;",
         ""]
for craft, teacher, iid, name in sorted(pairs):
    lines.append("UPDATE spell_template SET spellIconId = %-5d WHERE entry IN (%d, %d);   -- %s"
                 % (iid, craft, teacher, name.replace("\n", " ")))
lines.append("")
io.open(os.path.join(HERE, "sql", "12-recipe-icons.sql"), "w", encoding="utf-8").write(
    "\n".join(lines))

# The client half, consumed by content.py.
py = ["# GENERATED by gen_recipe_icons.py - do not edit by hand.",
      "#",
      "# (spell_id, icon_id) for every trainer-taught recipe and its wrapper, so the client",
      "# DBC agrees with sql/12-recipe-icons.sql.",
      "",
      "RECIPE_ICONS = ["]
for craft, teacher, iid, name in sorted(pairs):
    py.append("    (%d, %d)," % (craft, iid))
    py.append("    (%d, %d)," % (teacher, iid))
py.append("]")
py.append("")
py.append("# Textures with no SpellIcon.dbc entry, minted here and appended to that DBC by")
py.append("# build.py. Without these, most recipes could not carry their item's icon.")
py.append("SPELL_ICONS_ADD = [")
for _iid, _tex in new_icons:
    py.append('    (%d, "%s"),' % (_iid, _tex.replace(chr(92), chr(92) + chr(92))))
py.append("]")
py.append("")
io.open(os.path.join(HERE, "recipe_icons.py"), "w", encoding="utf-8").write("\n".join(py))

print("wrote sql/12-recipe-icons.sql and recipe_icons.py (%d spell rows)" % (len(pairs) * 2))
for c, t, i, n in sorted(pairs)[:5]:
    print("   %-34s craft %-6d icon %d" % (n, c, i))
