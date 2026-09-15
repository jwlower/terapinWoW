-- "Old School" (38725): death takes everything, and the walk back is the only way to get any
-- of it returned.
--
--   on death        every item in every bag, and everything equipped, is destroyed
--   spirit healer   you also lose all progress toward your next level
--   corpse run      you recover FOUR random pieces of the gear you were wearing
--
-- Taken as a quest from the Challenge Master (2600401). Dropped with `!oldschool` in say.
-- Replaces the earlier Fragile and Butterfingers challenges.
--
-- WHY THE PREVIOUS VERSION SILENTLY DID NOTHING
--   The corpse chest never appeared and it was NOT the GameObject hook. `Eluna.UseUnsafeMethods`
--   was false in mangosd.conf, CharDBQuery is flagged unsafe, and the script aborted the moment
--   it touched the database - failing quietly in game with the only trace in ElunaErrors.log.
--   That config is now true. If this feature ever goes quiet again, read that log FIRST.
--
-- WHY THE WORK HAPPENS ON RELEASE, NOT ON DEATH
--   PLAYER_EVENT_ON_REPOP (35) fires from OnPlayerReleasedGhost - a clean, player-initiated
--   packet. Death itself is mid-update, and destroying items there is the lifetime trap that
--   crashed salvage.lua: Player::DestroyItem ends in SetState(ITEM_REMOVED), and Item::SetState
--   deletes an ITEM_NEW item outright, leaving the running code holding freed memory.
--
-- HOW A CORPSE RUN IS TOLD FROM A SPIRIT HEALER
--   There is no bridged resurrect hook - OnResurrect does not appear anywhere in
--   ElunaScriptBridge.cpp. So the death position is recorded and a timer watches until the
--   player is alive again, then measures the distance. Resurrecting at your corpse puts you on
--   it; a spirit healer leaves you at the graveyard.
--
-- WHY SetLevel IS HOW XP IS WIPED
--   Eluna's GetXP is METHOD_REG_NONE - not implemented - so the current value cannot even be
--   read, and GiveXP only adds. But LuaUnit::SetLevel (UnitMethods.h:1275) does:
--       player->GiveLevel(newlevel); player->InitTalentForLevel();
--       player->SetUInt32Value(PLAYER_XP, 0);
--   so setting the level to the level you already have zeroes XP without delevelling you.

local OLD_SCHOOL = 38725

local RECOVER_COUNT   = 4        -- pieces of worn gear waiting at your corpse
local CORPSE_RANGE    = 40       -- yards; within this counts as "you walked back"
local WATCH_INTERVAL  = 2000     -- ms between checks for having resurrected
local WATCH_GIVEUP    = 1800     -- seconds before we stop watching (30 minutes)

local BACKPACK_BAG = 255
local EQUIP_FIRST, EQUIP_LAST       = 0, 18     -- EQUIPMENT_SLOT_START..END
local BACKPACK_FIRST, BACKPACK_LAST = 23, 38   -- INVENTORY_SLOT_ITEM_START..END
local BAG_FIRST, BAG_LAST = 19, 22             -- the four equipped bag containers
local MAX_BAG_SLOTS = 36

local ITEM_CLASS_CONTAINER = 1

local PLAYER_EVENT_ON_LOGIN = 3
local PLAYER_EVENT_ON_COMMAND  = 42

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

local PLAYER_EVENT_ON_REPOP = 35

-- ---------------------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------------------

local function ClearPending(guid)
    CharDBExecute(string.format(
        "DELETE FROM terapin_corpse_chest WHERE player_guid = %d", guid))
end

local function StorePending(guid, map, x, y, z, items)
    ClearPending(guid)
    for i = 1, #items do
        CharDBExecute(string.format(
            "INSERT INTO terapin_corpse_chest (player_guid, item_entry, item_count, map, pos_x, pos_y, pos_z) "
            .. "VALUES (%d, %d, %d, %d, %f, %f, %f)",
            guid, items[i][1], items[i][2], map, x, y, z))
    end
end

