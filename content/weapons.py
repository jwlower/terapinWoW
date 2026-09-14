"""Blacksmithing weapon coverage: the types and tiers the profession never had.

Run directly to emit sql/07-weapons.sql; imported by content.py for the client DBC half.

    python weapons.py

WHAT WAS ACTUALLY MISSING
  Measured, not guessed. Counting Blacksmithing-craftable weapons by item-level band:

      type        <20  20-34  35-49  50-59  60+
      1H Sword      1      2      4      1     5
      1H Mace       1      4      3      2     3
      1H Axe        2      1      3      3     3
      Dagger        1      3      2      2     3
      2H Sword      2      1      3      3     2
      2H Mace       1      3      0      3     4     <- one hole
      2H Axe        1      1      2      3     2
      Fist          2      1      1      0     1     <- one hole
      Polearm       0      0      0      1     2     <- bottom three missing
      Thrown        -      -      -      -     -     <- nothing at all
      Crossbow      -      -      -      -     -     <- nothing at all

  So the swords/maces/axes/daggers are already covered at every tier and are left alone.
  15 items close every remaining gap.

  NOTE ON TIERS: skill_line_ability.req_skill_value is NOT the tier for this profession -
  82 of 88 existing BS weapon recipes have it set to 1, because they are learned from
  dropped Plans whose own required_skill does the gating. Item level is the real tier, which
  is why the table above is banded by item_level.

WHERE EACH TYPE LIVES (as specified)
  Guns stay in Engineering. Staves stay in Jewelcrafting and Survival. Bows stay in
  Survival. Crossbows and Thrown come to Blacksmithing.

CROSSBOWS ARE DELIBERATELY CROSS-PROFESSION
  Metal from Blacksmithing, wood and rope from Survival - so a smith needs a forager. Both
  mats already exist (Survival's stick bundles, and Sturdy/Springy Rope, which its Slowing
  Bolas recipe already uses), so nothing new had to be invented to make the link work.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------------------
# ID allocation - see SPELL-IDS.md. Spells must stay under 60000; item ids are unrestricted.
# ---------------------------------------------------------------------------------------
ITEM_BASE = 90120          # 90120-90134
CRAFT_BASE = 38300         # 38300-38314
TEACH_BASE = 38330         # 38330-38344
SLA_BASE = 7260            # 7260-7274

BS_SKILL = 164
BS_TRAINER = 2600300

# Clone sources, chosen so each new item inherits the right sheath, material, ammo_type and
# inventory_type rather than having those set blind.
CLONE = {
    "thrown":   2947,      # Small Throwing Knife  - subclass 16, inv 25, ammo 4
    "crossbow": 15807,     # Light Crossbow        - subclass 18, inv 26, ammo 2
    "polearm":  7959,      # Blight                - subclass 6,  inv 17
    "fist":     65013,     # Frostbound Slasher    - subclass 13, inv 13
    "mace2h":   1990,      # Ballast Maul          - subclass 5,  inv 17
}
# Spell icons per weapon type, from SpellIcon.dbc.
#
# EVERY Blacksmithing recipe in this database - all the real ones too - uses icon 140
# (Spell_Shadow_SealOfKings), a shadowy face, because that is what the craft spells were
# given. Cloning inherited it. These are not a bug fix so much as an improvement: the new
# recipes at least show the weapon they make.
ICON = {
    "thrown":   1505,   # INV_ThrowingKnife_01
    "crossbow": 269,    # INV_Weapon_Crossbow_01
    "polearm":  370,    # INV_Spear_05
    "fist":     756,    # INV_Gauntlets_04
    "mace2h":   367,    # INV_Mace_01
}

CLONE_CRAFT = 2660         # Rough Sharpening Stone - a plain BS create-item recipe
CLONE_TEACH = 2754         # "Copper Mace" - a real TRAINER wrapper. NOT 2760 "Plans: ...":
                           # that is cast by the recipe ITEM and has effectImplicitTargetA1 = 1
                           # (TARGET_UNIT_CASTER), so a trainer casting it teaches ITSELF.

# tier -> (metal bar, count scale, wood sticks, rope, craft skill, ilvl, reqlevel)
TIERS = [
    ("Copper",  2840, 1, 42149, 50231,  40, 10,  5),
    ("Bronze",  2841, 2, 42150, 50231, 110, 25, 20),
    ("Iron",    3575, 2, 42151, 50231, 160, 38, 32),
    ("Mithril", 3860, 3, 42152, 42006, 215, 52, 46),
    ("Thorium", 12359, 3, 42153, 42006, 265, 63, 57),
]

# Per-type damage at each tier, and the delay. Scaled from the real items either side of
# each hole so nothing is stronger than the gear already available at that level.
#   kind: (name suffix, delay, [(dmin,dmax) per tier])
SHAPES = {
    "thrown":   ("Throwing Blade", 2000, [(5, 9), (14, 25), (24, 42), (38, 66), (52, 88)]),
    "crossbow": ("Crossbow",       2800, [(7, 13), (18, 34), (31, 57), (48, 89), (64, 119)]),
    "polearm":  ("Pike",           2700, [(12, 19), (30, 46), (50, 76), None, None]),
    "fist":     ("Claw",           1900, [None, None, None, (44, 82), None]),
    "mace2h":   ("Maul",           3200, [None, None, (54, 82), None, None]),
}


def weapons():
    """(item_id, craft_id, teach_id, sla_id, kind, tier_index, name, ...)."""
    out = []
    n = 0
    for kind in ("thrown", "crossbow", "polearm", "fist", "mace2h"):
        suffix, delay, dmg = SHAPES[kind]
        for ti, tier in enumerate(TIERS):
            if dmg[ti] is None:
                continue
            tname, metal, mcount, sticks, rope, skill, ilvl, reqlvl = tier
            dmin, dmax = dmg[ti]
            name = "%s %s" % (tname, suffix)

            if kind == "crossbow":
                reagents = [(metal, 4 + 2 * mcount), (sticks, 2), (rope, mcount)]
            elif kind == "thrown":
                reagents = [(metal, 2 + mcount)]
            else:
                reagents = [(metal, 6 + 2 * mcount)]

            out.append({
                "item": ITEM_BASE + n,
                "craft": CRAFT_BASE + n,
                "teach": TEACH_BASE + n,
                "sla": SLA_BASE + n,
                "kind": kind,
                "name": name,
                "clone_item": CLONE[kind],
                "ilvl": ilvl,
                "reqlvl": reqlvl,
                "dmin": dmin,
                "dmax": dmax,
                "delay": delay,
                "skill": skill,
                "icon": ICON[kind],
                "reagents": reagents,
            })
            n += 1
    return out


def _q(s):
    return "'" + s.replace("'", "''") + "'"


def main():
    W = weapons()
    L = []
    w = L.append
    BAR = "-- " + "-" * 85

    w(BAR)
    w("-- Blacksmithing weapon coverage - GENERATED by weapons.py. Do not edit by hand.")
    w("--")
    w("--   %d new weapons closing every gap in the type x tier grid: Thrown and Crossbow" % len(W))
    w("--   (absent entirely), Polearm at the bottom three tiers, Fist at 50-59, 2H Mace at")
    w("--   35-49. Swords, maces, axes and daggers were already covered and are untouched.")
    w("--")
    w("-- Crossbows need Survival's wood and rope as well as metal, so the two professions")
    w("-- depend on each other. Both mats already existed.")
    w("--")
    w("-- Run against tw_world. IDEMPOTENT. Needs a mangosd RESTART and a rebuilt patch-6.mpq.")
    w(BAR)
    w("")
    w("USE tw_world;")
    w("")
    items = [x["item"] for x in W]
    spells = [x["craft"] for x in W] + [x["teach"] for x in W]
    w("DELETE FROM item_template      WHERE entry    IN (%s);" % ",".join(map(str, items)))
    w("DELETE FROM spell_template     WHERE entry    IN (%s);" % ",".join(map(str, spells)))
    w("DELETE FROM npc_trainer        WHERE spell    IN (%s);" % ",".join(map(str, spells)))
    w("DELETE FROM skill_line_ability WHERE spell_id IN (%s);" % ",".join(map(str, spells)))
    w("")

    sla_rows, trainer_rows = [], []
    for x in W:
        w("-- %-26s ilvl %-3d req %-3d  %d-%d dmg / %.1fs  skill %d"
          % (x["name"], x["ilvl"], x["reqlvl"], x["dmin"], x["dmax"],
             x["delay"] / 1000.0, x["skill"]))
        # ---- the item ----
        w("DROP TEMPORARY TABLE IF EXISTS tmp_i;")
        w("CREATE TEMPORARY TABLE tmp_i LIKE item_template;")
        w("INSERT INTO tmp_i SELECT * FROM item_template WHERE entry = %d;" % x["clone_item"])
        w("UPDATE tmp_i SET entry=%d, name=%s, item_level=%d, required_level=%d,"
          % (x["item"], _q(x["name"]), x["ilvl"], x["reqlvl"]))
        w("  dmg_min1=%d, dmg_max1=%d, delay=%d, quality=2," % (x["dmin"], x["dmax"], x["delay"]))
        # Prices scale with tier; inherited ones would price a Thorium crossbow like a
        # starter one. random_property cleared - see the Runed Copper Shield note.
        w("  sell_price=%d, buy_price=%d, random_property=0;"
          % (x["ilvl"] * 120, x["ilvl"] * 120 * 5))
        w("INSERT INTO item_template SELECT * FROM tmp_i;")
        w("DROP TEMPORARY TABLE tmp_i;")
        # ---- the craft spell ----
        sets = ["name=%s" % _q(x["name"]), "nameSubtext=''",
                "description=%s" % _q("Forges a %s." % x["name"]),
                "effect1=24", "effectItemType1=%d" % x["item"],
                "effect2=0, effect3=0", "effectTriggerSpell1=0"]
        for i in range(1, 5):
            if i <= len(x["reagents"]):
                sets.append("reagent%d=%d, reagentCount%d=%d"
                            % (i, x["reagents"][i - 1][0], i, x["reagents"][i - 1][1]))
            else:
                sets.append("reagent%d=0, reagentCount%d=0" % (i, i))
        w("DROP TEMPORARY TABLE IF EXISTS tmp_c;")
        w("CREATE TEMPORARY TABLE tmp_c LIKE spell_template;")
        w("INSERT INTO tmp_c SELECT * FROM spell_template WHERE entry = %d;" % CLONE_CRAFT)
        w("UPDATE tmp_c SET entry=%d,\n  %s;" % (x["craft"], ",\n  ".join(sets)))
        w("INSERT INTO spell_template SELECT * FROM tmp_c;")
        w("DROP TEMPORARY TABLE tmp_c;")
        # ---- the teacher ----
        w("DROP TEMPORARY TABLE IF EXISTS tmp_t;")
        w("CREATE TEMPORARY TABLE tmp_t LIKE spell_template;")
        w("INSERT INTO tmp_t SELECT * FROM spell_template WHERE entry = %d;" % CLONE_TEACH)
        w("UPDATE tmp_t SET entry=%d, name=%s, nameSubtext='', description=%s,"
          % (x["teach"], _q(x["name"]),
             _q("Teaches you how to make a %s." % x["name"])))
        w("  effect1=36, effectTriggerSpell1=%d, effect2=0, effect3=0," % x["craft"])
        w("  effectImplicitTargetA1=0;")   # 0 = the trainer's target, i.e. the player
        w("INSERT INTO spell_template SELECT * FROM tmp_t;")
        w("DROP TEMPORARY TABLE tmp_t;")
        w("")
        sla_rows.append((x["sla"], BS_SKILL, x["craft"], x["skill"]))
        trainer_rows.append((BS_TRAINER, x["teach"], x["ilvl"] * 200, BS_SKILL, x["skill"]))

    w("-- File every recipe under Blacksmithing so it appears in the crafting window.")
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
    w("SELECT 'weapons' AS what, COUNT(*) AS n FROM item_template WHERE entry IN (%s);"
      % ",".join(map(str, items)))
    w("SELECT 'recipes' AS what, COUNT(*) AS n FROM skill_line_ability WHERE spell_id IN (%s);"
      % ",".join(map(str, [x["craft"] for x in W])))
    w("SELECT it.name, it.item_level AS ilvl, it.dmg_min1 AS dmin, it.dmg_max1 AS dmax,"
      " sla.req_skill_value AS skill")
    w("FROM item_template it JOIN spell_template s ON s.effectItemType1=it.entry")
    w("JOIN skill_line_ability sla ON sla.spell_id=s.entry")
    w("WHERE it.entry IN (%s) ORDER BY it.item_level;" % ",".join(map(str, items)))

    out = os.path.join(HERE, "sql", "07-weapons.sql")
    with open(out, "w") as f:
        f.write("\n".join(L) + "\n")
    print("wrote %s" % out)
    print("  %d weapons: %s" % (len(W), ", ".join(sorted(set(x["kind"] for x in W)))))
    for x in W:
        print("    %-26s ilvl %-3d skill %-3d  %d-%d" % (x["name"], x["ilvl"], x["skill"],
                                                          x["dmin"], x["dmax"]))


if __name__ == "__main__":
    main()
