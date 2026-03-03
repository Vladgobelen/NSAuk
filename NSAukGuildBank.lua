-- NSAukGuildBank.lua: Класс гильдбанка для аддона NSAuk (WoW 3.3.5)
-- Версия: 6.2 (Исправлено отображение для ретрансляторов и форматирование)
NSAukGuildBankClass = {}
NSAukGuildBankClass.__index = NSAukGuildBankClass
local SEND_DELAY = 0.05
local AUTO_SCAN_DELAY = 0.1
local SCAN_COOLDOWN = 20
local SCAN_FINISH_DELAY = 1.0
local PREFIX_END = "ns_GBEnd"

local function mysplit(str)
    local t = {}
    for word in string.gmatch(str, "%S+") do
        table.insert(t, word)
    end
    return t
end

NSAukGuildBankClass.PriceMultipliers = {
    byClass = {
        ["Символы"] = { fixedPrice = 10000 },
    },
    bySubclass = {
        ["Трава"] = 5,
    },
}

function NSAukGuildBankClass.new(parentAddon)
    local self = setmetatable({}, NSAukGuildBankClass)
    self.parent = parentAddon
    self.frame = nil
    self.itemFrames = {}
    self.itemEntries = {}
    self.ownershipData = {}
    self.scanCooldown = false
    self.cooldownRemaining = 0
    self.isScanning = false
    self.sendQueue = {}
    self.sendFrame = nil
    self.tradeFrame = nil
    self.tradeData = nil
    self.bagSnapshot = {}
    self.bankSnapshot = {}
    self.autoScanFrame = nil
    self.pendingBagScan = false
    self.pendingBankScan = false
    self.scanSessionStart = 0
    self.scanSessionActive = false
    self.receivedOwnersThisScan = {}
    self.scanFinishFrame = nil
    self.sessionFinalizeFrame = nil
    self.cooldownFrame = nil
    self.tradeClosedProcessed = false
    self.tradePartnerName = nil
    self.tradeStartMoney = 0
    self.incomingBuffers = {}

    if not NSAukGlobal then NSAukGlobal = {} end
    if not NSAukGlobal.guildBanks then NSAukGlobal.guildBanks = {} end
    if not NSAukGlobal.guildBanksSettings then NSAukGlobal.guildBanksSettings = {} end
    if not NSAukGlobal['золото'] then NSAukGlobal['золото'] = {} end
    if not NSAukGlobal['баланс'] then NSAukGlobal['баланс'] = {} end
    if not NSAukGlobal.guildBankTimestamps then NSAukGlobal.guildBankTimestamps = {} end
    if not NSAukGlobal.guildBankVersions then NSAukGlobal.guildBankVersions = {} end

    self:RegisterAddonChatHandler()
    self:RegisterTradeEvents()
    self:RegisterAutoScanEvents()
    self:InitializeImmediately()
    return self
end

function NSAukGuildBankClass:RegisterAutoScanEvents()
    if not self.autoScanFrame then
        self.autoScanFrame = CreateFrame("Frame")
    end
    self.autoScanFrame.owner = self
    self.autoScanFrame:SetScript("OnEvent", function(frame, event, ...)
        frame.owner:OnAutoScanEvent(event, ...)
    end)
    self.autoScanFrame:UnregisterAllEvents()
    self.autoScanFrame:RegisterEvent("BAG_UPDATE")
    self.autoScanFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self.autoScanFrame:RegisterEvent("ITEM_PUSH")
    self.autoScanFrame:RegisterEvent("PLAYER_MONEY")
    self.autoScanFrame:RegisterEvent("BANKFRAME_OPENED")
end

function NSAukGuildBankClass:OnAutoScanEvent(event, ...)
    local isGuildBank = self:IsGuildBankCharacter()
    if not isGuildBank then return end
    if event == "BAG_UPDATE" then
        local bagID = ...
        if bagID and bagID >= 0 and bagID <= 4 then
            self:ScheduleBagScan()
        end
    elseif event == "BANKFRAME_OPENED" then
        self:ScheduleBankScan()
    elseif event == "PLAYER_MONEY" then
        self:UpdateGoldInTable()
    elseif event == "ITEM_PUSH" or event == "BAG_UPDATE_COOLDOWN" then
        self:ScheduleBagScan()
    end
end

function NSAukGuildBankClass:ScheduleBagScan()
    if self.pendingBagScan then return end
    self.pendingBagScan = true
    if not self.autoScanFrame then
        self.autoScanFrame = CreateFrame("Frame")
    end
    self.autoScanFrame.startTime = GetTime()
    self.autoScanFrame:SetScript("OnUpdate", function(frame)
        if GetTime() - frame.startTime < AUTO_SCAN_DELAY then return end
        frame:SetScript("OnUpdate", nil)
        frame.owner.pendingBagScan = false
        frame.owner:ScanBagsToTable()
    end)
    self.autoScanFrame:Show()
end

function NSAukGuildBankClass:ScheduleBankScan()
    if self.pendingBankScan then return end
    self.pendingBankScan = true
    if not self.autoScanFrame then
        self.autoScanFrame = CreateFrame("Frame")
    end
    self.autoScanFrame.startTime = GetTime()
    self.autoScanFrame:SetScript("OnUpdate", function(frame)
        if GetTime() - frame.startTime < AUTO_SCAN_DELAY then return end
        frame:SetScript("OnUpdate", nil)
        frame.owner.pendingBankScan = false
        frame.owner:ScanBankToTable()
    end)
    self.autoScanFrame:Show()
end

function NSAukGuildBankClass:ScanBagsToTable()
    local myName = UnitName("player")
    if not NSAukGlobal then NSAukGlobal = {} end
    if not NSAukGlobal.guildBanks then NSAukGlobal.guildBanks = {} end
    if not NSAukGlobal.guildBanks[myName] then NSAukGlobal.guildBanks[myName] = {} end
    local currentItems = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, count = GetContainerItemInfo(bag, slot)
                    count = count or 1
                    currentItems[link] = (currentItems[link] or 0) + count
                end
            end
        end
    end
    self:UpdateCharacterTable(myName, currentItems, "bags")
end

function NSAukGuildBankClass:ScanBankToTable()
    if not BankFrame or not BankFrame:IsShown() then
        self.pendingBankScan = false
        return
    end
    local myName = UnitName("player")
    if not NSAukGlobal then NSAukGlobal = {} end
    if not NSAukGlobal.guildBanks then NSAukGlobal.guildBanks = {} end
    if not NSAukGlobal.guildBanks[myName] then NSAukGlobal.guildBanks[myName] = {} end
    local currentItems = {}
    local bankBags = { -1, 5, 6, 7, 8, 9, 10, 11 }
    for _, bag in ipairs(bankBags) do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, count = GetContainerItemInfo(bag, slot)
                    count = count or 1
                    currentItems[link] = (currentItems[link] or 0) + count
                end
            end
        end
    end
    self:UpdateCharacterTable(myName, currentItems, "bank")
end

function NSAukGuildBankClass:UpdateCharacterTable(charName, currentItems, source)
    if not NSAukGlobal.guildBanks[charName] then
        NSAukGlobal.guildBanks[charName] = {}
    end
    local existingMap = {}
    for _, entry in ipairs(NSAukGlobal.guildBanks[charName]) do
        if entry.link then
            existingMap[entry.link] = entry.count
        end
    end
    for link, count in pairs(currentItems) do
        existingMap[link] = count
    end
    local newTable = {}
    for link, count in pairs(existingMap) do
        if count > 0 then
            local _, _, itemIDStr = string.find(link, "item:(%d+):")
            local itemID = itemIDStr and tonumber(itemIDStr)
            if itemID and itemID > 0 then
                table.insert(newTable, { link = link, id = itemID, count = count, source = source })
            end
        end
    end
    NSAukGlobal.guildBanks[charName] = newTable
    NSAukGlobal.guildBankTimestamps[charName] = GetTime()
