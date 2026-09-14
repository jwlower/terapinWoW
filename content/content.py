"""TurtleMod content definitions.

Each entry describes a new spell as a CLONE of an existing one plus overrides. Cloning
matters: Spell.dbc has 173 fields and most of them are flags, indices and visual data we
have no reason to touch. Starting from a spell that already behaves the way we want and
changing only what differs is far safer than building a record from zero.

FIELD MAP - derived empirically, not guessed.
  The client's Spell.dbc does NOT share the server's SpellEntry layout (Mining's Effect1
  is at client field 61, not 21). The mapping below was produced by correlating every
  client field against the matching spell_template column across ~4000 spells and keeping
  only fields that agreed on every single one. See scratchpad/map_spell_fields.py.
"""

# client Spell.dbc field indices
F = {
    "Attributes": 6, "AttributesEx": 7,
    "CastingTimeIndex": 18, "RecoveryTime": 19,
    "AuraInterruptFlags": 22,
    "maxLevel": 27, "baseLevel": 28, "spellLevel": 29,
    "DurationIndex": 30, "manaCost": 32, "StackAmount": 39,
    # powerType 1 = rage. Throw (2764) is powerType 0 (mana), so without this the CLIENT
    # showed a mana cost on warrior thrown abilities even though the server charged rage.
    "powerType": 31,
    "rangeIndex": 36, "EquippedItemClass": 58,
    # Target-flag mask (TARGET_FLAG_ITEM etc). Index found by matching every field against
    # spell_template.Targets for 9 probe spells with distinctive values (16384/1026/16/0);
    # field 13 was the only one that agreed on all of them.
    "Targets": 13,
    "RequiresSpellFocus": 15,
    # Reagents live in the client DBC too - the 1.12 crafting window reads the mats out of
    # Spell.dbc, so if these disagree with spell_template the tooltip lists one set of
    # reagents while the server consumes another. Derived by the same all-or-nothing
    # correlation as the rest of this map (scratchpad/map_reagents.py): 2261 spells,
    # exactly one matching field each, no ambiguity.
    "reagent1": 42, "reagent2": 43, "reagent3": 44, "reagent4": 45,
    "reagentCount1": 50, "reagentCount2": 51, "reagentCount3": 52, "reagentCount4": 53,
    "effect1": 61, "effect2": 62, "effect3": 63,
    "basePoints1": 76, "basePoints2": 77, "basePoints3": 78,
    "target1": 82, "target2": 83,
    "EquippedItemSubClassMask": 59,   # 1<<16 = thrown; see sql/08
    "aura1": 91, "aura2": 92, "aura3": 93,
    "itemType1": 103,
    "misc1": 106, "misc2": 107, "misc3": 108,
    "trigger1": 109, "trigger2": 110, "trigger3": 111,
    "icon": 117,
    "name": 120,        # enUS; 121-127 are other locales, 128 is the name flags word
    "rank": 129,
    "desc": 138,
    "tooltip": 147,
    "family": 160,
}

# Durations are INDICES into SpellDuration.dbc, not milliseconds.
DURATION_6_SEC = 32          # verified: ID=32 base=6000

# AURA_INTERRUPT_FLAG_MELEE_ATTACK. Verified implemented at Unit.cpp:2561, where
# RemoveAurasWithInterruptFlags is called on `this` - the ATTACKER - at the end of
# AttackerStateUpdate. So the aura drops from whoever swung, which is what we want.
# AURA_INTERRUPT_FLAG_SPELL_ATTACK exists in the enum but has no implementation, so
# it is deliberately not used.
INTERRUPT_ON_MELEE = 0x00001000

SPELLFAMILY_WARRIOR = 4

# Edits to spells that ALREADY exist, applied to every matching record.
#
# Needed because a server-side change alone cannot fix a tooltip: the client generates
# tooltip text from its own Spell.dbc, so Battle Shout kept reading "2 min" even though
# the aura really lasted 10. Changing DurationIndex on the client side too makes the
# displayed duration match the actual one.
MODIFY = [
    {
        "match_name": "Battle Shout",
        "only_if": {"DurationIndex": 4},   # the ranks that apply the buff; the
                                           # LEARN_SPELL entries have DurationIndex 0
        "set": {"DurationIndex": 6},       # SpellDuration.dbc ID 6 = 600000 ms = 10 min
    },
]

