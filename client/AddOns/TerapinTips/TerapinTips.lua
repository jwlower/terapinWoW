-- TerapinTips - vendor prices on every item tooltip, and hold SHIFT to compare against
-- what you have equipped.
--
-- Lua 5.0 / the 1.12 API: table.getn rather than #, no varargs, no select(), no string
-- metatable methods.
--
-- WHY THIS ADDON EXISTS AT ALL
--   Both features are missing from this client, and neither is a settings toggle:
--
--   * There is NO sell-price API. Checked against WoW.exe directly - GetSellValue and
--     GetItemSellPrice do not exist, and GetItemInfo returns no price. Period addons
--     scanned merchant windows and cached what they saw, so prices stayed blank until you
--     had personally seen an item at a vendor. We ship prices.lua instead, generated from
--     the server's own item_template.sell_price, so every item is known immediately.
--
--   * There is NO ShowCompareItem / SetHyperlinkCompareItem - those arrive in TBC. The
--     comparison below is a second GameTooltip we position and fill ourselves.
--
--   * There is NO GetCoinTextureString either, so money is formatted by hand.

local WHITE  = { r = 1.00, g = 1.00, b = 1.00 }
local GOLD   = { r = 1.00, g = 0.82, b = 0.00 }

-- INVTYPE -> the inventory slots an item of that type could go in. Two entries means the
-- item has two possible homes (rings, trinkets, one-handers) and BOTH get compared, since
-- "is this better" depends on which one you would replace.
local SLOTS = {
    INVTYPE_HEAD            = { "HeadSlot" },
    INVTYPE_NECK            = { "NeckSlot" },
    INVTYPE_SHOULDER        = { "ShoulderSlot" },
    INVTYPE_BODY            = { "ShirtSlot" },
    INVTYPE_CHEST           = { "ChestSlot" },
    INVTYPE_ROBE            = { "ChestSlot" },
    INVTYPE_WAIST           = { "WaistSlot" },
    INVTYPE_LEGS            = { "LegsSlot" },
    INVTYPE_FEET            = { "FeetSlot" },
    INVTYPE_WRIST           = { "WristSlot" },
    INVTYPE_HAND            = { "HandsSlot" },
    INVTYPE_FINGER          = { "Finger0Slot", "Finger1Slot" },
    INVTYPE_TRINKET         = { "Trinket0Slot", "Trinket1Slot" },
    INVTYPE_CLOAK           = { "BackSlot" },
    INVTYPE_TABARD          = { "TabardSlot" },
    INVTYPE_WEAPON          = { "MainHandSlot", "SecondaryHandSlot" },
    INVTYPE_2HWEAPON        = { "MainHandSlot" },
    INVTYPE_WEAPONMAINHAND  = { "MainHandSlot" },
    INVTYPE_WEAPONOFFHAND   = { "SecondaryHandSlot" },
    INVTYPE_SHIELD          = { "SecondaryHandSlot" },
    INVTYPE_HOLDABLE        = { "SecondaryHandSlot" },
    INVTYPE_RANGED          = { "RangedSlot" },
    INVTYPE_RANGEDRIGHT     = { "RangedSlot" },
    INVTYPE_THROWN          = { "RangedSlot" },
    INVTYPE_RELIC           = { "RangedSlot" },
}

local function Money(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper - g * 10000) / 100)
    local c = copper - g * 10000 - s * 100
    local out = ""
    if g > 0 then out = out .. g .. "g " end
    if g > 0 or s > 0 then out = out .. s .. "s " end
    return out .. c .. "c"
end

local function ItemIdFromLink(link)
    if not link then return nil end
    local _, _, id = string.find(link, "item:(%d+)")
    if id then return tonumber(id) end
    return nil
end

