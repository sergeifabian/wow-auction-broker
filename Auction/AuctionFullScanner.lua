local AuctionBroker = _G.AuctionBroker

local Constants = AuctionBroker.Constants
local Database = AuctionBroker.Database
local Utils = AuctionBroker.Utils
local Query = AuctionBroker.AuctionQuery

local FullScanner = {}

local state = {
    running = false,
    waiting = false,

    started = false,
    needMore = false,

    sentAt = 0,
    nextAt = 0,

    seen = {},
    count = 0,

    found = 0,
    results = {},
}

local function RefreshUI()
    if AuctionBroker.UI and AuctionBroker.UI.Refresh then
        AuctionBroker.UI:Refresh()
    end
end

function FullScanner:GetState()
    return state
end

function FullScanner:IsRunning()
    return state.running
end

function FullScanner:Start()
    if state.running then
        return
    end

    Database:Ensure()

    state.running = true
    state.waiting = false

    state.started = false
    state.needMore = false

    state.sentAt = 0
    state.nextAt = Utils.GetTime()

    state.seen = {}
    state.count = 0

    state.found = 0
    state.results = {}

    RefreshUI()
end

function FullScanner:Stop()
    state.running = false
    state.waiting = false
    state.needMore = false

    RefreshUI()
end

function FullScanner:HandleResults()
    if not state.running or not state.waiting then
        return
    end

    local results = Query.GetBrowseResults()

    for _, result in ipairs(results) do
        local itemID = result.itemKey and result.itemKey.itemID

        if itemID
            and result.minPrice
            and not state.seen[itemID]
        then
            state.seen[itemID] = true
            state.count = state.count + 1

            local name = Utils.GetItemName(itemID)
            local qty = result.totalQuantity or 0

            Database:SetPrice(itemID, {
                name = name,
                minPrice = result.minPrice,
                qty = qty,
                time = Utils.Now(),
            })

            state.found = state.found + 1

            state.results[#state.results + 1] = {
                name = name,
                price = result.minPrice,
                qty = qty,
            }
        end
    end

    state.waiting = false

    if Query.HasFullResults() then
        state.running = false
        state.needMore = false

        print(
            "AuctionBroker: полное сканирование завершено. Предметов:",
            state.count
        )

        RefreshUI()
        return
    end

    state.needMore = true
    state.nextAt = Utils.GetTime()

    RefreshUI()
end

function FullScanner:Update(now)
    if not state.running then
        return
    end

    if state.waiting then
        if now - state.sentAt > Constants.QUERY_TIMEOUT then
            state.running = false
            state.waiting = false
            state.needMore = false

            print(
                "AuctionBroker: таймаут полного сканирования. "
                .. "Получено предметов: "
                .. state.count
            )

            RefreshUI()
        end

        return
    end

    if now < state.nextAt then
        return
    end

    if not Query.IsReady() then
        return
    end

    if not state.started then
        state.waiting = true
        state.sentAt = now
        state.started = true

        local ok, err = Query.SendFullQuery()

        if not ok then
            state.running = false
            state.waiting = false

            print(
                "AuctionBroker: ошибка полного запроса:",
                err
            )

            RefreshUI()
        end

        return
    end

    if state.needMore then
        state.needMore = false
        state.waiting = true
        state.sentAt = now

        local ok, err = Query.RequestMoreResults()

        if not ok then
            state.running = false
            state.waiting = false

            print(
                "AuctionBroker: ошибка загрузки страницы:",
                err
            )

            RefreshUI()
        end

        return
    end
end

function FullScanner:HandleEvent(event)
    if not state.running then
        return
    end

    if event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        state.running = false
        state.waiting = false
        state.needMore = false

        print(
            "AuctionBroker: ошибка получения данных аукциона."
        )

        RefreshUI()
        return
    end

    if state.waiting then
        self:HandleResults()
    end
end

AuctionBroker.AuctionFullScanner = FullScanner