end

function NSAukGuildBankClass:UpdateGoldInTable()
    local myName = UnitName("player")
    local isGuildBank = self:IsGuildBankCharacter()
    if not isGuildBank then return end
    local gold = GetMoney()
    local goldLink = "|Hgold:0|h[Золото]|h"
    if not NSAukGlobal.guildBanks[myName] then
        NSAukGlobal.guildBanks[myName] = {}
    end
    local found = false
    for _, entry in ipairs(NSAukGlobal.guildBanks[myName]) do
        if entry.link and string.find(entry.link, "|Hgold:") then
            entry.count = gold
            entry.id = 999999
            found = true
            break
        end
    end
    if not found then
        table.insert(NSAukGlobal.guildBanks[myName], {
            link = goldLink, id = 999999, count = gold, source = "gold"
        })
    end
    NSAukGlobal.guildBankTimestamps[myName] = GetTime()
end

function NSAukGuildBankClass:ScanTradeWindow()
    if not TradeFrame or not TradeFrame:IsShown() then return nil end
    local items = {}
    for i = 1, 6 do
        local link = GetTradePlayerItemLink(i)
        if link then
            local _, count = GetTradePlayerItemInfo(i)
            table.insert(items, { side = "player", slot = i, link = link, count = count or 1 })
        end
    end
    for i = 1, 6 do
        local link = GetTradeTargetItemLink(i)
        if link then
            local _, count = GetTradeTargetItemInfo(i)
            table.insert(items, { side = "target", slot = i, link = link, count = count or 1 })
        end
    end
    return items
end

