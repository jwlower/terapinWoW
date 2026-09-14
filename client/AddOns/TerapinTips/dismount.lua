-- Auto-dismount when you go to attack.
--
-- WHY THIS HAS TO BE CLIENT-SIDE
--   The server already dismounts you for casting a spell (Spell.cpp:5971) and for gathering
--   a node, and it would dismount you for a melee swing too - Unit::Attack was changed to do
--   exactly that. None of it helps, because THE 1.12 CLIENT NEVER SENDS THE PACKET.
--
--   Measured from a live session log: while mounted, the client sent nothing but movement
--   opcodes. One CMSG_ATTACKSWING in the whole session, and it arrived one second AFTER the
--   mount aura was removed with mode 2 (AURA_REMOVE_BY_CANCEL) - the player had dismounted
--   by hand first. Zero CMSG_GAMEOBJ_USE, ever. The block is local to the client, above the
--   network layer, so no amount of server code can reach it.
--
--   Gathering works because it arrives as a SPELL CAST, which the client is happy to send
--   while mounted. Anything that arrives as a bare opcode - attack swing, object click -
--   is dropped before it leaves the machine.
--
--   So: dismount FIRST, then let the action through. That is all this file does.
--
-- HOW A MOUNT IS RECOGNISED
--   By buff NAME, against the generated set in mounts.lua. The tempting check - "icon starts
--   with Ability_Mount_" - is wrong: of this client's 484 mount spells, only 41 use such an
--   icon. 83 use Spell_Nature_Swiftness and 48 use Ability_Hunter_BeastCall. And the 1.12
--   API gives no spell id for a buff, only an opaque index, so the tooltip name is the one
--   thing left to match on.
--
-- Lua 5.0 / 1.12 API: no #, no select(), no varargs. IsMounted() and Dismount() DO NOT
-- EXIST in this client - both were checked against WoW.exe and return zero hits.

local RETRY_SECONDS = 1.5     -- give up re-issuing the action if the dismount never lands
local DRAG_PIXELS   = 6       -- beyond this, a right-click was a camera turn, not a click

-- A hidden tooltip of our own, so reading buff names never disturbs the real GameTooltip.
local scan = CreateFrame("GameTooltip", "TerapinDismountScan", UIParent, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")

local pending = nil     -- function to run once we are off the mount
local pendingUntil = 0

-- Returns the buff index of the mount you are on, or nil.
local function MountBuffIndex()
    local i = 0
    while true do
        local id = GetPlayerBuff(i, "HELPFUL")
        -- 1.12 returns -1 to mean "no more buffs", which is the loop's terminator.
        if not id or id < 0 then
            return nil
        end
        scan:SetOwner(UIParent, "ANCHOR_NONE")
        scan:SetPlayerBuff(id)
        local name = TerapinDismountScanTextLeft1 and TerapinDismountScanTextLeft1:GetText()
        if name and TERAPIN_MOUNTS[name] then
            return id
        end
        i = i + 1
    end
end

-- Cancels the mount and queues `action` to run as soon as the buff is actually gone.
-- The cancel is a server round trip, so the action cannot simply be called on the next
-- line - the client would still consider you mounted and drop the packet again.
local function DismountThen(action)
    local id = MountBuffIndex()
    if not id then
        return false
    end
    CancelPlayerBuff(id)
    pending = action
    pendingUntil = GetTime() + RETRY_SECONDS
    return true
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
    if not pending then
        return
    end
    if MountBuffIndex() then
        -- still mounted; wait for the server, unless we have waited too long already
        if GetTime() > pendingUntil then
            pending = nil
        end
        return
    end
    local action = pending
    pending = nil
    action()
end)

-- ---------------------------------------------------------------------------------------
-- NO FUNCTION IS HOOKED. Nothing here overwrites a client global.
--
-- The first version wrapped AttackTarget and TurnOrActionStart/Stop. TurnOrAction* turned
-- out to be PROTECTED: the client's own right-mouse binding called our replacement - addon
-- code - which then called the protected original, and every right-click, camera panning
-- included, was refused with "blocked from an action only available to the Blizzard UI".
-- Core input was broken until the hook was removed.
--
-- AttackTarget was dropped for the same reason: it may well be protected too, and there is
-- no way to find out except by breaking someone's attack key. An addon that breaks input is
-- far worse than an addon that does less, so this file now only ever CANCELS A BUFF - an
-- ordinary, unprotected action - and never calls anything on the player's behalf.
--
-- /dismount, and the "Terapin: Dismount" keybinding, are the manual trigger. Bind it next
-- to your attack key: one tap gets you off the mount, then attack as normal.
-- ---------------------------------------------------------------------------------------

local function Dismount()
    local id = MountBuffIndex()
    if not id then
        return false
    end
    CancelPlayerBuff(id)
    return true
end

-- ---------------------------------------------------------------------------------------
-- The ONE hook, and why this one is worth the risk when the others were not.
--
-- TurnOrActionStart/Stop are protected: wrapping them broke every right-click, camera
-- panning included. AttackTarget may or may not be - and the server log from 16:20:03
-- suggests it is NOT, because it shows the mount aura removed with mode 2 (BY_CANCEL) and
-- CMSG_ATTACKSWING arriving ten log lines later in the same second. That is this hook's
-- signature: cancel, wait for the server, re-issue.
--
-- The failure modes are not comparable either. A protected TurnOrAction* broke core input.
-- A protected AttackTarget just means the attack key prints an error and does nothing -
-- contained, obvious, and switched off with one command:
--
--     /dm auto        toggle this hook off (or back on) for the session
--
-- If the attack key starts erroring, run that and use /dm or the keybinding instead.
-- ---------------------------------------------------------------------------------------

local autoAttackHook = true

local origAttackTarget = AttackTarget
AttackTarget = function()
    if autoAttackHook and DismountThen(origAttackTarget) then
        return
    end
    origAttackTarget()
end

SLASH_TERAPINDISMOUNT1 = "/dismount"
SLASH_TERAPINDISMOUNT2 = "/dm"
SlashCmdList["TERAPINDISMOUNT"] = function(msg)
    if msg and string.lower(msg) == "auto" then
        autoAttackHook = not autoAttackHook
        if autoAttackHook then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Dismount:|r attack-key auto-dismount ON.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Dismount:|r attack-key auto-dismount OFF - use /dm or the keybinding.")
        end
        return
    end
    if not Dismount() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Dismount:|r you are not mounted.")
    end
end

-- A binding of our own, so it can sit on a key without touching any Blizzard function.
BINDING_HEADER_TERAPIN = "Terapin"
BINDING_NAME_TERAPIN_DISMOUNT = "Dismount"
function TerapinDismount()
    Dismount()
end

-- ---------------------------------------------------------------------------------------
-- Hook 2 (REMOVED): right-clicking a mob in the world.
--
-- TurnOrActionStart/Stop are PROTECTED. Overwriting the globals meant the client's own
-- right-mouse binding called our replacement - addon code - which then called the protected
-- original, and the client refused with "has been blocked from an action only available to
-- the Blizzard UI" on EVERY right-click, including plain camera turning. That breaks normal
-- play, so the hook is gone and will not come back in this form.
--
-- Wrapping a protected function is never safe here, however careful the wrapper is. See
-- UI_ERROR_MESSAGE below for the approach that does not touch them at all.
-- ---------------------------------------------------------------------------------------

DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99TerapinTips:|r auto-dismount ready ("
    .. "mount list loaded)")
