# Combat Changes

## Durability ✅

**Repair is gone.** Nothing takes durability damage, nothing ever breaks, no repair bills.
A wipe costs you time, not money — which matters a great deal more when there are two of you
and no guild bank. `tuning-no-repair.sql`.

## Buffs ✅

**Battle Shout lasts 10 minutes** instead of 2 (`01-battle-shout-10min.sql`).

Worth knowing *how*, because it is the template for every duration change: a server-side
change alone cannot fix a tooltip. The client generates tooltip text from its own
`Spell.dbc`, so Battle Shout kept reading "2 min" even though the aura really lasted 10.
`DurationIndex` had to change on **both** sides.

## Thrown abilities ✅

Two, filed on the **spellbook tab** for their specialization — not in the talent tree.

| spell | ability | where |
|---|---|---|
| 38400 | **Heavy Throw** | Warrior Fury tab |
| 38403 | **Crippling Throw** | Warrior Fury tab |

Both carry custom icon art converted from PNG to BLP2 by the content pipeline
(`14-custom-icons.sql`).

A third, **Twin Throw**, was built and then removed (`09-remove-twin-throw.sql`) — it used a
double `TRIGGER_SPELL` that did not behave.

## Escape ✅

**Expeditious Retreat** (38000) — a warrior escape that increases movement speed, ending if
you are attacked. Trainable, via a proper teaching spell (38001).

> **Pattern worth copying:** a trainer entry cannot point at an ability directly.
> `npc_trainer.spell` must be a **teaching** spell (`SPELL_EFFECT_LEARN_SPELL`) whose trigger
> is the real ability. Pointing a trainer at an ability is rejected at load. Clone from a
> *real trainer wrapper* like 2754 — not a `Plans:` spell, which targets the caster and makes
> the NPC teach itself.

## Mounts

This is the part with the most surprising mechanics, and the part most likely to mislead you
if you reason from the server alone.

### What works ✅

| | behaviour |
|---|---|
| **Gathering** | Mine, herb and skin **without dismounting**. |
| **Any hostile ability** | Casting dismounts you and the spell fires. |
| **Being attacked** | Does **not** dismount you — riding away from a mob stays viable. |
| **World objects** | Chests, quest objects and signs no longer dismount you. |

### What does not, and cannot ⛔

**Melee auto-attack and direct object clicks.** While mounted, the client drops
`CMSG_ATTACKSWING` and `CMSG_GAMEOBJ_USE` **locally**, before the network layer. The server
never gets the chance to react, so no server-side change can reach them.

Measured from a session log: across two mounted windows the client sent nothing but
`MSG_MOVE_*`, and the session's only attack swing arrived **one second after** the mount aura
was removed with `AURA_REMOVE_BY_CANCEL` — the player had dismounted by hand first.

Two server-side fixes were built and shipped before this was measured, and both are
unreachable:

1. `AURA_INTERRUPT_FLAG_MELEE_ATTACK` on mount auras — unreachable because `Unit::Attack`
   refused mounted players outright, so no swing ever started. Reverted by `sql/20`.
2. Changing `Unit::Attack` to dismount instead of refuse — unreachable because the client
   refuses one layer higher. Kept, because it is correct for any path that does reach it.

The workaround is client-side: `TerapinTips/dismount.lua` hooks `AttackTarget()`, plus a
`/dismount` command and a keybinding. **Right-click on a mob cannot be intercepted** —
`TurnOrActionStart/Stop` are protected functions, and wrapping them breaks every right-click
including camera panning.

### The mechanism, in one table

The whole of mount behaviour follows from where the flag is set:

| `SPELL_ATTR_CASTABLE_WHILE_MOUNTED` | client sends the cast? | server dismounts? | result |
|---|---|---|---|
| neither side | ❌ no | — | **nothing happens** (the old behaviour for abilities) |
| **client only** | ✅ yes | ✅ yes | **dismount, then cast** ← how abilities work now |
| both sides | ✅ yes | ❌ no | **stay mounted** ← how gathering works |

The middle row is a deliberate client/server divergence. `21-interact-while-mounted.sql` and
`18-mount-management.sql` set the server side for gathering only; `content.py` sets the
client side for all 27,534 non-mount spells. **Adding a matching SQL file for those would
break the feature.**

## Boss loot ✅

Bosses drop **two guaranteed rare-or-better items** on top of their normal loot — see
[Small Group Play](Small-Group-Play#loot-that-works-for-two-people).

## Not changed

- **Per-player mob scaling** ⛔ — one creature is one level. There is no per-observer level
  in this core, and no amount of scripting changes that.
- **Arenas** ⛔ — there is no arena system in 1.12.
- **Battlegrounds and playerbots** — deliberately out of scope.
