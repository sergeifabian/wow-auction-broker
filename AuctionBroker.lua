local addonName = ...

local AuctionBroker = _G.AuctionBroker

AuctionBroker.Name = addonName

AuctionBroker.Database:Ensure()

if AuctionBroker.UI then
    AuctionBroker.UI:Init()
end

if AuctionBroker.AuctionTooltip then
    AuctionBroker.AuctionTooltip:Init()
end