# A trainer entry cannot point at an ability directly. npc_trainer.spell must be a
# TEACHING spell (SPELL_EFFECT_LEARN_SPELL, 36) whose trigger is the real ability -
# the same pattern as riding, where 33389 "Apprentice Riding" teaches 33388 "Riding".
# Pointing a trainer at the ability itself is rejected at load with:
#     Table `npc_trainer` for trainer (Entry: X) has non-learning spell Y, ignore
# so every new trainable ability needs this pair.
SPELLS = [
    {
        "id": 38001,
        "clone_from": 5243,          # "Battle Shout" rank-2 TEACHING spell (effect 36)
        "name": "Expeditious Retreat",
        "rank": "",
        "desc": "Teaches Expeditious Retreat.",
        "overrides": {
            "effect1": 36,           # SPELL_EFFECT_LEARN_SPELL
            "trigger1": 38000,       # ...teaches the ability below
            "effect2": 0, "effect3": 0,
            "aura1": 0, "aura2": 0, "aura3": 0,
            "basePoints1": 0,
            "family": SPELLFAMILY_WARRIOR,
            "baseLevel": 10,
            "spellLevel": 10,
            "DurationIndex": 0,
            "AuraInterruptFlags": 0,
            "RecoveryTime": 0,
            "manaCost": 0,
        },
    },
    {
        "id": 38003,
        # 2754 "Copper Mace" is a REAL trainer wrapper. 2760 "Plans: ..." is cast by the
        # recipe ITEM, and has effectImplicitTargetA1 = 1 (TARGET_UNIT_CASTER) - so when a
        # trainer cast it, the TRAINER learned the recipe instead of the player.
        "clone_from": 2754,
        "name": "Runed Copper Shield",
        "rank": "",
        "desc": "Teaches you how to make a Runed Copper Shield.",
        "overrides": {
            "effect1": 36,           # SPELL_EFFECT_LEARN_SPELL
            "trigger1": 38002,       # ...teaches the craft spell below
            "effect2": 0, "effect3": 0,
            "target1": 0,            # the trainer's target - i.e. you, not the trainer
        },
    },
    {
        "id": 38002,
        "clone_from": 2667,          # "Runed Copper Breastplate" - the CRAFT spell
        "name": "Runed Copper Shield",
        "rank": "",
        "desc": "Forges a Runed Copper Shield.",
        "overrides": {
            "effect1": 24,           # SPELL_EFFECT_CREATE_ITEM
            "itemType1": 90100,      # ...the shield
            "effect2": 0, "effect3": 0,
            "trigger1": 0,
            # Must match 05-craftable-shield.sql exactly. Left inherited from the clone
            # source these were 12 Copper Bar + 1 Shadowgem, so the crafting window would
            # have listed mats the server never consumes.
            "reagent1": 2840, "reagentCount1": 10,   # Copper Bar
            "reagent2": 774, "reagentCount2": 1,     # Malachite
            "reagent3": 0, "reagentCount3": 0,
            "reagent4": 0, "reagentCount4": 0,
        },
    },
    {
        "id": 38000,
        "clone_from": 2983,          # Sprint rank 1 - already +speed, self, instant
        "name": "Expeditious Retreat",
        "rank": "",
        "desc": "Increases movement speed by $s1% for $d. "
                "The effect ends if you attack.",
        "overrides": {
            "DurationIndex": DURATION_6_SEC,
            "AuraInterruptFlags": INTERRUPT_ON_MELEE,
            "basePoints1": 49,       # +50%: the aura amount is basePoints + 1
            "aura1": 31,             # SPELL_AURA_MOD_INCREASE_SPEED
            "effect1": 6,            # SPELL_EFFECT_APPLY_AURA
            "target1": 1,            # TARGET_UNIT_CASTER
            "family": SPELLFAMILY_WARRIOR,
            "baseLevel": 10,
            "spellLevel": 10,
            "RecoveryTime": 180000,  # 3 minute cooldown - it is an escape, not a sprint
            "manaCost": 0,
        },
    },
]