function NSAukGuildBankClass:GetItemFullInfo(itemLink)
    if not itemLink then return nil end
    local _, _, itemIDStr = string.find(itemLink, "item:(%d+):")
    local itemID = itemIDStr and tonumber(itemIDStr)
    if not itemID then return nil end
    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, sellPrice = GetItemInfo(itemID)
    local qualityColors = {
        [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff00ff00",
        [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000",
        [6] = "|cffe6cc80", [7] = "|cffe6cc80"
    }
    local qualityNames = {
        [0] = "Серый", [1] = "Белый", [2] = "Зеленый",
        [3] = "Синий", [4] = "Фиолетовый", [5] = "Оранжевый",
        [6] = "Артефакт", [7] = "Легендарный"
    }
    return {
        itemID = itemID,
        name = name or "Неизвестно",
        link = link or itemLink,
        quality = quality or 0,
        qualityName = qualityNames[quality] or "Неизвестно",
        qualityColor = qualityColors[quality] or "|cffffffff",
        itemLevel = iLevel or 0,
        reqLevel = reqLevel or 0,
        class = class or "Разное",
        subclass = subclass or "",
        maxStack = maxStack or 1,
        equipSlot = equipSlot or "",
        texture = texture or "",
        sellPrice = sellPrice or 0,
        sellPriceGold = (sellPrice or 0) / 10000
    }
end

function NSAukGuildBankClass:RegisterTradeEvents()
    if not self.tradeFrame then self.tradeFrame = CreateFrame("Frame") end
    self.tradeFrame.owner = self
    self.tradeFrame:SetScript("OnEvent", function(frame, event, arg1, arg2, arg3)
        frame.owner:OnTradeEvent(event, arg1, arg2, arg3)
    end)
    self.tradeFrame:UnregisterAllEvents()
    self.tradeFrame:RegisterEvent("TRADE_SHOW")
    self.tradeFrame:RegisterEvent("TRADE_CLOSED")
    self.tradeFrame:RegisterEvent("CHAT_MSG_SYSTEM")
end

function NSAukGuildBankClass:IsGuildBankCharacter()
    local myName = UnitName("player")
    if not NSAukGlobal then return false end
    if not NSAukGlobal.guildBanks then return false end
    local items = NSAukGlobal.guildBanks[myName]
    return items and type(items) == "table" and #items > 0
end

function NSAukGuildBankClass:ScanBags()
    local snapshot = {}
    local totalCount = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, count = GetContainerItemInfo(bag, slot)
                    count = count or 1
                    snapshot[link] = (snapshot[link] or 0) + count
                    totalCount = totalCount + count
                end
            end
        end
    end
    return snapshot, totalCount
end

function NSAukGuildBankClass:ScanBank()
    local snapshot = {}
    local totalCount = 0
    local bankBags = { -1, 5, 6, 7, 8, 9, 10, 11 }
    for _, bag in ipairs(bankBags) do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, count = GetContainerItemInfo(bag, slot)
                    count = count or 1
                    snapshot[link] = (snapshot[link] or 0) + count
                    totalCount = totalCount + count
                end
            end
        end
    end
    return snapshot, totalCount
end

function NSAukGuildBankClass:GetItemSellPrice(itemLink)
    if not itemLink then return 0 end
    if string.find(itemLink, "|Hgold:") then
        return 0
    end
    local _, _, itemIDStr = string.find(itemLink, "item:(%d+):")
    local itemID = itemIDStr and tonumber(itemIDStr)
    if not itemID then return 0 end
    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, sellPrice = GetItemInfo(itemID)
    sellPrice = sellPrice or 0
    if self.PriceMultipliers then
        if self.PriceMultipliers.byClass and class then
            local classConfig = self.PriceMultipliers.byClass[class]
            if classConfig and classConfig.fixedPrice then return classConfig.fixedPrice end
        end
        if self.PriceMultipliers.bySubclass and subclass then
            local multiplier = self.PriceMultipliers.bySubclass[subclass]
            if multiplier then return sellPrice * multiplier end
        end
    end
    return sellPrice
end

function NSAukGuildBankClass:GetItemSellPriceByID(itemID)
    if not itemID then return 0 end
    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, sellPrice = GetItemInfo(itemID)
    sellPrice = sellPrice or 0
    if self.PriceMultipliers then
        if self.PriceMultipliers.byClass and class then
            local classConfig = self.PriceMultipliers.byClass[class]
            if classConfig and classConfig.fixedPrice then return classConfig.fixedPrice end
        end
        if self.PriceMultipliers.bySubclass and subclass then
            local multiplier = self.PriceMultipliers.bySubclass[subclass]
            if multiplier then return sellPrice * multiplier end
        end
    end
    return sellPrice
end

function NSAukGuildBankClass:OnTradeEvent(event, arg1, arg2, arg3)
    if event == "TRADE_SHOW" then
        self.tradeClosedProcessed = false
        self.tradePartnerName = nil
        local npcName = UnitName("npc")
        local targetName = UnitName("target")
        if npcName and npcName ~= "Unknown Entity" then
            self.tradePartnerName = npcName
        elseif targetName and targetName ~= "Unknown Entity" then
            self.tradePartnerName = targetName
        end
        self.tradeStartMoney = GetMoney()
        local bags, totalCount = self:ScanBags()
        self.bagSnapshot = bags
        self.bagSnapshotCount = totalCount
    elseif event == "TRADE_CLOSED" then
        if self.tradeClosedProcessed then return end
        self.tradeClosedProcessed = true
        local delayFrame = CreateFrame("Frame")
        delayFrame.owner = self
        delayFrame.startTime = GetTime()
        delayFrame:SetScript("OnUpdate", function(frame)
            if GetTime() - frame.startTime < 1.0 then return end
            frame:SetScript("OnUpdate", nil)
            frame:Hide()
            if not frame.owner.bagSnapshot then return end
            local beforeBags = frame.owner.bagSnapshot
            local afterBags, afterBagCount = frame.owner:ScanBags()
            local allLinks = {}
            for link, _ in pairs(beforeBags) do allLinks[link] = true end
            for link, _ in pairs(afterBags) do allLinks[link] = true end
            local totalGivenValue = 0
            local totalReceivedValue = 0
            for link, _ in pairs(allLinks) do
                local beforeBagCount = beforeBags[link] or 0
                local afterBagCount = afterBags[link] or 0
                local diff = afterBagCount - beforeBagCount
                if diff ~= 0 then
                    local sellPrice = frame.owner:GetItemSellPrice(link)
                    if diff < 0 then
                        totalGivenValue = totalGivenValue + (sellPrice * math.abs(diff))
                    else
                        totalReceivedValue = totalReceivedValue + (sellPrice * diff)
                    end
                end
            end
            local itemBalance = totalReceivedValue - totalGivenValue
            local currentMoney = GetMoney()
            local moneyDiff = currentMoney - frame.owner.tradeStartMoney
            local partnerName = frame.owner.tradePartnerName
            local isGuildBank = frame.owner:IsGuildBankCharacter()
            if partnerName and partnerName ~= "Unknown Entity" and isGuildBank then
                if not NSAukGlobal then NSAukGlobal = {} end
                if not NSAukGlobal['баланс'] then NSAukGlobal['баланс'] = {} end
                if not NSAukGlobal['золото'] then NSAukGlobal['золото'] = {} end
                NSAukGlobal['баланс'][partnerName] = (NSAukGlobal['баланс'][partnerName] or 0) + itemBalance
                NSAukGlobal['золото'][partnerName] = (NSAukGlobal['золото'][partnerName] or 0) + moneyDiff
                local totalBalance = NSAukGlobal['баланс'][partnerName]
                local totalGold = NSAukGlobal['золото'][partnerName]

                local itemBalanceStr = string.format("%.2f", itemBalance / 10000)
                local goldDiffStr = string.format("%.2f", moneyDiff / 10000)
                local totalBalanceStr = string.format("%.2f", totalBalance / 10000)
                local totalGoldStr = string.format("%.2f", totalGold / 10000)

                if moneyDiff >= 0 then
                    SendChatMessage("[NSAuk] Сделка с " .. partnerName .. " Изм. предметов: " .. itemBalanceStr .. ". Всего: " .. totalBalanceStr, "OFFICER")
                    SendChatMessage("[NSAuk] Сделка с " .. partnerName .. " Получено золота: " .. goldDiffStr .. ". Всего: " .. totalGoldStr, "OFFICER")
                else
                    SendChatMessage("[NSAuk] Сделка с " .. partnerName .. " Изм. предметов: " .. itemBalanceStr .. ". Всего: " .. totalBalanceStr, "OFFICER")
                    SendChatMessage("[NSAuk] Сделка с " .. partnerName .. " Отдано золота: " .. goldDiffStr .. ". Всего: " .. totalGoldStr, "OFFICER")
                end
            end
            frame.owner.bagSnapshot = nil
            frame.owner.bagSnapshotCount = nil
        end)
        delayFrame:Show()
    elseif event == "CHAT_MSG_SYSTEM" then
        if arg1 == "Сделка совершена." then end
    end
end

function NSAukGuildBankClass:InitializeImmediately()
    if not NSAukGlobal then NSAukGlobal = {} end
    if not NSAukGlobal.guildBanks then NSAukGlobal.guildBanks = {} end
    local myName = UnitName("player")
    local isBank = self:IsGuildBankCharacter()
    if isBank then
        self:BuildLocalItemList()
        self:UpdateGoldInTable()
    end
end

function NSAukGuildBankClass:CreateUI()
    if not self.parent or not self.parent.frame then return nil end
    local frame = CreateFrame("Frame", nil, self.parent.frame)
    frame:SetSize(670, 380)
    frame:SetPoint("TOPLEFT", self.parent.categoriesPanel, "TOPRIGHT", 10, 0)
    frame:SetPoint("BOTTOMRIGHT", self.parent.frame, "BOTTOMRIGHT", -10, 10)
    frame:Hide()
    self.frame = frame
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    title:SetText('Гильдбанк "Ночной Стражи"')
    title:SetTextColor(0.2, 0.8, 1)
    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 24)
    clearBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", -155, 32)
    clearBtn:SetText("Очистить")
    clearBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Очистить все таблицы", 1, 0, 0)
        GameTooltip:AddLine("Удалить данные всех гильдбанков у всех игроков", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave", GameTooltip_Hide)
    clearBtn.owner = self
    clearBtn:SetScript("OnClick", function(btn)
        StaticPopup_Show("NSAUK_CLEAR_GUILDBANK")
    end)
    self.clearBtn = clearBtn
    local scanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scanBtn:SetSize(160, 24)
    scanBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -200, -10)
    scanBtn:SetText("Просканировать")
    scanBtn.owner = self
    scanBtn:SetScript("OnClick", function(btn)
        if btn.owner.scanCooldown then return end
        btn.owner:ScanGuildBank()
    end)
    self.scanBtn = scanBtn

    local checkboxBank = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    checkboxBank:SetSize(24, 24)
    checkboxBank:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -150, -12)
    checkboxBank.owner = self
    local checkboxBankText = checkboxBank:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    checkboxBankText:SetPoint("LEFT", checkboxBank, "RIGHT", 0, 0)
    checkboxBankText:SetText("Сделать гильдбанком")
    checkboxBank:SetScript("OnClick", function(cb)
        cb.owner:ToggleGuildBankCharacter(cb:GetChecked())
    end)
    self.checkboxBank = checkboxBank
    checkboxBank:SetScript("OnEnter", function(cb)
        GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
        GameTooltip:SetText("Активировать персонажа как точку гильдбанка", 1, 1, 1)
        GameTooltip:AddLine("Предметы из сумок и банка будут автоматически добавляться в общую таблицу", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    checkboxBank:SetScript("OnLeave", GameTooltip_Hide)

    local checkboxDisplay = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    checkboxDisplay:SetSize(24, 24)
    checkboxDisplay:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -150, 12)
    checkboxDisplay.owner = self
    local checkboxDisplayText = checkboxDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    checkboxDisplayText:SetPoint("LEFT", checkboxDisplay, "RIGHT", 0, 0)
    checkboxDisplayText:SetText("Отображать гильдбанк")
    checkboxDisplay:SetScript("OnClick", function(cb)
        cb.owner:ToggleShowGuildBank(cb:GetChecked())
    end)
    self.checkboxDisplay = checkboxDisplay
    checkboxDisplay:SetScript("OnEnter", function(cb)
        GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
        GameTooltip:SetText("Отображать гильдбанк", 1, 1, 1)
        GameTooltip:AddLine("При запросе будут отдаваться таблицы всех сохранённых гильдбанков", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    checkboxDisplay:SetScript("OnLeave", GameTooltip_Hide)

    local gridContainer = CreateFrame("ScrollFrame", "gridContainer", frame)
    gridContainer:SetSize(640, 280)
    gridContainer:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -15)
    gridContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    gridContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    gridContainer:SetBackdropColor(0.06, 0.06, 0.06, 1.0)
    gridContainer:SetBackdropBorderColor(0.45, 0.45, 0.45, 1.0)
    gridContainer:EnableMouseWheel(true)

    local gridList = CreateFrame("Frame", "gridList", gridContainer)
    gridList:SetWidth(630)
    gridList:SetHeight(1)
    gridContainer:SetScrollChild(gridList)

    local scrollbar = CreateFrame("Slider", "scrollbar", frame, "UIPanelScrollBarTemplate")
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetSize(16, 280)
    scrollbar:SetPoint("TOPLEFT", gridContainer, "TOPRIGHT", 0, -16)
    scrollbar:SetPoint("BOTTOMLEFT", gridContainer, "BOTTOMRIGHT", 0, 16)
    scrollbar.scrollFrame = gridContainer
    gridContainer.scrollbar = scrollbar
    self.gridContainer = gridContainer
    self.gridList = gridList
    self.gridScrollbar = scrollbar
    scrollbar.owner = self
    scrollbar:SetScript("OnValueChanged", function(sb, value)
        if sb.scrollFrame then sb.scrollFrame:SetVerticalScroll(value) end
    end)
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValue(0)

    gridContainer:SetScript("OnMouseWheel", function(gc, delta)
        local scrollBar = gc.scrollbar
        if not scrollBar then return end
        local minVal, maxVal = scrollBar:GetMinMaxValues()
        if maxVal <= 0 then return end
        local current = gc:GetVerticalScroll()
        local step = 36
        current = delta > 0 and math.max(0, current - step) or math.min(maxVal, current + step)
        gc:SetVerticalScroll(current)
        scrollBar:SetValue(current)
    end)

    self.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 0)
    self.statusText:SetText("Инициализация...")
    self.statusText:SetTextColor(0.7, 0.7, 0.7)

    frame.owner = self
    frame:SetScript("OnShow", function(f)
        local isBank = f.owner:IsGuildBankCharacter()
        local myName = UnitName("player")
        local showBank = NSAukGlobal.guildBanksSettings and NSAukGlobal.guildBanksSettings[myName] and NSAukGlobal.guildBanksSettings[myName].showGuildBank
        if isBank then
            f.owner.checkboxBank:SetChecked(true)
            f.owner.statusText:SetText("Персонаж активирован как точка гильдбанка")
            f.owner.statusText:SetTextColor(0.2, 1, 0.2)
        else
            f.owner.checkboxBank:SetChecked(false)
            f.owner.statusText:SetText("Нет данных. Нажмите 'Просканировать'")
            f.owner.statusText:SetTextColor(0.7, 0.7, 0.7)
        end
        if showBank then
            f.owner.checkboxDisplay:SetChecked(true)
        else
            f.owner.checkboxDisplay:SetChecked(false)
        end
        if not f.owner.scanCooldown then
            f.owner:ScanGuildBank()
        end
    end)
    return frame
end

function NSAukGuildBankClass:ToggleGuildBankCharacter(isChecked)
    local myName = UnitName("player")
    if not NSAukGlobal then NSAukGlobal = {} end
    if not NSAukGlobal.guildBanks then NSAukGlobal.guildBanks = {} end
    if not NSAukGlobal.guildBanksSettings then NSAukGlobal.guildBanksSettings = {} end
    if not NSAukGlobal.guildBanksSettings[myName] then NSAukGlobal.guildBanksSettings[myName] = {} end
    NSAukGlobal.guildBanks[myName] = {}
    if isChecked then
        self.statusText:SetText("Персонаж активирован как точка гильдбанка")
        self.statusText:SetTextColor(0.2, 1, 0.2)
        self:BuildLocalItemList()
        self:UpdateGoldInTable()
        SendAddonMessage("ns_GBUpdate", myName, "GUILD")
    else
        self.statusText:SetText("Персонаж деактивирован как точка гильдбанка")
        self.statusText:SetTextColor(1, 0.2, 0.2)
        SendAddonMessage("ns_GBRemove", myName, "GUILD")
    end
    if self.frame and self.frame:IsShown() then
        self:RefreshDisplay()
    end
end

function NSAukGuildBankClass:ToggleShowGuildBank(isChecked)
    local myName = UnitName("player")
    if not NSAukGlobal then NSAukGlobal = {} end
    if not NSAukGlobal.guildBanksSettings then NSAukGlobal.guildBanksSettings = {} end
    if not NSAukGlobal.guildBanksSettings[myName] then NSAukGlobal.guildBanksSettings[myName] = {} end
    NSAukGlobal.guildBanksSettings[myName].showGuildBank = isChecked
    if isChecked then
        self.statusText:SetText("Гильдбанк отображается для других игроков")
        self.statusText:SetTextColor(0.2, 0.8, 1)
    else
        self.statusText:SetText("Гильдбанк скрыт от других игроков")
        self.statusText:SetTextColor(1, 0.5, 0.2)
    end
end

function NSAukGuildBankClass:ClearAllGuildBanks(suppressBroadcast)
    if not NSAukGlobal then NSAukGlobal = {} end
    if not NSAukGlobal.guildBanks then NSAukGlobal.guildBanks = {} end
    if not NSAukGlobal.guildBankVersions then NSAukGlobal.guildBankVersions = {} end
    local clearedCount = 0
    for ownerName, items in pairs(NSAukGlobal.guildBanks) do
        if type(items) == "table" and #items > 0 then
            clearedCount = clearedCount + 1
        end
        NSAukGlobal.guildBanks[ownerName] = {}
        NSAukGlobal.guildBankVersions[ownerName] = 0
    end
    if not suppressBroadcast then
        SendAddonMessage("ns_GBClearAll", UnitName("player"), "GUILD")
    end
    if self.frame and self.frame:IsShown() then
        self:RefreshDisplay()
    end
end

function NSAukGuildBankClass:BuildLocalItemList()
    local myName = UnitName("player")
    if not NSAukGlobal then NSAukGlobal = {} end
    if not NSAukGlobal.guildBanks then NSAukGlobal.guildBanks = {} end
    local myItems = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, count = GetContainerItemInfo(bag, slot)
                    if not count or count == 0 then count = 1 end
                    local _, _, itemIDStr = string.find(itemLink, "item:(%d+):")
                    local itemID = itemIDStr and tonumber(itemIDStr)
                    if itemID and itemID > 0 then
                        table.insert(myItems, { link = itemLink, id = itemID, count = count, source = "bags" })
                    end
                end
            end
        end
    end
    local bankBags = { -1, 5, 6, 7, 8, 9, 10, 11 }
    for _, bag in ipairs(bankBags) do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, count = GetContainerItemInfo(bag, slot)
                    if not count or count == 0 then count = 1 end
                    local _, _, itemIDStr = string.find(itemLink, "item:(%d+):")
                    local itemID = itemIDStr and tonumber(itemIDStr)
                    if itemID and itemID > 0 then
                        table.insert(myItems, { link = itemLink, id = itemID, count = count, source = "bank" })
                    end
                end
            end
        end
    end
    NSAukGlobal.guildBanks[myName] = myItems
    NSAukGlobal.guildBankTimestamps[myName] = GetTime()
    if not NSAukGlobal.guildBankVersions then NSAukGlobal.guildBankVersions = {} end
    NSAukGlobal.guildBankVersions[myName] = (NSAukGlobal.guildBankVersions[myName] or 0) + 1
end

function NSAukGuildBankClass:AggregateItems(itemTables)
    local tempMap = {}
    local ownershipMap = {}
    for ownerName, items in pairs(itemTables) do
        if type(items) == "table" then
            for _, entry in ipairs(items) do
                if entry and entry.link and entry.count then
                    tempMap[entry.link] = (tempMap[entry.link] or 0) + entry.count
                    if not ownershipMap[entry.link] then ownershipMap[entry.link] = {} end
                    local found = false
                    for _, o in ipairs(ownershipMap[entry.link]) do
                        if o.name == ownerName then
                            o.count = (o.count or 0) + entry.count
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(ownershipMap[entry.link], { name = ownerName, count = entry.count })
                    end
                end
            end
        end
    end
    local aggregated = {}
    for link, totalCount in pairs(tempMap) do
        local _, _, itemIDStr = string.find(link, "item:(%d+):")
        local itemID = itemIDStr and tonumber(itemIDStr) or 0
        table.insert(aggregated, { link = link, id = itemID, count = totalCount })
    end
    return aggregated, ownershipMap
end

function NSAukGuildBankClass:GetAllAggregatedItems()
    if not NSAukGlobal or not NSAukGlobal.guildBanks then return {}, {} end
    local allBanks = {}
    for playerName, items in pairs(NSAukGlobal.guildBanks) do
        if type(items) == "table" and #items > 0 then
            allBanks[playerName] = items
        end
    end
    if next(allBanks) then
        return self:AggregateItems(allBanks)
    else
        return {}, {}
    end
end

function NSAukGuildBankClass:ConsolidateItems(items)
    local map = {}
    for _, entry in ipairs(items) do
        if entry and entry.link then
            if not map[entry.link] then
                map[entry.link] = { link = entry.link, id = entry.id, count = 0 }
            end
            map[entry.link].count = map[entry.link].count + (entry.count or 0)
        end
    end
    local result = {}
    for _, v in pairs(map) do
        table.insert(result, v)
    end
    return result
end

function NSAukGuildBankClass:SortItemsByClassSubclassQualityName(item_data)
    local itemInfoTable = {}
    for _, entry in ipairs(item_data) do
        local itemID = entry.id
        local itemLink = entry.link
        local count = entry.count
        local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, sellPrice
        if string.find(itemLink or "", "|Hgold:") then
            name = "Золото"
            quality = 5
            class = "Разное"
            subclass = "Валюта"
            sellPrice = count
            texture = "Interface\\Icons\\INV_Misc_Coin_01"
        else
            name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, sellPrice = GetItemInfo(itemLink or itemID)
        end
        if not name then
            name = "Unknown"
            quality = 0
            class = "Unknown"
            subclass = "Unknown"
            sellPrice = 0
            texture = "Interface\\Icons\\INV_Misc_QuestionMark"
            if itemID then GetItemInfo(itemID) end
        else
            class = class or "Unknown"
            subclass = subclass or "Unknown"
            sellPrice = sellPrice or 0
        end
        local classOrder = {
            ["Оружие"] = 1, ["Броня"] = 2, ["Доспехи"] = 2, ["Квестовые предметы"] = 3,
            ["Реагенты"] = 4, ["Расходуемые"] = 5, ["Ресурсы"] = 6, ["Товары для торговли"] = 7,
            ["Разное"] = 8, ["Другое"] = 8, ["Unknown"] = 999
        }
        local normalizedClass = class
        if classOrder[class] == nil then
            for knownClass, _ in pairs(classOrder) do
                if string.find(class, knownClass) or string.find(knownClass, class) then
                    normalizedClass = knownClass
                    break
                end
            end
        end
        table.insert(itemInfoTable, {
            id = itemID,
            link = itemLink or link,
            count = count,
            class = normalizedClass,
            subclass = subclass,
            classOrder = classOrder[normalizedClass] or 999,
            quality = quality or 0,
            name = name or ("Item: " .. itemID),
            sellPrice = sellPrice or 0,
            texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"
        })
    end
    table.sort(itemInfoTable, function(a, b)
        if a.classOrder ~= b.classOrder then return a.classOrder < b.classOrder end
        if a.class ~= b.class then return a.class < b.class end
        if a.subclass ~= b.subclass then return a.subclass < b.subclass end
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.name ~= b.name then return a.name < b.name end
        if a.sellPrice ~= b.sellPrice then return a.sellPrice > b.sellPrice end
        return a.id < b.id
    end)
    local sortedItems = {}
    for _, info in ipairs(itemInfoTable) do
        table.insert(sortedItems, { link = info.link, id = info.id, count = info.count })
    end
    return sortedItems
end

function NSAukGuildBankClass:PrepareDisplayData()
    local allItems, ownershipMap = self:GetAllAggregatedItems()
    if #allItems > 0 then
        self.ownershipData = ownershipMap
        local consolidated = self:ConsolidateItems(allItems)
        local result = self:SortItemsByClassSubclassQualityName(consolidated)
        return result
    else
        return {}
    end
end

function NSAukGuildBankClass:FinalizeScan()
    if not self.isScanning then return end
    self.isScanning = false
    if self.scanBtn then
        self.scanBtn:SetText("Просканировать")
        self.scanBtn:Enable()
    end
    if self.statusText then
        self.statusText:SetText("Сканирование завершено")
        self.statusText:SetTextColor(0.2, 1, 0.2)
    end
    self:RefreshDisplay()
end

function NSAukGuildBankClass:RefreshDisplay()
    local sortedItems = self:PrepareDisplayData()
    local totalGold = 0
    for _, entry in ipairs(sortedItems) do
        if entry.link and string.find(entry.link, "|Hgold:") then
            local goldAmount = entry.count
            if goldAmount then
                totalGold = totalGold + goldAmount
            end
        end
    end
    local goldStr = string.format(" | Золото : %.2f", totalGold / 10000)
    if #sortedItems > 0 then
        self:DisplayItems(sortedItems)
        if self.statusText then
            local currentText = self.statusText:GetText() or ""
            if not string.find(currentText, "Золото") then
                self.statusText:SetText(currentText .. goldStr)
            end
        end
    else
        if self.frame and self.frame:IsShown() then
            self.statusText:SetText("Нет данных в гильдбанках" .. goldStr)
            self.statusText:SetTextColor(1, 0.5, 0.5)
            self:ClearGrid()
        end
    end
end

function NSAukGuildBankClass:BroadcastGuildBankData(ownersList)
    if not ownersList or #ownersList == 0 then
        SendAddonMessage(PREFIX_END, UnitName("player") .. " 0", "GUILD")
        return
    end

    self.sendQueue = {}
    local myName = UnitName("player")
    local myVersion = (NSAukGlobal.guildBankVersions and NSAukGlobal.guildBankVersions[myName]) or 0

    for _, ownerName in ipairs(ownersList) do
        local items = NSAukGlobal.guildBanks[ownerName]
        if items and type(items) == "table" and #items > 0 then
            local consolidated = self:ConsolidateItems(items)
            local sortedItems = self:SortItemsByClassSubclassQualityName(consolidated)
            local versionToSend = 0

            if ownerName == myName then
                versionToSend = NSAukGlobal.guildBankVersions[myName] or 1
            else
                versionToSend = (NSAukGlobal.guildBankVersions and NSAukGlobal.guildBankVersions[ownerName]) or 0
            end

            -- Обновляем локальную таблицу данными, которые отправляем (для себя и ретранслятора)
            local localVersion = (NSAukGlobal.guildBankVersions and NSAukGlobal.guildBankVersions[ownerName]) or 0
            if versionToSend >= localVersion then
                NSAukGlobal.guildBanks[ownerName] = consolidated
                if not NSAukGlobal.guildBankVersions then
                    NSAukGlobal.guildBankVersions = {}
                end
                NSAukGlobal.guildBankVersions[ownerName] = versionToSend
                NSAukGlobal.guildBankTimestamps[ownerName] = GetTime()
            end

            for idx, entry in ipairs(sortedItems) do
                local msgStr = string.format("%s %s %d", ownerName, entry.link, entry.count)
                table.insert(self.sendQueue, { prefix = "ns_MyGb", message = msgStr })
            end
            table.insert(self.sendQueue, { prefix = PREFIX_END, message = ownerName .. "   " .. versionToSend })
        end
    end

    if #self.sendQueue > 0 and not self.sendFrame then
        self.sendFrame = CreateFrame("Frame")
        self.sendFrame.owner = self
        self.sendFrame.lastSendTime = 0
        self.sendFrame:SetScript("OnUpdate", function(sf)
            local now = GetTime()
            if now - sf.lastSendTime >= SEND_DELAY then
                if #sf.owner.sendQueue > 0 then
                    local packet = table.remove(sf.owner.sendQueue, 1)
                    SendAddonMessage(packet.prefix, packet.message, "GUILD")
                    sf.lastSendTime = now
                else
                    sf:SetScript("OnUpdate", nil)
                    sf:Hide()
                    sf.owner.sendFrame = nil
                    -- Если сканирование было активным, завершаем его после отправки
                    if sf.owner.isScanning then
                        sf.owner:FinalizeScan()
                    end
                end
            end
        end)
        self.sendFrame:Show()
    elseif #self.sendQueue == 0 then
        -- Если очередь пуста сразу (не должно быть при наличии данных), завершаем сканирование
        if self.isScanning then
            self:FinalizeScan()
        end
    end
    -- Принудительное обновление UI удалено, чтобы не показывать старые данные до получения новых
end

function NSAukGuildBankClass:StartCooldownTimer()
    self.scanCooldown = true
    self.cooldownRemaining = SCAN_COOLDOWN
    if self.scanBtn then
        self.scanBtn:Disable()
        self.scanBtn:SetText(string.format("Ждите %d сек", self.cooldownRemaining))
    end
    if not self.cooldownFrame then
        self.cooldownFrame = CreateFrame("Frame")
    end
    self.cooldownFrame.owner = self
    self.cooldownFrame.startTime = GetTime()
    self.cooldownFrame:SetScript("OnUpdate", function(frame)
        local elapsed = GetTime() - frame.startTime
        local remaining = math.ceil(SCAN_COOLDOWN - elapsed)
        frame.owner.cooldownRemaining = remaining

        if frame.owner.scanBtn then
            if remaining > 0 then
                frame.owner.scanBtn:SetText(string.format("Ждите %d сек", remaining))
            else
                frame.owner.scanBtn:SetText("Просканировать")
            end
        end

        if elapsed >= SCAN_COOLDOWN then
            frame.owner.scanCooldown = false
            frame.owner.cooldownRemaining = 0
            if frame.owner.scanBtn then
                frame.owner.scanBtn:Enable()
                frame.owner.scanBtn:SetText("Просканировать")
            end
            frame:SetScript("OnUpdate", nil)
            frame:Hide()
        end
    end)
    self.cooldownFrame:Show()
end

function NSAukGuildBankClass:OnScanRequestReceived(sender)
    if not NSAukGlobal or not NSAukGlobal.guildBanks or not NSAukGlobal.guildBanksSettings then return end
    local myName = UnitName("player")
    local isBank = self:IsGuildBankCharacter()
    local showBank = NSAukGlobal.guildBanksSettings[myName] and NSAukGlobal.guildBanksSettings[myName].showGuildBank
    local shouldSend = false
    local ownersToSend = {}

    -- Отвечаем только если мы гильдбанк или ретранслятор
    if not isBank and not showBank then
        shouldSend = false
    elseif isBank and not showBank then
        shouldSend = true
        self:BuildLocalItemList()
        self:UpdateGoldInTable()
        table.insert(ownersToSend, myName)
    elseif isBank and showBank then
        shouldSend = true
        self:BuildLocalItemList()
        self:UpdateGoldInTable()
        table.insert(ownersToSend, myName)
        for ownerName, items in pairs(NSAukGlobal.guildBanks) do
            if ownerName ~= myName and type(items) == "table" and #items > 0 then
                table.insert(ownersToSend, ownerName)
            end
        end
    elseif not isBank and showBank then
        shouldSend = true
        for ownerName, items in pairs(NSAukGlobal.guildBanks) do
            if type(items) == "table" and #items > 0 then
                table.insert(ownersToSend, ownerName)
            end
        end
    end

    if shouldSend then
        self.scanSessionStart = GetTime()
        self.scanSessionActive = true
        self.receivedOwnersThisScan = {}
        self:BroadcastGuildBankData(ownersToSend)
    end
end

function NSAukGuildBankClass:ScanGuildBank()
    if self.scanCooldown then
        return
    end

    self.isScanning = true
    self.scanSessionStart = GetTime()
    self.scanSessionActive = true
    self.receivedOwnersThisScan = {}
    self.incomingBuffers = {}

    local myName = UnitName("player")
    local isBank = self:IsGuildBankCharacter()
    local showBank = NSAukGlobal.guildBanksSettings and NSAukGlobal.guildBanksSettings[myName] and NSAukGlobal.guildBanksSettings[myName].showGuildBank

    if self.scanBtn then
        self.scanBtn:Disable()
        self.scanBtn:SetText("Сканирую...")
    end

    if self.statusText then
        self.statusText:SetText("Отправка запроса на сканирование...")
        self.statusText:SetTextColor(1, 1, 0)
    end

    self.itemEntries = {}
    self.ownershipData = {}
    
    -- Очищаем список товаров в окне при начале сканирования
    self:ClearGrid()

    if not NSAukGlobal or not NSAukGlobal.guildBanks then
        if self.statusText then
            self.statusText:SetText("Ошибка данных. Перезагрузите аддон")
            self.statusText:SetTextColor(1, 0, 0)
        end
        self.isScanning = false
        return
    end

    -- Все клиенты отправляют запрос, включая гильдбанк
    SendAddonMessage("ns_ScanGB", myName, "GUILD")

    -- Гильдбанк обновляет свои данные и отправляет их в ответ на запрос
    if isBank then
        self:BuildLocalItemList()
        self:UpdateGoldInTable()
    end

    -- Обрабатываем запрос локально сразу (чтобы ретранслятор видел данные)
    self:OnScanRequestReceived(myName)

    -- Запускаем таймер кулдауна кнопки
    self:StartCooldownTimer()
end

function NSAukGuildBankClass:ClearGrid()
    for _, frame in ipairs(self.itemFrames) do
        if frame and frame.Hide then frame:Hide() end
    end
    self.itemFrames = {}
    if self.gridList then
        self.gridList:SetHeight(1)
        if self.gridScrollbar then
            self.gridScrollbar:SetMinMaxValues(0, 0)
            self.gridScrollbar:SetValue(0)
        end
    end
end

function NSAukGuildBankClass:GetItemOwners(item_key)
    if not self.ownershipData or not self.ownershipData[item_key] then return nil end
    local owners = {}
    for _, ownerData in ipairs(self.ownershipData[item_key]) do
        table.insert(owners, ownerData)
    end
    table.sort(owners, function(a, b) return a.count > b.count end)
    return owners
end

function NSAukGuildBankClass:DisplayItems(item_data)
    self:ClearGrid()
    if #item_data == 0 then
        if self.statusText then
            self.statusText:SetText("Не найдено предметов в гильдбанках")
            self.statusText:SetTextColor(1, 0.5, 0.5)
        end
        return
    end
    self:Show()
    local items_per_row = 16
    local cell_size = 40
    local y_pos = 0
    local lastClass = nil
    local lastSubclass = nil
    local classSeparatorAdded = false
    local displayedCount = 0
    local classColors = {
        ["Оружие"] = { r = 0.8, g = 0.1, b = 0.1 },
        ["Броня"] = { r = 0.1, g = 0.5, b = 0.8 },
        ["Доспехи"] = { r = 0.1, g = 0.5, b = 0.8 },
        ["Квестовые предметы"] = { r = 0.8, g = 0.8, b = 0.1 },
        ["Реагенты"] = { r = 0.5, g = 0.1, b = 0.5 },
        ["Расходуемые"] = { r = 0.1, g = 0.8, b = 0.1 },
        ["Ресурсы"] = { r = 0.8, g = 0.5, b = 0.1 },
        ["Товары для торговли"] = { r = 0.5, g = 0.5, b = 0.5 },
        ["Разное"] = { r = 0.3, g = 0.3, b = 0.3 },
        ["Другое"] = { r = 0.3, g = 0.3, b = 0.3 },
        ["Unknown"] = { r = 0.2, g = 0.2, b = 0.2 }
    }
    local qualityColors = {
        [0] = { r = 0.5, g = 0.5, b = 0.5 },
        [1] = { r = 1.0, g = 1.0, b = 1.0 },
        [2] = { r = 0.12, g = 1.0, b = 0.0 },
        [3] = { r = 0.0, g = 0.44, b = 0.87 },
        [4] = { r = 0.64, g = 0.21, b = 0.93 },
        [5] = { r = 1.0, g = 0.5, b = 0.0 },
        [6] = { r = 0.9, g = 0.8, b = 0.5 },
        [7] = { r = 0.9, g = 0.8, b = 0.5 }
    }
    for i, entry in ipairs(item_data) do
        local skipGold = string.find(entry.link or "", "|Hgold:")
        if not skipGold then
            local item_id = entry.id
            local item_link = entry.link
            local count = entry.count
            local row = math.floor((displayedCount) / items_per_row)
            local col = (displayedCount) % items_per_row
            if row > 0 and col == 0 then
                y_pos = y_pos + cell_size
                classSeparatorAdded = false
            end
            local name, link, quality, iLevel, reqLevel, class, subclass
            name, link, quality, iLevel, reqLevel, class, subclass = GetItemInfo(item_link or item_id)
            class = class or "Unknown"
            subclass = subclass or "Unknown"
            quality = quality or 0
            if lastClass ~= nil and class ~= lastClass and not classSeparatorAdded then
                y_pos = y_pos + 5
                classSeparatorAdded = true
            elseif lastClass ~= nil and class == lastClass and subclass ~= lastSubclass and not classSeparatorAdded then
                y_pos = y_pos + 2
                classSeparatorAdded = true
            end
            lastClass = class
            lastSubclass = subclass
            local frame = CreateFrame("Button", nil, self.gridList)
            frame:SetSize(36, 36)
            frame:SetPoint("TOPLEFT", self.gridList, "TOPLEFT", col * cell_size + 2, -y_pos - 2)
            frame.item_id = item_id
            frame.item_link = item_link
            frame.count = count
            frame.class = class
            frame.subclass = subclass
            frame.owner = self
            local bg = frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(frame)
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            local classColor = classColors[class] or { r = 0.1, g = 0.1, b = 0.1 }
            bg:SetVertexColor(classColor.r * 0.3, classColor.g * 0.3, classColor.b * 0.3, 0.8)
            frame.bg = bg
            local border = frame:CreateTexture(nil, "BORDER")
            border:SetSize(38, 38)
            border:SetPoint("CENTER", frame, "CENTER")
            border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            border:SetBlendMode("ADD")
            border:SetAlpha(0.5)
            local qualityColor = qualityColors[quality] or { r = 0.5, g = 0.5, b = 0.5 }
            border:SetVertexColor(qualityColor.r, qualityColor.g, qualityColor.b, 0.7)
            frame.border = border
            local icon = frame:CreateTexture(nil, "ARTWORK")
            icon:SetSize(34, 34)
            icon:SetPoint("CENTER", frame, "CENTER")
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            frame.icon = icon
            local _, _, _, _, _, _, _, _, _, texture
            _, _, _, _, _, _, _, _, _, texture = GetItemInfo(item_link or item_id)
            if texture then
                icon:SetTexture(texture)
            else
                icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                if item_id then GetItemInfo(item_id) end
            end
            if count > 1 then
                local countText = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 2)
                countText:SetText(count)
                countText:SetTextColor(1, 1, 0)
                frame.countText = countText
            end
            frame:SetScript("OnEnter", function(f)
                f.bg:SetVertexColor(0.3, 0.3, 0.5, 1.0)
                GameTooltip:SetOwner(f, "ANCHOR_TOPRIGHT")
                if f.item_link and not string.find(f.item_link, "|Hgold:") then
                    GameTooltip:SetHyperlink(f.item_link)
                else
                    GameTooltip:SetText(f.item_link or "Золото", 1, 1, 1)
                    GameTooltip:AddLine(string.format("Количество: %d", f.count or 0), 1, 1, 0)
                end
                if f.count and f.count > 1 and not string.find(f.item_link or "", "|Hgold:") then
                    GameTooltip:AddLine(string.format("Всего в гильдбанке: %d", f.count), 1, 1, 0)
                end
                local owners = f.owner:GetItemOwners(f.item_link or f.item_id)
                if owners and #owners > 0 then
                    GameTooltip:AddLine("                 ")
                    GameTooltip:AddLine("Находится у:    ", 0.8, 0.8, 1.0)
                    local maxOwnersToShow = 5
                    local ownersShown = 0
                    for _, ownerData in ipairs(owners) do
                        if ownersShown < maxOwnersToShow then
                            local ownerName = ownerData.name
                            local _, playerClass = UnitClass(ownerName)
                            local color = "|cffffffff"
                            if playerClass then
                                local classColorsTbl = {
                                    ["WARRIOR"] = "|cffC79C6E", ["PALADIN"] = "|cffF58CBA",
                                    ["HUNTER"] = "|cffABD473", ["ROGUE"] = "|cffFFF569",
                                    ["PRIEST"] = "|cffFFFFFF", ["DEATHKNIGHT"] = "|cffC41F3B",
                                    ["SHAMAN"] = "|cff0070DE", ["MAGE"] = "|cff69CCF0",
                                    ["WARLOCK"] = "|cff9482C9", ["DRUID"] = "|cffFF7D0A"
                                }
                                color = classColorsTbl[playerClass] or "|cffffffff"
                            end
                            GameTooltip:AddLine(string.format("  %s%s|r - %d", color, ownerName, ownerData.count), 1, 1, 1)
                            ownersShown = ownersShown + 1
                        else
                            local remaining = #owners - maxOwnersToShow
                            GameTooltip:AddLine(string.format("  ... и еще %d игроков", remaining), 0.7, 0.7, 0.7)
                            break
                        end
                    end
                end
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function(f)
                local classColor = classColors[f.class or "Unknown"] or { r = 0.1, g = 0.1, b = 0.1 }
                f.bg:SetVertexColor(classColor.r * 0.3, classColor.g * 0.3, classColor.b * 0.3, 0.8)
                GameTooltip:Hide()
            end)
            frame:SetScript("OnClick", function(f, button)
                if button == "LeftButton" then
                    if f.item_link and not string.find(f.item_link, "|Hgold:") then
                        ChatEdit_InsertLink(f.item_link)
                    end
                end
            end)
            table.insert(self.itemFrames, frame)
            displayedCount = displayedCount + 1
        end
    end
    local total_rows = math.ceil(displayedCount / items_per_row)
    local total_height = total_rows * cell_size + (total_rows * 5)
    self.gridList:SetHeight(total_height)
    local scroll_range = total_height - self.gridContainer:GetHeight()
    if scroll_range > 0 then
        self.gridScrollbar:Show()
        self.gridScrollbar:SetMinMaxValues(0, scroll_range)
        self.gridScrollbar:SetValue(0)
        self.gridContainer:SetVerticalScroll(0)
    else
        self.gridScrollbar:Hide()
    end
    local total_items = 0
    local unique_items = 0
    local class_counts = {}
    for _, entry in ipairs(item_data) do
        local skipGoldStats = string.find(entry.link or "", "|Hgold:")
        if not skipGoldStats then
            total_items = total_items + entry.count
            unique_items = unique_items + 1
            local _, _, _, _, _, class
            _, _, _, _, _, class = GetItemInfo(entry.link or entry.id)
            class = class or "Unknown"
            class_counts[class] = (class_counts[class] or 0) + 1
        end
    end
    local statsText = string.format("%d (уникальных: %d)", total_items, unique_items)
    local mainClasses = { "Оружие", "Броня", "Доспехи", "Ресурсы", "Расходуемые", "Квестовые предметы" }
    local classStats = {}
    for _, className in ipairs(mainClasses) do
        if class_counts[className] then
            table.insert(classStats, string.format("%s: %d", className, class_counts[className]))
        end
    end
    local otherCount = 0
    for className, count in pairs(class_counts) do
        local isMainClass = false
        for _, mainClass in ipairs(mainClasses) do
            if className == mainClass then isMainClass = true; break end
        end
        if not isMainClass and className ~= "Unknown" then
            otherCount = otherCount + count
        end
    end
    if otherCount > 0 then
        table.insert(classStats, string.format("Другое: %d", otherCount))
    end
    if #classStats > 0 then
        statsText = statsText .. " [      " .. table.concat(classStats, ",      ") .. " ]     "
    end
    if self.statusText then
        self.statusText:SetText(statsText)
        self.statusText:SetTextColor(0.2, 1, 0.2)
    end
