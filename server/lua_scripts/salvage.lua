-- Salvage: break a weapon or piece of armour back down into materials.
--
-- Universal and free. Any class, any profession, known from level 1 - no skill requirement
-- and no reagent cost.
--
-- HOW IT IS HOOKED
--   PLAYER_EVENT_ON_SPELL_CAST is a GLOBAL hook - it fires for every spell cast by any
--   player, with no entry key. The alternative, ITEM_EVENT_ON_DUMMY_EFFECT, is keyed by the
--   target item's entry (Eluna/hooks/ItemHooks.cpp), which would mean registering the hook
--   for all 14,937 weapons and armour pieces individually.
--
--   Spell:GetTarget() returns the item when the spell carries an item target
--   (SpellMethods.h -> m_targets.GetItemTarget()), which is what makes this work.
--
-- WHAT IT RETURNS
--   Material type follows the item's own class and subclass - plate and mail give bars,
--   leather and mail-ish give leather, cloth gives cloth - and the TIER follows item level,
--   so a level 40 breastplate yields Mithril rather than Copper.
--
--   Amount scales with quality, per the roadmap:
--       white  0-2      green  1-5      blue  2-6      purple  3-8
--
-- SAFETY
--   Refuses equipped items, so a misclick cannot eat the weapon you are holding. Soulbound
--   items ARE allowed - those are most of what anyone wants to salvage.
--
-- WHY THE WORK IS DEFERRED BY A TICK  (this crashed the server before)
--   PLAYER_EVENT_ON_SPELL_CAST fires from Spell::prepare (Spell.cpp:3884) - PART WAY
--   THROUGH the cast, not after it. Everything below that line - TakeReagents(),
--   SendSpellGo(), handle_immediate() -> DoAllEffectOnTarget(ItemTargetInfo*) ->
--   HandleEffects(nullptr, target->item, ...) - keeps using the raw Item* we were handed.
--
--   Destroying the item inside the hook therefore pulls the rug out from under the running
--   spell. Worse, it is INTERMITTENT: Player::DestroyItem ends in SetState(ITEM_REMOVED),
--   and Item::SetState (Item.cpp:802) reads
--
--       if (uState == ITEM_NEW && state == ITEM_REMOVED) { ...; delete this; return; }
--
--   so an item that has not yet been saved to the database - anything freshly looted - is
--   FREED ON THE SPOT, and the spell then dereferences freed memory. An item that had
--   already been saved is merely detached and the same code appears to work fine. That is
--   why this survived testing and then crashed with an ACCESS_VIOLATION later.
--
--   The fix: read the item's properties in the hook (reads are harmless), then do the
--   destroy and the grant from a one-shot timed event on a later world tick, by which
--   point the Spell object is long gone. Timed events registered on a WorldObject are
--   cancelled automatically when it goes away, so a logout in between is safe.
--
-- WHY THE LINK IS REBUILT
--   LuaItem::GetItemLink returns the FRENCH name. It does
--       if (ItemLocale const* il = GetItemLocale(id)) name = il->Name[locale];
--   which overrides the English name whenever ANY locale row exists, and indexes Name[]
--   with a raw LocaleConstant. Those are different spaces: ObjectMgr::GetOrNewIndexForLocale
--   returns -1 for enUS and packs the other locales densely in first-seen order, so with
--   French rows in `locales_item`, index 0 IS French. Asking for English hands you French.
--   Item:GetName() reads Name1 directly and has no such problem, so we keep the link that
--   the client already renders correctly and swap only the bracketed name.

local SALVAGE_SPELL = 38600

-- Item classes
local CLASS_WEAPON, CLASS_ARMOR = 2, 4
-- Armour subclasses
local ARMOR_CLOTH, ARMOR_LEATHER, ARMOR_MAIL, ARMOR_PLATE = 1, 2, 3, 4

-- tier tables: {minimum item level, item entry}, highest first so the first match wins
local BARS = {
    { 50, 12359 },  -- Thorium Bar
    { 40, 3860  },  -- Mithril Bar
    { 35, 3859  },  -- Steel Bar
    { 30, 3575  },  -- Iron Bar
    { 20, 2841  },  -- Bronze Bar
    { 0,  2840  },  -- Copper Bar
}
local LEATHER = {
    { 50, 8170 },   -- Rugged Leather
    { 40, 4304 },   -- Thick Leather
    { 30, 4234 },   -- Heavy Leather
    { 20, 2319 },   -- Medium Leather
    { 0,  2318 },   -- Light Leather
}
local CLOTH = {
    { 50, 14047 },  -- Runecloth
    { 40, 4338  },  -- Mageweave Cloth
    { 30, 4306  },  -- Silk Cloth
    { 15, 2592  },  -- Wool Cloth
    { 0,  2589  },  -- Linen Cloth
}

