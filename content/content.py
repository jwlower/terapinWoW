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
    # Required TOOL items. Not in any layout doc for this DBC - found by taking every record
    # with a non-zero field 40 and correlating against spell_template.totem1: 362 of 362
    # agreed. Field 41 is totem2.
    "totem1": 40, "totem2": 41,
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
def _is_craft_spell(rec, F):
    """A recipe that actually creates an item - not a trainer wrapper, not an enchant."""
    return rec[F["effect1"]] == 24 and rec[F["itemType1"]] > 0


MODIFY = [
    {
        "match_name": "Battle Shout",
        "only_if": {"DurationIndex": 4},   # the ranks that apply the buff; the
                                           # LEARN_SPELL entries have DurationIndex 0
        "set": {"DurationIndex": 6},       # SpellDuration.dbc ID 6 = 600000 ms = 10 min
    },
    {
        "label": "instant crafting",
        # ---------------------------------------------------------------------------
        # CastingTimeIndex is an INDEX into SpellCastTimes.dbc, not milliseconds. id=1
        # is the entry every truly-instant spell in the game already uses: base=0,
        # perLevel=0, minimum=0. This is what the little progress bar under "Create"
        # actually times, so setting it to 1 is the whole trick - no core change.
        #
        # NEITHER Category NOR RecoveryTime/categoryRecoveryTime is touched here.
        #   - 2698 of 2727 craft spells have Category 0 (no shared cooldown) already.
        #   - The 28 that carry a real RecoveryTime/categoryRecoveryTime are the same
        #     ones batch_crafting.lua refuses to batch - Transmute: Arcanite (48h),
        #     the Salt Shaker (72h). The cooldown IS the recipe; instant cast removes
        #     the few seconds of "casting...", not the 48 hours after it.
        #   - Category 31/310 on conjures and transmutes are per-family throttles
        #     unrelated to cast time, left exactly as they are.
        # ---------------------------------------------------------------------------
        "match_where": _is_craft_spell,
        "expect_at_least": 1500,
        "set": {"CastingTimeIndex": 1},
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
# Every vanilla class as a SkillLineAbility class mask: warrior, paladin, hunter, rogue,
# priest, shaman, mage, warlock, druid. Bit for class C is 1 << (C - 1).
#
# THIS MATTERS FOR SPELLBOOK TABS. A class mask of 0 does not mean "all classes" here - the
# client treats it as belonging to no class and files the spell under General. Heroic Strike
# carries classmask 1 and gets the Arms tab; Blacksmithing carries 0 and does not.
ALL_CLASSES = 1503

SKILL_LINE = []

# ---------------------------------------------------------------------------------------
# SkillRaceClassInfo.dbc - which races and classes a skill applies to.
#
# A SKILL WITH NO ROW HERE IS GRANTED BUT INVISIBLE. The server sets it, it saves to
# character_skills, and the skills window simply does not list it - the client uses this table
# to decide whether a skill applies to you at all. That is exactly what happened to
# Adventuring: SetSkill succeeded, the row was in the database at 1/64, and the panel was
# empty.
#
# Shaped after Survival (142), First Aid (129) and Cooking (185), which are the other
# everyone-can-have-it secondary skills:
#     race 2047  = all 11 races      class 1503 = all 9 classes
#     flags 128  = SKILL_FLAG_INCLUDE_IN_SORT, so its spells sort together in the spellbook
# ---------------------------------------------------------------------------------------
SKILL_RACE_CLASS = [
    {"id": 900, "skill": 795, "race_mask": 2047, "class_mask": 1503,
     "flags": 128, "req_level": 0, "tier": 63, "cost": 0,
     "note": "Adventuring - every race, every class"},
    # Professions is only a filing cabinet for the spellbook - nothing is granted under it -
    # but the row costs one line and its absence is exactly what made Adventuring invisible.
    {"id": 901, "skill": 796, "race_mask": 2047, "class_mask": 1503,
     "flags": 128, "req_level": 0, "tier": 63, "cost": 0,
     "note": "Professions tab - every race, every class"},
]

# ---------------------------------------------------------------------------------------
# Lock.dbc edits: what skill a gathering node demands before it will open.
#
# A harvestable node points at a Lock row, and that row says "this lock type, at this skill
# value". Client and server each read their own copy, so an edit here must be mirrored into
# server/dbc/Lock.dbc by patch_server_dbc.py - otherwise one side offers a node the other
# refuses.
# ---------------------------------------------------------------------------------------
LOCK_SKILL = [
    # The Simple Wood Tree - the first tree in Survival and the only one a new character can
    # reach - demanded skill 5 while Survival starts you at 1. So the very first tree anyone
    # meets was the one tree they could not chop. The rest of the ladder (125/175/225/250/270
    # on locks 1660-1664) is deliberately untouched.
    {"lock": 1665, "slot": 0, "required": 1,
     "note": "Simple Wood Tree - chopable from skill 1"},
]

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
        "icon": 335,             # Trade_BlackSmithing - the hammer-and-anvil icon
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


# ---------------------------------------------------------------------------------------
# Summonable services - one class-trainer call per class, plus a banker (38700-38710).
#
# Defined in summons.py and shared with gen_summons.py, so the client DBC and the server
# SQL cannot disagree about ids, names or icons.
#
# Class gating happens at the GRANT, not here: sql/23 teaches each class spell only to its
# own class. The DBC record itself is identical in shape for all ten.
# ---------------------------------------------------------------------------------------
import summons as _sm   # noqa: E402

for _sid, _name, _desc, _icon, _npc, _cid in _sm.all_spells():
    SPELLS.append({
        "id": _sid,
        "clone_from": _sm.CLONE_FROM,     # Disenchant, as Salvage and Strongbox use
        "name": _name,
        "rank": "",
        "desc": _desc,
        "overrides": {
            "effect1": 3,                 # SPELL_EFFECT_DUMMY - summon_services.lua spawns it
            "effect2": 0, "effect3": 0,
            "itemType1": 0,
            "trigger1": 0,
            "Targets": 0,                 # takes no target
            "target1": 1,                 # TARGET_UNIT_CASTER
            "target2": 0,
            "baseLevel": 1,
            "spellLevel": 1,
            "manaCost": 0,
            "powerType": 0,
            "RecoveryTime": 0,
            "reagent1": 0, "reagentCount1": 0,
            "reagent2": 0, "reagentCount2": 0,
            "EquippedItemClass": 0xFFFFFFFF,
            "RequiresSpellFocus": 0,
            "icon": _icon,
        },
    })


# ---------------------------------------------------------------------------------------
# Hide the 14 "Artisan <profession>" teaching spells from the spellbook.
#
# CLIENT-SIDE ONLY - this is a display flag and the server has no opinion on it.
#
# THE PROBLEM
#   Every new character starts with all 14 professions at Artisan. The grant that does that
#   (tuning-profession-ranks.sql) teaches the ARTISAN TEACHER - 9786 "Artisan Blacksmith" -
#   and the teacher then sits in the General tab as a castable spell that appears to let you
#   teach Artisan professions to yourself and other people.
#
# WHY NOT JUST GRANT THE TAUGHT SPELL INSTEAD
#   Because the skill ceiling comes from the teacher, not the taught spell:
#
#     9786 Artisan Blacksmith  effect1=36 LEARN_SPELL  effect2=44 SKILL_STEP  base=3
#     9785 Blacksmithing       effect1=47 TRADE_SKILL  effect2=118 SKILL      base=3
#
#   Player::addSpell CASTS a spell carrying SKILL_STEP, and Spell::EffectLearnSkill then
#   computes max = step * 75 = 300. The taught spell has SKILL (118), not SKILL_STEP (44),
#   so it is filed rather than cast, and Player.cpp:7505 falls back to
#   GetSkillMaxForLevel() - which at level 1 is 5. Granting 9785 alone would give every new
#   character Blacksmithing 1/5.
#
#   So the teacher must stay granted. It just does not have to be VISIBLE.
#
# SPELL_ATTR_HIDDEN_CLIENTSIDE (0x80, bit 7) is described in SpellDefines.h as "Spells with
# this attribute are not visible in spellbook or aura bar". The spell stays known, the skill
# stays at 300, and the clutter goes.
# ---------------------------------------------------------------------------------------
ARTISAN_TEACHERS = [
    9786,  10249, 10663, 10769,  # Blacksmithing, Mining, Leatherworking, Skinning
    10847,                        # First Aid
    11612, 11994, 12181, 12657,  # Alchemy, Herbalism, Tailoring, Engineering
    13921, 18249, 18261, 30227,  # Enchanting, Fishing, Cooking, Jewelcrafting
    46057,                        # Survivalist (Turtle custom)
]

SPELL_ATTR_HIDDEN_CLIENTSIDE = 0x00000080

MODIFY.append({
    "label": "hide artisan teachers",
    "match_ids": set(ARTISAN_TEACHERS),
    "or_set": {"Attributes": SPELL_ATTR_HIDDEN_CLIENTSIDE},
})


# ---------------------------------------------------------------------------------------
# Death challenges (38720, 38721) and truth-in-advertising for the two dead ones.
#
# The spells are PASSIVE + HIDDEN_CLIENTSIDE markers - never cast, only checked with
# Player:HasSpell by lua_scripts/death_challenges.lua. Opt in with `.learn 38720`.
#
# 57738 and 57746 are EXISTING Turtle challenges that do nothing on this build. Their
# descriptions are rewritten here as well as in sql/25, because the client builds tooltips
# from its OWN Spell.dbc - a server-side description change alone is invisible in game,
# the same trap that made Battle Shout keep reading "2 min".
# ---------------------------------------------------------------------------------------
_DEAD = "|cffff2020[NOT IMPLEMENTED ON THIS SERVER - this challenge has no effect]|r "

SPELLS.append({
    "id": 38720,
    "clone_from": 13262,
    "name": "Fragile",
    "rank": "",
    "desc": "On death, one random piece of equipped gear falls to your corpse. "
            "Retrieve it before it rots away.",
    "overrides": {
        "effect1": 0, "effect2": 0, "effect3": 0,
        "itemType1": 0, "trigger1": 0,
        "Targets": 0, "target1": 1, "target2": 0,
        "baseLevel": 1, "spellLevel": 1, "manaCost": 0, "powerType": 0,
        "RecoveryTime": 0,
        "reagent1": 0, "reagentCount1": 0, "reagent2": 0, "reagentCount2": 0,
        "EquippedItemClass": 0xFFFFFFFF, "RequiresSpellFocus": 0,
        # PASSIVE but NOT hidden. These are taught by the Challenge Master (2600401), and a
        # trainer-taught challenge should be visible in your spellbook so you can see which
        # ones you are carrying. 38722 "Unrestrained" stays hidden - it is an opt-out toggled
        # by chat, not something you buy.
        "Attributes": 64,
        "icon": 1662,               # INV_Misc_Bone_HumanSkull_01
    },
})
SPELLS.append({
    "id": 38721,
    "clone_from": 13262,
    "name": "Butterfingers",
    "rank": "",
    "desc": "On death, a share of the items in your bags falls to your corpse. "
            "Bags themselves are spared.",
    "overrides": {
        "effect1": 0, "effect2": 0, "effect3": 0,
        "itemType1": 0, "trigger1": 0,
        "Targets": 0, "target1": 1, "target2": 0,
        "baseLevel": 1, "spellLevel": 1, "manaCost": 0, "powerType": 0,
        "RecoveryTime": 0,
        "reagent1": 0, "reagentCount1": 0, "reagent2": 0, "reagentCount2": 0,
        "EquippedItemClass": 0xFFFFFFFF, "RequiresSpellFocus": 0,
        "Attributes": 64,
        "icon": 1662,
    },
})

# These two already exist in the DBC - build.py updates a present id in place, so
# clone_from is ignored and only the fields below are rewritten.
SPELLS.append({
    "id": 57738, "clone_from": 13262, "name": "Traveling Craftmaster", "rank": "",
    "desc": _DEAD + "Equip only what you craft. True power comes from your own hands.",
    "overrides": {},
})
SPELLS.append({
    "id": 57746, "clone_from": 13262, "name": "Path of the Brewmaster", "rank": "",
    "desc": _DEAD + "You gain no experience unless you are completely smashed.",
    "overrides": {},
})


# ---------------------------------------------------------------------------------------
# Dungeon mentor scaling (38722 marker + 38730..38747 ladder).
#
# Defined in scaling.py and shared with gen_scaling.py, so the client DBC and the server SQL
# cannot disagree. The ladder entries carry the aura effects only so the client can build a
# sensible tooltip - the server is what actually applies them.
# ---------------------------------------------------------------------------------------
import scaling as _sc   # noqa: E402

SPELLS.append({
    "id": _sc.MARKER_SPELL,
    "clone_from": _sc.CLONE_FROM,
    "name": _sc.MARKER_NAME,
    "rank": "",
    "desc": "Dungeon scaling will not be applied to you.",
    "overrides": {
        "effect1": 0, "effect2": 0, "effect3": 0,
        "itemType1": 0, "trigger1": 0,
        "Targets": 0, "target1": 1, "target2": 0,
        "baseLevel": 1, "spellLevel": 1, "manaCost": 0, "powerType": 0,
        "RecoveryTime": 0,
        "reagent1": 0, "reagentCount1": 0, "reagent2": 0, "reagentCount2": 0,
        "EquippedItemClass": 0xFFFFFFFF, "RequiresSpellFocus": 0,
        "Attributes": 64 | 128,          # PASSIVE | HIDDEN_CLIENTSIDE
    },
})

for _sid, _pct in _sc.steps():
    SPELLS.append({
        "id": _sid,
        "clone_from": _sc.CLONE_FROM,
        "name": "Mentor's Restraint",
        "rank": "%d%%" % _pct,
        "desc": "Your power is held back to suit this dungeon. Damage, healing and health "
                "reduced by %d%%." % _pct,
        "overrides": {
            "effect1": 6, "effect2": 6, "effect3": 6,      # APPLY_AURA x3
            "aura1": _sc.AURA_DAMAGE_DONE,
            "aura2": _sc.AURA_HEALING_DONE,
            "aura3": _sc.AURA_HEALTH_PCT,
            "basePoints1": (-(_pct + 1)) & 0xFFFFFFFF,
            "itemType1": 0, "trigger1": 0,
            "Targets": 0, "target1": 1, "target2": 0,
            "baseLevel": 1, "spellLevel": 1, "manaCost": 0, "powerType": 0,
            "RecoveryTime": 0,
            "reagent1": 0, "reagentCount1": 0, "reagent2": 0, "reagentCount2": 0,
            "EquippedItemClass": 0xFFFFFFFF, "RequiresSpellFocus": 0,
            "Attributes": 64,            # PASSIVE, but VISIBLE: you should see why you hit softer
            "DurationIndex": 21,         # infinite
            "icon": 2458,
        },
    })


# ---------------------------------------------------------------------------------------
# White Blacksmithing weapons - 132 craft spells + 132 trainer wrappers (39000-39331).
#
# Defined in white_weapons.py and shared with gen_white_weapons.py, so the client DBC and the
# server SQL cannot disagree about ids or names.
#
# Only the SPELLS need DBC entries. Item data is server-side in 1.12 - the client asks for it
# with SMSG_ITEM_QUERY_SINGLE_RESPONSE - which is why 132 new items need no client work at
# all, while their recipes do.
# ---------------------------------------------------------------------------------------
import white_weapons as _ww   # noqa: E402

_WW_CRAFT = 2660   # Rough Sharpening Stone - a real Blacksmithing craft spell
_WW_TEACH = 2754   # a real trainer wrapper; NOT a "Plans:" spell, which targets the caster

for _r in _ww.grid():
    SPELLS.append({
        "id": _r["craft"],
        "clone_from": _WW_CRAFT,
        "name": _r["name"],
        "rank": "",
        "desc": "Forges %s." % _r["name"],
        "overrides": {
            "effect1": 24,                       # SPELL_EFFECT_CREATE_ITEM
            "itemType1": _r["item"],
            "effect2": 0, "effect3": 0,
            "trigger1": 0,
            "reagent1": _r["bar"], "reagentCount1": _r["bars"],
            "reagent2": 0, "reagentCount2": 0,
        },
    })
    SPELLS.append({
        "id": _r["teach"],
        "clone_from": _WW_TEACH,
        "name": _r["name"],
        "rank": "",
        "desc": "Teaches you how to make %s." % _r["name"],
        "overrides": {
            "effect1": 36,                       # SPELL_EFFECT_LEARN_SPELL
            "trigger1": _r["craft"],
            "effect2": 0, "effect3": 0,
            "itemType1": 0,
        },
    })

# The CLIENT needs its own skill-line row for every craft spell. Without one the client
# silently drops the trainer entry while the server looks perfectly healthy - the exact trap
# documented in docs/SPELL-IDS.md. 132 rows, matching sql/27 exactly.
for _r in _ww.grid():
    SKILL_LINE_ABILITY.append({
        "id": _r["sla"], "skill": _ww.SKILL_BS, "spell": _r["craft"],
        "req_skill_value": _r["skill"],
        "min_value": min(_r["skill"] + 15, 300),
        "max_value": min(_r["skill"] + 40, 300),
        "class_mask": 0, "race_mask": 0,
    })


# ---------------------------------------------------------------------------------------
# (Removed) Challenge Master teaching wrappers 38723/38724.
#
# The trainer window came up EMPTY. The reason was already written in sql/17: a spell with no
# skill_line_ability row lives in the GENERAL tab, and "the client drops trainer entries filed
# under no skill line". Fragile and Butterfingers are General-tab spells by design, so a
# trainer can never sell them - the two are mutually exclusive on this client.
#
# Turtle solves this for its own Hardcore challenge with a QUEST: the Mysterious Stranger is
# a questgiver, and quest 80388 carries RewSpell = 50006. A quest reward has no skill-line
# requirement. sql/29 does the same with quests 80500/80501, so no client-side spells are
# needed here at all.
# ---------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------
# No tools, no workbenches - the CLIENT half.
#
# The client enforces both requirements from its own Spell.dbc, exactly as it does the
# mounted-cast restriction, so sql/30 alone would leave it refusing to start the cast.
#
# The two sides disagree about scope, which is why neither can be skipped: 912 server-side
# trade spells carried a tool, but only 362 records in the client DBC do. The id list is
# generated from the SERVER (gen_crafting_tools.py) and applied to both.
#
# expect_at_least is low on purpose: most of these 1041 ids have nothing to clear on the
# client side, and MODIFY by id would otherwise refuse the whole edit.
# ---------------------------------------------------------------------------------------
import crafting_tools as _ct   # noqa: E402

# match_where, not match_ids: the id list comes from the SERVER, and at least one of those
# spells does not exist in the client's Spell.dbc at all. match_ids asserts an exact count and
# correctly refuses a half-applied edit - which is the right behaviour for a hand-written list,
# but wrong here, where the two sides are legitimately not the same set.
_CT_SET = set(_ct.SPELLS_WITH_TOOLS)


def _is_trade_tool_spell(rec, F):
    return rec[0] in _CT_SET


MODIFY.append({
    "label": "no crafting tools/focus",
    "match_where": _is_trade_tool_spell,
    "expect_at_least": 1800,
    "set": {"totem1": 0, "totem2": 0, "RequiresSpellFocus": 0},
})


# ---------------------------------------------------------------------------------------
# Craftable armour - 272 craft spells + 272 trainer wrappers (43000-43591).
#
# Defined in gear.py and shared with gen_gear.py, so the client DBC and the server SQL cannot
# disagree about ids, names or reagents. Same division of labour as the white weapons above:
# only the SPELLS need DBC rows, because item data is answered by the server over
# SMSG_ITEM_QUERY_SINGLE_RESPONSE, so 272 new items need no client work and their 272 recipes
# need all of it.
#
# TOOLS ARE CLEARED HERE, NOT BY THE "no crafting tools/focus" BLOCK ABOVE. That block matches
# an id list generated from the server by gen_crafting_tools.py, and it was generated before
# these spells existed - so a new craft spell cloned from 2660 would inherit 2660's Blacksmith
# Hammer and be uncraftable away from a forge, which is precisely what sql/30 set out to end.
# ---------------------------------------------------------------------------------------
import gear as _gr   # noqa: E402

_GR_CRAFT = 2660   # Rough Sharpening Stone - a real Blacksmithing craft spell
_GR_TEACH = 2754   # a real trainer wrapper; NOT a "Plans:" spell, which targets the caster

for _r in _gr.grid():
    _rare, _rare_n = _r["rare"] if _r["rare"] else (0, 0)
    SPELLS.append({
        "id": _r["craft"],
        "clone_from": _GR_CRAFT,
        "name": _r["name"],
        "rank": "",
        "desc": "Creates %s." % _r["name"],
        "overrides": {
            "effect1": 24,                       # SPELL_EFFECT_CREATE_ITEM
            "itemType1": _r["item"],
            "effect2": 0, "effect3": 0,
            "trigger1": 0,
            "reagent1": _r["reagent"], "reagentCount1": _r["count"],
            "reagent2": _rare, "reagentCount2": _rare_n,
            "reagent3": 0, "reagentCount3": 0,
            "totem1": 0, "totem2": 0, "RequiresSpellFocus": 0,
        },
    })
    SPELLS.append({
        "id": _r["teach"],
        "clone_from": _GR_TEACH,
        "name": _r["name"],
        "rank": "",
        "desc": "Teaches you how to make %s." % _r["name"],
        "overrides": {
            "effect1": 36,                       # SPELL_EFFECT_LEARN_SPELL
            "trigger1": _r["craft"],
            "effect2": 0, "effect3": 0,
            "itemType1": 0,
            "totem1": 0, "totem2": 0, "RequiresSpellFocus": 0,
        },
    })

# One client-side skill-line row per craft spell, matching sql/33 exactly. Without it the
# client files the spell under no skill line and silently drops the trainer entry, while the
# server looks perfectly healthy - see docs/SPELL-IDS.md.
for _r in _gr.grid():
    SKILL_LINE_ABILITY.append({
        "id": _r["sla"], "skill": _r["skill"], "spell": _r["craft"],
        "req_skill_value": _r["gate"],
        "min_value": min(_r["gate"] + 20, 300),
        "max_value": min(_r["gate"] + 50, 300),
        "class_mask": 0, "race_mask": 0,
    })


# ---------------------------------------------------------------------------------------
# Adventuring - a new skill, and 63 inn teleports filed under it.
#
# Generated data lives in inns.py (gen_inn_data.py builds it from areatrigger_tavern,
# AreaTrigger.dbc and the creature table); gen_inns.py turns the same list into SQL, so the
# client and the server cannot disagree about ids or destinations.
#
# WHY A NEW SKILL LINE AT ALL
#   63 teleports in the General tab would bury everything else in it. A skill line is what
#   gives the client a tab to put them in - and it doubles as a completion meter, because the
#   skill value is the number of inns found.
#
# THE SKILL AND ITS SPELLS MUST BOTH BE HERE. A SkillLineAbility row pointing at a skill the
# client has never heard of is dropped exactly as silently as a spell with no row at all.
# ---------------------------------------------------------------------------------------
import inns as _in   # noqa: E402

SKILL_LINE.append({
    "id": _in.SKILL_ADVENTURING,
    "category": _in.SKILL_CATEGORY,          # 9 = secondary, so it costs no profession slot
    "name": "Adventuring",
    "description": "The roads you have walked, and the way back to them.",
})

_IN_CLONE = 3561   # Teleport: Stormwind - 10s cast, breaks on damage, no cooldown

for _r in _in.grid():
    _where = _r["town"] and ("%s, %s" % (_r["town"], _r["zone"])) or _r["zone"]
    if _r["lo"]:
        _desc = ("Teleport to %s in %s. The land around it suits levels %d to %d."
                 % (_r["inn"], _where, _r["lo"], _r["hi"]))
    else:
        _desc = "Teleport to %s in %s." % (_r["inn"], _where)
    SPELLS.append({
        "id": _r["spell"],
        "clone_from": _IN_CLONE,
        "name": _r["inn"],
        "rank": _r["zone"],                  # shows under the name in the spellbook
        "desc": _desc,
        "overrides": {
            "icon": 2179,                    # the hearthstone rune
            "manaCost": 0,
        },
    })
    SKILL_LINE_ABILITY.append({
        "id": 7900 + _r["spell"] - _in.SPELL_BASE,
        "skill": _in.SKILL_ADVENTURING, "spell": _r["spell"],
        "req_skill_value": 1, "min_value": 0, "max_value": 0,
        # class_mask MUST name the classes, and 0 is not "everyone" - it is "nobody".
        # A tabbed spell reads classmask=1 (Heroic Strike, warrior); Blacksmithing reads 0
        # and lands in General. 1503 is all nine vanilla classes.
        "class_mask": ALL_CLASSES, "race_mask": 0,
    })


# ---------------------------------------------------------------------------------------
# Adventuring, part two - 29 dungeon portals, earned at summoning stones.
#
# Same skill line as the inns above, so travel collects in one tab. Generated data lives in
# dungeon_portals.py; gen_dungeon_portals.py writes that, the SQL and the server's copy of the
# list from one pass, so none of the three can drift.
#
# The destination is the doorway OUTSIDE the instance, taken from AreaTrigger.dbc, not the
# position inside it that areatrigger_teleport carries. You still walk in.
# ---------------------------------------------------------------------------------------
import dungeon_portals as _dp   # noqa: E402

for _d in _dp.grid():
    SPELLS.append({
        "id": _d["spell"],
        "clone_from": 3561,                  # Teleport: Stormwind
        "name": _d["name"],
        "rank": "Dungeon",
        "desc": ("Teleport to the entrance of %s. The door requires level %d."
                 % (_d["name"], _d["req"])),
        "overrides": {
            "icon": 237,                     # Spell_Arcane_PortalStormwind
            "manaCost": 0,
        },
    })
    SKILL_LINE_ABILITY.append({
        "id": _dp.SLA_BASE + _d["spell"] - _dp.SPELL_BASE,
        "skill": _dp.SKILL_ADVENTURING, "spell": _d["spell"],
        "req_skill_value": 1, "min_value": 0, "max_value": 0,
        "class_mask": ALL_CLASSES, "race_mask": 0,
    })


# ---------------------------------------------------------------------------------------
# A Professions tab - REVERTED. It broke every profession opener except Enchanting's.
#
# The idea: file 96 profession spells (Blacksmithing, Mining, Smelting, First Aid, ...) under
# a new category-7 "Professions" skill line, moving them out of General the same way
# Adventuring got its own tab.
#
# WHAT ACTUALLY HAPPENED: re-pointing skill_line_ability.skill on a profession's OPENER spell
# (effect1 = 47, SPELL_EFFECT_TRADE_SKILL - Blacksmithing 2018, Enchanting 7411, etc.) away
# from its real profession skill broke the trade window for every one of them except
# Enchanting - and Enchanting's opener was moved by this code exactly the same way, so
# whatever it is surviving on is not something this block controls. Diagnosis was still in
# progress when this was reverted; the opener spells are NOT safe to re-file until it is
# understood. See EffectTradeSkill (Spell.cpp) as the likely next place to look - the window
# may be gated on the caster actually holding the skill the OPENER's own row claims, which
# nobody holds for skill 796.
#
# professions_tab.py (the generator) and gen_professions_tab.py are left in place - the 96
# spells identified as "belongs in a spellbook, not a recipe" is still correct and reusable
# once a re-filing approach is found that does not touch the opener spells' own routing.
# ---------------------------------------------------------------------------------------
# import professions_tab as _pt   # noqa: E402
#
# SKILL_LINE.append({
#     "id": _pt.SKILL_PROFESSIONS,
#     "category": _pt.SKILL_CATEGORY,
#     "name": "Professions",
#     "description": "Everything your trades let you do.",
# })
#
# for _spell, _name, _realskill in _pt.grid():
#     SKILL_LINE_ABILITY.append({
#         "skill": _pt.SKILL_PROFESSIONS,
#         "spell": _spell,
#         "class_mask": ALL_CLASSES,
#     })