-- Returns map, x, y, z and the item list, or nil when nothing is pending.
local function LoadPending(guid)
    local q = CharDBQuery(string.format(
        "SELECT item_entry, item_count, map, pos_x, pos_y, pos_z "
        .. "FROM terapin_corpse_chest WHERE player_guid = %d", guid))
    if not q then
        return nil
    end
    local items, map, x, y, z = {}, nil, nil, nil, nil
    repeat
        items[#items + 1] = { q:GetUInt32(0), q:GetUInt32(1) }
        map, x, y, z = q:GetUInt32(2), q:GetFloat(3), q:GetFloat(4), q:GetFloat(5)
    until not q:NextRow()
    return map, x, y, z, items
end

-- ---------------------------------------------------------------------------------------
-- Taking it all
-- ---------------------------------------------------------------------------------------

-- Everything worn, as a list of Item objects.
local function EquippedItems(player)
    local out = {}
    for slot = EQUIP_FIRST, EQUIP_LAST do
        local item = player:GetItemByPos(BACKPACK_BAG, slot)
        if item then
            out[#out + 1] = item
        end
    end
    return out
end

-- Everything carried. Bags THEMSELVES are included - Old School takes the lot - but they are
-- destroyed last, because destroying a bag while walking its contents would be destroying the
-- container out from under the loop.
local function CarriedItems(player)
    local loose, bags = {}, {}
    for slot = BACKPACK_FIRST, BACKPACK_LAST do
        local item = player:GetItemByPos(BACKPACK_BAG, slot)
        if item then
            if item:GetClass() == ITEM_CLASS_CONTAINER then
                bags[#bags + 1] = item
            else
                loose[#loose + 1] = item
            end
        end
    end
    for bag = BAG_FIRST, BAG_LAST do
        local container = player:GetItemByPos(BACKPACK_BAG, bag)
        for slot = 0, MAX_BAG_SLOTS - 1 do
            local item = player:GetItemByPos(bag, slot)
            if item then
                loose[#loose + 1] = item
            end
        end
        if container then
            bags[#bags + 1] = container
        end
    end
    return loose, bags
end

local function OnRepop(event, player)
    if not player:HasSpell(OLD_SCHOOL) then
        return
    end

    -- Choose what will be waiting at the corpse BEFORE anything is destroyed.
    local worn = EquippedItems(player)
    local recover = {}
    if #worn > 0 then
        -- partial Fisher-Yates: shuffle only as far as we need
        local n = RECOVER_COUNT
        if n > #worn then n = #worn end
        for i = 1, n do
            local j = math.random(i, #worn)
            worn[i], worn[j] = worn[j], worn[i]
            recover[#recover + 1] = { worn[i]:GetItemId(), worn[i]:GetCount() }
        end
    end

    -- The corpse is where you died; the ghost is already at the graveyard.
    local corpse = player:GetCorpse()
    local x, y, z
    if corpse then
        x, y, z = corpse:GetX(), corpse:GetY(), corpse:GetZ()
    else
        x, y, z = player:GetX(), player:GetY(), player:GetZ()
    end
    StorePending(player:GetGUIDLow(), player:GetMapId(), x, y, z, recover)

    -- Now take everything. Worn first, then loose items, then the bags themselves.
    local taken = 0
    for _, item in ipairs(EquippedItems(player)) do
        player:RemoveItem(item, item:GetCount()); taken = taken + 1
    end
    local loose, bags = CarriedItems(player)
    for _, item in ipairs(loose) do
        player:RemoveItem(item, item:GetCount()); taken = taken + 1
    end
    for _, item in ipairs(bags) do
        player:RemoveItem(item, item:GetCount()); taken = taken + 1
    end

    player:SendBroadcastMessage(string.format(
        "|cffff2020You have lost everything.|r %d item(s) gone where you fell.", taken))
    if #recover > 0 then
        player:SendBroadcastMessage(string.format(
            "|cffffcc00%d piece(s) of your gear are still on your body.|r Reach it and they are yours; "
            .. "take the spirit healer and you lose your progress to the next level as well.", #recover))
    end

    StartWatch(player)
end

-- ---------------------------------------------------------------------------------------
-- Deciding what happened
-- ---------------------------------------------------------------------------------------

local function Resolve(player)
    local guid = player:GetGUIDLow()
    local map, x, y, z, items = LoadPending(guid)
    if not map then
        return true                              -- nothing pending; stop watching
    end

    if player:GetMapId() ~= map then
        -- Resurrected on a different map entirely; that is not a corpse run.
        ClearPending(guid)
        player:SetLevel(player:GetLevel())       -- zeroes PLAYER_XP, see the header
        player:SendBroadcastMessage(
            "|cffff2020The spirit healer takes its price.|r Your progress to the next level is gone.")
        return true
    end

    local dx, dy, dz = player:GetX() - x, player:GetY() - y, player:GetZ() - z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

    if dist <= CORPSE_RANGE then
        for i = 1, #items do
            player:AddItem(items[i][1], items[i][2])
        end
        ClearPending(guid)
        player:SendBroadcastMessage(string.format(
            "|cff33ff99You reach your body.|r %d piece(s) of your gear recovered.", #items))
    else
        ClearPending(guid)
        player:SetLevel(player:GetLevel())
        player:SendBroadcastMessage(
            "|cffff2020The spirit healer takes its price.|r Your progress to the next level is gone, "
            .. "and what was on your body is lost.")
    end
    return true
end

-- Watches until the player is alive again, then resolves once.
function StartWatch(player)
    local deadline = GetGameTime() + WATCH_GIVEUP
    player:RegisterEvent(function(eventId, delay, repeats, pl)
        if not pl then
            return
        end
        if pl:IsAlive() then
            Resolve(pl)
            pl:RemoveEventById(eventId)
            return
        end
        -- Still a ghost. Give up eventually rather than ticking forever: a player who dies
        -- and simply stays dead would otherwise carry a repeating event for the whole
        -- session. The pending row survives in the database either way, and OnLogin picks
        -- it up again next time they log in.
        if GetGameTime() > deadline then
            pl:RemoveEventById(eventId)
        end
    end, WATCH_INTERVAL, 0)                      -- 0 = repeat until removed
end

-- A death that spanned a logout, a disconnect or a restart still has to resolve.
local function OnLogin(event, player)
    if LoadPending(player:GetGUIDLow()) then
        if player:IsAlive() then
            Resolve(player)
        else
            StartWatch(player)
            player:SendBroadcastMessage(
                "|cffffcc00Your body is still out there, and so is your gear.|r")
        end
    end
end

local function OnCommand(event, player, command)
    if not player or not command or string.lower(command) ~= "oldschool" then
        return true                               -- not ours; let the core answer
    end
    if player:HasSpell(OLD_SCHOOL) then
        player:RemoveSpell(OLD_SCHOOL)
        player:SendBroadcastMessage("|cffffcc00Old School OFF.|r Death is gentle again.")
    else
        player:LearnSpell(OLD_SCHOOL)
        player:SendBroadcastMessage(
            "|cffff2020Old School ON.|r Everything you carry and everything you wear is forfeit when you die.")
    end
    return false                                 -- handled
end

RegisterPlayerEvent(PLAYER_EVENT_ON_REPOP, OnRepop)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)

print("[Terapin] old_school.lua loaded - spell " .. OLD_SCHOOL)
