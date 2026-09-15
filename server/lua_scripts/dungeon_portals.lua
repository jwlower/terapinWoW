-- Adventuring, part two: the summoning stone outside a dungeon gives you the way back to it.
--
--   Use any meeting stone and you learn a ten second teleport to that dungeon's door, filed in
--   the same Adventuring tab as the inns. `!portals` lists what you have found.
--
--   Inns are where you rest; dungeons are where you go. One skill covers both, so the tab
--   fills in as a record of everywhere you have actually been.
--
-- THE HOOK IS KEYED BY GAMEOBJECT ENTRY, WHICH IS WHY THE LIST IS GENERATED
--   Eluna::OnGameObjectUse (GameObjectHooks.cpp:137) does:
--       START_HOOK_WITH_RETVAL(GAMEOBJECT_EVENT_ON_USE, pGameObject->GetEntry(), false);
--   The binding key is the object's ENTRY, so a handler fires only for entries it was
--   registered against - there is no global "any gameobject" form. All 32 meeting stone
--   templates are registered individually, from the generated TerapinMeetingStones list.
--
-- WHY A MEETING STONE REACHES THE HOOK AT ALL
--   GameObject::Use calls sScriptMgr.OnGameObjectUse at GameObject.cpp:1496, BEFORE the switch
--   on object type at 1509. Nothing in the core lets you use a meeting stone alone, but the
--   hook runs before any of that, so a solo click still gets here.
--
-- THE HANDLER MUST RETURN FALSE
--   The hook is CallAllFunctionsBool and a true return means "handled, stop" - which would
--   break the stone's real summoning behaviour for anyone in a group. Learning a portal is a
--   side effect, never a replacement.
--
-- LOAD ORDER
--   ElunaLoader.cpp:338 sorts scripts by file path, and "dungeon_portal_targets" sorts BEFORE
--   "dungeon_portals" ('_' is 0x5F, 's' is 0x73). So unlike inn_discovery.lua, the generated
--   globals here ARE present when this chunk runs - which they must be, because registering an
--   entry-keyed hook cannot be deferred.

local STONE_RANGE = 1000      -- yards from the stone to the door it belongs to

local PLAYER_EVENT_ON_COMMAND     = 42

-- WHY ON_COMMAND AND NOT ON_CHAT
--   A message starting with '!' never reaches the chat hook. ChatHandler::ParseCommands
--   (Chat.cpp:1790) treats a leading '!' or '.' as a COMMAND and consumes it, so the original
--   version of this handler could never have fired - the player just got the core's own
--   "There is no such command".
--
--   PLAYER_EVENT_ON_COMMAND (42) is dispatched from the CHAT_COMMAND_UNKNOWN case at
--   Chat.cpp:1716, immediately BEFORE that message. Returning false marks the command handled
--   and suppresses it; returning true lets the core answer as usual, which is correct for any
--   command that is not ours. The text arrives with the '!' already stripped.

local GAMEOBJECT_EVENT_ON_USE  = 14

local SKILL_ADVENTURING = 795

local function Portals()
    return TerapinDungeonPortals or {}
end

-- ---------------------------------------------------------------------------------------
-- Finding one
-- ---------------------------------------------------------------------------------------

local function Known(player)
    local n = 0
    for _, d in ipairs(Portals()) do
        if player:HasSpell(d.spell) then
            n = n + 1
        end
    end
    return n
end

-- Keeps Adventuring's value equal to everything discovered, inns and dungeons together.
-- inn_discovery.lua owns the same skill, so this counts both rather than fighting it.
local function SyncSkill(player)
    local inns = TerapinInns or {}
    local total = #inns + #Portals()
    if total == 0 then
        return
    end
    local found = 0
    for _, i in ipairs(inns) do
        if player:HasSpell(i.spell) then found = found + 1 end
    end
    found = found + Known(player)
    player:SetSkill(SKILL_ADVENTURING, 0, found + 1, total + 1)
end

local function NearestDungeon(map, x, y, z)
    local best, bestD = nil, STONE_RANGE * STONE_RANGE
    for _, d in ipairs(Portals()) do
        if d.map == map then
            local dx, dy, dz = x - d.x, y - d.y, z - d.z
            local dd = dx * dx + dy * dy + dz * dz
            if dd < bestD then
                best, bestD = d, dd
            end
        end
    end
    return best
end

local function OnStoneUse(event, go, player)
    if not player then
        return false
    end

    local d = NearestDungeon(go:GetMapId(), go:GetX(), go:GetY(), go:GetZ())
    if d and not player:HasSpell(d.spell) then
        player:LearnSpell(d.spell)
        SyncSkill(player)
        player:SendBroadcastMessage(string.format(
            "|cff33ff99Adventuring:|r the way to |cffffffff%s|r is yours. "
            .. "|cff888888(the door requires level %d)|r", d.name, d.req))
        player:SendBroadcastMessage(string.format(
            "|cff888888%d of %d dungeon portals found.|r", Known(player), #Portals()))
    end

    -- Never swallow the click: a true return would stop the stone summoning anyone.
    return false
end

-- ---------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------

local function OnCommand(event, player, command)
    if not player or not command or string.lower(command) ~= "portals" then
        return true                               -- not ours; let the core answer
    end

    local all = Portals()
    local found = Known(player)
    player:SendBroadcastMessage(string.format(
        "|cff33ff99Adventuring:|r %d of %d dungeon portals found.", found, #all))
    if found == 0 then
        player:SendBroadcastMessage(
            "|cff888888Use the summoning stone outside any dungeon to keep the way back.|r")
        return false
    end
    for _, d in ipairs(all) do
        if player:HasSpell(d.spell) then
            player:SendBroadcastMessage(string.format(
                "  |cffffffff%s|r |cff888888(level %d)|r", d.name, d.req))
        end
    end
    return false
end

-- ---------------------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------------------

local stones = TerapinMeetingStones or {}
for _, entry in ipairs(stones) do
    RegisterGameObjectEvent(entry, GAMEOBJECT_EVENT_ON_USE, OnStoneUse)
end
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)

print(string.format("[Terapin] dungeon_portals.lua loaded - %d dungeons, %d stone template(s)",
                    #Portals(), #stones))