# Rows to append to OTHER client DBCs.
#
# SkillLineAbility.dbc is what tells the CLIENT which profession a recipe belongs to and
# at what skill it becomes available - without a row here the craft spell exists but never
# appears in the Blacksmithing window. The server does not read this DBC at all; it uses
# the skill_line_ability SQL table (ObjectMgr.cpp:7209), so both sides need their own copy.
#
# Field order is taken from the live file and verified against known rows at build time.
SKILL_LINE_ABILITY = [
    {
        "id": 7211,            # next free id (max existing 7210; column is SMALLINT)
        "skill": 164,          # Blacksmithing
        "spell": 38002,        # the craft spell
        "req_skill_value": 90, # same tier as Runed Copper Breastplate
        "min_value": 120,
        "max_value": 160,
    },
    {
        # Expeditious Retreat, filed under the warrior Protection line.
        #
        # NOT cosmetic - without this row the spell was invisible in the TRAINER window.
        # The server was sending it correctly the whole time (npc_trainer row loaded,
        # GetTrainerSpellState returns GREEN, the packet goes out), but the client groups
        # trainer entries by skill line and a spell belonging to no skill line has nowhere
        # to be drawn, so it is silently dropped. Every other custom spell here happened to
        # have a skill_line_ability row already, which is why this was the only one missing.
        "id": 7250,            # 7212-7249 are the generated test-content rows
        "skill": 257,          # Protection (warrior) - a real SkillLine.dbc class line
        "spell": 38000,
        "class_mask": 1,       # warrior only
        "req_skill_value": 0,
        "min_value": 0,
        "max_value": 0,
    },
]


# ---------------------------------------------------------------------------------------
# TEST CONTENT - generated from testcontent.py, the same tables that generate
# sql/06-test-content.sql. Never hand-write one side: a spell that exists on the server
# but not in the client DBC has no name, no icon and cannot be cast, and the reverse is a
# spell that appears in the spellbook and does nothing.
# ---------------------------------------------------------------------------------------
import testcontent as _tc   # noqa: E402

_sla_id = _tc.SLA_ID_BASE

for _ab, _te, _cls, _cmask, _trainer, _skill, _spec, _stat in _tc.class_spells():
    _name = _tc.spec_spell_name(_spec)
    SPELLS.append({
        "id": _ab,
        "clone_from": _tc.CLONE_CLASS_ABILITY,
        "name": _name,
        "rank": "",
        "desc": _tc.spec_spell_desc(_spec, _stat),
        "overrides": {
            "effect1": 6,            # SPELL_EFFECT_APPLY_AURA
            "aura1": 29,             # SPELL_AURA_MOD_STAT
            "misc1": _stat,          # 0 STR 1 AGI 2 STA 3 INT 4 SPI
            "basePoints1": 4,        # the aura amount is basePoints + 1 -> +5
            "effect2": 0, "effect3": 0,
            "aura2": 0, "aura3": 0,
            "basePoints2": 0, "basePoints3": 0,
            "family": _tc.FAMILY[_cls],
            "baseLevel": _tc.TRAIN_LEVEL,
            "spellLevel": _tc.TRAIN_LEVEL,
            "manaCost": 0,
        },
    })
    SPELLS.append({
        "id": _te,
        "clone_from": _tc.CLONE_TEACHER,
        "name": _name,
        "rank": "",
        "desc": "Teaches %s." % _name,
        "overrides": {
            "effect1": 36,           # SPELL_EFFECT_LEARN_SPELL
            "trigger1": _ab,
            "effect2": 0, "effect3": 0,
            "aura1": 0, "aura2": 0, "aura3": 0,
            "basePoints1": 0,
            "family": _tc.FAMILY[_cls],
            "baseLevel": _tc.TRAIN_LEVEL,
            "spellLevel": _tc.TRAIN_LEVEL,
            "DurationIndex": 0,
            "RecoveryTime": 0,
            "manaCost": 0,
        },
    })
    # class_mask keeps a Warrior's Arms Buff out of a Mage's spellbook.
    SKILL_LINE_ABILITY.append({
        "id": _sla_id, "skill": _skill, "spell": _ab,
        "req_skill_value": 0, "min_value": 0, "max_value": 0,
        "class_mask": _cmask, "race_mask": 0,
    })
    _sla_id += 1

