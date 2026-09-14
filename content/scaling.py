"""Dungeon mentor scaling - shared definition for gen_scaling.py and content.py.

WHAT IT IS
  When a character walks into a dungeon well above its level, their output is scaled down
  toward that dungeon's level so a level 60 can run Ragefire Chasm with a level 15 friend
  without trivialising it. It reverts the moment they leave.

WHAT IS REDUCED, AND WHY NOT STATS
  Damage done, healing done and maximum health - by percentage, via three aura effects on
  one spell:

      79   SPELL_AURA_MOD_DAMAGE_PERCENT_DONE
      136  SPELL_AURA_MOD_HEALING_DONE_PERCENT
      133  SPELL_AURA_MOD_INCREASE_HEALTH_PERCENT

  The tempting alternative, SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE (137), reduces TOTAL stats
  - which includes everything the player's gear contributes. That makes good gear feel
  worthless, which is the opposite of the point: the gear should still feel great, the
  numbers coming out the other end should just be level-appropriate.

WHY A LADDER OF SPELLS
  Eluna's Unit:AddAura applies a FIXED spell; there is no binding to set an aura's magnitude
  at runtime. So the reduction is quantised into 5% steps and the script picks the nearest.

THE BASE POINTS CONVENTION
  SpellEntry::CalculateSimpleValue is EffectBasePoints + EffectBaseDice, and these spells use
  a dice of 1. So a -40% aura needs basePoints = -41. Confirmed against a stock spell:
  "Tamed Pet Passive (DND)" (7000) carries basePoints -11 / dice 1 for -10% damage.
"""

MARKER_SPELL = 38722          # known = scaling is DISABLED for this player (opt-out)
MARKER_NAME  = "Unrestrained"

FIRST_SPELL  = 38730          # 38730..38747 -> 5% .. 90%
STEP         = 5
MAX_REDUCTION = 90

CLONE_FROM   = 13262          # Disenchant, as with the other custom spells
ICON         = 2458           # placeholder, overridden below if resolved

AURA_DAMAGE_DONE   = 79
AURA_HEALING_DONE  = 136
AURA_HEALTH_PCT    = 133

# How far above a dungeon's entry requirement counts as "the right level for it". Ragefire
# Chasm requires level 8; +10 puts its target at 18, which is where it actually plays.
TARGET_OFFSET = 10

# Never reduce beyond this. A mentor should be clearly stronger than the people they are
# helping - just not so much that nothing else in the room matters.
REDUCTION_CAP = 85


def steps():
    """[(spell_id, reduction_percent)] - the ladder, weakest first."""
    out = []
    pct = STEP
    sid = FIRST_SPELL
    while pct <= MAX_REDUCTION:
        out.append((sid, pct))
        sid += 1
        pct += STEP
    return out


def reduction_for(player_level, dungeon_required_level):
    """The percentage to shave off, or 0 when no scaling applies.

    Proportional to how far above the dungeon the character is, so it eases in rather than
    switching on hard at one level. A 60 in Ragefire (target 18) loses (60-18)/60 = 70%;
    a 25 in the same place loses 28%; a 60 in a target-55 dungeon loses 8%.
    """
    target = dungeon_required_level + TARGET_OFFSET
    if player_level <= target:
        return 0
    pct = int(((player_level - target) * 100) / player_level)
    if pct > REDUCTION_CAP:
        pct = REDUCTION_CAP
    # quantise DOWN to a step we actually have a spell for
    pct = (pct // STEP) * STEP
    return pct
