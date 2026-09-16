-- Adventuring: walk into an inn and you keep the road back to it.
--
--   Every inn you visit teaches you a ten second teleport to that inn, filed in its own
--   Adventuring tab. No trainer, no cost - the only way to get one is to have stood there.
--
--   `!inns` lists what you have found and what is left.
--
-- WHY ON_UPDATE_AREA AND NOT THE TAVERN TRIGGER ITSELF
--   The inns ARE areatrigger_tavern rows, so the obvious hook is the area trigger - but no
--   area trigger hook is bridged to Eluna. ElunaScriptBridge.cpp has no OnAreaTrigger at all.
--
--   PLAYER_EVENT_ON_UPDATE_AREA (47) IS bridged, with (player, oldArea, newArea), and fires
--   on every subzone change - which is more than often enough, because you cannot reach an
--   inn's interior without crossing an area boundary on the way in. From there it is a
--   distance check against the 63 known inns on that map.
--
--   That also avoids needing to know which area id each inn sits in, which is terrain data
--   the server reads from .map files and SQL cannot see.
--
-- THE SKILL IS GRANTED ON LOGIN, NOT ON FIRST DISCOVERY
--   A spell whose skill line the character does not have is filed under nothing, and the
--   client quietly drops it - the same trap documented in docs/SPELL-IDS.md that left the
--   Challenge Master's trainer window empty. So Adventuring is handed out at login, before
--   any spell can arrive, and its maximum is the number of inns in the world so the skill
--   bar doubles as a completion meter.
--
-- WHY TerapinInns IS READ LAZILY
--   ElunaLoader.cpp:338 sorts scripts by file path. "inn_discovery" sorts before
--   "inn_targets", so the table does not exist when this chunk runs. Every use goes through
--   Inns() below, which reads the global at CALL time.

local DISCOVER_RANGE = 70      -- yards from the landing spot that counts as "you are here"

local PLAYER_EVENT_ON_LOGIN       = 3
local PLAYER_EVENT_ON_COMMAND        = 42

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

local PLAYER_EVENT_ON_UPDATE_AREA = 47

local function Inns()
    return TerapinInns or {}
end

local function Skill()
    return TerapinInnSkill or 795
end

-- ---------------------------------------------------------------------------------------
-- The skill itself
-- ---------------------------------------------------------------------------------------

local function Known(player)
    local n = 0
    for _, inn in ipairs(Inns()) do
        if player:HasSpell(inn.spell) then
            n = n + 1
        end
    end
    return n
end

-- Keeps the skill present and its value equal to the number of inns found.
local function SyncSkill(player)
    local total = #Inns()
    if total == 0 then
        return
    end
    local found = Known(player)
    -- SetSkill(id, step, currentValue, maxValue). A value of 0 would hide the line, so the
    -- floor is 1 - "you know about inns" - even before the first one is found.
    player:SetSkill(Skill(), 0, found + 1, total + 1)
end

-- ---------------------------------------------------------------------------------------
-- Finding one
-- ---------------------------------------------------------------------------------------

