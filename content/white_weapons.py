"""White (common) Blacksmithing weapons - one per weapon type per 5 levels.

WHY
  Measured against this database, Blacksmithing could make only 13 white weapons, ALL below
  level 25, and none at all for polearms, thrown or crossbows:

      1H Axe   bands 0,15     2H Axe   band 20     1H Mace  bands 0,15
      2H Mace  bands 10,20    1H Sword bands 0,15  2H Sword bands 5,20
      Fist     band 5         Dagger   band 5      Polearm/Thrown/Crossbow  none

  Greens and blues are well covered (186 and 88). It is the plain, cheap, make-it-yourself
  tier that stops existing almost immediately.

THE GRID
  11 weapon types x 12 bands (required level 5,10,...,60) = 132 items. Two bands per metal
  tier, the upper one prefixed "Heavy", so the tier ladder and the level ladder line up:

      req  5,10 -> Copper      req 35,40 -> Steel
      req 15,20 -> Bronze      req 45,50 -> Mithril
      req 25,30 -> Iron        req 55,60 -> Thorium

  item_level = required_level + 5, matching the shield convention in shields.py.

DAMAGE COMES FROM A REAL WEAPON, NOT FROM A FORMULA
  Each item clones the closest REAL weapon of the same subclass and item level, then has its
  stats stripped and its quality forced to white. That puts damage and speed on the curve the
  game already uses instead of inventing one - the same approach shields.py takes for armour
  and block values.

  Where no close source exists - polearms have NOTHING below item level 21 in this database -
  the generator falls back to the nearest available and scales damage by the item-level
  ratio. Those cases are reported when generating so they can be eyeballed.
"""

# subclass, noun, bars per craft at the lowest tier, two-handed, DPS family
#
# THE FAMILY IS WHAT SETS DAMAGE. Every weapon in a family shares one DPS curve for a given
# item level, and only SPEED differs between types - which is how vanilla actually works, and
# what keeps a Halberd comparable to a Greatblade of the same tier rather than to whatever
# happened to exist near its item level.
#
# Ranged is its own family on purpose: thrown and crossbows sit on a different curve from
# two-handed melee despite also occupying both hands.
TYPES = [
    (0,  "Hatchet",        4, False, "1h"),
    (1,  "Waraxe",         6, True,  "2h"),
    (4,  "Cudgel",         4, False, "1h"),
    (5,  "Sledge",         6, True,  "2h"),
    (6,  "Halberd",        6, True,  "2h"),
    (7,  "Shortblade",     4, False, "1h"),
    (8,  "Greatblade",     6, True,  "2h"),
    (13, "Grips",          3, False, "1h"),
    (15, "Dirk",           3, False, "1h"),
    (16, "Throwing Knife", 2, False, "ranged"),
    (18, "Handbow",        5, True,  "ranged"),
]

# required_level, tier name, bar entry, name prefix, craft skill required
BANDS = [
    (5,  "Copper",  2840,  "",      25),
    (10, "Copper",  2840,  "Heavy ", 50),
    (15, "Bronze",  2841,  "",      85),
    (20, "Bronze",  2841,  "Heavy ", 110),
    (25, "Iron",    3575,  "",      135),
    (30, "Iron",    3575,  "Heavy ", 155),
    (35, "Steel",   3859,  "",      175),
    (40, "Steel",   3859,  "Heavy ", 195),
    (45, "Mithril", 3860,  "",      215),
    (50, "Mithril", 3860,  "Heavy ", 235),
    (55, "Thorium", 12359, "",      255),
    (60, "Thorium", 12359, "Heavy ", 275),
]

ITEM_BASE  = 90200     # 90200 .. 90331
CRAFT_BASE = 39000     # 39000 .. 39131
TEACH_BASE = 39200     # 39200 .. 39331
SLA_BASE   = 7400      # 7400  .. 7531

ILVL_OFFSET = 5        # item_level = required_level + ILVL_OFFSET
SKILL_BS    = 164


def name_for(tier, prefix, noun):
    return "%s%s %s" % (prefix, tier, noun)


def grid():
    """[(index, subclass, noun, two_handed, req_level, ilvl, tier, bar, bars_needed, skill, name)]"""
    out = []
    n = 0
    for subclass, noun, base_bars, two_handed, family in TYPES:
        for bi, (req, tier, bar, prefix, skill) in enumerate(BANDS):
            out.append({
                "n": n,
                "item":  ITEM_BASE + n,
                "craft": CRAFT_BASE + n,
                "teach": TEACH_BASE + n,
                "sla":   SLA_BASE + n,
                "subclass": subclass,
                "noun": noun,
                "two_handed": two_handed,
                "family": family,
                "req": req,
                "ilvl": req + ILVL_OFFSET,
                "tier": tier,
                "bar": bar,
                # a couple more bars as the tiers climb, so higher whites are not free
                "bars": base_bars + (bi // 2),
                "skill": skill,
                "name": name_for(tier, prefix, noun),
            })
            n += 1
    return out
