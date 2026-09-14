"""Summonable service NPCs: one class-trainer call per class, plus a banker.

Shared definition table for gen_summons.py (SQL) and content.py (client Spell.dbc).

WHY ONE SPELL PER CLASS AND NOT ONE SHARED SPELL
  A single "Call Class Trainer" would be less to maintain, but Creature::IsTrainerOf
  enforces an exact class match for TRAINER_TYPE_CLASS, so there are nine distinct NPCs
  regardless. Giving each class its own named spell costs one extra row per class and means
  a warrior sees "Call Warrior Master" rather than something generic.

WHY THE BANKER IS A SUMMON AND NOT JUST Strongbox (38601)
  Strongbox opens YOUR bank, for you, wherever you are - it is strictly simpler and you
  should normally use it. A summoned banker is a physical NPC, so in a duo one person can
  summon it and BOTH use it. That is the only thing it adds.

The banker NPC is custom (2600400) rather than a stock one because every stock banker is
faction-specific - Olivia Burnside is faction 12 (Alliance), Randolph Montague is 68
(Horde). Cloning 21002 gives faction 35, friendly to everyone.
"""

CLASS_TRAINERS = [
    # spell, class id, class name, trainer creature entry
    (38700,  1, "Warrior", 2600200),
    (38701,  2, "Paladin", 2600201),
    (38702,  3, "Hunter",  2600202),
    (38703,  4, "Rogue",   2600203),
    (38704,  5, "Priest",  2600204),
    (38705,  7, "Shaman",  2600205),
    (38706,  8, "Mage",    2600206),
    (38707,  9, "Warlock", 2600207),
    (38708, 11, "Druid",   2600208),
]

BANKER_SPELL    = 38710
BANKER_CREATURE = 2600400
BANKER_NAME     = "Call Banker"

# Services that are not class-gated. Same shape as the banker: one spell, one NPC, everyone
# gets it. Keep this list as the single source of truth - gen_summons.py writes both the SQL
# and the Lua lookup table from it, so the two cannot drift apart.
SERVICES = [
    (BANKER_SPELL, BANKER_CREATURE, BANKER_NAME,
     "Summons a banker for 5 minutes. Anyone nearby can use it.", 1657),
    (38711, 2600401, "Call Challenge Master",
     "Summons the Challenge Master for 5 minutes. She teaches the optional challenges.", 1662),
]

CLONE_FROM   = 13262    # Disenchant - the same base Salvage and Strongbox use
ICON_TRAINER = 319      # INV_Scroll_02
ICON_BANKER  = 1657     # INV_Misc_Note_02
DESPAWN_MS   = 300000   # 5 minutes


def spell_name(cls):
    return "Call %s Master" % cls


def all_spells():
    """[(spell_id, name, description, icon, creature_entry, class_id or None)]"""
    out = []
    for sid, cid, cname, npc in CLASS_TRAINERS:
        out.append((sid, spell_name(cname),
                    "Summons your %s Master for 5 minutes." % cname,
                    ICON_TRAINER, npc, cid))
    for sid, npc, nm, desc, icon in SERVICES:
        out.append((sid, nm, desc, icon, npc, None))
    return out
