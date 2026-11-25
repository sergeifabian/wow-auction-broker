local AuctionBroker = _G.AuctionBroker

local Constants = AuctionBroker.Constants
local Database = AuctionBroker.Database
local Utils = AuctionBroker.Utils
local Query = AuctionBroker.AuctionQuery
local FullScanner = AuctionBroker.AuctionFullScanner

local Scanner = {}

local state = {
    running = false,
    waiting = false,

    items = {},
    total = 0,
    done = 0,
    index = 0,
    current = nil,

    sentAt = 0,
    nextAt = 0,
    morePages = 0,

    results = {},
    found = 0,
    missing = 0,
    failed = 0,
}

local function RefreshUI()
    if AuctionBroker.UI and AuctionBroker.UI.Refresh then
        AuctionBroker.UI:Refresh()
    end
end

local function CollectBagItems()
    local seen = {}
    local list = {}

    local last = NUM_BAG_SLOTS or 4

    if Enum
        and Enum.BagIndex
        and Enum.BagIndex.ReagentBag
    then
        last = Enum.BagIndex.ReagentBag
    elseif NUM_REAGENTBAG_SLOTS then
        last = last + NUM_REAGENTBAG_SLOTS
    end

    for bag = 0, last do
        local slots = C_Container.GetContainerNumSlots(bag) or 0

        for slot = 1, slots do
            local info =
                C_Container.GetContainerItemInfo(bag, slot)

            if info
                and info.itemID
                and not info.isBound
                and not seen[info.itemID]
            then
                seen[info.itemID] = true

                local name = info.itemName

                if not name
                    and C_Item
                    and C_Item.GetItemNameByID
                then
                    name = C_Item.GetItemNameByID(info.itemID)
                end

                if not name and GetItemInfo then
                    name = GetItemInfo(info.itemID)
                end

                list[#list + 1] = {
                    id = info.itemID,
                    name = name,
                }
            end
        end
    end

    return list
end

local function Advance()
    state.done = state.done + 1
    state.current = nil
    state.waiting = false

    state.nextAt =
        Utils.GetTime() + Constants.QUERY_DELAY

    if state.done >= state.total then
        state.running = false
    end

    RefreshUI()
end

local function ProcessResults(force)
    local item = state.current

    if not item or not state.waiting then
        return
    end

    local results = Query.GetBrowseResults()

    if #results == 0 and not force then
        return
    end

    local best
    local qty

    for _, result in ipairs(results) do
        if result.itemKey
            and result.itemKey.itemID == item.id
            and result.minPrice
        then
            if not best
                or result.minPrice < best
            then
                best = result.minPrice
            end

            qty = (qty or 0)
                + (result.totalQuantity or 0)
        end
    end

    if best then
        Database:SetPrice(item.id, {
            name = item.name,
            minPrice = best,
            qty = qty,
            time = Utils.Now(),
        })

        state.found = state.found + 1

        state.results[#state.results + 1] = {
            name = item.name,
            price = best,
            qty = qty,
        }

        Advance()
        return
    end

    local full = true

    if C_AuctionHouse.HasFullBrowseResults then
        full = C_AuctionHouse.HasFullBrowseResults()
    end

    if not force
        and not full
        and state.morePages < Constants.MAX_MORE_PAGES
        and C_AuctionHouse.RequestMoreBrowseResults
    then
        state.morePages = state.morePages + 1
        state.sentAt = Utils.GetTime()

        Query.RequestMoreResults()

        return
    end

    Database:SetPrice(item.id, {
        name = item.name,
        missing = true,
        time = Utils.Now(),
    })

    state.missing = state.missing + 1

    state.results[#state.results + 1] = {
        name = item.name,
    }

    Advance()
end

local function SendNext()
    if not Query.IsReady() then
        return
    end

    state.index = state.index + 1

    local item = state.items[state.index]

    if not item then
        state.running = false
        RefreshUI()
        return
    end

    state.current = item
    state.morePages = 0

    if not item.name then
        state.failed = state.failed + 1
        Advance()
        return
    end

    state.waiting = true
    state.sentAt = Utils.GetTime()

    local ok, err = Query.SendItemQuery(item.name)

    if not ok then
        print(
            "AuctionBroker: ошибка запроса:",
            err
        )

        state.failed = state.failed + 1
        Advance()
    end
end

function Scanner:GetState()
    return state
end

function Scanner:IsRunning()
    return state.running
end

function Scanner:StartBagScan()
    if state.running or FullScanner:IsRunning() then
        return
    end

    Database:Ensure()

    state.items = CollectBagItems()
    state.total = #state.items

    state.done = 0
    state.index = 0
    state.current = nil

    state.found = 0
    state.missing = 0
    state.failed = 0

    state.results = {}

    state.waiting = false
    state.nextAt = 0

    state.running = state.total > 0

    RefreshUI()
end

function Scanner:Stop()
    state.running = false
    state.waiting = false

    FullScanner:Stop()

    RefreshUI()
end

function Scanner:Update(now)
    if not state.running then
        return
    end

    if not state.waiting then
        if now >= state.nextAt then
            SendNext()
        end

        return
    end

    local elapsed = now - state.sentAt

    if elapsed > Constants.QUERY_TIMEOUT then
        ProcessResults(true)

    elseif elapsed > Constants.EMPTY_GRACE
        and state.morePages == 0
        and #Query.GetBrowseResults() == 0
    then
        ProcessResults(true)
    end
end

function Scanner:HandleEvent(event)
    if not state.running then
        return
    end

    if not state.waiting then
        return
    end

    if event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        local item = state.current

        if not item then
            return
        end

        item.retries = (item.retries or 0) + 1

        if item.retries <= Constants.MAX_RETRIES then
            state.index = state.index - 1
            state.waiting = false
            state.nextAt = Utils.GetTime() + 1
        else
            state.failed = state.failed + 1
            Advance()
        end
    else
        ProcessResults(false)
    end
end

local ticker = CreateFrame("Frame")

ticker:SetScript("OnUpdate", function()
    local now = Utils.GetTime()

    if FullScanner:IsRunning() then
        FullScanner:Update(now)
        return
    end

    Scanner:Update(now)
end)

local events = CreateFrame("Frame")

events:RegisterEvent(
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"
)

pcall(
    events.RegisterEvent,
    events,
    "AUCTION_HOUSE_BROWSE_RESULTS_ADDED"
)

pcall(
    events.RegisterEvent,
    events,
    "AUCTION_HOUSE_BROWSE_FAILURE"
)

events:SetScript("OnEvent", function(_, event)
    if FullScanner:IsRunning() then
        FullScanner:HandleEvent(event)
        return
    end

    Scanner:HandleEvent(event)
end)

AuctionBroker.AuctionScanner = Scanner