local AuctionBroker = _G.AuctionBroker

local Database = AuctionBroker.Database
local Utils = AuctionBroker.Utils

local Tooltip = {}

local function GetHoverStackCount(tooltip)
    local owner =
        tooltip.GetOwner
        and tooltip:GetOwner()

    if not owner or not owner.GetID then
        return nil
    end

    local slot = owner:GetID()

    local bag =
        owner.GetBagID
        and owner:GetBagID()

    if bag == nil then
        local parent =
            owner.GetParent
            and owner:GetParent()

        bag =
            parent
            and parent.GetID
            and parent:GetID()
    end

    if bag == nil
        or not slot
        or slot == 0
    then
        return nil
    end

    local info =
        C_Container.GetContainerItemInfo(
            bag,
            slot
        )

    return info
        and info.stackCount,
        info
        and info.itemID
end

local function GetUnitSellPrice(itemID)
    local getInfo =
        GetItemInfo
        or (
            C_Item
            and C_Item.GetItemInfo
        )

    if not getInfo then
        return nil
    end

    local result = {
        pcall(getInfo, itemID)
    }

    if not result[1] then
        return nil
    end

    if type(result[2]) == "table" then
        return result[2].sellPrice
    end

    return result[12]
end

local function FindVendorLine(tooltip)
    local name = tooltip:GetName()

    if not name then
        return nil
    end

    for i = 2, tooltip:NumLines() do
        local fontString =
            _G[name .. "TextLeft" .. i]

        local text =
            fontString
            and fontString:GetText()

        if text
            and text:find(":")
            and (
                text:find("MoneyFrame")
                or text:find("coin")
            )
            and not text:find("^Аукцион")
        then
            return fontString, text
        end
    end

    return nil
end

local function AddAuctionLine(
    tooltip,
    itemID
)
    if not itemID then
        return
    end

    local count = 1
    local mark = ""

    if IsShiftKeyDown() then
        local n, hoveredItemID =
            GetHoverStackCount(tooltip)

        if n
            and n >= 1
            and hoveredItemID == itemID
        then
            count = n
            mark =
                " (×" .. count .. ")"
        end
    end

    local unit =
        GetUnitSellPrice(itemID)

    local fontString, text =
        FindVendorLine(tooltip)

    if unit
        and unit > 0
        and fontString
    then
        local label =
            text:match("^(.-):")

        if label then
            fontString:SetText(
                label
                    .. ": "
                    .. mark
                    .. " "
                    .. Utils.Money(
                        unit * count
                    )
            )
        end
    end

    local price =
        Database:GetPrice(itemID)

    if not price then
        return
    end

    local stamp =
        price.time
        and date(
            "%d.%m %H:%M",
            price.time
        )
        or "?"

    local age =
        price.time
        and (
            time() - price.time
        )
        or nil

    local dateColor =
        "|cff888888"

    if age then
        if age < 15 * 60 then
            dateColor = "|cff00ff00"
        elseif age < 30 * 60 then
            dateColor = "|cffffff00"
        else
            dateColor = "|cffff0000"
        end
    end

    if price.minPrice then
        tooltip:AddLine(
            "Цена на аукционе: "
                .. mark
                .. " "
                .. Utils.Money(
                    price.minPrice * count
                ),
            1,
            1,
            1
        )
    else
        local status =
            (
                price.qty
                and price.qty > 0
            )
            and "нет цены выкупа"
            or "нет лотов"

        tooltip:AddLine(
            "Цена на аукционе: "
                .. mark
                .. " "
                .. status,
            1,
            1,
            1
        )
    end

    tooltip:AddLine(
        "Дата сканирования: "
            .. dateColor
            .. stamp
            .. "|r",
        1,
        1,
        1
    )
end

local function RegisterTooltipHook()
    if TooltipDataProcessor
        and TooltipDataProcessor.AddTooltipPostCall
        and Enum.TooltipDataType
        and Enum.TooltipDataType.Item
    then
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Item,
            function(tooltip, data)
                if data and data.id then
                    AddAuctionLine(
                        tooltip,
                        data.id
                    )
                end
            end
        )

        return
    end

    local function OnSetItem(tooltip)
        local _, link =
            tooltip:GetItem()

        local itemID =
            link
            and tonumber(
                link:match(
                    "item:(%d+)"
                )
            )

        AddAuctionLine(
            tooltip,
            itemID
        )

        tooltip:Show()
    end

    GameTooltip:HookScript(
        "OnTooltipSetItem",
        OnSetItem
    )

    ItemRefTooltip:HookScript(
        "OnTooltipSetItem",
        OnSetItem
    )
end

local function RegisterModifierHook()
    local frame =
        CreateFrame("Frame")

    frame:RegisterEvent(
        "MODIFIER_STATE_CHANGED"
    )

    frame:SetScript(
        "OnEvent",
        function(_, _, key)
            if key ~= "LSHIFT"
                and key ~= "RSHIFT"
            then
                return
            end

            if not GameTooltip:IsShown() then
                return
            end

            local owner =
                GameTooltip:GetOwner()

            if not owner then
                return
            end

            local _, link =
                GameTooltip:GetItem()

            local itemID =
                link
                and tonumber(
                    link:match(
                        "item:(%d+)"
                    )
                )

            local count, bagItemID =
                GetHoverStackCount(
                    GameTooltip
                )

            if itemID
                and count
                and count >= 1
                and bagItemID == itemID
            then
                local onEnter =
                    owner:GetScript(
                        "OnEnter"
                    )

                if onEnter then
                    pcall(
                        onEnter,
                        owner
                    )
                end
            end
        end
    )
end

function Tooltip:Init()
    RegisterTooltipHook()
    RegisterModifierHook()
end

AuctionBroker.AuctionTooltip = Tooltip