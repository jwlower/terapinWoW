"""Blacksmithing shields - the worst gap in the profession.

Run directly to emit sql/15-shields.sql; imported by content.py for the client DBC half.

    python shields.py

WHAT WAS MISSING
  Blacksmithing makes exactly FOUR shields, and two of them are item level 70 raid-tier:

      Blast Shield                ilvl 15
      Runed Copper Shield         ilvl 18   (added by this mod)
      Jagged Obsidian Shield      ilvl 70
      Bulwark of Unshaken Earth   ilvl 70

  So between roughly level 18 and 60 a smith can craft no shield at all - for a profession
  whose entire identity is plate, mail and protection.

THREE PER TIER, ON THREE AXES
  Taken from the roadmap:

    all metal       warrior / paladin      strength + stamina
    leather + metal shaman and healers     intellect + spirit
    wood + metal    mixed                  stamina + agility

  The wood variant takes Survival's stick bundles, the same cross-profession link the
  crossbows use, so a smith still needs a forager.

STATS AND ARMOUR COME FROM CLONING
  Each tier clones a REAL shield of that item level, so armour and block land on the
  existing curve (ilvl 10 -> ~183 armour / 3.7 block, ilvl 63 -> ~1918 / 36) instead of
  being invented. Only name, stats, reagents and price are overridden.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------------------
# ID allocation. Spell ids must stay under 60000 - see SPELL-IDS.md.
# ---------------------------------------------------------------------------------------
ITEM_BASE = 90140          # 90140-90154
CRAFT_BASE = 38500         # 38500-38514
TEACH_BASE = 38530         # 38530-38544
SLA_BASE = 7300            # 7300-7314

BS_SKILL = 164
BS_TRAINER = 2600300
CLONE_CRAFT = 2660         # Rough Sharpening Stone - a plain BS create-item recipe
CLONE_TEACH = 2754         # "Copper Mace" - a REAL trainer wrapper (target 0, not the
                           # recipe-item spell, which teaches the trainer itself)

# ITEM_MOD, from ItemPrototype.h
AGILITY, STRENGTH, INTELLECT, SPIRIT, STAMINA = 3, 4, 5, 6, 7

# tier name, metal bar, leather, wood sticks, craft skill, clone shield (real item of that
# item level, so armour and block are correct for the tier)
TIERS = [
    ("Copper",  2840,  2318, 42149,  45, 61370, 10),   # Bristlehide Buckler  ilvl 10
    ("Bronze",  2841,  2319, 42150, 115,  4820, 25),   # Guardian Buckler     ilvl 25
    ("Iron",    3575,  4234, 42151, 165,  6828, 38),   # Visionary Buckler    ilvl 38
    ("Steel",   3859,  4304, 42152, 190,  8135, 46),   # Chromite Shield      ilvl 46
    ("Mithril", 3860,  8170, 42153, 220,  9974, 52),   # Overlord's Shield    ilvl 52
    ("Thorium", 12359, 8171, 42153, 270, 10366, 63),   # Demon Guard          ilvl 63
]

# required_level is set EXPLICITLY rather than inherited from the clone. Five of the six
# clone sources happen to carry item_level - 5, which is the vanilla convention for a green,
# but Visionary Buckler (6828, the Iron source) carries 0 - so the whole Iron tier was
# wearable at level 1 and sat out of order between Bronze (20) and Steel (41). Deriving the
# value makes the progression hold no matter what a clone source happens to have.
REQ_LEVEL_BELOW_ILVL = 5

# Appearance per axis per tier, so the three shields of a tier do not look identical and
# each still reads as gear of its own era. Every display_id is taken from a REAL shield of
# that item-level band, so the art already matches the tier's armour sets.
#
# Cloning gives armour and block; only the look is overridden, which keeps the whole tier on
# one stats curve while still looking like three different shields.
DISPLAY = {
    #            Copper Bronze Iron   Steel  Mithril Thorium
    "metal":   [ 18655, 18694, 26060, 26085, 26844, 26911 ],
    "leather": [ 27782,  3445, 18488, 18451, 23835, 27803 ],
    "wood":    [  2552, 20826, 18824, 11925, 26176, 26324 ],
}

# suffix, axis, (stat, stat), icon, scale of the stat values by tier index
SHAPES = [
    ("Bulwark",      "metal",   (STRENGTH, STAMINA),  1955),   # INV_Shield_06
    ("Wardingshield", "leather", (INTELLECT, SPIRIT), 1953),   # INV_Shield_04
    ("Roundshield",  "wood",    (STAMINA, AGILITY),   1959),   # INV_Shield_09
]

# Stat budget per tier index, split across the two stats. Deliberately modest - these are
# craftable greens, not raid drops, and they should not outclass the quest rewards of
# their level.
STAT_BUDGET = [3, 5, 7, 9, 11, 13]


def shields():
    out, n = [], 0
    for si, (suffix, axis, stats, icon) in enumerate(SHAPES):
        for ti, (tname, bar, leather, wood, skill, clone, ilvl) in enumerate(TIERS):
            budget = STAT_BUDGET[ti]
            first = (budget + 1) // 2
            second = budget - first

            if axis == "metal":
                reagents = [(bar, 8 + 2 * ti)]
            elif axis == "leather":
                reagents = [(bar, 5 + 2 * ti), (leather, 4 + ti)]
            else:
                reagents = [(bar, 5 + 2 * ti), (wood, 2 + ti)]

            out.append({
                "item": ITEM_BASE + n,
                "craft": CRAFT_BASE + n,
                "teach": TEACH_BASE + n,
                "sla": SLA_BASE + n,
                "name": "%s %s" % (tname, suffix),
                "clone_item": clone,
                "required_level": max(1, ilvl - REQ_LEVEL_BELOW_ILVL),
                "skill": skill,
                "icon": icon,
                "display": DISPLAY[axis][ti],
                "stats": [(stats[0], first), (stats[1], second)],
                "reagents": reagents,
                "axis": axis,
            })
            n += 1
    return out


def _q(s):
    return "'" + s.replace("'", "''") + "'"


def main():
    S = shields()
    L, w = [], None
    L = []
    w = L.append
    BAR = "-- " + "-" * 85

    w(BAR)
    w("-- Blacksmithing shields - GENERATED by shields.py. Do not edit by hand.")
    w("--")
    w("--   %d shields, three per tier: all-metal (str/sta), leather+metal (int/spi)," % len(S))
    w("--   and wood+metal (sta/agi). Blacksmithing previously made FOUR shields in total,")
    w("--   two of them item level 70, so nothing was craftable between level 18 and 60.")
    w("--")
    w("--   Armour and block are inherited by cloning a real shield of each item level, so")
    w("--   they sit on the existing curve rather than being invented.")
    w("--")
    w("-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.")
    w(BAR)
    w("")
    w("USE tw_world;")
    w("")
    items = [x["item"] for x in S]
    spells = [x["craft"] for x in S] + [x["teach"] for x in S]
    w("DELETE FROM item_template      WHERE entry    IN (%s);" % ",".join(map(str, items)))
    w("DELETE FROM spell_template     WHERE entry    IN (%s);" % ",".join(map(str, spells)))
    w("DELETE FROM npc_trainer        WHERE spell    IN (%s);" % ",".join(map(str, spells)))
    w("DELETE FROM skill_line_ability WHERE spell_id IN (%s);" % ",".join(map(str, spells)))
    w("")

    sla_rows, trainer_rows = [], []
    for x in S:
        w("-- %-24s %-8s skill %-4d  %s" % (x["name"], x["axis"], x["skill"],
          " + ".join("%d x item %d" % (c, i) for i, c in x["reagents"])))
        w("DROP TEMPORARY TABLE IF EXISTS tmp_s;")
        w("CREATE TEMPORARY TABLE tmp_s LIKE item_template;")
        w("INSERT INTO tmp_s SELECT * FROM item_template WHERE entry = %d;" % x["clone_item"])
        sets = ["entry = %d" % x["item"], "name = %s" % _q(x["name"]), "Quality = 2",
                "random_property = 0",
                # Never inherited - see REQ_LEVEL_BELOW_ILVL.
                "required_level = %d" % x["required_level"],
                # Overridden so the three shields of a tier look different from each other.
                "display_id = %d" % x["display"]]
        for i, (stype, sval) in enumerate(x["stats"], start=1):
            sets.append("stat_type%d = %d, stat_value%d = %d" % (i, stype, i, sval))
        for i in range(len(x["stats"]) + 1, 6):
            sets.append("stat_type%d = 0, stat_value%d = 0" % (i, i))
        w("UPDATE tmp_s SET %s;" % ",\n  ".join(sets))
        w("INSERT INTO item_template SELECT * FROM tmp_s;")
        w("DROP TEMPORARY TABLE tmp_s;")

        craft_sets = ["name = %s" % _q(x["name"]), "nameSubtext = ''",
                      "description = %s" % _q("Forges a %s." % x["name"]),
                      "effect1 = 24", "effectItemType1 = %d" % x["item"],
                      "effect2 = 0, effect3 = 0", "effectTriggerSpell1 = 0",
                      "spellIconId = %d" % x["icon"]]
        for i in range(1, 5):
            if i <= len(x["reagents"]):
                craft_sets.append("reagent%d = %d, reagentCount%d = %d"
                                  % (i, x["reagents"][i - 1][0], i, x["reagents"][i - 1][1]))
            else:
                craft_sets.append("reagent%d = 0, reagentCount%d = 0" % (i, i))
        w("DROP TEMPORARY TABLE IF EXISTS tmp_c;")
        w("CREATE TEMPORARY TABLE tmp_c LIKE spell_template;")
        w("INSERT INTO tmp_c SELECT * FROM spell_template WHERE entry = %d;" % CLONE_CRAFT)
        w("UPDATE tmp_c SET entry = %d,\n  %s;" % (x["craft"], ",\n  ".join(craft_sets)))
        w("INSERT INTO spell_template SELECT * FROM tmp_c;")
        w("DROP TEMPORARY TABLE tmp_c;")

        w("DROP TEMPORARY TABLE IF EXISTS tmp_t;")
        w("CREATE TEMPORARY TABLE tmp_t LIKE spell_template;")
        w("INSERT INTO tmp_t SELECT * FROM spell_template WHERE entry = %d;" % CLONE_TEACH)
        w("UPDATE tmp_t SET entry = %d, name = %s, nameSubtext = '', description = %s,"
          % (x["teach"], _q(x["name"]), _q("Teaches you how to make a %s." % x["name"])))
        w("  effect1 = 36, effectTriggerSpell1 = %d, effect2 = 0, effect3 = 0,"
          % x["craft"])
        w("  effectImplicitTargetA1 = 0, spellIconId = %d;" % x["icon"])
        w("INSERT INTO spell_template SELECT * FROM tmp_t;")
        w("DROP TEMPORARY TABLE tmp_t;")
        w("")
        sla_rows.append((x["sla"], BS_SKILL, x["craft"], x["skill"]))
        trainer_rows.append((BS_TRAINER, x["teach"], x["skill"] * 90, BS_SKILL, x["skill"]))

    w("-- File each under Blacksmithing so it appears in the crafting window.")
    w("INSERT INTO skill_line_ability")
    w("  (id, skill_id, spell_id, race_mask, class_mask, req_skill_value,")
    w("   superseded_by_spell, learn_on_get_skill, max_value, min_value, req_train_points)")
    w("VALUES")
    w(",\n".join("  (%d, %d, %d, 0, 0, %d, 0, 0, %d, %d, 0)"
                 % (i, s, sp, rq, rq + 50, rq + 15) for i, s, sp, rq in sla_rows) + ";")
    w("")
    w("-- Sell the plans at the Blacksmithing Master.")
    w("INSERT INTO npc_trainer (entry, spell, spellcost, reqskill, reqskillvalue, reqlevel)")
    w("VALUES")
    w(",\n".join("  (%d, %d, %d, %d, %d, 0)" % t for t in trainer_rows) + ";")
    w("")
    w("SELECT it.name, it.item_level AS ilvl, it.armor, it.block,")
    w("       it.stat_type1, it.stat_value1, it.stat_type2, it.stat_value2,")
    w("       sla.req_skill_value AS skill")
    w("FROM item_template it JOIN spell_template s ON s.effectItemType1 = it.entry")
    w("JOIN skill_line_ability sla ON sla.spell_id = s.entry")
    w("WHERE it.entry IN (%s) ORDER BY it.item_level, it.name;" % ",".join(map(str, items)))

    out = os.path.join(HERE, "sql", "15-shields.sql")
    with open(out, "w") as f:
        f.write("\n".join(L) + "\n")
    print("wrote %s" % out)
    print("  %d shields" % len(S))
    for x in S:
        print("    %-24s %-8s skill %-4d stats %s"
              % (x["name"], x["axis"], x["skill"],
                 ", ".join("%d:+%d" % (t, v) for t, v in x["stats"])))


if __name__ == "__main__":
    main()