-- ---------------------------------------------------------------------------------------
-- The comparison tooltip
-- ---------------------------------------------------------------------------------------
local compare1 = CreateFrame("GameTooltip", "TerapinCompare1", UIParent, "GameTooltipTemplate")
local compare2 = CreateFrame("GameTooltip", "TerapinCompare2", UIParent, "GameTooltipTemplate")
compare1:SetOwner(UIParent, "ANCHOR_NONE")
compare2:SetOwner(UIParent, "ANCHOR_NONE")

local function HideCompare()
    compare1:Hide()
    compare2:Hide()
end

-- The slot line as it is PRINTED on the tooltip, mapped to inventory slots.
--
-- This client's GetItemInfo does not return an equip location at all - verified by dumping
-- all twelve return values for a sword and a robe and finding no INVTYPE_ string anywhere.
-- Guessing positions was wrong twice (8th = maxStack, then 9th), so the equip slot is read
-- off the tooltip text instead, which is what period addons did for exactly this reason.
local SLOT_TEXT = {
    ["Head"] = { "HeadSlot" },
    ["Neck"] = { "NeckSlot" },
    ["Shoulder"] = { "ShoulderSlot" },
    ["Shirt"] = { "ShirtSlot" },
    ["Chest"] = { "ChestSlot" },
    ["Robe"] = { "ChestSlot" },
    ["Waist"] = { "WaistSlot" },
    ["Legs"] = { "LegsSlot" },
    ["Feet"] = { "FeetSlot" },
    ["Wrist"] = { "WristSlot" },
    ["Hands"] = { "HandsSlot" },
    ["Finger"] = { "Finger0Slot", "Finger1Slot" },
    ["Trinket"] = { "Trinket0Slot", "Trinket1Slot" },
    ["Back"] = { "BackSlot" },
    ["Tabard"] = { "TabardSlot" },
    ["One-Hand"] = { "MainHandSlot", "SecondaryHandSlot" },
    ["Two-Hand"] = { "MainHandSlot" },
    ["Main Hand"] = { "MainHandSlot" },
    ["Off Hand"] = { "SecondaryHandSlot" },
    ["Held In Off-hand"] = { "SecondaryHandSlot" },
    ["Ranged"] = { "RangedSlot" },
    ["Thrown"] = { "RangedSlot" },
    ["Relic"] = { "RangedSlot" },
}

-- Scan the tooltip's left-hand lines for a slot name. The slot is NOT on a fixed line -
-- "Binds when equipped" and quality lines push it down - so lines 2..8 are searched.
local function EquipSlotsFromTooltip()
    for i = 2, 8 do
        local fs = getglobal("GameTooltipTextLeft" .. i)
        local txt = fs and fs:GetText()
        if txt and SLOT_TEXT[txt] then
            return SLOT_TEXT[txt], txt
        end
    end
    return nil, nil
end

-- Kept as the preferred path in case some items DO carry it, with the tooltip as fallback.
local function ItemEquipLoc(link)
    if not link then return nil end
    local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12 = GetItemInfo(link)
    local vals = { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12 }
    for i = 1, 12 do
        local v = vals[i]
        if type(v) == "string" and string.find(v, "INVTYPE_") then
            return v
        end
    end
    return nil
end

