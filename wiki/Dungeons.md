# Dungeons

Vanilla dungeons assume five people, a full evening, and a week between visits. All three
assumptions break for a duo. These changes address them.

## Bosses respawn, and lockouts are gone ✅

The two were never separate problems — **the lockout is derived from the respawn time.**

When you kill something in a dungeon, `Unit.cpp:1552` runs:

```cpp
pCreatureVictim->GetMap()->BindToInstanceOrRaid(
    playerKiller, pCreatureVictim->GetRespawnTimeEx(), ...);
```

and `Map::BindToInstanceOrRaid` (`Map.cpp:3529`) does:

```cpp
time_t resettime = objectResetTime + 2 * HOUR;
if (save->GetResetTime() < resettime)
    save->SetResetTime(resettime);
```

`GetRespawnTimeEx()` is the **absolute** time that creature will return. So killing a boss
whose respawn is 604800s (7 days) stamps the instance to reset in 7 days + 2 hours. Measured
against live data: Stockades instance 100 was stamped 6.74 days out — exactly 7d+2h from the
kill.

Bringing boss respawn times down therefore fixes **both**: bosses come back, and the instance
stops being locked for a week every time you clear it. `tuning-dungeon-respawn.sql`.

## One questgiver per dungeon ✅

A summonable NPC per dungeon that both **offers** and **accepts** every quest filed under
that dungeon — so you are not running back to three different cities to hand things in.

Built by matching `quest_template.ZoneOrSort` to the dungeon's zone id, then attaching each
quest twice (`creature_questrelation` to offer, `creature_involvedrelation` to turn in).

`ZoneOrSort` is how the game itself files a quest under a dungeon, and it gives realistic
counts — The Deadmines: 9. The obvious alternative, matching on "items that drop inside",
over-matches wildly: common drops like Linen Cloth are required by dozens of unrelated world
quests, which produced 45 for Deadmines and **239** for Dire Maul.

**Prerequisites still apply.** Attaching a quest here does not bypass its level, class, race
or prior-quest requirements — the core checks those when deciding what to show, so a quest
your character cannot take simply will not appear.

Sources: `setup-dungeon-questgivers.sql`, `setup-dungeon-questgivers-2.sql` (the dungeons the
first pass missed).

## Boss loot ✅

Bosses drop **two guaranteed rare-or-better items** on top of their normal loot — enough to
hand something to each of two or three people per kill. The mechanism is explained in
[Small Group Play](Small-Group-Play#loot-that-works-for-two-people).

## Mentor scaling ✅

Walk into a dungeon well above its level and your power is held back toward that dungeon's
level. Leave, and it is gone. A level 60 can run Ragefire Chasm with a level 15 friend
without trivialising it.

**Gear, talents and abilities are untouched.** What is reduced is damage done, healing done
and maximum health — by percentage. That distinction is the whole design: the obvious
implementation, `SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE`, reduces *total* stats, which includes
everything your gear gives you and makes good gear feel worthless. Your gear should still
feel great; only the numbers coming out the other end should be level-appropriate.

The target level is the dungeon's `areatrigger_teleport.required_level` **+ 10** — all 29
dungeons carry a usable value. The reduction is proportional to how far above it you are, so
it eases in rather than switching on hard, and is capped at 85% so a mentor is always clearly
stronger than the people they are helping:

| dungeon | target | L20 | L30 | L45 | L60 |
|---|---|---|---|---|---|
| Ragefire Chasm | 18 | −10% | −40% | −60% | **−70%** |
| Deadmines | 20 | — | −30% | −55% | −65% |
| Scarlet Monastery | 30 | — | — | −25% | −50% |
| Stratholme | 55 | — | — | — | −5% |

**Toggling it:** type `!scale` in say. Default is on. It works by learning or unlearning a
hidden marker spell, and the message is swallowed rather than broadcast.

*Two implementation notes.* Eluna's `AddAura` applies a **fixed** spell and there is no
binding to set an aura's magnitude at runtime, so the reduction is a ladder of 18 spells in
5% steps and the script picks the nearest one down. And `PLAYER_EVENT_ON_MAP_CHANGE` is **not
bridged** on this build — `ON_UPDATE_ZONE` is, and dungeons are their own zones, so that is
what triggers it. It is re-checked on login and on release too, so the scaling survives a
death, a disconnect, or a summon into the middle of an instance.

## What is not changed ⛔

**Mobs do not scale to party size.** One creature is one level — there is no per-observer
level in this core, so a dungeon cannot present itself as level 20 to one player and 45 to
another simultaneously. No amount of scripting changes that.

A narrower version is 🟨 achievable: adjusting a specific dungeon's creature levels or stats
outright, which changes them for everyone rather than per-player.