local function Discover(player, inn, why)
    player:LearnSpell(inn.spell)
    SyncSkill(player)

    local range = ""
    if inn.lo and inn.lo > 0 then
        range = string.format(" |cff888888(levels %d-%d)|r", inn.lo, inn.hi)
    end
    player:SendBroadcastMessage(string.format(
        "|cff33ff99Adventuring:|r you will remember |cffffffff%s|r, %s%s.%s",
        inn.name, inn.where, why and (" - " .. why) or "", range))
    player:SendBroadcastMessage(string.format(
        "|cff888888%d of %d inns found. The road back is in your Adventuring tab.|r",
        Known(player), #Inns()))
end

-- ---------------------------------------------------------------------------------------
-- Your home inn counts too
--
-- Binding at an innkeeper is the clearest possible statement that you know an inn, so it
-- should hand you the teleport even if walking in somehow did not - and it covers the inns
-- whose innkeeper stands further from the rest-spot than DISCOVER_RANGE.
--
-- THERE IS NO HOMEBIND HOOK. PLAYER_EVENT_ON_BIND_TO_INSTANCE is about instance saves, and
-- the bind itself happens through innkeeper gossip, which is not bridged to Eluna at all.
-- So the homebind is read from character_homebind instead: once at login, and at most every
-- HOME_CHECK_SECONDS on an area change. Bind at an inn and walking out the door claims it.
--
-- HOME_RANGE is wider than DISCOVER_RANGE on purpose: the bind point is wherever the
-- innkeeper happens to stand, which is not always where the teleport lands you.
-- ---------------------------------------------------------------------------------------
local HOME_RANGE = 150
local HOME_CHECK_SECONDS = 30

local lastHomeCheck = {}

local function HomeInn(player)
    local q
    local ok, res = pcall(function()
        return CharDBQuery(string.format(
            "SELECT map, position_x, position_y, position_z FROM character_homebind "
            .. "WHERE guid = %d", player:GetGUIDLow()))
    end)
    if not ok or not res then
        return nil                               -- no bind row yet, or the database is off
    end
    q = res

    local map = q:GetUInt32(0)
    local x, y, z = q:GetFloat(1), q:GetFloat(2), q:GetFloat(3)
    for _, inn in ipairs(Inns()) do
        if inn.map == map then
            local dx, dy, dz = x - inn.x, y - inn.y, z - inn.z
            if dx * dx + dy * dy + dz * dz <= HOME_RANGE * HOME_RANGE then
                return inn
            end
        end
    end
    return nil
end

-- Grants the home inn if it is not already known. Rate limited: this is the only part of
-- discovery that touches the database, and an area change is a frequent event.
local function CheckHome(player, force)
    local guid = player:GetGUIDLow()
    local now = GetGameTime()
    if not force and lastHomeCheck[guid] and now - lastHomeCheck[guid] < HOME_CHECK_SECONDS then
        return
    end
    lastHomeCheck[guid] = now

    local inn = HomeInn(player)
    if inn and not player:HasSpell(inn.spell) then
        Discover(player, inn, "you have made it your home")
    end
end

local function OnUpdateArea(event, player, oldArea, newArea)
    local map = player:GetMapId()
    local x, y, z = player:GetX(), player:GetY(), player:GetZ()
    for _, inn in ipairs(Inns()) do
        if inn.map == map and not player:HasSpell(inn.spell) then
            local dx, dy, dz = x - inn.x, y - inn.y, z - inn.z
            if dx * dx + dy * dy + dz * dz <= DISCOVER_RANGE * DISCOVER_RANGE then
                Discover(player, inn)
                return
            end
        end
    end
    CheckHome(player)
end

-- ---------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------

local function OnCommand(event, player, command)
    if not player or not command or string.lower(command) ~= "inns" then
        return true                               -- not ours; let the core answer
    end

    local all = Inns()
    local found = Known(player)
    player:SendBroadcastMessage(string.format(
        "|cff33ff99Adventuring:|r %d of %d inns found.", found, #all))

    if found == 0 then
        player:SendBroadcastMessage(
            "|cff888888Walk into any inn and you will remember the way back to it.|r")
        return false
    end

    for _, inn in ipairs(all) do
        if player:HasSpell(inn.spell) then
            local range = ""
            if inn.lo and inn.lo > 0 then
                range = string.format(" (%d-%d)", inn.lo, inn.hi)
            end
            player:SendBroadcastMessage(string.format(
                "  |cffffffff%s|r - %s%s", inn.name, inn.where, range))
        end
    end
    return false                                 -- handled
end

local function OnLogin(event, player)
    SyncSkill(player)
    CheckHome(player, true)      -- force: a bind made in an earlier session still counts
end

RegisterPlayerEvent(PLAYER_EVENT_ON_UPDATE_AREA, OnUpdateArea)
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)

print("[Terapin] inn_discovery.lua loaded - Adventuring skill " .. tostring(TerapinInnSkill or 795))