for _cr, _te, _item, _skill, _prof, _trainer, _clone, _reagents in _tc.prof_spells():
    _iname = _tc.prof_item_name(_prof)
    _ov = {
        "effect1": 24,               # SPELL_EFFECT_CREATE_ITEM
        "itemType1": _item,
        "effect2": 0, "effect3": 0,
        "trigger1": 0,
    }
    # Must match the SQL exactly: the crafting window reads the mats from the client DBC,
    # the server consumes what spell_template says. RequiresSpellFocus is deliberately NOT
    # overridden - it comes from this profession's own recipe (fire for Cooking, forge for
    # Smelting and Jewelcrafting, nothing for Enchanting).
    for _n in range(1, 5):
        if _n <= len(_reagents):
            _ov["reagent%d" % _n] = _reagents[_n - 1][0]
            _ov["reagentCount%d" % _n] = _reagents[_n - 1][1]
        else:
            _ov["reagent%d" % _n] = 0
            _ov["reagentCount%d" % _n] = 0
    SPELLS.append({
        "id": _cr, "clone_from": _clone, "name": _iname, "rank": "",
        "desc": "Creates a %s." % _iname, "overrides": _ov,
    })
    SPELLS.append({
        "id": _te,
        "clone_from": _tc.CLONE_PROF_TEACHER,
        "name": _iname,
        "rank": "",
        "desc": "Teaches you how to make a %s." % _iname,
        "overrides": {
            "effect1": 36,
            "trigger1": _cr,
            "effect2": 0, "effect3": 0,
            "target1": 0,        # NOT 1 (caster): a trainer would teach itself
        },
    })
    SKILL_LINE_ABILITY.append({
        "id": _sla_id, "skill": _skill, "spell": _cr,
        "req_skill_value": _tc.CRAFT_SKILL, "min_value": 0, "max_value": 0,
        "class_mask": 0, "race_mask": 0,
    })
    _sla_id += 1


# ---------------------------------------------------------------------------------------
# BLACKSMITHING WEAPON COVERAGE - generated from weapons.py, the same table that generates
# sql/07-weapons.sql.
#
# Reagents MUST be set here as well as in the SQL: the 1.12 crafting window reads the mats
# out of the client's Spell.dbc, so a mismatch shows one set of reagents and consumes
# another.
# ---------------------------------------------------------------------------------------
import weapons as _wp   # noqa: E402

for _x in _wp.weapons():
    _ov = {
        "effect1": 24,               # SPELL_EFFECT_CREATE_ITEM
        "itemType1": _x["item"],
        "effect2": 0, "effect3": 0,
        "trigger1": 0,
        # Without this every recipe inherits icon 140 (Spell_Shadow_SealOfKings) - the
        # shadowy face every Blacksmithing craft spell in this database uses.
        "icon": _x["icon"],
    }
    for _n in range(1, 5):
        if _n <= len(_x["reagents"]):
            _ov["reagent%d" % _n] = _x["reagents"][_n - 1][0]
            _ov["reagentCount%d" % _n] = _x["reagents"][_n - 1][1]
        else:
            _ov["reagent%d" % _n] = 0
            _ov["reagentCount%d" % _n] = 0
    SPELLS.append({
        "id": _x["craft"], "clone_from": _wp.CLONE_CRAFT, "name": _x["name"], "rank": "",
        "desc": "Forges a %s." % _x["name"], "overrides": _ov,
    })
    SPELLS.append({
        "id": _x["teach"], "clone_from": _wp.CLONE_TEACH,
        "name": _x["name"], "rank": "",
        "desc": "Teaches you how to make a %s." % _x["name"],
        "overrides": {"effect1": 36, "trigger1": _x["craft"], "effect2": 0,
                      "effect3": 0, "target1": 0, "icon": _x["icon"]},
    })
    SKILL_LINE_ABILITY.append({
        "id": _x["sla"], "skill": _wp.BS_SKILL, "spell": _x["craft"],
        "req_skill_value": _x["skill"],
        "min_value": _x["skill"] + 15, "max_value": _x["skill"] + 50,
        "class_mask": 0, "race_mask": 0,
    })


# ---------------------------------------------------------------------------------------
# WARRIOR THROWN ABILITIES - the client half of sql/08-thrown-abilities.sql.
#
# All four clone Throw (2764), which already carries EquippedItemClass 2 +
# EquippedItemSubClassMask 65536 (1<<16, thrown). That requirement is therefore inherited,
# and the client renders "Requires Thrown" without us setting anything. Throw is family 8
# (rogue), so only the family is overridden.
# ---------------------------------------------------------------------------------------
_THROW = 2764
_TEACH = 5243

