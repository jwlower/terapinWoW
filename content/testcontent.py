"""Test content: one buff spell per class specialization, one craft recipe per profession.

SINGLE SOURCE OF TRUTH. Both halves of every spell are generated from the tables below:
  * the SERVER half  -> sql/06-test-content.sql   (written by gen_test_sql.py)
  * the CLIENT half  -> patch-6.mpq               (content.py imports this module)
Editing one by hand is how the two drift apart, so edit the tables and regenerate.

ID RANGE - READ TurtleMod/SPELL-IDS.md BEFORE CHANGING THESE.
  Spell ids must stay below 60000. SMSG_INITIAL_SPELLS packs them as uint16, so anything
  above 65535 silently arrives at the client as a DIFFERENT spell, and MAX_SPELL_ID (60000)
  makes Spell::cast bail out without a word. Everything here lives in the reserved 38xxx
  block. Item ids are NOT affected - those travel as uint32.
"""

# --------------------------------------------------------------------------------------
# ID allocation inside the reserved 38000-38999 block
# --------------------------------------------------------------------------------------
CLASS_ABILITY_BASE = 38100   # 38100-38126  the 27 buffs themselves
CLASS_TEACHER_BASE = 38150   # 38150-38176  their LEARN_SPELL wrappers
PROF_CRAFT_BASE    = 38200   # 38200-38210  the 11 craft spells
PROF_TEACHER_BASE  = 38220   # 38220-38230  their LEARN_SPELL wrappers
PROF_ITEM_BASE     = 90101   # 90101-90111  the items they create (uint32, unrestricted)
SLA_ID_BASE        = 7212    # skill_line_ability.id is SMALLINT UNSIGNED; 7211 is in use

# Clone sources. Cloning beats building a record from zero: Spell.dbc has 173 fields and
# spell_template has over 200, nearly all of them flags and indices we have no reason to
# reason about. Start from something that already behaves correctly.
CLONE_CLASS_ABILITY = 1243   # Power Word: Fortitude rank 1 - APPLY_AURA / MOD_STAT on an ally
CLONE_TEACHER       = 5243   # Battle Shout rank 2 TEACHER - effect 36 LEARN_SPELL
CLONE_PROF_TEACHER  = 2754   # "Copper Mace" - a real TRAINER wrapper. 2760 "Plans: ..." is
                             # cast by the recipe ITEM (target 1 = CASTER), so a trainer
                             # casting it teaches itself, not the player.

# SPELL_AURA_MOD_STAT misc values. HandleAuraModStat (SpellAuras.cpp:4615) accepts -2..4.
STATS = ["Strength", "Agility", "Stamina", "Intellect", "Spirit"]

# SpellFamilyName
FAMILY = {"Warrior": 4, "Paladin": 10, "Hunter": 9, "Rogue": 8, "Priest": 6,
          "Shaman": 11, "Mage": 3, "Warlock": 5, "Druid": 7}

# --------------------------------------------------------------------------------------
# Class specializations.
#
# The spec names and skill ids are REAL SkillLine.dbc rows (category 7 = class skills),
# read out of the client's own patch-5.mpq - they are not invented. Filing a spell under
# one of these skill lines is what puts it on that tab in the spellbook; the client builds
# its tab list from the skill lines its known spells belong to.
#
#   class          classmask  trainer   (spec skill id, spec name)
# --------------------------------------------------------------------------------------
CLASSES = [
    ("Warrior", 1,    1, 2600200, [(26, "Arms"), (256, "Fury"), (257, "Protection")]),
    ("Paladin", 2,    2, 2600201, [(594, "Holy"), (267, "Protection"), (184, "Retribution")]),
    ("Hunter",  3,    4, 2600202, [(50, "Beast Mastery"), (163, "Marksmanship"), (51, "Survival")]),
    ("Rogue",   4,    8, 2600203, [(253, "Assassination"), (38, "Combat"), (39, "Subtlety")]),
    ("Priest",  5,   16, 2600204, [(613, "Discipline"), (56, "Holy"), (78, "Shadow Magic")]),
    ("Shaman",  7,   64, 2600205, [(375, "Elemental Combat"), (373, "Enhancement"), (374, "Restoration")]),
    ("Mage",    8,  128, 2600206, [(237, "Arcane"), (8, "Fire"), (6, "Frost")]),
    ("Warlock", 9,  256, 2600207, [(355, "Affliction"), (354, "Demonology"), (593, "Destruction")]),
    ("Druid",  11, 1024, 2600208, [(574, "Balance"), (134, "Feral Combat"), (573, "Restoration")]),
]

TRAIN_LEVEL = 2
TRAIN_COST  = 100      # 1 silver - it is a test spell, not a gold sink

# --------------------------------------------------------------------------------------
# Professions.
#
# clone_from is each profession's own lowest-tier CREATE_ITEM recipe, found by querying
# skill_line_ability for the minimum req_skill_value. Cloning the profession's OWN recipe
# is what carries the correct RequiresSpellFocus across - Cooking needs a fire (focus 4),
# Smelting and Jewelcrafting need a forge (focus 3), Enchanting needs nothing. Getting that
# wrong makes a recipe that can never be cast, with no useful error.
#
#   skill, name, trainer, clone_from, [(reagent, count), ...]
# --------------------------------------------------------------------------------------
# REMOVED - the per-profession Test Tokens were scaffolding and are gone; see
# sql/11-remove-test-tokens.sql. The table is kept empty rather than deleted so
# prof_spells() still works and a future profession recipe has an obvious home.
PROFESSIONS = []

CRAFT_SKILL     = 5        # "at skill level 5", as asked
CLONE_PROF_ITEM = 2589     # Linen Cloth - a plain trade good, no equip slot to get wrong
PROF_ITEM_QUALITY = 2      # uncommon, so it stands out in the bag as a test item


def _stat_for(index):
    """Assign a stat per spec.

    Deliberately NOT random at cast time - see the note in gen_test_sql.py. Spell data has
    no way to express "pick one at random"; that needs a script, and this core has no live
    Eluna. Spreading the stats deterministically across the 27 specs at least exercises
    every value of the MOD_STAT misc field.
    """
    return index % len(STATS)


def class_spells():
    """(ability_id, teacher_id, class_name, classmask, trainer, skill_id, spec, stat)."""
    out, i = [], 0
    for cname, _cid, cmask, trainer, specs in CLASSES:
        for skill_id, spec in specs:
            out.append((CLASS_ABILITY_BASE + i, CLASS_TEACHER_BASE + i,
                        cname, cmask, trainer, skill_id, spec, _stat_for(i)))
            i += 1
    return out


def prof_spells():
    """(craft_id, teacher_id, item_id, skill, prof, trainer, clone_from, reagents)."""
    out = []
    for j, (skill, pname, trainer, clone, reagents) in enumerate(PROFESSIONS):
        out.append((PROF_CRAFT_BASE + j, PROF_TEACHER_BASE + j, PROF_ITEM_BASE + j,
                    skill, pname, trainer, clone, reagents))
    return out


def spec_spell_name(spec):
    return "%s Buff" % spec


def spec_spell_desc(spec, stat):
    return ("This is the %s test custom spell. Buffs %s by 5 points."
            % (spec, STATS[stat]))


def prof_item_name(prof):
    return "%s Test Token" % prof
