local AuctionBroker = _G.AuctionBroker

local Constants = AuctionBroker.Constants
local Scanner = AuctionBroker.AuctionScanner
local FullScanner = AuctionBroker.AuctionFullScanner
local Utils = AuctionBroker.Utils

local UI = {}

local panel
local tabCreated = false
local ui = {}

local function GetScanState()
    local bagState = Scanner:GetState()
    local fullState = FullScanner:GetState()

    if FullScanner:IsRunning() then
        return {
            mode = "full",
            running = true,

            total = 0,
            done = fullState.count,

            found = fullState.found,
            missing = 0,
            failed = 0,

            results = fullState.results,
        }
    end

    return {
        mode = "bags",
        running = Scanner:IsRunning(),

        total = bagState.total,
        done = bagState.done,

        found = bagState.found,
        missing = bagState.missing,
        failed = bagState.failed,

        results = bagState.results,
    }
end

function UI:Refresh()
    if not panel then
        return
    end

    local state = GetScanState()

    if state.mode == "full" then
        ui.progress:SetText(string.format(
            "Полное сканирование: получено предметов — %d",
            state.done
        ))
    else
        local pct = 0

        if state.total > 0 then
            pct = math.max(
                0,
                math.min(
                    100,
                    math.floor(
                        state.done / state.total * 100
                    )
                )
            )
        end

        ui.progress:SetText(string.format(
            "Прогресс: %d%% (%d/%d)",
            pct,
            state.done,
            state.total
        ))
    end

    ui.stat:SetText(string.format(
        "Найдено: %d   Нет на аукционе: %d   Ошибок: %d",
        state.found,
        state.missing,
        state.failed
    ))

    local lines = {}

    local from = math.max(
        1,
        #state.results - Constants.MAX_LINES + 1
    )

    for i = from, #state.results do
        local result = state.results[i]

        if result.price then
            lines[#lines + 1] = string.format(
                "%s: %s  (%d шт.)",
                result.name,
                Utils.Money(result.price),
                result.qty or 0
            )
        else
            lines[#lines + 1] = string.format(
                "%s: нет цены выкупа",
                result.name
            )
        end
    end

    ui.list:SetText(
        table.concat(lines, "\n")
    )

    if state.running then
        ui.bags:Disable()
        ui.full:Disable()
        ui.stop:Enable()
    else
        ui.bags:Enable()
        ui.full:Enable()
        ui.stop:Disable()
    end
end

local function InitAuctionTab()
    print("|cffffd700DeepBroker: InitAuctionTab called|r")
    print("AuctionHouseFrame:", AuctionHouseFrame)
    print("AuctionHouseFrame.Tabs:", AuctionHouseFrame and AuctionHouseFrame.Tabs)

    if tabCreated
        or not AuctionHouseFrame
        or not AuctionHouseFrame.Tabs
    then
        return
    end

    tabCreated = true

    panel = CreateFrame(
        "Frame",
        nil,
        AuctionHouseFrame
    )

    panel:SetPoint(
        "TOPLEFT",
        AuctionHouseFrame,
        "TOPLEFT",
        10,
        -65
    )

    panel:SetPoint(
        "BOTTOMRIGHT",
        AuctionHouseFrame,
        "BOTTOMRIGHT",
        -10,
        35
    )

    panel:Hide()

    AuctionHouseFrame.AuctionBrokerPanel = panel

    local title = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )

    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("AuctionBroker")

    ui.bags = CreateFrame(
        "Button",
        nil,
        panel,
        "UIPanelButtonTemplate"
    )

    ui.bags:SetSize(145, 26)
    ui.bags:SetPoint("TOPLEFT", 10, -45)
    ui.bags:SetText("Сканировать сумки")
    ui.bags:SetScript(
        "OnClick",
        function()
            Scanner:StartBagScan()
        end
    )

    ui.full = CreateFrame(
        "Button",
        nil,
        panel,
        "UIPanelButtonTemplate"
    )

    ui.full:SetSize(165, 26)
    ui.full:SetPoint(
        "LEFT",
        ui.bags,
        "RIGHT",
        8,
        0
    )

    ui.full:SetText("Сканировать аукцион")

    ui.full:SetScript(
        "OnClick",
        function()
            FullScanner:Start()
        end
    )

    ui.stop = CreateFrame(
        "Button",
        nil,
        panel,
        "UIPanelButtonTemplate"
    )

    ui.stop:SetSize(80, 26)
    ui.stop:SetPoint(
        "LEFT",
        ui.full,
        "RIGHT",
        8,
        0
    )

    ui.stop:SetText("Стоп")

    ui.stop:SetScript(
        "OnClick",
        function()
            Scanner:Stop()
        end
    )

    ui.stop:Disable()

    ui.progress = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )

    ui.progress:SetPoint(
        "TOPLEFT",
        ui.bags,
        "BOTTOMLEFT",
        0,
        -15
    )

    ui.stat = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )

    ui.stat:SetPoint(
        "TOPLEFT",
        ui.progress,
        "BOTTOMLEFT",
        0,
        -6
    )

    ui.list = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )

    ui.list:SetPoint(
        "TOPLEFT",
        ui.stat,
        "BOTTOMLEFT",
        0,
        -10
    )

    ui.list:SetJustifyH("LEFT")
    ui.list:SetWidth(740)

    local mode = {
        "AuctionBrokerPanel"
    }

    local tab = CreateFrame(
        "Button",
        "AuctionBrokerAuctionTab",
        AuctionHouseFrame,
        "AuctionHouseFrameDisplayModeTabTemplate"
    )

    tab:SetPoint(
        "LEFT",
        AuctionHouseFrameAuctionsTab,
        "RIGHT",
        -15,
        0
    )

    tab:SetText("AuctionBroker")
    tab.displayMode = mode

    if PanelTemplates_TabResize then
        pcall(
            PanelTemplates_TabResize,
            tab,
            0
        )
    end

    local present = false

    for _, existingTab in ipairs(
        AuctionHouseFrame.Tabs
    ) do
        if existingTab == tab then
            present = true
            break
        end
    end

    if not present then
        table.insert(
            AuctionHouseFrame.Tabs,
            tab
        )
    end

    if PanelTemplates_SetNumTabs then
        pcall(
            PanelTemplates_SetNumTabs,
            AuctionHouseFrame,
            #AuctionHouseFrame.Tabs
        )
    end

    hooksecurefunc(
        AuctionHouseFrame,
        "SetDisplayMode",
        function(self, displayMode)
            panel:SetShown(
                displayMode == mode
            )

            for i, existingTab in ipairs(
                self.Tabs
            ) do
                if existingTab.displayMode == displayMode then
                    PanelTemplates_SetTab(
                        self,
                        i
                    )

                    break
                end
            end
        end
    )

    AuctionHouseFrame:HookScript(
        "OnHide",
        function()
            Scanner:Stop()
        end
    )

    UI:Refresh()
end

function UI:Init()
    local loader = CreateFrame("Frame")

    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("AUCTION_HOUSE_SHOW")

    loader:SetScript("OnEvent", function(self, event)
        if event == "ADDON_LOADED" then
            InitAuctionTab()
        elseif event == "AUCTION_HOUSE_SHOW" then
            InitAuctionTab()
        end

        if tabCreated then
            self:UnregisterAllEvents()
        end
    end)

    -- Если интерфейс аукциона уже доступен, создаём вкладку сразу.
    InitAuctionTab()
end

AuctionBroker.UI = UI