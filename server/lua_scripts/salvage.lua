-- Salvage: break gear back down into materials.
--
-- Universal and free. Any class, any profession, known from level 1 - no skill requirement
-- and no reagent cost.
--
-- WHAT IT ACCEPTS
--   Weapons, all armour, jewellery (rings, necks, trinkets), shields and held items, from
--   poor quality through epic. Equipped items are refused so a misclick cannot eat what you
--   are wearing; soulbound is allowed, since that is most of what anyone wants to salvage.
--
-- WHAT IT RETURNS
--   A BASE material chosen by what the item is made of, at a tier chosen by its item level,
--   plus RARITY BONUSES for green and better:
--
--     plate / mail / shields / weapons -> metal bars
--     leather                          -> leather
--     cloth, shirts, tabards           -> cloth
--     rings / necks / trinkets         -> gems, plus a precious metal bar once worthwhile
--
--     green and up  -> + enchanting dust
--     blue and up   -> + a magic essence
--     epic          -> + an enchanting shard
--
--   Jewellery is identified by INVENTORY TYPE, not by subclass. Armour subclass 0 is not
--   jewellery: measured against this database it is 691 rings, 440 necks and 424 trinkets,
--   but also 354 held items, 149 shirts and 83 tabards. Only inventory types 2 (neck),
--   11 (finger) and 12 (trinket) are actually jewellery.
--
-- WHY THE WORK IS DEFERRED BY A TICK  (this crashed the server before)
--   PLAYER_EVENT_ON_SPELL_CAST fires from Spell::prepare (Spell.cpp:3884) - PART WAY
--   THROUGH the cast, not after it. Everything below that line - TakeReagents(),
--   SendSpellGo(), handle_immediate() -> DoAllEffectOnTarget(ItemTargetInfo*) ->
--   HandleEffects(nullptr, target->item, ...) - keeps using the raw Item* we were handed.
--
--   Destroying the item inside the hook therefore pulls the rug out from under the running
--   spell. Worse, it is INTERMITTENT: Player::DestroyItem ends in SetState(ITEM_REMOVED),
--   and Item::SetState (Item.cpp:802) deletes the item outright when its state is still
--   ITEM_NEW - anything freshly looted - so the spell then dereferences freed memory. An
--   item already saved to the database is merely detached and the same code appears to work
--   fine. That is why this survived testing and then crashed with an ACCESS_VIOLATION.
--
-- WHY THE LINK IS REBUILT
--   LuaItem::GetItemLink returns the FRENCH name: it overrides the English name whenever
--   ANY locales_item row exists, and indexes Name[] with a raw LocaleConstant.
--   ObjectMgr::GetOrNewIndexForLocale returns -1 for enUS and packs the other locales
--   densely in first-seen order, so with French rows loaded, index 0 IS French.

local SALVAGE_SPELL = 38600

local CLASS_WEAPON, CLASS_ARMOR = 2, 4
local ARMOR_MISC, ARMOR_CLOTH, ARMOR_LEATHER, ARMOR_MAIL, ARMOR_PLATE = 0, 1, 2, 3, 4
local ARMOR_SHIELD = 6

local JEWELLERY = { [2] = true, [11] = true, [12] = true }   -- neck, finger, trinket
local CLOTHLIKE = { [4] = true, [19] = true, [20] = true }   -- shirt, tabard, robe

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
local GEMS = {
    { 60, 12800 },  -- Azerothian Diamond
    { 55, 12361 },  -- Blue Sapphire
    { 50, 12799 },  -- Large Opal
    { 45, 7910  },  -- Star Ruby
    { 40, 7909  },  -- Aquamarine
    { 35, 1529  },  -- Jade
    { 30, 3864  },  -- Citrine
    { 25, 1206  },  -- Moss Agate
    { 20, 1705  },  -- Lesser Moonstone
    { 15, 1210  },  -- Shadowgem
    { 8,  774   },  -- Malachite
    { 0,  818   },  -- Tigerseye
}
local PRECIOUS = {
    { 45, 6037 },   -- Truesilver Bar
    { 30, 3577 },   -- Gold Bar
    { 0,  2842 },   -- Silver Bar
}
local DUST = {
    { 55, 16204 },  -- Illusion Dust
    { 45, 11176 },  -- Dream Dust
    { 35, 11137 },  -- Vision Dust
    { 25, 11083 },  -- Soul Dust
    { 0,  10940 },  -- Strange Dust
}
local ESSENCE = {
    { 55, 16203 },  -- Greater Eternal Essence
    { 50, 16202 },  -- Lesser Eternal Essence
    { 45, 11175 },  -- Greater Nether Essence
    { 40, 11174 },  -- Lesser Nether Essence
    { 35, 11135 },  -- Greater Mystic Essence
    { 30, 11134 },  -- Lesser Mystic Essence
    { 25, 11082 },  -- Greater Astral Essence
    { 20, 10998 },  -- Lesser Astral Essence
    { 10, 10939 },  -- Greater Magic Essence
    { 0,  10938 },  -- Lesser Magic Essence
}
local SHARD = {
    { 55, 14344 },  -- Large Brilliant Shard
    { 50, 14343 },  -- Small Brilliant Shard
    { 45, 11178 },  -- Large Radiant Shard
    { 40, 11177 },  -- Small Radiant Shard
    { 35, 11139 },  -- Large Glowing Shard
    { 30, 11138 },  -- Small Glowing Shard
    { 25, 11084 },  -- Large Glimmering Shard
    { 0,  10978 },  -- Small Glimmering Shard
}