SPELLS.extend([
    {
        "id": 38400, "clone_from": _THROW, "name": "Heavy Throw", "rank": "",
        "desc": "Hurls your thrown weapon with great force, causing weapon damage "
                "plus $s1. Requires a thrown weapon.",
        "overrides": {
            "effect1": 58,               # SPELL_EFFECT_WEAPON_DAMAGE
            "basePoints1": 29,           # +30 (amount is points + 1)
            "effect2": 0, "effect3": 0,
            "family": 4, "baseLevel": 20, "spellLevel": 20,
            "RecoveryTime": 8000, "manaCost": 150, "powerType": 1,
        },
    },
    # Twin Throw (38401) and its hidden half (38402) were removed: two TRIGGER_SPELL
    # effects firing the same spell produced no damage numbers at all in game. See
    # sql/09-remove-twin-throw.sql. Those ids stay reserved rather than reused.
    {
        "id": 38403, "clone_from": _THROW, "name": "Crippling Throw", "rank": "",
        "desc": "Hurls your thrown weapon at the target's legs, causing weapon damage "
                "plus $s1 and slowing movement by $s2% for $d. Requires a thrown weapon.",
        "overrides": {
            "effect1": 58, "basePoints1": 4,
            "effect2": 6,                # SPELL_EFFECT_APPLY_AURA
            "aura2": 33,                 # SPELL_AURA_MOD_DECREASE_SPEED
            "basePoints2": -51,          # -50%
            "target2": 6,                # the same enemy the damage hits
            "effect3": 0,
            "DurationIndex": 31,         # SpellDuration.dbc 31 = 8000 ms
            "family": 4, "baseLevel": 22, "spellLevel": 22,
            "RecoveryTime": 15000, "manaCost": 100, "powerType": 1,
        },
    },
])

for _id, _name, _trig, _lvl in ((38410, "Heavy Throw", 38400, 20),
                                (38412, "Crippling Throw", 38403, 22)):
    SPELLS.append({
        "id": _id, "clone_from": _TEACH, "name": _name, "rank": "",
        "desc": "Teaches %s." % _name,
        "overrides": {
            "effect1": 36, "trigger1": _trig,
            "effect2": 0, "effect3": 0,
            "aura1": 0, "aura2": 0, "aura3": 0, "basePoints1": 0,
            "family": 4, "baseLevel": _lvl, "spellLevel": _lvl,
            "DurationIndex": 0, "RecoveryTime": 0, "manaCost": 0, "powerType": 1,
        },
    })

# Fury (256), warriors only. 38402 is absent on purpose.
# 38401/38402 (Twin Throw) removed - see sql/09-remove-twin-throw.sql.
for _sla, _spell in ((7280, 38400), (7282, 38403)):
    SKILL_LINE_ABILITY.append({
        "id": _sla, "skill": 256, "spell": _spell,
        "class_mask": 1, "race_mask": 0,
        "req_skill_value": 0, "min_value": 0, "max_value": 0,
    })


# ---------------------------------------------------------------------------------------
# FREE TELEPORTS FOR EVERY CLASS - the client half of sql/10-teleports-for-all.sql.
#
# These are EXISTING spells, so they are edited in place rather than cloned. Matching by id
# rather than by name is deliberate: "Teleport: Stormwind" is the name of BOTH the teleport
# (3561) and its LEARN_SPELL wrapper (665), and editing the wrapper would do nothing useful.
#
# Removing their skill_line_ability rows is what moves them to the GENERAL tab - General is
# the absence of a skill line, not a line of its own - and simultaneously drops the
# class_mask 128 (mage) gating.
# ---------------------------------------------------------------------------------------
TELEPORTS_ALLIANCE = [3561, 3562, 3565, 49361]   # Stormwind, Ironforge, Darnassus, Theramore
TELEPORTS_HORDE    = [3567, 3563, 3566, 49358]   # Orgrimmar, Undercity, Thunder Bluff, Stonard
TELEPORTS_ALL = TELEPORTS_ALLIANCE + TELEPORTS_HORDE

MODIFY.append({
    "label": "teleports (free)",
    "match_ids": set(TELEPORTS_ALL),
    "set": {
        "manaCost": 0,          # was 120
        "reagent1": 0,          # was 17031 Rune of Teleportation
        "reagentCount1": 0,
        "spellLevel": 1,        # was 20-30
        "baseLevel": 1,
    },
})

# Drop the mage-only Arcane rows so these land in General and lose their class gating.
SKILL_LINE_ABILITY_REMOVE = list(TELEPORTS_ALL)


# ---------------------------------------------------------------------------------------
# RECIPE ICONS - every trainer-taught recipe carries the icon of the item it makes.
#
# Generated by gen_recipe_icons.py, matching sql/12-recipe-icons.sql. See that script for
# why: no profession in this database had per-recipe icons, every one shared a placeholder.
# ---------------------------------------------------------------------------------------
import recipe_icons as _ri   # noqa: E402

MODIFY.append({
    "label": "recipe icons",
    "match_ids": set(s for s, _ in _ri.RECIPE_ICONS),
    "set": {},              # per-spell values are applied below, not uniformly
})
# MODIFY applies ONE set of values to every matched id, which cannot express "a different
# icon per spell". So the per-spell icons go through their own list that build.py walks.
MODIFY.pop()

