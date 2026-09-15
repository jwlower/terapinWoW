-- TerapinTravel - pins every inn and dungeon you have discovered on the world map.
--
-- Rides on pfQuest. pfMap:AddNode already handles the world map, the minimap, clustering,
-- tooltips and redraws, so this addon only has to say WHERE and WHAT - it draws nothing
-- itself and hooks nothing. The last addon here that reached into client internals took out
-- camera panning for the whole game; adding entries to another addon's node list cannot.
--
-- HOW IT KNOWS WHAT YOU HAVE DISCOVERED
--   It reads your spellbook. Every inn and dungeon you have found is a teleport spell in the
--   Adventuring tab, so the tab is walked with GetSpellName() and matched by name against the
--   generated table in data.lua. Nothing is sent from the server, nothing is saved, and
--   nothing can fall out of sync - learn a teleport and the pin appears on the next
--   SPELLS_CHANGED.
--
--   The names in data.lua and the spell names come from the same generated lists (inns.py and
--   dungeon_portals.py), which is what makes matching by name safe.

local ADDON = "TerapinTravel"          -- pfMap namespace, so we only ever delete our own pins
local TAB_NAME = "Adventuring"

local ICON_INN     = "Interface\\Icons\\INV_Misc_Rune_01"
local ICON_DUNGEON = "Interface\\Icons\\Spell_Arcane_PortalStormwind"

local BOOKTYPE_SPELL = "spell"

-- ---------------------------------------------------------------------------------------
-- Reading the spellbook
-- ---------------------------------------------------------------------------------------

-- Returns a set of the travel spell names you actually know.
--
-- THE ADVENTURING TAB IS A PREFERENCE, NOT A REQUIREMENT. Whether the client gives a
-- category-9 skill its own spellbook tab, and whether it labels that tab exactly
-- "Adventuring", is the client's business and cannot be checked from outside the game. So the
-- tab is used when it is there - it is the cheapest place to look - and otherwise the whole
-- spellbook is scanned. Either way the pins are correct; only the amount of work differs.
--
-- Matching is by name against data.lua, so scanning extra tabs cannot produce a false pin:
-- no other spell in the game shares a name with an inn or a dungeon.
local function KnownTravelSpells()
    local found = {}
    local hits = 0

    local function scan(offset, count)
        for i = offset + 1, offset + count do
            local spell = GetSpellName(i, BOOKTYPE_SPELL)
            if spell then
                found[spell] = true
                hits = hits + 1
            end
        end
    end

    local sawTab = false
    local tabs = GetNumSpellTabs()
    for tab = 1, tabs do
        local name, _, offset, count = GetSpellTabInfo(tab)
        if name == TAB_NAME then
            sawTab = true
            scan(offset, count)
        end
    end

    if not sawTab then
        for tab = 1, tabs do
            local _, _, offset, count = GetSpellTabInfo(tab)
            scan(offset, count)
        end
    end

    if hits == 0 then
        return nil
    end
    return found
end

-- ---------------------------------------------------------------------------------------
-- Pinning
-- ---------------------------------------------------------------------------------------

local function Refresh()
    if not pfMap or not pfMap.AddNode or not TerapinTravelData then
        return
    end

    -- Clear only our own pins. pfMap:DeleteNode(addon) is namespaced, so pfQuest's own
    -- quest nodes are untouched.
    pfMap:DeleteNode(ADDON)

    local known = KnownTravelSpells()
    if not known then
        return                                   -- no Adventuring tab yet: nothing discovered
    end

    local n = 0
    for _, e in pairs(TerapinTravelData) do
        if known[e.name] then
            local note = e.note ~= "" and ("\n" .. e.note) or ""
            pfMap:AddNode({
                addon = ADDON,
                zone = e.zone,
                x = e.x,
                y = e.y,
                title = e.name,
                spawn = e.name,
                description = e.where .. note .. "\n|cff33ff99Adventuring|r",
                texture = (e.kind == "inn") and ICON_INN or ICON_DUNGEON,
                -- Only the fields pfMap actually reads. It ignores anything else, so an
                -- invented "vertex" or "layer" would silently do nothing: the draw layer is
                -- derived from the texture by GetLayerByTexture, not passed in.
                spawntype = (e.kind == "inn") and "Inn" or "Dungeon",
                priority = 1,
            })
            n = n + 1
        end
    end

    if pfMap.UpdateNodes then
        pfMap:UpdateNodes()
    end
    return n
end

-- ---------------------------------------------------------------------------------------
-- Events
--
-- SPELLS_CHANGED is the one that matters: it fires when a teleport is learned, which is the
-- moment a new pin should appear. The rest are there because the spellbook is not reliably
-- readable at login until the client has finished populating it.
-- ---------------------------------------------------------------------------------------

local f = CreateFrame("Frame", ADDON .. "Frame", UIParent)
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("LEARNED_SPELL_IN_TAB")

local pending, elapsed = false, 0
f:SetScript("OnEvent", function()
    -- Coalesce: SPELLS_CHANGED can fire several times in a row while the book loads, and
    -- rebuilding 92 nodes on each one is wasted work.
    pending, elapsed = true, 0
end)

f:SetScript("OnUpdate", function()
    if not pending then
        return
    end
    elapsed = elapsed + (arg1 or 0)
    if elapsed < 1.0 then
        return
    end
    pending = false
    Refresh()
end)

SLASH_TERAPINTRAVEL1 = "/travel"
SlashCmdList["TERAPINTRAVEL"] = function()
    local n = Refresh()
    if n then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff33ff99Travel:|r %d discovered place(s) pinned on the map.", n))
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff33ff99Travel:|r nothing discovered yet - visit an inn or a summoning stone.")
    end
end
