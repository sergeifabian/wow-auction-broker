print("|cff00ff00DeepBroker: AuctionBroker.lua loaded|r")

local addonName = ...

local AuctionBroker = _G.AuctionBroker

AuctionBroker.Name = addonName

AuctionBroker.Database:Ensure()

if AuctionBroker.UI then
    print("|cff00ff00DeepBroker: before UI init|r")
    AuctionBroker.UI:Init()
    print("|cff00ff00DeepBroker: after UI init|r")
end

if AuctionBroker.AuctionTooltip then
    AuctionBroker.AuctionTooltip:Init()
end