SPELL_ICON_BY_ID = dict(_ri.RECIPE_ICONS)
SPELL_ICONS_ADD = _ri.SPELL_ICONS_ADD


# ---------------------------------------------------------------------------------------
# CUSTOM ICONS - PNG art converted to BLP2 and shipped inside patch-6.mpq.
#
# The client has no icon for these (checked against SpellIcon.dbc), so each needs a new
# SpellIcon.dbc row as well as the image itself. build.py does the conversion; the source
# PNGs live in TurtleMod/icons/ so the build does not depend on where the art pack sits.
#
# SpellIcon ids start above the highest the client ships (2523) AND above the 305 minted for
# recipe icons, so nothing can collide.
#
#   png    - relative to TurtleMod/
#   name   - becomes Interface\Icons\<name>.blp inside the patch
#   spells - every spell id that should use it
# ---------------------------------------------------------------------------------------
CUSTOM_ICONS = [
    {
        "id": 2900,
        "png": "icons/ShatteringThrow.png",
        "name": "Terapin_ShatteringThrow",
        "spells": [38400, 38410],      # Heavy Throw + its trainer wrapper
    },
    {
        "id": 2901,
        "png": "icons/ChilledToTheBone.png",
        "name": "Terapin_ChilledToTheBone",
        "spells": [38403, 38412],      # Crippling Throw + its trainer wrapper
    },
]


# ---------------------------------------------------------------------------------------
# SHIELDS - the client half of sql/15-shields.sql, generated from the same table.
#
# Blacksmithing made four shields in total, two of them item level 70, so nothing was
# craftable between roughly level 18 and 60. Three per tier on three axes fixes that.
# ---------------------------------------------------------------------------------------
import shields as _sh   # noqa: E402

for _x in _sh.shields():
    _ov = {
        "effect1": 24,               # SPELL_EFFECT_CREATE_ITEM
        "itemType1": _x["item"],
        "effect2": 0, "effect3": 0,
        "trigger1": 0,
        "icon": _x["icon"],
    }
    for _n in range(1, 5):
        if _n <= len(_x["reagents"]):
            _ov["reagent%d" % _n] = _x["reagents"][_n - 1][0]
            _ov["reagentCount%d" % _n] = _x["reagents"][_n - 1][1]
        else:
            _ov["reagent%d" % _n] = 0
            _ov["reagentCount%d" % _n] = 0
    SPELLS.append({
        "id": _x["craft"], "clone_from": _sh.CLONE_CRAFT, "name": _x["name"], "rank": "",
        "desc": "Forges a %s." % _x["name"], "overrides": _ov,
    })
    SPELLS.append({
        "id": _x["teach"], "clone_from": _sh.CLONE_TEACH, "name": _x["name"], "rank": "",
        "desc": "Teaches you how to make a %s." % _x["name"],
        "overrides": {"effect1": 36, "trigger1": _x["craft"], "effect2": 0, "effect3": 0,
                      "target1": 0, "icon": _x["icon"]},
    })
    SKILL_LINE_ABILITY.append({
        "id": _x["sla"], "skill": _sh.BS_SKILL, "spell": _x["craft"],
        "req_skill_value": _x["skill"],
        "min_value": _x["skill"] + 15, "max_value": _x["skill"] + 50,
        "class_mask": 0, "race_mask": 0,
    })


# ---------------------------------------------------------------------------------------
# SMELTING SKILL BANDS - the client half of sql/16-smelting-skill-bands.sql.
#
# min_value is where a recipe turns green, max_value where it turns grey. Five high smelting
# tiers shipped with min == max, so they went grey the moment they became usable and granted
# no skill-ups at all. The CLIENT colours the crafting window from its own DBC, so these have
# to match the SQL or the two disagree about what is worth smelting.
#
# build.py updates an existing SkillLineAbility row in place when it already has one for the
# spell, so these edit rather than append.
# ---------------------------------------------------------------------------------------
for _spell, _green, _grey, _skill in (
        (3307,  130, 165, 186),   # Smelt Iron
        (3569,  165, 210, 186),   # Smelt Steel
        (10097, 175, 230, 186),   # Smelt Mithril
        (10098, 230, 250, 186),   # Smelt Truesilver
        (14891, 230, 270, 186),   # Smelt Dark Iron
        (16153, 250, 290, 186),   # Smelt Thorium
        (57121, 300, 320, 186),   # Dreamsteel
):
    SKILL_LINE_ABILITY.append({
        "skill": _skill, "spell": _spell,
        "min_value": _green, "max_value": _grey,
        "req_skill_value": 1,
        "class_mask": 0, "race_mask": 0,
    })