local function ShowCompare(link)
    HideCompare()
    if not IsShiftKeyDown() then return end
    if not link then return end

    -- Prefer the API if it ever gives us an INVTYPE_; otherwise read the tooltip, which is
    -- the only thing that actually works in this client.
    local slotNames
    local equipLoc = ItemEquipLoc(link)
    if equipLoc and SLOTS[equipLoc] then
        slotNames = SLOTS[equipLoc]
    else
        slotNames = EquipSlotsFromTooltip()
    end
    if not slotNames then return end

    -- Anchor the first comparison to the LEFT of the main tooltip when there is room,
    -- otherwise to the right - the main tooltip is usually already near a bag on the
    -- right-hand side of the screen.
    local shown = 0
    for i = 1, table.getn(slotNames) do
        local slotId = GetInventorySlotInfo(slotNames[i])
        local equipped = GetInventoryItemLink("player", slotId)
        if equipped then
            local tip = (shown == 0) and compare1 or compare2
            tip:SetOwner(UIParent, "ANCHOR_NONE")
            if shown == 0 then
                if GameTooltip:GetLeft() and GameTooltip:GetLeft() > 350 then
                    tip:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", -4, 0)
                else
                    tip:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 4, 0)
                end
            else
                tip:SetPoint("TOPLEFT", compare1, "BOTTOMLEFT", 0, -4)
            end
            -- SetInventoryItem, NOT SetHyperlink. In 1.12 SetHyperlink wants the bare
            -- "item:12345:0:0:0" form; handed the full |cff..|Hitem:..|h[Name]|h|r link it
            -- throws "Unknown link type". We already know the unit and slot, so ask for the
            -- equipped item directly and skip link parsing altogether.
            --
            -- Safe despite GameTooltip.SetInventoryItem being wrapped above: the wrapper is
            -- set on the GameTooltip frame itself, so these separate frames still resolve
            -- the original method and cannot recurse.
            tip:SetInventoryItem("player", slotId)
            tip:AddLine(" ")
            tip:AddLine("Currently equipped", GOLD.r, GOLD.g, GOLD.b)
            tip:Show()
            shown = shown + 1
        end
    end
end

-- ---------------------------------------------------------------------------------------
-- The price line
-- ---------------------------------------------------------------------------------------
local function AddPrice(tooltip, link, count)
    local id = ItemIdFromLink(link)
    if not id then return end
    local price = TerapinPrices and TerapinPrices[id]
    if not price then return end

    count = count or 1
    if count > 1 then
        tooltip:AddDoubleLine("Sell: " .. Money(price) .. " each",
                              Money(price * count),
                              WHITE.r, WHITE.g, WHITE.b, GOLD.r, GOLD.g, GOLD.b)
    else
        tooltip:AddDoubleLine("Sell:", Money(price),
                              WHITE.r, WHITE.g, WHITE.b, GOLD.r, GOLD.g, GOLD.b)
    end
    tooltip:Show()     -- re-layout; the tooltip has already sized itself without our line
end

-- Remembered so the SHIFT watcher knows what the tooltip is showing. GameTooltip:GetItem()
-- is unreliable here (it is not a documented 1.12 method and returns nothing for several of
-- the Set* paths), so we record the link at the point we already have it for certain.
local lastLink = nil

local function Decorate(tooltip, link, count)
    if not link then return end
    AddPrice(tooltip, link, count)
    if tooltip == GameTooltip then
        lastLink = link
        ShowCompare(link)
    end
end

-- ---------------------------------------------------------------------------------------
-- Hooks.
--
-- Each GameTooltip:SetXxx has its own way of naming the item it just drew, so each needs
-- its own small shim that recovers the link. Wrapping the methods (rather than hooking
-- OnShow) is what period addons do: OnShow fires before the tooltip knows its item.
-- ---------------------------------------------------------------------------------------
local function Wrap(name, getter)
    local original = GameTooltip[name]
    if not original then return end
    GameTooltip[name] = function(self, a1, a2, a3, a4)
        -- The return values MUST be passed through. SetInventoryItem returns
        -- (hasItem, hasCooldown, repairCost), and PaperDollItemSlotButton_OnEnter does:
        --     local hasItem = GameTooltip:SetInventoryItem("player", this:GetID())
        --     if not hasItem then GameTooltip:SetText(slotName) end
        -- Swallowing them made hasItem nil, so the character sheet decided every slot was
        -- empty and overwrote the item tooltip with the slot name. Bags never showed it
        -- because SetBagItem's return is not used that way.
        local r1, r2, r3 = original(self, a1, a2, a3, a4)

        local link, count
        if getter then
            local ok, l, c = pcall(getter, a1, a2, a3, a4)
            if ok then link, count = l, c end
        end
        if not link then
            -- Fallback for setters this client has no link getter for - SetInboxItem and
            -- SetBuybackItem exist, GetInboxItemLink and GetBuybackItemLink do not (checked
            -- against WoW.exe). Ask the tooltip what it just drew instead. Wrapped in pcall
            -- because GetItem is not a documented 1.12 method and may simply not be there;
            -- if it is missing we just do not decorate those two windows.
            local ok2, _, l2 = pcall(self.GetItem, self)
            if ok2 then link = l2 end
        end

        Decorate(self, link, count)
        return r1, r2, r3
    end
