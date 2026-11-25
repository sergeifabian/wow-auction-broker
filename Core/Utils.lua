local AuctionBroker = _G.AuctionBroker

local Utils = {}

function Utils.Money(copper)
    return GetMoneyString(
        math.floor(tonumber(copper) or 0),
        true
    )
end

function Utils.GetItemName(itemID)
    local name

    if C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(itemID)
    end

    if not name and GetItemInfo then
        name = GetItemInfo(itemID)
    end

    return name or ("Item " .. tostring(itemID))
end

function Utils.Now()
    return time()
end

function Utils.GetTime()
    return GetTime()
end

AuctionBroker.Utils = Utils