end

function NSAukGuildBankClass:RegisterAddonChatHandler()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame.owner = self
    frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
        local myName = UnitName("player")
        if channel ~= "GUILD" then return end
        if sender == myName then return end
        if prefix == "ns_ScanGB" then
            self.owner:OnScanRequestReceived(sender)
            return
        end

        if prefix == "ns_MyGb" then
            local parts = mysplit(message)
            if #parts < 3 then return end
            local ownerName = parts[1]
            local count = tonumber(parts[#parts])
            local itemLink = table.concat(parts, " ", 2, #parts - 1)
            if not count or count <= 0 then return end

            if not self.owner.incomingBuffers[ownerName] then
                self.owner.incomingBuffers[ownerName] = { items = {}, finalized = false }
            end

            local buffer = self.owner.incomingBuffers[ownerName]
            if buffer.finalized then
                buffer.items = {}
                buffer.finalized = false
            end

            local _, _, itemIDStr = string.find(itemLink, "item:(%d+):")
            local itemID = itemIDStr and tonumber(itemIDStr) or 0
            if itemID and itemID > 0 or string.find(itemLink, "|Hgold:") then
                local found = false
                for _, entry in ipairs(buffer.items) do
                    if entry.link == itemLink then
                        entry.count = entry.count + count
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(buffer.items, { link = itemLink, id = itemID, count = count })
                end
            end
            return
        end

        if prefix == PREFIX_END then
            local parts = mysplit(message)
            if #parts < 2 then return end
            local ownerName = parts[1]
            local version = tonumber(parts[2])

            if not ownerName or not version then return end

            if self.owner.incomingBuffers[ownerName] then
                local buffer = self.owner.incomingBuffers[ownerName]
                local existingVersion = (NSAukGlobal.guildBankVersions and NSAukGlobal.guildBankVersions[ownerName]) or 0

                if version > existingVersion then
                    NSAukGlobal.guildBanks[ownerName] = buffer.items
                    if not NSAukGlobal.guildBankVersions then NSAukGlobal.guildBankVersions = {} end
                    NSAukGlobal.guildBankVersions[ownerName] = version
                    NSAukGlobal.guildBankTimestamps[ownerName] = GetTime()

                    -- Потоковая отрисовка: обновляем UI сразу при получении актуальной таблицы
                    self.owner:RefreshDisplay()
                end

                self.owner.incomingBuffers[ownerName] = nil
            end

            -- Завершаем сканирование после задержки
            if self.owner.isScanning then
                if not self.owner.scanFinishFrame then
                    self.owner.scanFinishFrame = CreateFrame("Frame")
                    self.owner.scanFinishFrame.owner = self.owner
                    self.owner.scanFinishFrame.startTime = GetTime()
                    self.owner.scanFinishFrame:SetScript("OnUpdate", function(sff)
                        if GetTime() - sff.startTime >= SCAN_FINISH_DELAY then
                            sff.owner:FinalizeScan()
                            sff:SetScript("OnUpdate", nil)
                            sff:Hide()
                            sff.owner.scanFinishFrame = nil
                        end
                    end)
                    self.owner.scanFinishFrame:Show()
                end
            end
            return
        end

        if prefix == "ns_GBRemove" then
            local removedName = message
            if NSAukGlobal.guildBanks[removedName] then
                NSAukGlobal.guildBanks[removedName] = {}
            end
            if self.owner.frame and self.owner.frame:IsShown() then
                self.owner:RefreshDisplay()
            end
            return
        end
        if prefix == "ns_GBUpdate" then
            return
        end
        if prefix == "ns_GBClearAll" then
            self.owner:ClearAllGuildBanks(true)
            return
        end
    end)
end

function NSAukGuildBankClass:ProcessItemResponse(item_entries, owner, sender)
    if not self.itemEntries then self.itemEntries = {} end
    if not self.ownershipData then self.ownershipData = {} end
    for _, entry in ipairs(item_entries) do
        local uniqueKey = entry.link or entry.id
        if not self.ownershipData[uniqueKey] then self.ownershipData[uniqueKey] = {} end
        local ownerExists = false
        for _, ownerData in ipairs(self.ownershipData[uniqueKey]) do
            if ownerData.name == owner then
                ownerExists = true
                ownerData.count = (ownerData.count or 0) + entry.count
                break
            end
        end
        if not ownerExists then
            table.insert(self.ownershipData[uniqueKey], { name = owner, count = entry.count })
        end
        table.insert(self.itemEntries, { link = entry.link, id = entry.id, count = entry.count })
    end
    if not self.displayFrame or not self.displayFrame:IsShown() then
        if self.displayFrame then self.displayFrame:SetScript("OnUpdate", nil); self.displayFrame:Hide() end
        self.displayFrame = CreateFrame("Frame")
        self.displayFrame.owner = self
        self.displayFrame.startTime = GetTime()
        self.displayFrame:SetScript("OnUpdate", function(df)
            if GetTime() - df.startTime >= 0.3 then
                df.owner:RefreshDisplay()
                df:SetScript("OnUpdate", nil)
                df:Hide()
            end
        end)
        self.displayFrame:Show()
    end
end

function NSAukGuildBankClass:Show()
    if not self.frame then self:CreateUI() end
    if self.frame then self.frame:Show() end
end

function NSAukGuildBankClass:Hide()
    if self.frame then self.frame:Hide() end
end

if not StaticPopupDialogs["NSAUK_CLEAR_GUILDBANK"] then
    StaticPopupDialogs["NSAUK_CLEAR_GUILDBANK"] = {
        text = "Вы уверены что хотите очистить ВСЕ таблицы гильдбанка? Это действие нельзя отменить!",
        button1 = "Да, очистить",
        button2 = "Отмена",
        OnAccept = function()
            if NSAukGuildBank and NSAukGuildBank.ClearAllGuildBanks then
                NSAukGuildBank:ClearAllGuildBanks(false)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }
end
NSAukGuildBank = NSAukGuildBankClass