end

Wrap("SetBagItem", function(bag, slot)
    local _, count = GetContainerItemInfo(bag, slot)
    return GetContainerItemLink(bag, slot), count
end)
Wrap("SetInventoryItem", function(unit, slot)
    return GetInventoryItemLink(unit, slot), 1
end)
Wrap("SetHyperlink", function(link) return link, 1 end)
Wrap("SetLootItem", function(slot) return GetLootSlotLink(slot), 1 end)
Wrap("SetMerchantItem", function(index) return GetMerchantItemLink(index), 1 end)
Wrap("SetQuestItem", function(qtype, index) return GetQuestItemLink(qtype, index), 1 end)
Wrap("SetQuestLogItem", function(qtype, index) return GetQuestLogItemLink(qtype, index), 1 end)
Wrap("SetCraftItem", function(index, reagent) return GetCraftReagentItemLink(index, reagent), 1 end)
Wrap("SetTradeSkillItem", function(index, reagent)
    if reagent then return GetTradeSkillReagentItemLink(index, reagent), 1 end
    return GetTradeSkillItemLink(index), 1
end)
-- These four have real link getters in this client.
Wrap("SetAuctionItem", function(list, index) return GetAuctionItemLink(list, index), 1 end)
Wrap("SetTradePlayerItem", function(i) return GetTradePlayerItemLink(i), 1 end)
Wrap("SetTradeTargetItem", function(i) return GetTradeTargetItemLink(i), 1 end)
Wrap("SetLootRollItem", function(i) return GetLootRollItemLink(i), 1 end)
-- These have no link getter at all, so they rely on the GetItem fallback in Wrap.
Wrap("SetInboxItem", nil)
Wrap("SetBuybackItem", nil)
Wrap("SetSendMailItem", nil)

-- ---------------------------------------------------------------------------------------
-- /tt - say exactly why a comparison did not appear, instead of failing silently.
--
-- Every bug in this addon so far (equipSlot read from the wrong return position, swallowed
-- return values breaking the character sheet) failed silently and had to be guessed at.
-- Hover an item, type /tt, and it reports each step.
-- ---------------------------------------------------------------------------------------
local function Say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99TerapinTips|r: " .. msg)
end

