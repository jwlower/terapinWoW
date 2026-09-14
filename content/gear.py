"""Craftable armour sets for Blacksmithing, Leatherworking and Tailoring.

THE GAP THIS FILLS
  Measured against the live database, by the skill level at which a recipe becomes useful
  (skill_line_ability.min_value - req_skill_value is 1 on 309 of these and gates nothing):

      band      want     BS has      LW has      Tailor has
      1-75      greens   1 green     2 green     3 green
      76-150    blues    0 BLUE      2 blue      1 blue
      151-225   epics    0 EPIC      0 EPIC      0 EPIC
      226+      epics    28 epic     35 epic     23 epic

  The top band is well served. Everything below it is close to empty, and NO profession has
  a single epic below skill 226 - so a level 40 has nothing worth chasing.

THE GRID
  4 armour types x 8 slots x 4 bands x 2-3 stat flavours = 320 items.

      Blacksmithing  plate, mail        Leatherworking  leather      Tailoring  cloth

  Armour types are split one-per-profession on purpose. Blacksmithing and Leatherworking
  both make mail in stock data, which is exactly the kind of overlap that makes two
  professions feel like one.

STATS ARE PAID FOR IN MATERIALS
  The stat budget comes from item level and quality. The material COUNT is fixed per band and
  the cost follows from the reagent's real value, which produces this curve:

      band  quality  ilvl  budget  materials                 cost     stat points / 1000c
      A     green     22     10    10 x Bronze                 500c        20.0
      B     blue      40     28    12 x Iron                  2400c        11.7
      C     epic      56     42    16 x Mithril + 2 Earth     7200c         5.8
      D     epic      71     71    20 x Thorium + 4 Fire     13600c         5.2

  Seven times the stats for twenty-seven times the cost: higher skill buys a much better
  item, and epics are deliberately poor value per copper, which is what makes them epic.

  Deriving the COUNT from a cost budget instead was the first attempt and it collapsed -
  material value climbs faster than the stat budget does, so every band pinned to the cap and
  a band-A green helm wanted forty bronze bars.

  Material values are taken from item_template.sell_price, with one correction: Steel Bar
  sells for 60 where Iron Bar sells for 200, which is backwards for a bar made FROM iron.
  MATERIAL_VALUE below uses a monotonic tier scale instead of trusting that row.
"""

# ---------------------------------------------------------------------------------------
# Armour types: subclass, profession skill, the reagent ladder, and who makes it
# ---------------------------------------------------------------------------------------
SKILL_BS, SKILL_LW, SKILL_TAILOR = 164, 165, 197

# subclass -> (name, profession skill, reagent per band, bands this type may use)
#
# PLATE ONLY EXISTS IN THE TOP TWO BANDS, deliberately. Plate proficiency arrives at level 40,
# so a green plate helm with a required level of 16 is something nobody could ever wear. The
# database agrees: there is no plate at all below item level 32, which left the generator with
# no on-curve item to clone armour values from. Blacksmithing covers the early bands with MAIL
# instead, which is exactly what a low-level warrior actually wears.
ARMOUR = {
    4: ("Plate",   SKILL_BS,     [2841, 3575, 3860, 12359], ("C", "D")),
    3: ("Mail",    SKILL_BS,     [2841, 3575, 3860, 12359], ("A", "B", "C", "D")),
    2: ("Leather", SKILL_LW,     [2319, 4234, 4304, 8170],  ("A", "B", "C", "D")),
    1: ("Cloth",   SKILL_TAILOR, [2592, 4306, 4338, 14047], ("A", "B", "C", "D")),
}

# Monotonic value per reagent, in copper. Grounded in sell_price except where that data is
# inconsistent - see the module docstring.
MATERIAL_VALUE = {
    2841: 50,   3575: 200,  3860: 400,  12359: 600,    # bronze, iron, mithril, thorium
    2319: 50,   4234: 150,  4304: 300,  8170: 500,     # medium, heavy, thick, rugged leather
    2592: 33,   4306: 150,  4338: 250,  14047: 400,    # wool, silk, mageweave, runecloth
}

# ---------------------------------------------------------------------------------------
# Slots. inventory_type is what the client uses to decide where a piece goes.
# ---------------------------------------------------------------------------------------
SLOTS = [
    (1,  "Helm"),
    (3,  "Pauldrons"),
    (5,  "Chestguard"),
    (9,  "Bracers"),
    (10, "Gauntlets"),
    (6,  "Girdle"),
    (7,  "Legguards"),
    (8,  "Boots"),
]