# ---------------------------------------------------------------------------------------
# SALVAGE - the client half of sql/17-salvage.sql.
#
# Cloned from Disenchant so the item-targeting cursor, range and cast shape are inherited.
# The effect is switched to DUMMY; lua_scripts/salvage.lua does the actual work on
# PLAYER_EVENT_ON_SPELL_CAST.
#
# No SKILL_LINE_ABILITY entry on purpose - that keeps it in the General tab and ungated.
# ---------------------------------------------------------------------------------------
SPELLS.append({
    "id": 38600,
    "clone_from": 13262,         # Disenchant - already targets an item
    "name": "Salvage",
    "rank": "",
    "desc": "Breaks a weapon or piece of armour down into raw materials. "
            "Better items yield more. The item is destroyed.",
    "overrides": {
        "effect1": 3,            # SPELL_EFFECT_DUMMY
        "effect2": 0, "effect3": 0,
        "itemType1": 0,
        "trigger1": 0,
        "baseLevel": 1,
        "spellLevel": 1,
        "manaCost": 0,
        "powerType": 0,
        "RecoveryTime": 0,
        "reagent1": 0, "reagentCount1": 0,
        "reagent2": 0, "reagentCount2": 0,
        "EquippedItemClass": 0xFFFFFFFF,   # -1: no equipped-item requirement
        "RequiresSpellFocus": 0,
    },
})


# ---------------------------------------------------------------------------------------
# Gathering while mounted.
#
# SPELL_ATTR_CASTABLE_WHILE_MOUNTED (bit 24) is the ONE gate. Spell.cpp:5971 reads:
#
#     if (m_casterUnit->IsMounted() && m_casterUnit->IsPlayer() && !m_IsTriggeredSpell &&
#         !m_spellInfo->IsPassiveSpell() && !(Attributes & SPELL_ATTR_CASTABLE_WHILE_MOUNTED))
#         { Unmount(); RemoveSpellsCausingAura(SPELL_AURA_MOUNTED); }
#
# so setting the bit makes the server skip the dismount outright - there is no second
# dismount path to worry about. Every other Unmount() call site in src/game is a taxi
# landing, a GM command or a creature, and mount auras carry AuraInterruptFlags = 0
# (481 of 484 of them), so nothing strips the aura on cast either.
#
# The client generates its own "You can't do that while mounted" from ITS Spell.dbc, which
# is why the bit has to go in both places - sql/18 does the server side.
#
# ALL RANKS, because the client casts the highest rank you know. Missing one would make
# the feature quietly stop working the moment a player trained up.
#   mining  2575 2576 2577 2578 2579 3564 10248   (Attributes 65680 / 128)
#   herb    2366 2368 2369 2371 3570 11993        (Attributes 128)
#   skin    8613 8617 8618 10768                  (Attributes 16)
# Three different starting values is exactly why this uses or_set rather than set.
# ---------------------------------------------------------------------------------------
GATHERING_SPELLS = [
    2575, 2576, 2577, 2578, 2579, 3564, 10248,   # Mining
    2366, 2368, 2369, 2371, 3570, 11993,         # Herb Gathering
    8613, 8617, 8618, 10768,                     # Skinning
]

SPELL_ATTR_CASTABLE_WHILE_MOUNTED = 0x01000000

MODIFY.append({
    "label": "gather while mounted",
    "match_ids": set(GATHERING_SPELLS),
    "or_set": {"Attributes": SPELL_ATTR_CASTABLE_WHILE_MOUNTED},
})


