local AuctionBroker = _G.AuctionBroker

local Database = {}

function Database:Ensure()
    AuctionBrokerDB = AuctionBrokerDB or {}
    AuctionBrokerDB.prices = AuctionBrokerDB.prices or {}
end

function Database:GetPrice(itemID)
    if not AuctionBrokerDB or not AuctionBrokerDB.prices then
        return nil
    end

    return AuctionBrokerDB.prices[itemID]
end

function Database:SetPrice(itemID, data)
    self:Ensure()
    AuctionBrokerDB.prices[itemID] = data
end

AuctionBroker.Database = Database