# Eluna — what it takes to get it, and what it buys

## Where things stand

**The server you are running has no Eluna in it.** Checked directly rather than inferred:

```
TortoiseNew/.../mangosd.exe   0 Eluna symbols   (only a false positive, "eLunarTrigger")
TortoiseEluna/server/mangosd.exe   11 Eluna RTTI symbols  (.?AV?$El...)
```

Nothing in `info.log` mentions Lua either. The `lua_scripts/` folder sitting next to the
running server is a leftover copy from the TortoiseEluna build — those scripts are not
being executed, which is worth knowing on its own if anything was expected to depend on
`auto_learn_class_spells.lua`.

The source tree *does* have it, and it is on by default:

```
CMakeLists.txt:43   option(BUILD_ELUNA "Build the Eluna Lua scripting engine" ON)
CMakeLists.txt:45   set(ELUNA_LUA_VERSION "lua52" ...)
```

So this is purely a build question, not a "does this core support it" question.

## The catch

Eluna arrived in `80914fb  Merge pull request #5 from Nighthawk42/eluna`, dated
**2026-08-31**. The last known-good core is the **2026-08-23** prebuilt now running as
`TortoiseNew`. Every commit that contains Eluna therefore sits *inside* the window where
creatures stopped chasing players (see the `chase-regression-in-sep-2026-core` note —
mobs aggro, face you, melee when adjacent, but never close distance).

There is no build that currently has both. `TortoiseEluna` is dated 2026-09-08, well past
the break, so it almost certainly carries the chase bug — worth five minutes of testing to
confirm rather than assume.

## The way through

The regression window is small and the symptom is instant to test, so `git bisect` is the
proportionate tool — roughly five compiles:

```
cd tortoise-oneclick-compiler/source
git bisect start 80914fb <last-good-commit-on-or-before-2026-08-23>
# each step: build, start, /way to any mob, pull it, back up, see if it follows
```

Once the offending commit is identified it is either revertible on top of HEAD, or HEAD is
usable with that one change backed out. Then build with `BUILD_ELUNA=ON` (already the
default) and both problems are solved at once.

Full git history is present in `source/`, so nothing has to be re-fetched.

## What Eluna would actually unlock

Worth being precise, because it does **not** replace the DBC/SQL pipeline:

| want | Eluna helps? |
|---|---|
| a new spell appearing in the spellbook with a name and icon | **No** — still needs the client `Spell.dbc` row in patch-6.mpq |
| a new recipe in a crafting window | **No** — still needs `skill_line_ability` on both sides |
| a new item | **No** — `item_template` |
| *behaviour* — "buff a RANDOM stat", "on cast, do X", custom cooldown rules | **Yes** — this is the gap |
| custom commands, NPC gossip logic, events, quest hooks | **Yes** |
| iterating without a server restart | **Yes** — scripts reload |

The last row is the real prize for adding content regularly. The data layer still has to be
data; Eluna is what lets that data *do* something other than what the 2006 effect list
allows.

The one thing in the current test content that hit this wall is the "randomly buffs one
stat" spec buff — `SPELL_AURA_MOD_STAT` takes a single misc value and no effect in this
core picks at random, so each spec's buff currently raises one fixed stat. That becomes a
few lines of Lua the moment Eluna is running.