-- quality -> {min, max} returned
local YIELD = {
    [1] = { 0, 2 },   -- white
    [2] = { 1, 5 },   -- green
    [3] = { 2, 6 },   -- blue
    [4] = { 3, 8 },   -- purple
}

local function PickTier(tiers, ilvl)
    for i = 1, #tiers do
        if ilvl >= tiers[i][1] then
            return tiers[i][2]
        end
    end
    return tiers[#tiers][2]
end

local function MaterialFor(itemClass, subClass, ilvl)
    if itemClass == CLASS_WEAPON then
        return PickTier(BARS, ilvl)
    end
    if itemClass == CLASS_ARMOR then
        if subClass == ARMOR_CLOTH then return PickTier(CLOTH, ilvl) end
        if subClass == ARMOR_LEATHER then return PickTier(LEATHER, ilvl) end
        if subClass == ARMOR_MAIL or subClass == ARMOR_PLATE then
            return PickTier(BARS, ilvl)
        end
        -- shields, librams, and the rest: metal
        return PickTier(BARS, ilvl)
    end
    return nil
end

-- Runs a tick after the cast, from a one-shot timed event. By now the Spell object that
-- handed us the item is gone, so destroying the item is safe.
local function Finish(player, guid, link, mat, amount)
    -- Re-find it by guid. If it is no longer there - destroyed, traded, mailed in the
    -- meantime - grant nothing. Bailing out is the safe direction to fail: awarding the
    -- materials without consuming an item would be a duplication bug.
    local item = player:GetItemByGUID(guid)
    if not item then
        player:SendBroadcastMessage("|cffff5555Salvage:|r that item is no longer in your bags.")
        return
    end

    player:RemoveItem(item, 1)

    if amount > 0 then
        player:AddItem(mat, amount)
        player:SendBroadcastMessage(string.format(
            "|cff33ff99Salvage:|r %s yielded %d material(s).", link, amount))
    else
        -- A white item can legitimately produce nothing. Say so rather than leaving the
        -- player wondering whether the spell failed.
        player:SendBroadcastMessage(string.format(
            "|cff33ff99Salvage:|r %s came apart into nothing usable.", link))
    end
end


local function OnSpellCast(event, player, spell, skipCheck)
    if spell:GetEntry() ~= SALVAGE_SPELL then
        return
    end

    -- GetTarget returns whichever target the spell carries - unit, gameobject, corpse or
    -- item. Only an Item has GetItemLevel, so that is the cheapest way to tell them apart.
    local item = spell:GetTarget()
    if not item or type(item.GetItemLevel) ~= "function" then
        player:SendBroadcastMessage("|cffff5555Salvage:|r target an item in your bags.")
        return
    end

    local quality = item:GetQuality()
    local ilvl = item:GetItemLevel()
    local itemClass = item:GetClass()
    local subClass = item:GetSubClass()

    if itemClass ~= CLASS_WEAPON and itemClass ~= CLASS_ARMOR then
        player:SendBroadcastMessage("|cffff5555Salvage:|r only weapons and armour can be salvaged.")
        return
    end

    -- Equipped gear is refused so a misclick cannot destroy what you are wearing.
    if item:IsEquipped() then
        player:SendBroadcastMessage("|cffff5555Salvage:|r unequip it first.")
        return
    end

    local band = YIELD[quality]
    if not band then
        player:SendBroadcastMessage("|cffff5555Salvage:|r nothing useful in that.")
        return
    end

    local mat = MaterialFor(itemClass, subClass, ilvl)
    if not mat then
        player:SendBroadcastMessage("|cffff5555Salvage:|r nothing useful in that.")
        return
    end

    local amount = math.random(band[1], band[2])

    -- Keep the link the client already renders, but put the English name back in it.
    -- A function replacement rather than a string one, so a "%" in a name cannot be read
    -- as a gsub capture escape.
    local name = item:GetName()
    local link = item:GetItemLink():gsub("%[.-%]", function() return "[" .. name .. "]" end, 1)

    -- Identify the exact item rather than its entry, so a player holding two of the same
    -- thing loses the one they actually clicked. Eluna pushes ObjectGuid BY VALUE
    -- (LuaEngine.cpp:495), so this stays valid to hold across ticks even though the Item
    -- behind it may not.
    local guid = item:GetGUID()

    -- 100 ms: one world tick is enough, and the delay is imperceptible. See the header for
    -- why this cannot run inline.
    player:RegisterEvent(function(eventId, delay, repeats, pl)
        Finish(pl, guid, link, mat, amount)
    end, 100, 1)
end

RegisterPlayerEvent(5, OnSpellCast)   -- 5 = PLAYER_EVENT_ON_SPELL_CAST

print("[Terapin] salvage.lua loaded - spell " .. SALVAGE_SPELL)