-- quality -> { base min, base max, dust, essence, shard }
local YIELD = {
    [0] = { 0, 1, false, false, false },   -- poor
    [1] = { 0, 2, false, false, false },   -- white
    [2] = { 1, 5, true,  false, false },   -- green
    [3] = { 2, 6, true,  true,  false },   -- blue
    [4] = { 3, 8, true,  true,  true  },   -- epic
}

local function PickTier(tiers, ilvl)
    for i = 1, #tiers do
        if ilvl >= tiers[i][1] then
            return tiers[i][2]
        end
    end
    return tiers[#tiers][2]
end

-- Returns the base material table, and whether a precious metal comes with it.
local function BaseMaterial(itemClass, subClass, invType)
    if JEWELLERY[invType] then
        return GEMS, true
    end
    if itemClass == CLASS_WEAPON then
        return BARS, false
    end
    if itemClass == CLASS_ARMOR then
        if subClass == ARMOR_CLOTH then return CLOTH, false end
        if subClass == ARMOR_LEATHER then return LEATHER, false end
        if subClass == ARMOR_MAIL or subClass == ARMOR_PLATE or subClass == ARMOR_SHIELD then
            return BARS, false
        end
        if subClass == ARMOR_MISC and CLOTHLIKE[invType] then
            return CLOTH, false
        end
        return BARS, false
    end
    return nil, false
end

-- Runs a tick after the cast, from a one-shot timed event. By now the Spell object that
-- handed us the item is gone, so destroying the item is safe.
local function Finish(player, guid, link, rewards)
    -- Re-find it by guid. If it is gone - destroyed, traded, mailed in the meantime - grant
    -- nothing. Bailing out is the safe direction to fail: awarding materials without
    -- consuming an item would be a duplication bug.
    local item = player:GetItemByGUID(guid)
    if not item then
        player:SendBroadcastMessage("|cffff5555Salvage:|r that item is no longer in your bags.")
        return
    end

    player:RemoveItem(item, 1)

    local given = 0
    for i = 1, #rewards do
        local entry, count = rewards[i][1], rewards[i][2]
        if count > 0 then
            player:AddItem(entry, count)
            given = given + count
        end
    end

    if given > 0 then
        player:SendBroadcastMessage(string.format(
            "|cff33ff99Salvage:|r %s yielded %d material(s).", link, given))
    else
        -- A poor or white item can legitimately produce nothing. Say so rather than leaving
        -- the player wondering whether the spell failed.
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

    local quality   = item:GetQuality()
    local ilvl      = item:GetItemLevel()
    local itemClass = item:GetClass()
    local subClass  = item:GetSubClass()
    local invType   = item:GetInventoryType()

    if itemClass ~= CLASS_WEAPON and itemClass ~= CLASS_ARMOR then
        player:SendBroadcastMessage("|cffff5555Salvage:|r only weapons, armour and jewellery can be salvaged.")
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

    local baseTable, alsoPrecious = BaseMaterial(itemClass, subClass, invType)
    if not baseTable then
        player:SendBroadcastMessage("|cffff5555Salvage:|r nothing useful in that.")
        return
    end

    local rewards = {}
    rewards[#rewards + 1] = { PickTier(baseTable, ilvl), math.random(band[1], band[2]) }

    -- Jewellery gives a precious metal alongside its gem, but only once it is worth
    -- something - a level 3 copper ring should not hand out silver.
    if alsoPrecious and ilvl >= 15 then
        rewards[#rewards + 1] = { PickTier(PRECIOUS, ilvl), 1 }
    end

    if band[3] then rewards[#rewards + 1] = { PickTier(DUST, ilvl), math.random(1, 2) } end
    if band[4] then rewards[#rewards + 1] = { PickTier(ESSENCE, ilvl), 1 } end
    if band[5] then rewards[#rewards + 1] = { PickTier(SHARD, ilvl), 1 } end

    -- Keep the link the client already renders, but put the English name back in it. A
    -- function replacement rather than a string one, so a percent sign in a name cannot be
    -- read as a gsub capture escape.
    local name = item:GetName()
    local link = item:GetItemLink():gsub("%[.-%]", function() return "[" .. name .. "]" end, 1)

    -- Identify the exact item rather than its entry, so a player holding two of the same
    -- thing loses the one they clicked. Eluna pushes ObjectGuid BY VALUE
    -- (LuaEngine.cpp:495), so a guid is safe to hold across ticks; an Item* is not.
    local guid = item:GetGUID()

    -- 100 ms: one world tick is enough, and the delay is imperceptible. See the header for
    -- why this cannot run inline.
    player:RegisterEvent(function(eventId, delay, repeats, pl)
        Finish(pl, guid, link, rewards)
    end, 100, 1)
end

RegisterPlayerEvent(5, OnSpellCast)   -- 5 = PLAYER_EVENT_ON_SPELL_CAST

print("[Terapin] salvage.lua loaded - spell " .. SALVAGE_SPELL)