# ---------------------------------------------------------------------------------------
# Bands: the skill range each is gated behind, the quality it produces, and where it sits.
# ---------------------------------------------------------------------------------------
# key, skill gate, quality, item level, required level, stat budget, name prefix,
# primary reagent count, (rare reagent, count) or None
#
# COUNTS ARE FIXED PER BAND AND THE COST FOLLOWS, not the other way round. Deriving the count
# from a cost budget was the first attempt and it collapsed: material value climbs faster than
# the stat budget does, so every band pinned to the cap and a green helm wanted 40 bronze bars.
# Fixing the count keeps recipes recognisable while the VALUE still climbs steeply -
# 500c of bronze for a band-A green, 12000c of thorium for a band-D epic.
# THE BUDGET IS AN ABSOLUTE NUMBER, MEASURED, NOT A MULTIPLE OF ITEM LEVEL. The first attempt
# used ilvl * multiplier, which quietly put band D at 89 stat points - equal to the single best
# epic in the game (best 88, average 43.7) - and band C at 59, which beat the AVERAGE ilvl 71
# raid epic. Craftable gear that outclasses Molten Core makes Molten Core pointless.
#
# Each band is now calibrated against what actually exists at its item level:
#
#     band  quality  ilvl  real avg  real best  ours   what that means
#     A     green      22       6.5         11    10   the best green at its level
#     B     blue       40      16.7         35    28   a strong blue, short of the best
#     C     epic       56      25.9*        39*   42   better than ANY blue at 56, and just
#                                                      under the ilvl 71 raid floor of 43.7
#     D     epic       71      43.7         88    71   well above the average raid epic,
#                                                      below the best one in the game
#
#     * no real epic exists at ilvl 56 - that is the gap band C is built to fill - so the
#       comparison there is against blues, which are the best thing at that level today.
#
# So every band is the best thing available at its own level, and the ladder still points
# upward: band C carries you INTO raiding rather than past it.
BANDS = [
    ("A",  20, 2, 22, 16, 10, "",          10, None),        # 1-75    green
    ("B",  90, 3, 40, 33, 28, "Fine ",     12, None),        # 76-150  blue
    ("C", 165, 4, 56, 45, 42, "Grand ",    16, (7067, 2)),   # 151-225 epic, for the level 40s
    ("D", 245, 4, 71, 58, 71, "Hallowed ", 20, (7068, 4)),   # 226-300 epic, the real ones
]

# ---------------------------------------------------------------------------------------
# Stat flavours. "One per flavour per item type, doubled up where a class needs it."
#
# stat ids: 3 Agility, 4 Strength, 5 Intellect, 6 Spirit, 7 Stamina
# ---------------------------------------------------------------------------------------
FLAVOURS = {
    4: [  # plate
        ("Valor",   4, 7),   # Strength / Stamina  - warrior, retribution
        ("Bastion", 7, 4),   # Stamina / Strength  - protection
        ("Dawn",    5, 6),   # Intellect / Spirit  - holy paladin
    ],
    3: [  # mail
        ("Hunt",    3, 7),   # Agility / Stamina   - hunter
        ("Tempest", 4, 7),   # Strength / Stamina  - enhancement
        ("Tide",    5, 6),   # Intellect / Spirit  - restoration
    ],
    2: [  # leather
        ("Shadow",  3, 7),   # Agility / Stamina   - rogue, feral
        ("Grove",   5, 6),   # Intellect / Spirit  - restoration druid
    ],
    1: [  # cloth
        ("Runeweave", 5, 7), # Intellect / Stamina - caster damage
        ("Vestment",5, 6),   # Intellect / Spirit  - healer
    ],
}

ITEM_BASE  = 90400     # 90400 .. 90719
CRAFT_BASE = 43000     # 43000 .. 43319
TEACH_BASE = 43320     # 43320 .. 43639
SLA_BASE   = 7600      # 7600  .. 7919

# Rare reagents used by the top two bands, so the best gear needs more than bars.
RARE_VALUE = {7067: 400, 7068: 400}    # Elemental Earth, Elemental Fire


def grid():
    """Every item to generate, fully resolved."""
    out, n = [], 0
    for subclass in (4, 3, 2, 1):
        aname, skill, reagents, allowed = ARMOUR[subclass]
        for flavour, stat_a, stat_b in FLAVOURS[subclass]:
            for bi, (band, gate, quality, ilvl, req, budget, prefix, count, rare) in enumerate(BANDS):
                if band not in allowed:
                    continue
                primary = int(round(budget * 0.6))
                secondary = budget - primary
                reagent = reagents[bi]
                cost = count * MATERIAL_VALUE[reagent]
                if rare:
                    cost += rare[1] * RARE_VALUE[rare[0]]
                for inv, slotname in SLOTS:
                    out.append({
                        "n": n,
                        "item":  ITEM_BASE + n,
                        "craft": CRAFT_BASE + n,
                        "teach": TEACH_BASE + n,
                        "sla":   SLA_BASE + n,
                        "subclass": subclass,
                        "armour_name": aname,
                        "skill": skill,
                        "band": band,
                        "gate": gate,
                        "quality": quality,
                        "ilvl": ilvl,
                        "req": req,
                        "inv": inv,
                        "slot": slotname,
                        "flavour": flavour,
                        "stat_a": stat_a, "val_a": primary,
                        "stat_b": stat_b, "val_b": secondary,
                        "reagent": reagent, "count": count,
                        "rare": rare, "cost": cost,
                        "budget": budget,
                        "name": "%s%s %s" % (prefix, flavour, slotname),
                    })
                    n += 1
    return out
