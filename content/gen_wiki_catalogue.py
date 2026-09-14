"""Generate wiki/Items-and-Spells.md from the live database.

    python gen_wiki_catalogue.py

WHY GENERATED
  A hand-written catalogue of custom content is wrong the moment content is added, and
  nobody notices because it is prose. This reads spell_template and item_template directly,
  so the tables cannot drift from what the server actually has. Rationale that cannot be
  derived from data lives in NOTES below, keyed by id band.
"""
import os, subprocess, collections

MYSQL = r"D:\Games\turtlewow\tortoise-oneclick-compiler\DB\bin\mysql.exe"
OUT = r"C:\Users\jlowe\source\repos\terapinWoW\wiki\Items-and-Spells.md"


def q(sql):
    r = subprocess.run([MYSQL, "-h127.0.0.1", "-P3307", "-umangos", "-pmangos", "-N", "-B",
                        "-e", sql], capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("mysql failed: " + r.stderr.strip())
    return [l.split("\t") for l in r.stdout.strip().splitlines() if l.strip()]


spells = q("SELECT entry,name,effect1,LEFT(REPLACE(description,'|','/'),90) "
           "FROM tw_world.spell_template WHERE entry BETWEEN 38000 AND 38999 ORDER BY entry;")
items = q("SELECT entry,name,class,subclass,item_level,required_level "
          "FROM tw_world.item_template WHERE entry BETWEEN 90000 AND 90999 ORDER BY entry;")
if not spells or not items:
    raise SystemExit("no rows returned - is the database up on port 3307?")

SUBCLASS = {  # item class 2 = weapon, 4 = armour
    (2, 5): "Two-hand mace", (2, 6): "Polearm", (2, 13): "Fist weapon",
    (2, 16): "Thrown", (2, 18): "Crossbow", (4, 6): "Shield",
}

BANDS = [
    (38000, 38099, "Misc abilities and their trainers"),
    (38100, 38199, "Class specialization abilities"),
    (38300, 38399, "Blacksmithing weapon recipes"),
    (38400, 38499, "Thrown abilities"),
    (38500, 38599, "Blacksmithing shield recipes"),
    (38600, 38699, "Universal utility spells"),
]

out = []
w = out.append
w("# Items and Spells\n")
w("**This page is generated** by `content/gen_wiki_catalogue.py` from `spell_template` and")
w("`item_template`. Re-run it after adding content rather than editing it by hand.\n")

w("## ID allocation\n")
w("Custom IDs live in reserved blocks so they never collide with Turtle's own content.\n")
w("| block | used for | count |")
w("|---|---|---|")
for lo, hi, label in BANDS:
    n = sum(1 for s in spells if lo <= int(s[0]) <= hi)
    if n:
        w("| **%d-%d** | %s | %d |" % (lo, hi, label, n))
w("| **90000-90999** | custom items | %d |" % len(items))
w("")
w("> ### The hard ceiling ⛔")
w("> **Custom spell IDs must stay below 60000.** `SMSG_INITIAL_SPELLS` packs the player's")
w("> whole spellbook as 16-bit values, so anything above 65535 wraps: the server thinks it")
w("> told the client about your spell, the client is told about a completely different one,")
w("> and **neither side reports an error**. A second limit, `MAX_SPELL_ID` 60000, makes")
w("> `Spell::cast` return silently above it. Use the 38000-38999 block.\n")

w("## Custom spells\n")
w("Rows marked *teacher* are `SPELL_EFFECT_LEARN_SPELL` wrappers. A trainer entry cannot")
w("point at an ability directly - `npc_trainer.spell` must be a teaching spell whose trigger")
w("is the real ability - so every trainable ability needs a pair.\n")

for lo, hi, label in BANDS:
    band = [s for s in spells if lo <= int(s[0]) <= hi]
    if not band:
        continue
    abil = [s for s in band if s[2] != "36"]
    teach = len(band) - len(abil)
    w("### %s (%d-%d)\n" % (label, lo, hi))
    if lo == 38100:
        w("27 abilities + 27 teachers. **All 27 are still placeholder test content** - see")
        w("[Classes](Classes). The mechanism (one ability per spec, filed on its own")
        w("spellbook tab) is proven; the content is not written.\n")
        w("| id | ability | current placeholder effect |")
        w("|---|---|---|")
        for s in abil:
            eff = s[3].split("Buffs ")[-1].rstrip(".") if "Buffs " in s[3] else s[3]
            w("| %s | %s | %s |" % (s[0], s[1], eff))
        w("")
        continue
    if lo in (38300, 38500):
        w("%d recipes + %d teachers. The crafted items are listed under" % (len(abil), teach))
        w("[Custom items](#custom-items).\n")
        continue
    w("| id | name | | what it does |")
    w("|---|---|---|---|")
    for s in band:
        kind = "*teacher*" if s[2] == "36" else ""
        w("| %s | **%s** | %s | %s |" % (s[0], s[1], kind, s[3]))
    w("")

w("## Custom items\n")
w("Every one is **crafted by Blacksmithing** - none drop. Quality is uncommon (green)")
w("throughout: the stat budgets are deliberately modest so craftables do not outclass quest")
w("rewards of the same level.\n")

groups = collections.OrderedDict()
for i in items:
    entry, name, cls, sub, ilvl, req = i
    kind = SUBCLASS.get((int(cls), int(sub)), "class %s/%s" % (cls, sub))
    shape = name.split()[-1] if kind == "Shield" else kind
    groups.setdefault(shape, []).append((int(entry), name, int(ilvl), int(req)))

w("### Progression ladder\n")
w("Shield required levels are derived as `item_level - 5`, consistent across all three")
w("shapes. **Weapons are not consistent with them**: Copper and Bronze use -5, but Iron,")
w("Mithril and Thorium use -6, so a weapon unlocks one level before the shield of the same")
w("item level. Harmless, but unintended - the two generators were written separately and")
w("only shields were later given an explicit rule.")
w("")
w("**Weapons also have no Steel tier.** Steel was added to the shield line and never")
w("back-filled to weapons, which is why that column is empty for them below.")
w("")
w("| line | " + " | ".join(["Copper", "Bronze", "Iron", "Steel", "Mithril", "Thorium"]) + " |")
w("|---|---|---|---|---|---|---|")
TIERS = ["Copper", "Bronze", "Iron", "Steel", "Mithril", "Thorium"]
for shape, rows in groups.items():
    by_tier = {}
    for entry, name, ilvl, req in rows:
        for t in TIERS:
            if name.startswith(t):
                by_tier[t] = req
    if not by_tier:
        continue
    cells = [("lvl %d" % by_tier[t]) if t in by_tier else "—" for t in TIERS]
    w("| **%s** | %s |" % (shape, " | ".join(cells)))
w("")

w("### Full list\n")
w("| id | item | type | ilvl | req |")
w("|---|---|---|---|---|")
for entry, name, cls, sub, ilvl, req in items:
    kind = SUBCLASS.get((int(cls), int(sub)), "class %s/%s" % (cls, sub))
    w("| %s | %s | %s | %s | %s |" % (entry, name, kind, ilvl, req))
w("")

w(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "wiki_notes.md"),
       encoding="utf-8").read())

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out))
print("wrote %s (%d lines, %d spells, %d items)" % (OUT, len(out), len(spells), len(items)))