# ---------------------------------------------------------------------------------------
# (Removed) "dismount on own swing" via AURA_INTERRUPT_FLAG_MELEE_ATTACK.
#
# The idea was sound - Unit.cpp:2561 processes that flag on the ATTACKER only - but it was
# UNREACHABLE for players. Unit::Attack (Unit.cpp:5265) refused outright for a mounted
# player, so no attack ever started and AttackerStateUpdate never ran. Setting the bit did
# nothing; you simply could not attack while mounted at all.
#
# That guard is now a dismount instead of a refusal (see terapin-core.patch), which handles
# it at attack INITIATION - better timing anyway. The flag would then be dead weight for
# players, and RemoveAurasWithInterruptFlags applies to any Unit, so leaving it set risked
# dismounting creatures that carry a mount aura. Reverted by sql/20.
# ---------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------
# Cast anything while mounted - and be dismounted for it.
#
# CLIENT-SIDE ONLY. There is deliberately NO SQL companion to this, and adding one would
# break the feature. The whole mechanism is the divergence:
#
#   client Spell.dbc  has SPELL_ATTR_CASTABLE_WHILE_MOUNTED -> the client SENDS the cast
#   server spell_template  does NOT                         -> Spell.cpp:5971 dismounts you
#
#         if (IsMounted() && IsPlayer() && !triggered && !passive &&
#             !(Attributes & SPELL_ATTR_CASTABLE_WHILE_MOUNTED))
#         { Unmount(); RemoveSpellsCausingAura(SPELL_AURA_MOUNTED); }
#
# so the spell goes off and you end up on foot, which is exactly the wanted behaviour.
#
# WHY THIS IS NEEDED
#   The client enforces the mounted restriction ITSELF, from its own copy of the attribute,
#   before anything reaches the network. Measured: Charge (11578) was cast at 16:31:58, one
#   second AFTER the mount aura was cancelled at 16:31:57 - the client had refused it while
#   mounted. In the same session Herb Gathering (2366) cast fine while mounted, because
#   sql/18 had set the bit for it. Same client, same session, opposite outcomes, one bit.
#
# MOUNTS ARE EXCLUDED
#   A mount spell with the bit set would let the client cast a mount while already mounted,
#   and the server would dismount-then-remount. Nothing good comes of that.
#
# Taxi flights stay safe without any special casing: the branch above checks IsTaxiFlying()
# first and returns SPELL_FAILED_NOT_ON_TAXI rather than dropping the player out of the sky.
# ---------------------------------------------------------------------------------------

SPELL_AURA_MOUNTED = 78


def _not_a_mount(rec, F):
    return SPELL_AURA_MOUNTED not in (rec[F["aura1"]], rec[F["aura2"]], rec[F["aura3"]])


MODIFY.append({
    "label": "cast while mounted (client only)",
    "match_where": _not_a_mount,
    "expect_at_least": 20000,        # ~28k records in this DBC, 484 of them mounts
    "or_set": {"Attributes": SPELL_ATTR_CASTABLE_WHILE_MOUNTED},
})


# ---------------------------------------------------------------------------------------
# Strongbox (38601) - open your bank from anywhere.
#
# The carried-inventory ceiling is 160 slots (a 16-slot backpack that cannot be resized,
# plus four bag slots at the 36-slot bag cap) and all three numbers are fixed player update
# field ranges. Rather than fight that, this reaches the 240-slot bank from wherever you are.
#
# NO CORE CHANGE NEEDED. WorldSession::CanUseBank (ItemHandler.cpp:1393) already has a
# bankerless mode:
#
#     bool isUsingBankCommand = (bankerGUID == GetPlayer()->GetObjectGuid() &&
#                                bankerGUID == m_currentBankerGUID);
#     if (!isUsingBankCommand) { ...require a real banker NPC in range... }
#
# so when the banker guid IS the player, the proximity check is skipped entirely. That is
# how the .bank GM command works (Commands.cpp:3664), and Eluna already exposes the call as
# Player:SendShowBank(worldobject). Passing the player themselves is the whole trick.
#
# Cloned from Salvage, which is already free, level 1, dummy-effect and reagentless - but
# retargeted at the caster, since Salvage inherits Disenchant's item-targeting cursor and
# this one takes no target at all.
# ---------------------------------------------------------------------------------------
SPELLS.append({
    "id": 38601,
    # NOT clone_from 38600: Salvage is created by this same build, so it is not in the
    # source DBC's index yet. Clone the same base Salvage does and repeat the overrides.
    "clone_from": 13262,         # Disenchant
    "name": "Strongbox",
    "rank": "",
    "desc": "Opens your bank from anywhere.",
    "overrides": {
        "effect1": 3,            # SPELL_EFFECT_DUMMY - bank.lua does the work
        "effect2": 0, "effect3": 0,
        "itemType1": 0,
        "trigger1": 0,
        "baseLevel": 1,
        "spellLevel": 1,
        "reagent1": 0, "reagentCount1": 0,
        "reagent2": 0, "reagentCount2": 0,
        "EquippedItemClass": 0xFFFFFFFF,   # -1: no equipped-item requirement
        "RequiresSpellFocus": 0,
        "Targets": 0,            # no TARGET_FLAG_ITEM: this takes no target
        "target1": 1,            # TARGET_UNIT_CASTER
        "target2": 0,
        "icon": 2311,            # INV_Misc_Bag_08
        "RecoveryTime": 0,
        "manaCost": 0,
        "powerType": 0,
    },
})