SLASH_TERAPINTIPS1 = "/tt"
SlashCmdList["TERAPINTIPS"] = function()
    Say("tooltip visible: " .. tostring(GameTooltip:IsVisible()))
    Say("last item seen : " .. tostring(lastLink))
    if not lastLink then
        Say("|cffff5555No item recorded.|r Hover an item in a bag, then run /tt again.")
        return
    end
    -- Dump EVERY return position. A robe reporting "not equippable" means the equip slot is
    -- not where this client puts it, and guessing the position again would be the third
    -- guess. Print the lot and read it off.
    local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12 = GetItemInfo(lastLink)
    local vals = { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12 }
    for i = 1, 12 do
        local v = vals[i]
        if v ~= nil then
            Say("  GetItemInfo[" .. i .. "] = " .. tostring(v))
        end
    end

    Say("GetItemInfo equipLoc: " .. tostring(ItemEquipLoc(lastLink)) .. " (nil is expected here)")
    -- Show the tooltip lines actually being scanned, so a slot word I have not mapped is
    -- obvious rather than silent.
    for i = 2, 8 do
        local fs = getglobal("GameTooltipTextLeft" .. i)
        local txt = fs and fs:GetText()
        if txt and txt ~= "" then
            Say("  tooltip line " .. i .. ": '" .. txt .. "'"
                .. (SLOT_TEXT[txt] and "  <-- MATCHED" or ""))
        end
    end
    local slots, word = EquipSlotsFromTooltip()
    Say("slot from tooltip  : " .. tostring(word))
    if not slots then
        Say("|cffff5555No slot line matched|r - paste the tooltip lines above to Claude.")
        return
    end
    for i = 1, table.getn(slots) do
        local id = GetInventorySlotInfo(slots[i])
        Say("  " .. slots[i] .. " (id " .. tostring(id) .. ") equipped: "
            .. tostring(GetInventoryItemLink("player", id)))
    end
    Say("compare frames : " .. tostring(compare1 ~= nil) .. " / " .. tostring(compare2 ~= nil)
        .. "   SetHyperlink: " .. tostring(compare1 and compare1.SetHyperlink ~= nil))
    Say("SHIFT held now : " .. tostring(IsShiftKeyDown()))
end

-- The comparison must disappear with the tooltip it is attached to.
--
-- HookScript does NOT exist in 1.12 - it is a later addition - so chain the handler by
-- hand: keep whatever OnHide was already set and call it first.
local prevOnHide = GameTooltip:GetScript("OnHide")
GameTooltip:SetScript("OnHide", function()
    if prevOnHide then prevOnHide() end
    lastLink = nil
    HideCompare()
end)

-- SHIFT is usually pressed while the tooltip is ALREADY up, so watch for the keypress
-- rather than only evaluating it at tooltip-draw time.
local watcher = CreateFrame("Frame")
local wasShift = false
watcher:SetScript("OnUpdate", function()
    local isShift = IsShiftKeyDown()
    if isShift ~= wasShift then
        wasShift = isShift
        if lastLink and GameTooltip:IsVisible() then
            if isShift then ShowCompare(lastLink) else HideCompare() end
        else
            HideCompare()
        end
    end
end)

DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99TerapinTips|r loaded - hold SHIFT over an item to compare.")

-- ---------------------------------------------------------------------------------------
-- Reagents on trainer tooltips.
--
-- The trainer window tells you a recipe's name, cost and skill requirement, but never what
-- it is made of - so deciding whether a recipe is worth buying means learning it first.
-- recipes.lua carries the mats for every trainer-taught recipe.
--
-- Matched by NAME: GetTrainerServiceInfo returns (name, subText, type, isExpanded) and this
-- client has no GetTrainerServiceItemLink, so a name is all there is to match on. That works
-- because a trainer wrapper is named identically to the craft spell it teaches.
-- ---------------------------------------------------------------------------------------
local origSetTrainerService = GameTooltip.SetTrainerService
if origSetTrainerService then
    GameTooltip.SetTrainerService = function(self, index)
        local r1, r2, r3 = origSetTrainerService(self, index)
        local ok, name = pcall(GetTrainerServiceInfo, index)
        if ok and name and TerapinRecipes and TerapinRecipes[name] then
            self:AddLine(" ")
            self:AddLine("Requires:", GOLD.r, GOLD.g, GOLD.b)
            -- One reagent per line, wrapped, so a four-mat recipe stays readable.
            local mats = TerapinRecipes[name]
            local start = 1
            while start <= string.len(mats) do
                local cut = string.find(mats, ", ", start, true)
                local piece
                if cut then
                    piece = string.sub(mats, start, cut - 1)
                    start = cut + 2
                else
                    piece = string.sub(mats, start)
                    start = string.len(mats) + 1
                end
                self:AddLine("  " .. piece, WHITE.r, WHITE.g, WHITE.b)
            end
            self:Show()
        end
        return r1, r2, r3
    end
end
