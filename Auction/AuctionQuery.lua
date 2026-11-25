local AuctionBroker = _G.AuctionBroker

local Query = {}

function Query.BuildItemQuery(name)
    return {
        searchString = name,
        sorts = {
            { sortOrder = 0, reverseSort = false }, -- Price
            { sortOrder = 1, reverseSort = false }, -- Name
        },
        minLevel = 0,
        maxLevel = 0,
        filters = { 6, 7, 8, 9, 10, 11, 12 },
    }
end

function Query.BuildFullQuery()
    return {
        searchString = "",
        sorts = {},
        filters = {},
        itemClassFilters = {},
    }
end

function Query.SendItemQuery(name)
    return pcall(
        C_AuctionHouse.SendBrowseQuery,
        Query.BuildItemQuery(name)
    )
end

function Query.SendFullQuery()
    return pcall(
        C_AuctionHouse.SendBrowseQuery,
        Query.BuildFullQuery()
    )
end

function Query.RequestMoreResults()
    return pcall(
        C_AuctionHouse.RequestMoreBrowseResults
    )
end

function Query.IsReady()
    if C_AuctionHouse.IsThrottledMessageSystemReady
        and not C_AuctionHouse.IsThrottledMessageSystemReady()
    then
        return false
    end

    return true
end

function Query.HasFullResults()
    if C_AuctionHouse.HasFullBrowseResults then
        return C_AuctionHouse.HasFullBrowseResults()
    end

    return true
end

function Query.GetBrowseResults()
    return C_AuctionHouse.GetBrowseResults() or {}
end

AuctionBroker.AuctionQuery = Query