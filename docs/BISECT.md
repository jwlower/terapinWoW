# Hunting the chase regression

## What we are doing

Creatures stopped chasing players somewhere between the **2026-08-23** prebuilt (working,
now running as `TortoiseNew`) and **2026-09-02** (`e21b68b`, confirmed broken). Eluna landed
2026-08-31, *inside* that window, so there is currently no build that has both working
chase and Lua scripting. Finding the offending commit gets us both.

`git bisect` is a binary search over commits: mark one good, one bad, and git checks out the
midpoint each round. Limiting it to the code that could plausibly matter —
`src/game/Movement/`, `src/game/Objects/`, `src/game/AI/` — cuts the range from 394 commits
to **48**, so roughly **6 rounds** instead of 9.

## The catch worth knowing up front

Your working server came from a **downloaded prebuilt**, not from a commit we built. So the
"good" end of the range is a guess: `5fb6339` (2026-08-22), the last commit before the
package date. **Round 0 is verifying that guess.** If mobs do not chase on `5fb6339` either,
the regression is older than we think and the whole range moves — better to find that out in
one build than after six.

## The test, each round

The build only swaps `mangosd.exe`. Your database, configs, maps and characters are
untouched, and the original binary is backed up before the first swap.

1. Stop the server.
2. Say so — the freshly built `mangosd.exe` gets copied into
   `TortoiseNew\TortoiseCompiledNew\server\`.
3. Start the server, log in.
4. Find an ordinary hostile mob — **not** an elite, not a critter, not a guard.
5. Pull it from ~20 yards, then back away.

| what happens | verdict |
|---|---|
| it runs after you and keeps closing | **good** |
| it aggros, turns to face you, but never closes the gap | **bad** |

On the broken build it also spams `targeted home` evades, so the mob tends to reset and walk
back. Either of those is a **bad**.

That verdict is the whole input — the range halves and the next build starts.

## Why each build is slow

The bisect commits mostly predate the Eluna merge, so these test builds have **no Lua** in
them. That is fine: we are hunting the movement bug, not testing Eluna. Once the culprit is
found and reverted, the final build is made from HEAD with `BUILD_ELUNA=ON` (already the
default in `CMakeLists.txt:43`) and you get both at once.

## Restoring

At any point, putting back the original binary is a file copy, and
`git bisect reset` in `source/` returns the tree to normal. Nothing here is one-way.

## Already ruled out — do not re-investigate

From the earlier diagnosis: spawn/movement data, nav mesh (`mmap.enabled` both ways), vmaps,
map data provenance, player position tracking, player combat reach, `leash_range`, GM flags,
creature speeds, creature AI assignment, and the playerbot module.

Reading the diff was tried first and did not settle it. The one promising hunk —
`Unit::UpdateSpeed` no longer scaling a snare by `ratio`, with a `0.01f` floor so a spline is
never rejected outright — turned out to be a **fix** for this exact symptom, landed 2026-08-29
inside the window. It is in the broken build already, so something else is responsible.

---

## Update: the bisect was pre-empted

Playerbots are being dropped entirely (the plan is to scale dungeons and raids to party
size instead). That makes a much cheaper experiment available than six bisect builds.

The earlier diagnosis ruled playerbots out by **disabling them in config** — which is not
the same as removing them from the build. The bot work edited *shared* core movement code;
the clearest case is `Unit::UpdateSpeed`, where the comment reads "ratio is the caller's
speed MULTIPLIER - the playerbots pass 10", sitting in the speed path every unit uses. A
config flag unloads bot *instances*, not bot *code*.

So: `e21b68b` — the confirmed-broken commit, which also contains the Eluna merge — rebuilt
with `BUILD_PLAYERBOTS=OFF`, `MODULE_MOD_PLAYERBOTS=disabled`, `BUILD_ELUNA=ON`.

* mobs chase -> regression was in the bot integration; no bisect needed, and Eluna arrives
  in the same build
* mobs still do not chase -> it is genuinely core, and the bisect resumes, but with every
  bot and dungeon-clear commit excluded from the range

Build artefacts: the new binary is 11,257,344 bytes, within 512 bytes of the TortoiseEluna
package — that package was evidently built the same way (Eluna on, playerbots off).

### State of the live server while testing this

* `mangosd.exe` replaced; original kept as `mangosd.exe.ORIGINAL-2026-08-23`
* `AiPlayerbot.Enabled = 0`
* Eluna config block appended to `mangosd.conf`, `Eluna.ScriptPath = "./lua_scripts"`
* `auto_join_guild.lua` and `auto_learn_class_spells.lua` moved to `lua_scripts_parked/`.
  They had never executed before (no Eluna in the old binary), and a script that grants
  class spells firing for the first time mid-test would muddy both results.
* `lua_scripts/00_eluna_alive.lua` prints a proof-of-life line at startup.
