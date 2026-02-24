-- NSAuk: Аукционный помощник для World of Warcraft 3.3.5
-- Версия 3.0.1 (исправлена задержка проверки типа игрока)

function mysplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

-- === Таблица разделов (жёстко в коде) ===
local NSAukRazdely = {
    ["Задания    "] = {
        ["Задания    "] = {},
    },
    ["Разное    "] = {
        ["Хлам    "] = {},
        ["Реагенты    "] = {},
        ["Питомцы    "] = {},
        ["Праздничные предметы    "] = {},
        ["Другое    "] = {},
        ["Верховые животные    "] = {},
    },
    ["Самоцветы    "] = {
        ["Красные    "] = {},
        ["Синие    "] = {},
        ["Желтые    "] = {},
        ["Фиолетовые    "] = {},
        ["Зеленые    "] = {},
        ["Оранжевые    "] = {},
        ["Особые    "] = {},
        ["Простые    "] = {},
        ["Радужные    "] = {},
    },
    ["Рецепты    "] = {
        ["Книга    "] = {},
        ["Кожевничество    "] = {},
        ["Портняжное дело    "] = {},
        ["Инженерное дело    "] = {},
        ["Кузнечное дело    "] = {},
        ["Кулинария    "] = {},
        ["Алхимия    "] = {},
        ["Первая помощь    "] = {},
        ["Наложение чар    "] = {},
        ["Рыбная ловля    "] = {},
        ["Ювелирное дело    "] = {},
        ["Начертание    "] = {},
    },
    ["Амуниция    "] = {
        ["Колчан    "] = {},
        ["Подсумок    "] = {},
    },
    ["Боеприпасы    "] = {
        ["Стрелы    "] = {},
        ["Пули    "] = {},
    },
    ["Хозяйственные товары    "] = {
        ["Стихии    "] = {},
        ["Ткань    "] = {},
        ["Кожа    "] = {},
        ["Металл и камень    "] = {},
        ["Мясо    "] = {},
        ["Трава    "] = {},
        ["Наложение чар    "] = {},
        ["Ювелирное дело    "] = {},
        ["Детали    "] = {},
        ["Устройства    "] = {},
        ["Взрывчатка    "] = {},
        ["Материалы    "] = {},
        ["Другое    "] = {},
        ["Чары для доспехов    "] = {},
        ["Чары для оружия    "] = {},
    },
    ["Символы    "] = {
        ["Воин    "] = {},
        ["Паладин    "] = {},
        ["Охотник    "] = {},
        ["Разбойник    "] = {},
        ["Жрец    "] = {},
        ["Шаман    "] = {},
        ["Рыцарь смерти    "] = {},
        ["Маг    "] = {},
        ["Чернокнижник    "] = {},
        ["Друид    "] = {},
    },
    ["Расходуемые    "] = {
        ["Еда и напитки    "] = {},
        ["Зелья    "] = {},
        ["Эликсиры    "] = {},
        ["Настойки    "] = {},
        ["Бинты    "] = {},
        ["Улучшения    "] = {},
        ["Свитки    "] = {},
        ["Другое    "] = {},
    },
    ["Сумки    "] = {
        ["Сумка    "] = {},
        ["Сумка душ    "] = {},
        ["Сумка травника    "] = {},
        ["Сумка зачаровывателя    "] = {},
        ["Сумка инженера    "] = {},
        ["Сумка ювелира    "] = {},
        ["Сумка шахтера    "] = {},
        ["Сумка кожевника    "] = {},
        ["Сумка начертателя    "] = {},
    },
    ["Доспехи    "] = {
        ["Разное    "] = {},
        ["Тканевые    "] = {},
        ["Кожаные    "] = {},
        ["Кольчужные    "] = {},
        ["Латные    "] = {},
        ["Щиты    "] = {},
        ["Манускрипты    "] = {},
        ["Идолы    "] = {},
        ["Тотемы    "] = {},
        ["Печати    "] = {},
    },
    ["Оружие    "] = {
        ["Одноручные топоры    "] = {},
        ["Двуручные топоры    "] = {},
        ["Луки    "] = {},
        ["Огнестрельное    "] = {},
        ["Одноручное дробящее    "] = {},
        ["Двуручное дробящее    "] = {},
        ["Древковое    "] = {},
        ["Одноручные мечи    "] = {},
        ["Двуручные мечи    "] = {},
        ["Посохи    "] = {},
        ["Кистевое    "] = {},
        ["Разное    "] = {},
        ["Кинжалы    "] = {},
        ["Метательное    "] = {},
        ["Арбалеты    "] = {},
        ["Жезлы    "] = {},
        ["Удочки    "] = {},
    }
}

-- === Система асинхронной загрузки предметов ===
local ns_ItemQueryFrame = CreateFrame("Frame")
ns_ItemQueryFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ns_ItemQueryFrame.queryCallbacks = {}
ns_ItemQueryFrame.itemCache = {}
ns_ItemQueryFrame:SetScript("OnEvent", function(self, event, itemID)
    if event == "GET_ITEM_INFO_RECEIVED" and type(itemID) == "number" then
        local _, link = GetItemInfo(itemID)
        if link then
            self.itemCache[itemID] = link
            local cb = self.queryCallbacks[itemID]
            if cb then
                cb(link)
                self.queryCallbacks[itemID] = nil
            end
        end
    end
end)

function GetItemLinkWithQuery(itemID, callback)
    if not itemID or itemID == 0 or type(itemID) ~= "number" then
        if callback then callback(nil) end
        return nil
    end
    if ns_ItemQueryFrame.itemCache[itemID] then
        if callback then callback(ns_ItemQueryFrame.itemCache[itemID]) end
        return ns_ItemQueryFrame.itemCache[itemID]
    end
    local _, link = GetItemInfo(itemID)
    if link then
        ns_ItemQueryFrame.itemCache[itemID] = link
        if callback then callback(link) end
        return link
    end
    local tooltip = CreateFrame("GameTooltip", "ns_HiddenTooltip" .. itemID, UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink("item:" .. itemID .. ":0:0:0:0:0:0:0")
    tooltip:Hide()
    if callback then
        ns_ItemQueryFrame.queryCallbacks[itemID] = callback
    end
    return nil
end
-- === Конец системы загрузки ===

NSAuk = NSAuk or {}
if type(NSAuk) ~= "table" then NSAuk = {} end
NSAuk.items = NSAuk.items or {}

if not NSAuk.originalUIParentOnKeyDown then
    NSAuk.originalUIParentOnKeyDown = UIParent:GetScript("OnKeyDown")
end

UIParent:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" and NSAukFrame and NSAukFrame:IsShown() and
        not ChatFrameEditBox:IsVisible() and not IsChatFrameFocused() then
        NSAukFrame:Hide()
        return true
    end
    if NSAuk.originalUIParentOnKeyDown then
        return NSAuk.originalUIParentOnKeyDown(self, key)
    end
end)

local NSAukClass = {}
NSAukClass.__index = NSAukClass

function NSAukClass.new()
    local self = setmetatable({}, NSAukClass)
    self.frame = nil
    self.searchBox = nil
    self.sellItemFrame = nil
    self.sellItemInfo = nil
    self.sellButton = nil
    self.deleteButton = nil
    self.buyTab = nil
    self.sellTab = nil
    self.currentTab = "buy"
    self.quantityBox = nil
    self.goldBox = nil
    self.silverBox = nil
    self.copperBox = nil
    self.resultsList = nil
    self.resultsContainer = nil
    self.results = {}
    self.findBtn = nil
    self.findButtonCooldown = false
    self.findButtonTimer = 0
    self.cooldownFrame = nil
    self.lastSearchQuery = nil
    self.currentPage = 1
    self.pageButton = nil
    self.offlineButton = nil
    self.searchMode = "online"
    self.pendingSearchItem = nil
    self.pendingSearchTimer = 0
    self.pendingSearchFrame = nil
    self.scrollbar = nil
    self.categoriesPanel = nil
    self.categoriesContainer = nil
    self.categoriesList = nil
    self.categoriesScrollbar = nil
    self.categoryButtons = {}
    self.expandedCategories = {}
    self.minLevelBox = nil
    self.maxLevelBox = nil
    self.qualityDropdown = nil
    self.selectedQuality = -1
    self.selectedQualityText = "Все"
    self.maxGoldBox = nil
    self.maxSilverBox = nil
    self.maxCopperBox = nil
    -- Тип игрока (ХК/ХК+/Обычный)
    self.playerType = nil
    self.playerDebuff = nil
    self.playerPrefix = ""

    self:CreateUI()
    self:RegisterChatHandler()

    -- === ЗАДЕРЖКА ПРОВЕРКИ ДЕБАФОВ (3 секунды) ===
    local delayFrame = CreateFrame("Frame")
    delayFrame.owner = self
    delayFrame.elapsed = 0
    delayFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 3 then
            self.owner:CheckPlayerDebuffs()
            self:SetScript("OnUpdate", nil)
        end
    end)
    delayFrame:Show()
    -- =============================================

    return self
end

-- === ФУНКЦИЯ: Проверка дебафов игрока (3.3.5) ===
function NSAukClass:CheckPlayerDebuffs()
    self.playerType = nil
    self.playerDebuff = nil
    self.playerPrefix = ""

    for i = 1, 40 do
        local debuffName = UnitDebuff("player", i)
        if not debuffName then break end

        if debuffName == "Призрачная усталость" then
            self.playerType = "HK"
            self.playerDebuff = "Призрачная усталость"
            self.playerPrefix = "-"
            break
        elseif debuffName == "Слабость" then
            self.playerType = "HK+"
            self.playerDebuff = "Слабость"
            self.playerPrefix = "~"
            break
        end
    end

    if self.playerType then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00NSAuk: Тип игрока определён: " .. self.playerType .. " (" .. self.playerDebuff .. ")|r")
    else
        self.playerType = "Обычный"
        self.playerPrefix = " "
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: ВНИМАНИЕ! Не найден дебаф ХК/ХК+. Вы обычный игрок.|r")
    end

    return self.playerType
end

-- === ФУНКЦИЯ: Получение префикса команды ===
function NSAukClass:GetCommandPrefix(baseCmd)
    return baseCmd .. self.playerPrefix
end

local function ParsePriceToCopper(priceStr)
    local gold, silver, copper = 0, 0, 0
    local g = priceStr:match("(%d+)з")
    if g then gold = tonumber(g) end
    local s = priceStr:match("(%d+)с")
    if s then silver = tonumber(s) end
    local c = priceStr:match("(%d+)м")
    if c then copper = tonumber(c) end
    return gold * 10000 + silver * 100 + copper
end

local function ParsePrice(priceStr)
    local gold, silver, copper = 0, 0, 0
    local g = priceStr:match("(%d+)з")
    if g then gold = tonumber(g) end
    local s = priceStr:match("(%d+)с")
    if s then silver = tonumber(s) end
    local c = priceStr:match("(%d+)м")
    if c then copper = tonumber(c) end
    return gold, silver, copper
end

local function FormatPrice(gold, silver, copper)
    local parts = {}
    if gold > 0 then table.insert(parts, gold .. "з") end
    if silver > 0 then table.insert(parts, silver .. "с") end
    if copper > 0 then table.insert(parts, copper .. "м") end
    if #parts == 0 then return "0м" end
    return table.concat(parts, "")
end

local function CalculateTotalPrice(priceStr, quantity)
    local g, s, c = ParsePrice(priceStr)
    local totalCopper = (g * 10000 + s * 100 + c) * quantity
    local totalGold = math.floor(totalCopper / 10000)
    local totalSilver = math.floor((totalCopper % 10000) / 100)
    local totalCopperRem = totalCopper % 100
    return totalGold, totalSilver, totalCopperRem
end

local function EnsureAuctionChannel(callback)
    local chanID, chanName = GetChannelName("Аукцион")
    if chanID and chanID ~= 0 and type(chanName) == "string" then
        if callback then callback(chanID) end
        return
    end
    for i = 1, 32 do
        local name, id = GetChannelName(i)
        if type(name) == "string" and name:lower():find("аукцион") then
            if callback then callback(id) end
            return
        end
    end
    JoinChannelByName("Аукцион")
    local joinFrame = CreateFrame("Frame")
    joinFrame.timer = 0
    joinFrame:SetScript("OnUpdate", function(self, elapsed)
        self.timer = self.timer + elapsed
        if self.timer < 1.5 then return end
        self:Hide()
        self:SetScript("OnUpdate", nil)
        chanID, chanName = GetChannelName("Аукцион")
        if chanID and chanID ~= 0 and type(chanName) == "string" then
            if callback then callback(chanID) end
            return
        end
        for i = 1, 32 do
            local name, id = GetChannelName(i)
            if type(name) == "string" and name:lower():find("аукцион") then
                if callback then callback(id) end
                return
            end
        end
        if callback then callback(nil) end
    end)
    joinFrame:Show()
end

function NSAukClass:OnItemDrop(frame)
    if not frame or not frame.texture then return end
    local cursorType, arg1 = GetCursorInfo()
    if cursorType == "item" and type(arg1) == "number" then
        local itemID = arg1
        local itemLink = nil
        local fullName = nil

        -- Ищем предмет в сумках через GetContainerItemLink (даёт полное имя с суффиксом)
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local slotLink = GetContainerItemLink(bag, slot)
                if slotLink then
                    local slotID = slotLink:match("item:(%d+)")
                    if slotID and tonumber(slotID) == itemID then
                        itemLink = slotLink
                        fullName = slotLink:match("%[(.-)%]")
                        break
                    end
                end
            end
            if itemLink then break end
        end

        -- Фоллбэк: GetItemInfo
        if not itemLink then
            local _, link = GetItemInfo(itemID)
            if link then
                itemLink = link
                fullName = link:match("%[(.-)%]")
            end
        end

        if itemLink and fullName then
            local _, _, quality, _, _, itemType, itemSubType, _, _, texture = GetItemInfo(itemLink)

            if texture then
                frame.texture:SetTexture(texture)
                frame.itemLink = itemLink
                frame.itemID = itemID
                frame.itemType = itemType or "Неизвестно"
                frame.itemSubType = itemSubType or "Неизвестно"
                frame.quality = type(quality) == "number" and quality or 0
                frame.itemName = fullName

                local infoText = string.format("%s\nID: %d | Класс: %s | Подкласс: %s | Качество: %d",
                    fullName, itemID, frame.itemType, frame.itemSubType, frame.quality)
                frame.itemInfo:SetText(infoText)
                ClearCursor()
                return
            end
        end
    end

    frame.texture:SetTexture(" ")
    frame.itemInfo:SetText(" ")
    frame.itemLink = nil
    frame.itemID = nil
    frame.itemType = nil
    frame.itemSubType = nil
    frame.quality = nil
    frame.itemName = nil
    ClearCursor()
end

function NSAukClass:CreateUI()
    local frame = CreateFrame("Frame", "NSAukFrame", UIParent)
    frame:SetSize(850, 410)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetToplevel(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    self.frame = frame

    local backdrop = frame:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints(frame)
    backdrop:SetTexture("Interface\\Buttons\\WHITE8X8")
    backdrop:SetVertexColor(0, 0, 0, 1)

    local titleFrame = CreateFrame("Frame", nil, frame)
    titleFrame:SetSize(830, 30)
    titleFrame:SetPoint("TOP", frame, "TOP", 0, -10)
    local titleText = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("CENTER", titleFrame, "CENTER", 0, 0)
    titleText:SetText('Аукцион от "Ночной стражи"')
    titleText:SetTextColor(1, 0.82, 0)
    local emblem = titleFrame:CreateTexture(nil, "OVERLAY")
    emblem:SetSize(48, 48)
    emblem:SetPoint("RIGHT", titleText, "LEFT", -8, 0)
    emblem:SetTexture("Interface\\AddOns\\NSAuk\\emblem.tga")

    local categoriesPanel = CreateFrame("ScrollFrame", "categoriesPanel", frame)
    categoriesPanel:SetSize(150, 345)
    categoriesPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -45)
    categoriesPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    categoriesPanel:SetBackdropColor(0.05, 0.05, 0.05, 1.0)
    categoriesPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1.0)
    categoriesPanel:EnableMouseWheel(true)
    local categoriesList = CreateFrame("Frame", "categoriesList", categoriesPanel)
    categoriesList:SetWidth(130)
    categoriesList:SetHeight(1)
    categoriesPanel:SetScrollChild(categoriesList)
    self.categoriesPanel = categoriesPanel
    self.categoriesList = categoriesList

    local categoriesScrollbar = CreateFrame("Slider", "categoriesScrollbar", frame, "UIPanelScrollBarTemplate")
    categoriesScrollbar:SetOrientation("VERTICAL")
    categoriesScrollbar:SetSize(16, 340)
    categoriesScrollbar:SetPoint("TOPLEFT", categoriesPanel, "TOPRIGHT", 0, -16)
    categoriesScrollbar:SetPoint("BOTTOMLEFT", categoriesPanel, "BOTTOMRIGHT", 0, 16)
    categoriesScrollbar.scrollFrame = categoriesPanel
    categoriesPanel.categoriesScrollbar = categoriesScrollbar
    categoriesScrollbar:SetScript("OnValueChanged", function(self, value)
        if self.scrollFrame then
            self.scrollFrame:SetVerticalScroll(value)
        end
    end)
    categoriesPanel:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.categoriesScrollbar
        if not scrollBar then return end
        local minVal, maxVal = scrollBar:GetMinMaxValues()
        if maxVal <= 0 then return end
        local current = self:GetVerticalScroll()
        local step = 18
        if delta > 0 then
            current = current - step
        else
            current = current + step
        end
        current = math.max(0, math.min(maxVal, current))
        self:SetVerticalScroll(current)
        scrollBar:SetValue(current)
    end)
    self.categoriesScrollbar = categoriesScrollbar

    local buyPanel = CreateFrame("Frame", "buyPanel", frame)
    buyPanel:SetSize(670, 340)
    buyPanel:SetPoint("TOPLEFT", categoriesPanel, "TOPRIGHT", 10, 0)
    buyPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    buyPanel:Hide()

    local searchEdit = CreateFrame("EditBox", "searchEdit", buyPanel)
    searchEdit:SetSize(480, 22)
    searchEdit:SetPoint("TOPLEFT", buyPanel, "TOPLEFT", 10, -3)
    searchEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    searchEdit:SetBackdropColor(0, 0, 0, 0.8)
    searchEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    searchEdit:SetFont("Fonts\\FRIZQT__.TTF", 12)
    searchEdit:SetTextInsets(5, 5, 3, 3)
    searchEdit:SetAutoFocus(false)
    searchEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchEdit:SetScript("OnEnterPressed", function(self)
        if not self.owner.findButtonCooldown then
            self.owner:StartSearch()
        end
        self:ClearFocus()
    end)
    searchEdit:SetScript("OnEditFocusGained", function(self)
        local owner = self.owner
        owner:ClearResults()
        owner.lastSearchQuery = nil
        owner.currentPage = 1
        owner.searchMode = "online"
        owner.pendingSearchItem = nil
        if owner.pageButton then owner.pageButton:Hide() end
        if owner.offlineButton then owner.offlineButton:Hide() end
    end)
    searchEdit.owner = self
    self.searchBox = searchEdit

    local findBtn = CreateFrame("Button", "findBtn", buyPanel, "UIPanelButtonTemplate")
    findBtn:SetSize(80, 22)
    findBtn:SetPoint("LEFT", searchEdit, "RIGHT", 8, 0)
    findBtn:SetText("Найти")
    findBtn.owner = self
    findBtn:SetScript("OnClick", function(self)
        if self.owner.findButtonCooldown then return end
        self.owner:StartSearch()
    end)
    self.findBtn = findBtn

    local filtersFrame = CreateFrame("Frame", "filtersFrame", buyPanel)
    filtersFrame:SetSize(640, 30)
    filtersFrame:SetPoint("TOPLEFT", searchEdit, "BOTTOMLEFT", -3, -8)

    local levelLabel = filtersFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelLabel:SetText("Уровень:  ")
    levelLabel:SetPoint("LEFT", filtersFrame, "LEFT", 0, 0)

    local minLevelBox = CreateFrame("EditBox", "minLevelBox", filtersFrame)
    minLevelBox:SetSize(60, 20)
    minLevelBox:SetPoint("LEFT", levelLabel, "RIGHT", 5, 0)
    minLevelBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    minLevelBox:SetBackdropColor(0, 0, 0, 0.8)
    minLevelBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    minLevelBox:SetFont("Fonts\\FRIZQT__.TTF", 11)
    minLevelBox:SetTextInsets(3, 3, 2, 2)
    minLevelBox:SetAutoFocus(false)
    minLevelBox:SetText(" ")
    minLevelBox:SetNumeric(true)
    minLevelBox:SetMaxLetters(3)
    minLevelBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.minLevelBox = minLevelBox

    local dashLabel = filtersFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dashLabel:SetText("-")
    dashLabel:SetPoint("LEFT", minLevelBox, "RIGHT", 5, 0)

    local maxLevelBox = CreateFrame("EditBox", "maxLevelBox", filtersFrame)
    maxLevelBox:SetSize(60, 20)
    maxLevelBox:SetPoint("LEFT", dashLabel, "RIGHT", 5, 0)
    maxLevelBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    maxLevelBox:SetBackdropColor(0, 0, 0, 0.8)
    maxLevelBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    maxLevelBox:SetFont("Fonts\\FRIZQT__.TTF", 11)
    maxLevelBox:SetTextInsets(3, 3, 2, 2)
    maxLevelBox:SetAutoFocus(false)
    maxLevelBox:SetText(" ")
    maxLevelBox:SetNumeric(true)
    maxLevelBox:SetMaxLetters(3)
    maxLevelBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.maxLevelBox = maxLevelBox

    local qualityLabel = filtersFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qualityLabel:SetText("Качество:  ")
    qualityLabel:SetPoint("LEFT", maxLevelBox, "RIGHT", 10, 0)

    local qualityDropdown = CreateFrame("Frame", "qualityDropdown", filtersFrame, "UIDropDownMenuTemplate")
    qualityDropdown:SetSize(100, 20)
    qualityDropdown:SetPoint("LEFT", qualityLabel, "RIGHT", -10, 0)
    UIDropDownMenu_SetWidth(qualityDropdown, 100)
    self.qualityDropdown = qualityDropdown

    local nsauk = self
    local qualityOptions = {
        { text = "Все", value = -1, color = { 1, 1, 1 } },
        { text = "Низкое", value = 0, color = { 0.5, 0.5, 0.5 } },
        { text = "Обычное", value = 1, color = { 1, 1, 1 } },
        { text = "Необычное", value = 2, color = { 0.1, 0.8, 0.1 } },
        { text = "Редкое", value = 3, color = { 0, 0.4, 1 } },
        { text = "Превосходное", value = 4, color = { 0.6, 0.2, 0.8 } }
    }

    local function Quality_Initialize(frame, level)
        for i, option in ipairs(qualityOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                nsauk.selectedQuality = option.value
                nsauk.selectedQualityText = option.text
                UIDropDownMenu_SetText(qualityDropdown, option.text)
                PlaySound("igMainMenuOptionCheckBoxOn")
            end
            info.colorCode = string.format("|cff%02x%02x%02x", option.color[1] * 255, option.color[2] * 255, option.color[3] * 255)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(qualityDropdown, Quality_Initialize)
    UIDropDownMenu_SetText(qualityDropdown, "Все")
    self.selectedQuality = -1
    self.selectedQualityText = "Все"

    local priceLabel = filtersFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    priceLabel:SetText("Цена до:  ")
    priceLabel:SetPoint("LEFT", qualityDropdown, "RIGHT", 0, 0)

    local maxGoldBox = CreateFrame("EditBox", "maxGoldBox", filtersFrame)
    maxGoldBox:SetSize(45, 20)
    maxGoldBox:SetPoint("LEFT", priceLabel, "RIGHT", 5, 0)
    maxGoldBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    maxGoldBox:SetBackdropColor(0, 0, 0, 0.8)
    maxGoldBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    maxGoldBox:SetFont("Fonts\\FRIZQT__.TTF", 11)
    maxGoldBox:SetTextInsets(3, 3, 2, 2)
    maxGoldBox:SetAutoFocus(false)
    maxGoldBox:SetText("0")
    maxGoldBox:SetNumeric(true)
    maxGoldBox:SetMaxLetters(4)
    maxGoldBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.maxGoldBox = maxGoldBox

    local goldIcon = filtersFrame:CreateTexture(nil, "OVERLAY")
    goldIcon:SetSize(14, 14)
    goldIcon:SetPoint("LEFT", maxGoldBox, "RIGHT", 3, 0)
    goldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")

    local maxSilverBox = CreateFrame("EditBox", "maxSilverBox", filtersFrame)
    maxSilverBox:SetSize(35, 20)
    maxSilverBox:SetPoint("LEFT", goldIcon, "RIGHT", 8, 0)
    maxSilverBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    maxSilverBox:SetBackdropColor(0, 0, 0, 0.8)
    maxSilverBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    maxSilverBox:SetFont("Fonts\\FRIZQT__.TTF", 11)
    maxSilverBox:SetTextInsets(3, 3, 2, 2)
    maxSilverBox:SetAutoFocus(false)
    maxSilverBox:SetText("0")
    maxSilverBox:SetNumeric(true)
    maxSilverBox:SetMaxLetters(2)
    maxSilverBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.maxSilverBox = maxSilverBox

    local silverIcon = filtersFrame:CreateTexture(nil, "OVERLAY")
    silverIcon:SetSize(14, 14)
    silverIcon:SetPoint("LEFT", maxSilverBox, "RIGHT", 3, 0)
    silverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")

    local maxCopperBox = CreateFrame("EditBox", "maxCopperBox", filtersFrame)
    maxCopperBox:SetSize(35, 20)
    maxCopperBox:SetPoint("LEFT", silverIcon, "RIGHT", 8, 0)
    maxCopperBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    maxCopperBox:SetBackdropColor(0, 0, 0, 0.8)
    maxCopperBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    maxCopperBox:SetFont("Fonts\\FRIZQT__.TTF", 11)
    maxCopperBox:SetTextInsets(3, 3, 2, 2)
    maxCopperBox:SetAutoFocus(false)
    maxCopperBox:SetText("0")
    maxCopperBox:SetNumeric(true)
    maxCopperBox:SetMaxLetters(2)
    maxCopperBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.maxCopperBox = maxCopperBox

    local copperIcon = filtersFrame:CreateTexture(nil, "OVERLAY")
    copperIcon:SetSize(14, 14)
    copperIcon:SetPoint("LEFT", maxCopperBox, "RIGHT", 3, 0)
    copperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")

    local pageButton = CreateFrame("Button", "pageButton", buyPanel, "UIPanelButtonTemplate")
    pageButton:SetSize(60, 22)
    pageButton:SetPoint("LEFT", findBtn, "RIGHT", 6, 0)
    pageButton:SetText("  >  > 2")
    pageButton.owner = self
    pageButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Показать вторую страницу", 1, 1, 1)
        GameTooltip:Show()
    end)
    pageButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    pageButton:SetScript("OnClick", function(self)
        local owner = self.owner
        if owner.findButtonCooldown or not owner.lastSearchQuery then return end
        local pageNum = tonumber(self:GetText():match("%d+")) or (owner.currentPage + 1)
        owner:ClearResults()
        owner.currentPage = pageNum
        self:Hide()
        owner.findButtonCooldown = true
        owner.findButtonTimer = 25
        owner.cooldownFrame:Show()
        owner.findBtn:SetText("Найти (25)")
        EnsureAuctionChannel(function(chanID)
            if chanID then
                local cmd = owner:GetCommandPrefix(owner.searchMode == "online" and "КПОН" or "КПН")
                SendChatMessage(cmd .. "  " .. pageNum .. "  " .. owner.lastSearchQuery, "CHANNEL", nil, chanID)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Не удалось подключиться к каналу 'Аукцион'.|r")
            end
        end)
    end)
    pageButton:Hide()
    self.pageButton = pageButton

    local offlineButton = CreateFrame("Button", "offlineButton", buyPanel, "UIPanelButtonTemplate")
    offlineButton:SetSize(240, 30)
    offlineButton:SetPoint("CENTER", buyPanel, "CENTER", 0, 0)
    offlineButton:SetText("Показать офлайновых игроков")
    offlineButton.owner = self
    offlineButton:SetScript("OnClick", function(self)
        local owner = self.owner
        owner:ClearResults()
        owner.searchMode = "offline"
        owner.offlineButton:Hide()
        owner.findButtonCooldown = true
        owner.findButtonTimer = 25
        owner.cooldownFrame:Show()
        owner.findBtn:SetText("Найти (25)")
        EnsureAuctionChannel(function(chanID)
            if chanID then
                local cmd = owner:GetCommandPrefix("КП")
                SendChatMessage(cmd .. "  " .. owner.lastSearchQuery, "CHANNEL", nil, chanID)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Не удалось подключиться к каналу 'Аукцион'.|r")
            end
        end)
    end)
    offlineButton:Hide()
    self.offlineButton = offlineButton

    local cooldownFrame = CreateFrame("Frame")
    cooldownFrame.owner = self
    cooldownFrame:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        if not owner.findButtonCooldown then
            self:Hide()
            return
        end
        owner.findButtonTimer = owner.findButtonTimer - elapsed
        if owner.findButtonTimer <= 0 then
            owner.findButtonCooldown = false
            owner.findButtonTimer = 0
            owner.findBtn:Enable()
            owner.findBtn:SetText("Найти")
            for _, btnData in ipairs(owner.categoryButtons) do
                if btnData.button then
                    btnData.button:Enable()
                end
            end
            self:Hide()
            return
        end
        local remaining = math.ceil(owner.findButtonTimer)
        owner.findBtn:SetText("Найти (" .. remaining .. ")")
    end)
    cooldownFrame:Hide()
    self.cooldownFrame = cooldownFrame

    local pendingFrame = CreateFrame("Frame")
    pendingFrame.owner = self
    pendingFrame:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        if not owner.pendingSearchItem then
            self:Hide()
            return
        end
        owner.pendingSearchTimer = owner.pendingSearchTimer - elapsed
        if owner.pendingSearchTimer <= 0 then
            owner.pendingSearchItem = nil
            self:Hide()
            if #owner.results == 0 then
                owner.offlineButton:Show()
            end
            return
        end
    end)
    pendingFrame:Hide()
    self.pendingSearchFrame = pendingFrame

    local resultsContainer = CreateFrame("ScrollFrame", "resultsContainer", buyPanel)
    resultsContainer:SetSize(640, 230)
    resultsContainer:SetPoint("TOPLEFT", filtersFrame, "BOTTOMLEFT", 0, -10)
    resultsContainer:SetPoint("BOTTOMRIGHT", buyPanel, "BOTTOMRIGHT", -10, 10)
    resultsContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    resultsContainer:SetBackdropColor(0.06, 0.06, 0.06, 1.0)
    resultsContainer:SetBackdropBorderColor(0.45, 0.45, 0.45, 1.0)
    resultsContainer:EnableMouseWheel(true)
    local resultsList = CreateFrame("Frame", "resultsList", resultsContainer)
    resultsList:SetWidth(630)
    resultsList:SetHeight(1)
    resultsContainer:SetScrollChild(resultsList)
    self.resultsContainer = resultsContainer
    self.resultsList = resultsList

    local scrollbar = CreateFrame("Slider", "scrollbar", buyPanel, "UIPanelScrollBarTemplate")
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetSize(16, 250)
    scrollbar:SetPoint("TOPLEFT", resultsContainer, "TOPRIGHT", 0, -16)
    scrollbar:SetPoint("BOTTOMLEFT", resultsContainer, "BOTTOMRIGHT", 0, 16)
    scrollbar.scrollFrame = resultsContainer
    resultsContainer.scrollbar = scrollbar
    scrollbar:SetScript("OnValueChanged", function(self, value)
        if self.scrollFrame then
            self.scrollFrame:SetVerticalScroll(value)
        end
    end)
    resultsContainer:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.scrollbar
        if not scrollBar then return end
        local minVal, maxVal = scrollBar:GetMinMaxValues()
        if maxVal <= 0 then return end
        local current = self:GetVerticalScroll()
        local step = 24
        if delta > 0 then
            current = current - step
        else
            current = current + step
        end
        current = math.max(0, math.min(maxVal, current))
        self:SetVerticalScroll(current)
        scrollBar:SetValue(current)
    end)
    self.scrollbar = scrollbar

    self.buyPanel = buyPanel

    local sellPanel = CreateFrame("Frame", nil, frame)
    sellPanel:SetSize(670, 340)
    sellPanel:SetPoint("TOPLEFT", categoriesPanel, "TOPRIGHT", 10, 0)
    sellPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    sellPanel:Hide()
    local dropLabel = sellPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropLabel:SetText("Перетащите предмет для продажи:  ")
    dropLabel:SetPoint("TOPLEFT", sellPanel, "TOPLEFT", 10, -10)
    local itemFrame = CreateFrame("Button", nil, sellPanel)
    itemFrame:SetSize(64, 64)
    itemFrame:SetPoint("TOPLEFT", dropLabel, "BOTTOMLEFT", 0, -10)
    itemFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    itemFrame:SetBackdropColor(0, 0, 0, 0.5)
    itemFrame:SetBackdropBorderColor(1, 1, 1, 0.8)
    itemFrame:EnableMouse(true)
    itemFrame:RegisterForDrag("LeftButton")
    itemFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    itemFrame.owner = self
    itemFrame:SetScript("OnReceiveDrag", function(self)
        self.owner:OnItemDrop(self)
    end)
    local texture = itemFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(itemFrame)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    itemFrame.texture = texture
    local itemInfo = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemInfo:SetPoint("TOPLEFT", itemFrame, "TOPRIGHT", 10, 0)
    itemInfo:SetWidth(580)
    itemInfo:SetJustifyH("LEFT")
    itemInfo:SetJustifyV("TOP")
    itemInfo:SetText(" ")
    itemInfo:SetTextColor(1, 1, 1)
    itemInfo:SetFont("Fonts\\FRIZQT__.TTF", 11)
    itemFrame.itemInfo = itemInfo

    local quantityLabel = sellPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    quantityLabel:SetText("Количество:  ")
    quantityLabel:SetPoint("TOPLEFT", itemFrame, "BOTTOMLEFT", 0, -25)
    local quantityBox = CreateFrame("EditBox", nil, sellPanel)
    quantityBox:SetSize(60, 20)
    quantityBox:SetPoint("LEFT", quantityLabel, "RIGHT", 5, 0)
    quantityBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    quantityBox:SetBackdropColor(0, 0, 0, 0.8)
    quantityBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    quantityBox:SetFont("Fonts\\FRIZQT__.TTF", 12)
    quantityBox:SetTextInsets(5, 5, 3, 3)
    quantityBox:SetAutoFocus(false)
    quantityBox:SetText("1")
    quantityBox:SetNumeric(true)
    quantityBox:SetMaxLetters(3)
    quantityBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.quantityBox = quantityBox

    local priceLabel = sellPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceLabel:SetText("Цена за шт:  ")
    priceLabel:SetPoint("TOPLEFT", quantityLabel, "BOTTOMLEFT", 0, -15)
    local goldBox = CreateFrame("EditBox", nil, sellPanel)
    goldBox:SetSize(45, 20)
    goldBox:SetPoint("TOPLEFT", priceLabel, "BOTTOMLEFT", 0, -5)
    goldBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    goldBox:SetBackdropColor(0, 0, 0, 0.8)
    goldBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    goldBox:SetFont("Fonts\\FRIZQT__.TTF", 12)
    goldBox:SetTextInsets(5, 5, 3, 3)
    goldBox:SetAutoFocus(false)
    goldBox:SetText("0")
    goldBox:SetNumeric(true)
    goldBox:SetMaxLetters(4)
    goldBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.goldBox = goldBox
    local goldIconSell = sellPanel:CreateTexture(nil, "OVERLAY")
    goldIconSell:SetSize(14, 14)
    goldIconSell:SetPoint("LEFT", goldBox, "RIGHT", 3, 0)
    goldIconSell:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")

    local silverBox = CreateFrame("EditBox", nil, sellPanel)
    silverBox:SetSize(35, 20)
    silverBox:SetPoint("LEFT", goldIconSell, "RIGHT", 8, 0)
    silverBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    silverBox:SetBackdropColor(0, 0, 0, 0.8)
    silverBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    silverBox:SetFont("Fonts\\FRIZQT__.TTF", 12)
    silverBox:SetTextInsets(5, 5, 3, 3)
    silverBox:SetAutoFocus(false)
    silverBox:SetText("0")
    silverBox:SetNumeric(true)
    silverBox:SetMaxLetters(2)
    silverBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.silverBox = silverBox
    local silverIconSell = sellPanel:CreateTexture(nil, "OVERLAY")
    silverIconSell:SetSize(14, 14)
    silverIconSell:SetPoint("LEFT", silverBox, "RIGHT", 3, 0)
    silverIconSell:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")

    local copperBox = CreateFrame("EditBox", nil, sellPanel)
    copperBox:SetSize(35, 20)
    copperBox:SetPoint("LEFT", silverIconSell, "RIGHT", 8, 0)
    copperBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    copperBox:SetBackdropColor(0, 0, 0, 0.8)
    copperBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    copperBox:SetFont("Fonts\\FRIZQT__.TTF", 12)
    copperBox:SetTextInsets(5, 5, 3, 3)
    copperBox:SetAutoFocus(false)
    copperBox:SetText("0")
    copperBox:SetNumeric(true)
    copperBox:SetMaxLetters(2)
    copperBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.copperBox = copperBox
    local copperIconSell = sellPanel:CreateTexture(nil, "OVERLAY")
    copperIconSell:SetSize(14, 14)
    copperIconSell:SetPoint("LEFT", copperBox, "RIGHT", 3, 0)
    copperIconSell:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")

    local sellBtn = CreateFrame("Button", nil, sellPanel, "UIPanelButtonTemplate")
    sellBtn:SetSize(120, 26)
    sellBtn:SetPoint("BOTTOM", sellPanel, "BOTTOM", -70, 20)
    sellBtn:SetText("Продать")
    sellBtn:SetScript("OnClick", function() self:OnSell() end)

    local deleteBtn = CreateFrame("Button", nil, sellPanel, "UIPanelButtonTemplate")
    deleteBtn:SetSize(120, 26)
    deleteBtn:SetPoint("BOTTOM", sellPanel, "BOTTOM", 70, 20)
    deleteBtn:SetText("Удалить")
    deleteBtn:SetScript("OnClick", function() self:OnDelete() end)

    self.sellItemFrame = itemFrame
    self.sellItemInfo = itemInfo
    self.sellButton = sellBtn
    self.deleteButton = deleteBtn
    self.sellPanel = sellPanel
    self.lotsPanel = self:CreateMyLotsTab()

    local tabWidth = 200
    local tabHeight = 24
    local buyTab = CreateFrame("Button", "buyTab", frame, "UIPanelButtonTemplate2")
    buyTab:SetSize(tabWidth, tabHeight)
    buyTab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, -20)
    buyTab:SetText("Купить")
    buyTab:SetScript("OnClick", function() self:SwitchTab("buy") end)

    local sellTab = CreateFrame("Button", "sellTab", frame, "UIPanelButtonTemplate2")
    sellTab:SetSize(tabWidth, tabHeight)
    sellTab:SetPoint("LEFT", buyTab, "RIGHT", 10, 0)
    sellTab:SetText("Продать")
    sellTab:SetScript("OnClick", function() self:SwitchTab("sell") end)

    self.buyTab = buyTab
    self.sellTab = sellTab

    local lotsTab = CreateFrame("Button", "lotsTab", frame, "UIPanelButtonTemplate2")
    lotsTab:SetSize(tabWidth, tabHeight)
    lotsTab:SetPoint("LEFT", sellTab, "RIGHT", 10, 0)
    lotsTab:SetText("Мои лоты")
    lotsTab:SetScript("OnClick", function() self:SwitchTab("lots") end)
    self.lotsTab = lotsTab

    local guildBankTab = CreateFrame("Button", "guildBankTab", frame, "UIPanelButtonTemplate2")
    guildBankTab:SetSize(tabWidth, tabHeight)
    guildBankTab:SetPoint("LEFT", lotsTab, "RIGHT", 10, 0)
    guildBankTab:SetText("Гильдбанк")
    guildBankTab:SetScript("OnClick", function() self:SwitchTab("guildbank") end)
    self.guildBankTab = guildBankTab

    if NSAukGuildBankClass then
        self.guildBankPanel = NSAukGuildBankClass.new(self)
    end

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local helpBtn = CreateFrame("Button", nil, frame, " ")
    helpBtn:SetSize(22, 22)
    helpBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -6)

    local helpText = helpBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpText:SetText("?")
    helpText:SetPoint("CENTER", helpBtn, "CENTER", 0, 1)
    helpText:SetTextColor(1, 1, 0)

    helpBtn:SetScript("OnEnter", function(self)
        helpText:SetTextColor(1, 1, 0.7)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Справка по аукциону", 1, 0.82, 0, true)
        GameTooltip:AddLine("", 1, 1, 1)
        GameTooltip:AddLine("Поиск предметов:", 0.5, 1, 0.5, true)
        GameTooltip:AddLine("• Введите название и нажмите 'Найти'", 1, 1, 1)
        GameTooltip:AddLine("• Или выберите раздел слева", 1, 1, 1)
        GameTooltip:AddLine("", 1, 1, 1)
        GameTooltip:AddLine("Фильтры поиска:", 0.5, 1, 0.5, true)
        GameTooltip:AddLine("• Уровень: укажите мин/макс уровень предмета", 1, 1, 1)
        GameTooltip:AddLine("• Качество: выберите редкость предмета", 1, 1, 1)
        GameTooltip:AddLine("• Цена до: макс. цена в з/с/м", 1, 1, 1)
        GameTooltip:AddLine("", 1, 1, 1)
        GameTooltip:AddLine("Режимы поиска:", 0.5, 1, 0.5, true)
        GameTooltip:AddLine("• Онлайн: только активные игроки (зелёный ник)", 0.2, 1, 0.2)
        GameTooltip:AddLine("• Офлайн: все игроки (красный ник)", 1, 0.2, 0.2)
        GameTooltip:AddLine("", 1, 1, 1)
        GameTooltip:AddLine("Покупка:", 0.5, 1, 0.5, true)
        GameTooltip:AddLine("Кликните по нику продавца - отправится предложение", 1, 1, 1)
        GameTooltip:AddLine("", 1, 1, 1)
        GameTooltip:AddLine("Продажа:", 0.5, 1, 0.5, true)
        GameTooltip:AddLine("Перетащите предмет - укажите цену - 'Продать'", 1, 1, 1)
        GameTooltip:AddLine("", 1, 1, 1)
        GameTooltip:AddLine("Мои лоты:", 0.5, 1, 0.5, true)
        GameTooltip:AddLine("Вкладка 'Мои лоты' - удаление кликом", 1, 1, 1)
        GameTooltip:AddLine( "  ", 1, 1, 1)
        GameTooltip:AddLine( "Гильдбанк:  ", 0.5, 1, 0.5, true)
        GameTooltip:AddLine( "• 1 предмет в сутки (гильдчат + аддон)  ", 1, 1, 1)
        GameTooltip:AddLine( "• Лимиты: зелья 5, ресурсы 50, символы 1  ", 1, 1, 1)
        GameTooltip:AddLine( "• Превышение: внеси равную сумму  ", 1, 1, 1)
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function(self)
        helpText:SetTextColor(1, 1, 0)
        GameTooltip:Hide()
    end)

    local me = self
    local waitTime = 2
    local elapsed = 0

    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(self, add)
        elapsed = elapsed + add
        if elapsed >= waitTime then
            if NSAukGuildBankClass then
                me.guildBankPanel = NSAukGuildBankClass.new(me)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Ошибка загрузки модуля гильдбанка!|r")
            end
            self:SetScript("OnUpdate", nil)
        end
    end)
    self:SwitchTab("buy")
    self:UpdateCategories()
    self:CreateMinimapButton()
end

function NSAukClass:CreateMyLotsTab()
    local lotsPanel = CreateFrame("Frame", nil, self.frame)
    lotsPanel:SetSize(670, 340)
    lotsPanel:SetPoint("TOPLEFT", self.categoriesPanel, "TOPRIGHT", 10, 0)
    lotsPanel:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 10)
    lotsPanel:Hide()
    self.lotsPanel = lotsPanel
    local searchEdit = CreateFrame("EditBox", nil, lotsPanel)
    searchEdit:SetSize(640, 22)
    searchEdit:SetPoint("TOPLEFT", lotsPanel, "TOPLEFT", 10, -10)
    searchEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    searchEdit:SetBackdropColor(0, 0, 0, 0.8)
    searchEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    searchEdit:SetFont("Fonts\\FRIZQT__.TTF", 12)
    searchEdit:SetTextInsets(5, 5, 3, 3)
    searchEdit:SetAutoFocus(false)
    searchEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchEdit:SetScript("OnTextChanged", function(self)
        self.owner:RefreshMyLots(self:GetText())
    end)
    searchEdit.owner = self
    self.lotsSearchBox = searchEdit

    local hint = lotsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", searchEdit, "BOTTOMLEFT", 0, -5)
    hint:SetText("Поиск по названию, типу или подтипу предмета")
    hint:SetTextColor(0.7, 0.7, 0.7)

    local resultsContainer = CreateFrame("ScrollFrame", nil, lotsPanel)
    resultsContainer:SetSize(640, 290)
    resultsContainer:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    resultsContainer:SetPoint("BOTTOMRIGHT", lotsPanel, "BOTTOMRIGHT", -10, 10)
    resultsContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    resultsContainer:SetBackdropColor(0.06, 0.06, 0.06, 1.0)
    resultsContainer:SetBackdropBorderColor(0.45, 0.45, 0.45, 1.0)
    resultsContainer:EnableMouseWheel(true)

    local resultsList = CreateFrame("Frame", nil, resultsContainer)
    resultsList:SetWidth(630)
    resultsList:SetHeight(1)
    resultsContainer:SetScrollChild(resultsList)

    local scrollbar = CreateFrame("Slider", nil, lotsPanel, "UIPanelScrollBarTemplate")
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetSize(16, 290)
    scrollbar:SetPoint("TOPLEFT", resultsContainer, "TOPRIGHT", 0, -16)
    scrollbar:SetPoint("BOTTOMLEFT", resultsContainer, "BOTTOMRIGHT", 0, 16)
    scrollbar.scrollFrame = resultsContainer
    resultsContainer.scrollbar = scrollbar
    scrollbar:SetScript("OnValueChanged", function(self, value)
        if self.scrollFrame then self.scrollFrame:SetVerticalScroll(value) end
    end)
    resultsContainer:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.scrollbar
        if not scrollBar then return end
        local minVal, maxVal = scrollBar:GetMinMaxValues()
        if maxVal <= 0 then return end
        local current = self:GetVerticalScroll()
        local step = 24
        current = delta > 0 and math.max(0, current - step) or math.min(maxVal, current + step)
        self:SetVerticalScroll(current)
        scrollBar:SetValue(current)
    end)

    self.lotsResultsContainer = resultsContainer
    self.lotsResultsList = resultsList
    self.lotsScrollbar = scrollbar
    self.lotsCooldown = false

    lotsPanel:SetScript("OnShow", function()
        self:RefreshMyLots(self.lotsSearchBox:GetText())
    end)

    return lotsPanel
end

function NSAukClass:RefreshMyLots(filterText)
    if not self.lotsResultsList then return end
    local children = { self.lotsResultsList:GetChildren() }
    for _, child in ipairs(children) do child:Hide() end

    NSAuk = NSAuk or {}
    NSAuk.items = NSAuk.items or {}
    local items = NSAuk.items
    local results = {}

    local filterLower = filterText:lower():gsub("^%s*(.-)%s*$", "%1")
    for name, lot in pairs(items) do
        if filterLower == " " or
            name:lower():find(filterLower, 1, true) or
            (lot.itemType and lot.itemType:lower():find(filterLower, 1, true)) or
            (lot.itemSubType and lot.itemSubType:lower():find(filterLower, 1, true)) then
            table.insert(results, { name = name, lot = lot })
        end
    end

    table.sort(results, function(a, b)
        return (a.lot.timestamp or 0) > (b.lot.timestamp or 0)
    end)

    local qualityColors = {
        [0] = { 0.5, 0.5, 0.5 },
        [1] = { 1, 1, 1 },
        [2] = { 0.1, 0.8, 0.1 },
        [3] = { 0, 0.4, 1 },
        [4] = { 0.6, 0.2, 0.8 },
        [5] = { 1, 0.5, 0 },
        [6] = { 1, 0.82, 0 },
        [7] = { 1, 0.82, 0 },
    }

    local yPos = 0
    for i, item in ipairs(results) do
        local frame = CreateFrame("Button", nil, self.lotsResultsList)
        frame:SetSize(630, 24)
        frame:SetPoint("TOPLEFT", self.lotsResultsList, "TOPLEFT", 0, -yPos)
        frame.itemName = item.name
        frame.owner = self

        frame:SetScript("OnEnter", function(self)
            self.bg:SetVertexColor(0.3, 0.3, 0.5, 0.7)
        end)
        frame:SetScript("OnLeave", function(self)
            self.bg:SetVertexColor(0, 0, 0, 0.3)
        end)

        frame:SetScript("OnClick", function(self)
            if self.owner.lotsCooldown then return end
            self.owner:DeleteMyLot(self.itemName)
        end)

        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(frame)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0, 0, 0, 0.3)
        frame.bg = bg

        local qc = qualityColors[item.lot.quality or 1] or qualityColors[1]
        local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", frame, "LEFT", 5, 0)
        nameText:SetSize(300, 20)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(item.name)
        nameText:SetFont("Fonts\\FRIZQT__.TTF", 11)
        nameText:SetTextColor(qc[1], qc[2], qc[3])

        local qtyPrice = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        qtyPrice:SetPoint("LEFT", nameText, "RIGHT", 10, 0)
        qtyPrice:SetText(string.format("%dx за |cffffd700%s|r", item.lot.quantity, item.lot.priceStr))
        qtyPrice:SetFont("Fonts\\FRIZQT__.TTF", 10)

        local typeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        typeText:SetPoint("LEFT", qtyPrice, "RIGHT", 10, 0)
        typeText:SetText(string.format("(%s / %s)", item.lot.itemType or "?", item.lot.itemSubType or "?"))
        typeText:SetFont("Fonts\\FRIZQT__.TTF", 9)
        typeText:SetTextColor(0.7, 0.7, 0.7)

        local delIcon = frame:CreateTexture(nil, "OVERLAY")
        delIcon:SetSize(16, 16)
        delIcon:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        delIcon:SetTexture("Interface\\Buttons\\UI-Panel-Button-Delete-Up")
        frame.delIcon = delIcon

        yPos = yPos + 24
    end

    self.lotsResultsList:SetHeight(yPos)
    self.lotsResultsContainer:SetVerticalScroll(0)

    local scrollRange = self.lotsResultsContainer:GetVerticalScrollRange()
    if scrollRange > 0 then
        self.lotsScrollbar:Show()
        self.lotsScrollbar:SetMinMaxValues(0, scrollRange)
    else
        self.lotsScrollbar:Hide()
    end

    if self.lotsSearchBox then
        local total = 0
        for _ in pairs(NSAuk.items) do total = total + 1 end
        self.lotsSearchBox:SetScript("OnEditFocusGained", nil)
        self.lotsSearchBox:SetScript("OnEditFocusLost", function(self)
            self.owner.lotsSearchBox.hint:SetText(string.format("Всего лотов: %d", total))
        end)
        if not self.lotsSearchBox.hint then
            self.lotsSearchBox.hint = self.lotsSearchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            self.lotsSearchBox.hint:SetPoint("RIGHT", self.lotsSearchBox, "RIGHT", -5, 0)
        end
        self.lotsSearchBox.hint:SetText(string.format("Найдено: %d", #results))
    end
end

function NSAukClass:DeleteMyLot(itemName)
    if self.lotsCooldown then return end
    NSAuk = NSAuk or {}
    NSAuk.items = NSAuk.items or {}
    if not NSAuk.items[itemName] then return end

    NSAuk.items[itemName] = nil

    EnsureAuctionChannel(function(chanID)
        if chanID then
            local deletePrefix = self:GetCommandPrefix("ДЛ")
            SendChatMessage(deletePrefix .. "  " .. itemName, "CHANNEL", nil, chanID)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00NSAuk: Лот удалён: %s|r", itemName))
        end
    end)

    self.lotsCooldown = true
    local cooldownFrame = CreateFrame("Frame")
    cooldownFrame.owner = self
    cooldownFrame.startTime = GetTime()
    cooldownFrame:SetScript("OnUpdate", function(self)
        if GetTime() - self.startTime >= 2 then
            self.owner.lotsCooldown = false
            self.owner:RefreshMyLots(self.owner.lotsSearchBox:GetText())
            self:SetScript("OnUpdate", nil)
        end
    end)
    cooldownFrame:Show()

    self:RefreshMyLots(self.lotsSearchBox:GetText())
end

function NSAukClass:CreateMinimapButton()
    NSAuk = NSAuk or {}
    if not NSAuk["эмблема"] then
        NSAuk["эмблема"] = { x = 80, y = 0 }
    end
    local button = CreateFrame("Button", "NSAukMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetToplevel(true)
    button:EnableMouse(true)
    button:Show()
    local tex = "Interface\\AddOns\\NSAuk\\emblem.tga"
    button:SetNormalTexture(tex)
    button:SetPushedTexture(tex)
    button:SetHighlightTexture(tex)
    button:SetPoint("CENTER", Minimap, "CENTER", 80, 0)
    local delayFrame = CreateFrame("Frame")
    delayFrame.startTime = GetTime()
    delayFrame:SetScript("OnUpdate", function(self)
        if GetTime() - self.startTime >= 1 then
            self:SetScript("OnUpdate", nil)
            if NSAuk and type(NSAuk) == "table" and NSAuk["эмблема"] and type(NSAuk["эмблема"]) == "table" then
                local x = NSAuk["эмблема"].x
                local y = NSAuk["эмблема"].y
                if type(x) == "number" and type(y) == "number" then
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
                end
            end
        end
    end)

    local function UpdatePosition(self)
        local cursorX, cursorY = GetCursorPosition()
        local minimapX, minimapY = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local relX = (cursorX / scale) - minimapX
        local relY = (cursorY / scale) - minimapY
        local angle = math.atan2(relY, relX)
        local radius = Minimap:GetWidth() * 0.5 + 10
        local newX = math.cos(angle) * radius
        local newY = math.sin(angle) * radius
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", newX, newY)
        NSAuk = NSAuk or {}
        NSAuk["эмблема"] = NSAuk["эмблема"] or {}
        NSAuk["эмблема"].x = newX
        NSAuk["эмблема"].y = newY
    end

    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", UpdatePosition)
        self:SetAlpha(0.6)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:SetAlpha(1)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText('От "Ночной стражи":', 1, 1, 1)
        GameTooltip:AddLine('Аукцион 3.0.1"', 1, 1, 1)
        GameTooltip:AddLine('Гильдбанк 5.2"', 1, 1, 1)
        GameTooltip:AddLine('Отображение смертей хк 6.0.2"', 1, 1, 1)
        GameTooltip:AddLine(' ', 1, 1, 1)
        GameTooltip:AddLine("ЛКМ: открыть/закрыть окно", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Перетащите для перемещения", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            self.owner:Toggle()
        end
    end)
    button.owner = self
    self.minimapButton = button
end

function NSAukClass:SwitchTab(tab)
    self.currentTab = tab
    self.buyTab:UnlockHighlight()
    self.sellTab:UnlockHighlight()
    if self.lotsTab then self.lotsTab:UnlockHighlight() end
    if self.guildBankTab then self.guildBankTab:UnlockHighlight() end
    if tab == "buy" then
        self.buyTab:LockHighlight()
        self.buyPanel:Show()
        self.sellPanel:Hide()
        if self.lotsPanel then self.lotsPanel:Hide() end
        if self.guildBankPanel then self.guildBankPanel:Hide() end
    elseif tab == "sell" then
        self.sellTab:LockHighlight()
        self.sellPanel:Show()
        self.buyPanel:Hide()
        if self.lotsPanel then self.lotsPanel:Hide() end
        if self.guildBankPanel then self.guildBankPanel:Hide() end
    elseif tab == "lots" then
        if self.lotsTab then self.lotsTab:LockHighlight() end
        if self.lotsPanel then
            self.lotsPanel:Show()
            self.buyPanel:Hide()
            self.sellPanel:Hide()
            if self.guildBankPanel then self.guildBankPanel:Hide() end
        end
    elseif tab == "guildbank" then
        if self.guildBankTab then self.guildBankTab:LockHighlight() end
        if not self.guildBankPanel and NSAukGuildBankClass then
            self.guildBankPanel = NSAukGuildBankClass.new(self)
        end
        if self.guildBankPanel then
            self.guildBankPanel:Show()
            self.buyPanel:Hide()
            self.sellPanel:Hide()
            if self.lotsPanel then self.lotsPanel:Hide() end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Модуль гильдбанка не загружен!|r")
        end
    end
end

function NSAukClass:UpdateScrollbar()
    if not self.scrollbar or not self.resultsContainer then return end
    local scrollRange = self.resultsContainer:GetVerticalScrollRange()
    if scrollRange <= 0 then
        self.scrollbar:Hide()
    else
        self.scrollbar:Show()
        self.scrollbar:SetMinMaxValues(0, scrollRange)
        self.scrollbar:SetValue(self.resultsContainer:GetVerticalScroll())
    end
end

function NSAukClass:ClearResults()
    for i = 1, #self.results do
        if self.results[i].frame then
            self.results[i].frame:Hide()
        end
    end
    wipe(self.results)
    self.resultsList:SetHeight(1)
    self.resultsContainer:SetVerticalScroll(0)
    self:UpdateScrollbar()
    if self.offlineButton then self.offlineButton:Hide() end
end

function NSAukClass:AddResult(seller, buyer, quantity, pricePerItem, itemName, isOffline, itemID, sellerType)
    local playerName = UnitName("player")
    if playerName and seller then
        local function normalize(name)
            return (name:match("^([^%-]+)") or name):lower()
        end
        if normalize(playerName) == normalize(seller) then
            return
        end
    end
    -- === ФИЛЬТР ПО ТИПУ ИГРОКА ===
    -- Игрок видит только лоты от игроков своего типа
    if sellerType and self.playerType and sellerType ~= self.playerType then
        return
    end

    local duplicateIndex = nil
    for i = 1, #self.results do
        local lot = self.results[i]
        if lot.seller == seller and lot.itemName == itemName then
            duplicateIndex = i
            break
        end
    end

    if duplicateIndex then
        local existingLot = self.results[duplicateIndex]
        if not isOffline then
            if existingLot.frame then existingLot.frame:Hide() end
            table.remove(self.results, duplicateIndex)
        else
            return
        end
    elseif isOffline and self.searchMode == "online" then
        return
    end

    if #self.results >= 999 then
        local oldLot = table.remove(self.results, 1)
        if oldLot.frame then oldLot.frame:Hide() end
        for i = 1, #self.results do
            self.results[i].frame:ClearAllPoints()
            self.results[i].frame:SetPoint("TOPLEFT", self.resultsList, "TOPLEFT", 0, -((i - 1) * 24))
        end
    end

    local index = #self.results + 1
    local resultFrame = CreateFrame("Frame", nil, self.resultsList)
    resultFrame:SetSize(630, 24)
    local totalGold, totalSilver, totalCopper = CalculateTotalPrice(pricePerItem, tonumber(quantity))
    local totalPriceStr = FormatPrice(totalGold, totalSilver, totalCopper)

    local ownerButton = CreateFrame("Button", nil, resultFrame)
    ownerButton:SetSize(120, 20)
    ownerButton:SetPoint("LEFT", resultFrame, "LEFT", 5, 0)
    local ownerText = ownerButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ownerText:SetPoint("CENTER", ownerButton, "CENTER", 0, 0)
    ownerText:SetText(seller)
    ownerText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")

    if isOffline then
        ownerText:SetTextColor(1, 0.2, 0.2)
    else
        ownerText:SetTextColor(0.2, 1, 0.2)
    end

    ownerButton:SetScript("OnEnter", function()
        if isOffline then
            ownerText:SetTextColor(1, 0.5, 0.5)
            GameTooltip:SetOwner(ownerButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("Ожидает подтверждения продавца", 1, 0.5, 0.5)
        else
            ownerText:SetTextColor(0.5, 1, 0.5)
            GameTooltip:SetOwner(ownerButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("Кликните для предложения покупки", 0.5, 1, 0.5)
        end
        GameTooltip:Show()
    end)
    ownerButton:SetScript("OnLeave", function()
        if isOffline then
            ownerText:SetTextColor(1, 0.2, 0.2)
        else
            ownerText:SetTextColor(0.2, 1, 0.2)
        end
        GameTooltip:Hide()
    end)
    ownerButton:SetScript("OnClick", function()
        if not isOffline then
            local message = string.format("Хочу купить: %s (%s шт) за %s. Договоримся?", itemName, quantity, totalPriceStr)
            SendChatMessage(message, "WHISPER", nil, seller)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00NSAuk: Предложение отправлено игроку %s|r", seller))
        end
    end)

    local itemButton = CreateFrame("Button", nil, resultFrame)
    itemButton:SetSize(495, 20)
    itemButton:SetPoint("LEFT", ownerButton, "RIGHT", 5, 0)
    itemButton:EnableMouse(true)
    itemButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local qualityColors = {
        [0] = { 0.5, 0.5, 0.5 },
        [1] = { 1, 1, 1 },
        [2] = { 0.1, 0.8, 0.1 },
        [3] = { 0, 0.4, 1 },
        [4] = { 0.6, 0.2, 0.8 },
        [5] = { 1, 0.5, 0 },
        [6] = { 1, 0.82, 0 },
        [7] = { 1, 0.82, 0 },
    }

    local quality = 1
    if itemID and itemID > 0 then
        local _, _, q = GetItemInfo(itemID)
        if type(q) == "number" then
            quality = q
        else
            NSAuk = NSAuk or {}
            NSAuk.items = NSAuk.items or {}
            local lot = NSAuk.items[itemName]
            if lot and type(lot.quality) == "number" then
                quality = lot.quality
            end
        end
    end

    local qc = qualityColors[quality] or qualityColors[1]
    local r, g, b = math.floor(qc[1] * 255), math.floor(qc[2] * 255), math.floor(qc[3] * 255)
    local coloredText = string.format("%s шт по |cffffd700%s|r (итого |cffffd700%s|r) - |cff%02x%02x%02x%s|r",
        quantity, pricePerItem, totalPriceStr, r, g, b, itemName)

    local itemText = itemButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemText:SetSize(495, 20)
    itemText:SetPoint("LEFT", itemButton, "LEFT", 0, 0)
    itemText:SetJustifyH("LEFT")
    itemText:SetText(coloredText)
    itemText:SetFont("Fonts\\FRIZQT__.TTF", 11)

    if itemID and itemID > 0 then
        local itemLink = GetItemLinkWithQuery(itemID, function(link)
            if link and itemButton:IsVisible() then
                itemButton:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(itemButton, "ANCHOR_TOPRIGHT")
                    GameTooltip:SetHyperlink(link)
                    GameTooltip:Show()
                end)
                itemButton:SetScript("OnLeave", GameTooltip_Hide)
                itemButton:SetScript("OnClick", function(self, buttonName)
                    if buttonName == "LeftButton" then
                        ChatEdit_InsertLink(link)
                    elseif buttonName == "RightButton" then
                        DressUpItemLink(link)
                    end
                end)
            end
        end)
        if itemLink then
            itemButton:SetScript("OnEnter", function()
                GameTooltip:SetOwner(itemButton, "ANCHOR_TOPRIGHT")
                GameTooltip:SetHyperlink(itemLink)
                GameTooltip:Show()
            end)
            itemButton:SetScript("OnLeave", GameTooltip_Hide)
            itemButton:SetScript("OnClick", function(self, buttonName)
                if buttonName == "LeftButton" then
                    ChatEdit_InsertLink(itemLink)
                elseif buttonName == "RightButton" then
                    DressUpItemLink(itemLink)
                end
            end)
        end
    end

    resultFrame:SetPoint("TOPLEFT", self.resultsList, "TOPLEFT", 0, -((index - 1) * 24))
    table.insert(self.results, {
        frame = resultFrame,
        ownerButton = ownerButton,
        ownerText = ownerText,
        itemButton = itemButton,
        itemText = itemText,
        seller = seller,
        buyer = buyer,
        itemName = itemName,
        quantity = quantity,
        pricePerItem = pricePerItem,
        itemID = itemID,
        isOffline = isOffline,
        sellerType = sellerType
    })

    self.resultsList:SetHeight(#self.results * 24)
    self:UpdateScrollbar()

    if #self.results >= 10 and self.lastSearchQuery and not self.pageButton:IsShown() then
        self.currentPage = self.currentPage + 1
        self.pageButton:SetText("  >  >  " .. self.currentPage)
        self.pageButton:Show()
    end
end

function NSAukClass:StartSearch()
    if self.findButtonCooldown then return end
    local query = self.searchBox:GetText():gsub("^%s*(.-)%s*$", "%1")

    if query == " " or #query < 6 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Минимальная длина поискового запроса — 6 символов.|r")
        return
    end

    local minLevelText = self.minLevelBox:GetText():gsub("^%s*(.-)%s*$", "%1")
    local maxLevelText = self.maxLevelBox:GetText():gsub("^%s*(.-)%s*$", "%1")
    local hasLevelFilter = (minLevelText ~= " " or maxLevelText ~= " ")
    local qualityValue = self.selectedQuality
    local hasQualityFilter = (qualityValue >= 0)

    local maxGold = tonumber(self.maxGoldBox:GetText()) or 0
    local maxSilver = tonumber(self.maxSilverBox:GetText()) or 0
    local maxCopper = tonumber(self.maxCopperBox:GetText()) or 0
    local maxPriceCopper = maxGold * 10000 + maxSilver * 100 + maxCopper
    local hasPriceFilter = (maxPriceCopper > 0)

    local searchQuery = query
    local filters = {}

    if hasLevelFilter or hasQualityFilter then
        local minLvl = (minLevelText ~= " ") and tonumber(minLevelText) or 1
        local maxLvl = (maxLevelText ~= " ") and tonumber(maxLevelText) or 100

        if hasLevelFilter and hasQualityFilter then
            table.insert(filters, string.format("[%d %d %d]", minLvl, maxLvl, qualityValue))
        elseif hasLevelFilter then
            table.insert(filters, string.format("[%d %d]", minLvl, maxLvl))
        elseif hasQualityFilter then
            table.insert(filters, string.format("[1 100 %d]", qualityValue))
        end
    end

    if hasPriceFilter then
        table.insert(filters, string.format("{0 %d}", maxPriceCopper))
    end

    if #filters > 0 then
        searchQuery = query .. "  " .. table.concat(filters, "  ")
    end

    self:ClearResults()
    if self.pageButton then self.pageButton:Hide() end
    self.lastSearchQuery = searchQuery
    self.currentPage = 1
    self.searchMode = "online"
    self.pendingSearchItem = query
    self.pendingSearchTimer = 5
    self.pendingSearchFrame:Show()

    self.findButtonCooldown = true
    self.findButtonTimer = 25
    self.findBtn:Disable()
    self.cooldownFrame:Show()
    self.findBtn:SetText("Найти (25)")
    self.searchBox:SetText(" ")

    for _, btnData in ipairs(self.categoryButtons) do
        if btnData.button and not btnData.button.isSection then
            btnData.button:Disable()
        end
    end

    EnsureAuctionChannel(function(chanID)
        if chanID then
            local cmd = self:GetCommandPrefix("КПО")
            SendChatMessage(cmd .. "  " .. searchQuery, "CHANNEL", nil, chanID)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Не удалось подключиться к каналу 'Аукцион'.|r")
        end
    end)
end

function NSAukClass:OnSell()
    NSAuk = NSAuk or {}
    if type(NSAuk) ~= "table" then NSAuk = {} end
    NSAuk.items = NSAuk.items or {}
    local itemLink = self.sellItemFrame.itemLink
    if not itemLink then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Нет предмета для продажи!|r")
        return
    end

    local quantity = tonumber(self.quantityBox:GetText()) or 1
    if quantity < 1 then quantity = 1 end

    local gold = tonumber(self.goldBox:GetText()) or 0
    local silver = tonumber(self.silverBox:GetText()) or 0
    local copper = tonumber(self.copperBox:GetText()) or 0
    if silver > 99 then silver = 99 end
    if copper > 99 then copper = 99 end

    local itemName = self.sellItemFrame.itemName
    if not itemName or itemName == " " then
        itemName = itemLink:match("%[(.-)%]")
    end

    if not itemName or itemName == " " then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Не удалось извлечь название предмета!|r")
        return
    end

    local _, _, quality, itemLevel, _, itemType, itemSubType, _, _, _, _, _, itemID = GetItemInfo(itemLink)
    itemID = itemID or tonumber(self.sellItemFrame.itemID) or 0
    itemType = itemType or self.sellItemFrame.itemType or "Неизвестно"
    itemSubType = itemSubType or self.sellItemFrame.itemSubType or "Неизвестно"
    quality = quality or tonumber(self.sellItemFrame.quality) or 0
    itemLevel = itemLevel or 0

    local priceStr = " "
    if gold > 0 then priceStr = priceStr .. gold .. "з" end
    if silver > 0 then priceStr = priceStr .. silver .. "с" end
    if copper > 0 then priceStr = priceStr .. copper .. "м" end
    if priceStr == " " then priceStr = "0м" end

    NSAuk.items[itemName] = {
        quantity = quantity,
        gold = gold,
        silver = silver,
        copper = copper,
        priceStr = priceStr,
        itemID = itemID,
        itemType = itemType,
        itemSubType = itemSubType,
        quality = quality,
        itemLevel = itemLevel,
        timestamp = GetTime(),
        sellerType = self.playerType
    }

    EnsureAuctionChannel(function(chanID)
        if chanID then
            local sellPrefix = self:GetCommandPrefix("ПР")
            local message = string.format("%s %d %s (%s) (%s) %d %d %d %s",
                sellPrefix, quantity, priceStr, itemType, itemSubType, quality, itemLevel, itemID, itemName)
            SendChatMessage(message, "CHANNEL", nil, chanID)

            self.sellItemFrame.texture:SetTexture(" ")
            self.sellItemFrame.itemInfo:SetText(" ")
            self.sellItemFrame.itemLink = nil
            self.sellItemFrame.itemID = nil
            self.sellItemFrame.itemType = nil
            self.sellItemFrame.itemSubType = nil
            self.sellItemFrame.quality = nil
            self.sellItemFrame.itemName = nil
            self.quantityBox:SetText("1")
            self.goldBox:SetText("0")
            self.silverBox:SetText("0")
            self.copperBox:SetText("0")

            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00NSAuk: Лот выставлен: %s x%d за %s (уровень %d) [%s]|r",
                itemName, quantity, priceStr, itemLevel, self.playerType))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Не удалось подключиться к каналу 'Аукцион'.|r")
        end
    end)
end

function NSAukClass:OnDelete()
    NSAuk = NSAuk or {}
    if type(NSAuk) ~= "table" then NSAuk = {} end
    NSAuk.items = NSAuk.items or {}
    local itemLink = self.sellItemFrame.itemLink
    if not itemLink then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Нет предмета для удаления!|r")
        return
    end

    local itemName = self.sellItemFrame.itemName
    if not itemName then
        itemName = itemLink:match("%[(.-)%]")
    end

    if not itemName or itemName == " " then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Не удалось извлечь название предмета!|r")
        return
    end

    NSAuk.items[itemName] = nil

    EnsureAuctionChannel(function(chanID)
        if chanID then
            local deletePrefix = self:GetCommandPrefix("ДЛ")
            SendChatMessage(deletePrefix .. "  " .. itemName, "CHANNEL", nil, chanID)
            self.sellItemFrame.texture:SetTexture(" ")
            self.sellItemFrame.itemInfo:SetText(" ")
            self.sellItemFrame.itemLink = nil
            self.sellItemFrame.itemName = nil
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00NSAuk: Лот удалён:  " .. itemName .. "|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Не удалось подключиться к каналу 'Аукцион'.|r")
        end
    end)
end

function NSAukClass:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:UpdateCategories()
        if self.currentTab == "buy" then
            self.searchBox:SetFocus()
        end
    end
end

function NSAukClass:UpdateCategories()
    for _, btn in pairs(self.categoryButtons) do
        if btn.frame then btn.frame:Hide() end
    end
    wipe(self.categoryButtons)
    local yPos = 0
    local index = 1

    for sectionName, subsections in pairs(NSAukRazdely) do
        local isExpanded = self.expandedCategories[sectionName] == true
        local sectionFrame = CreateFrame("Frame", nil, self.categoriesList)
        sectionFrame:SetSize(130, 18)
        sectionFrame:SetPoint("TOPLEFT", self.categoriesList, "TOPLEFT", 0, -yPos)
        local sectionButton = CreateFrame("Button", nil, sectionFrame)
        sectionButton:SetAllPoints(sectionFrame)
        sectionButton.owner = self
        sectionButton.sectionName = sectionName
        sectionButton.subsections = subsections
        sectionButton.index = index
        sectionButton.isSection = true

        local sectionText = sectionButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sectionText:SetPoint("LEFT", sectionFrame, "LEFT", 10, -5)
        sectionText:SetText(sectionName)
        sectionText:SetFont("Fonts\\FRIZQT__.TTF", 10)
        sectionText:SetTextColor(1, 1, 0)

        local arrowText = sectionButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        arrowText:SetPoint("RIGHT", sectionFrame, "RIGHT", -8, 0)
        arrowText:SetText(isExpanded and " " or " ")
        arrowText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        arrowText:SetTextColor(0.7, 0.7, 0.7)
        sectionButton.arrowText = arrowText

        sectionButton:SetScript("OnEnter", function(self)
            sectionText:SetTextColor(1, 1, 1)
            arrowText:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Кликните для раскрытия", 1, 1, 1)
            GameTooltip:Show()
        end)
        sectionButton:SetScript("OnLeave", function(self)
            sectionText:SetTextColor(1, 1, 0)
            arrowText:SetTextColor(0.7, 0.7, 0.7)
            GameTooltip:Hide()
        end)
        sectionButton:SetScript("OnClick", function(self)
            local owner = self.owner
            if type(self.subsections) == "table" and next(self.subsections) then
                owner.expandedCategories[self.sectionName] = not owner.expandedCategories[self.sectionName]
                owner:UpdateCategories()
            else
                owner:SearchByCategory(self.sectionName)
            end
        end)

        table.insert(self.categoryButtons, { frame = sectionFrame, button = sectionButton })
        yPos = yPos + 18
        index = index + 1

        if isExpanded and type(subsections) == "table" then
            for subName, _ in pairs(subsections) do
                local subFrame = CreateFrame("Frame", nil, self.categoriesList)
                subFrame:SetSize(130, 16)
                subFrame:SetPoint("TOPLEFT", self.categoriesList, "TOPLEFT", 10, -yPos)
                local subButton = CreateFrame("Button", nil, subFrame)
                subButton:SetAllPoints(subFrame)
                subButton.owner = self
                subButton.subName = subName
                subButton.sectionName = sectionName
                subButton.isSection = false

                local subText = subButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                subText:SetPoint("LEFT", subFrame, "LEFT", 10, -5)
                subText:SetText(subName)
                subText:SetFont("Fonts\\FRIZQT__.TTF", 9)
                subText:SetTextColor(0.7, 0.7, 1)

                subButton:SetScript("OnEnter", function(self)
                    subText:SetTextColor(1, 1, 1)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Поиск по подразделу", 0.7, 0.7, 1)
                    GameTooltip:Show()
                end)
                subButton:SetScript("OnLeave", function(self)
                    subText:SetTextColor(0.7, 0.7, 1)
                    GameTooltip:Hide()
                end)
                subButton:SetScript("OnClick", function(self)
                    local owner = self.owner
                    owner:SearchByCategory(self.subName)
                end)

                table.insert(self.categoryButtons, { frame = subFrame, button = subButton })
                yPos = yPos + 16
                index = index + 1
            end
        end
    end

    self.categoriesList:SetHeight(yPos)
    local visibleHeight = 340
    local scrollRange = math.max(0, yPos - visibleHeight)

    if scrollRange > 0 then
        self.categoriesScrollbar:Show()
        self.categoriesScrollbar:SetMinMaxValues(0, scrollRange)
        local currentScroll = self.categoriesPanel:GetVerticalScroll()
        if currentScroll > scrollRange then
            self.categoriesPanel:SetVerticalScroll(scrollRange)
            self.categoriesScrollbar:SetValue(scrollRange)
        end
    else
        self.categoriesScrollbar:Hide()
        self.categoriesPanel:SetVerticalScroll(0)
    end
end

function NSAukClass:SearchByCategory(categoryName)
    if not categoryName or categoryName == "" or self.findButtonCooldown then return end
    self:ClearResults()
    self.lastSearchQuery = nil
    self.currentPage = 1
    self.searchMode = "online"
    self.pendingSearchItem = nil
    if self.pageButton then self.pageButton:Hide() end
    if self.offlineButton then self.offlineButton:Hide() end

    local minLevelText = self.minLevelBox:GetText():gsub("^%s*(.-)%s*$", "%1")
    local maxLevelText = self.maxLevelBox:GetText():gsub("^%s*(.-)%s*$", "%1")
    local hasLevelFilter = (minLevelText ~= " " or maxLevelText ~= " ")
    local qualityValue = self.selectedQuality
    local hasQualityFilter = (qualityValue >= 0)

    local maxGold = tonumber(self.maxGoldBox:GetText()) or 0
    local maxSilver = tonumber(self.maxSilverBox:GetText()) or 0
    local maxCopper = tonumber(self.maxCopperBox:GetText()) or 0
    local maxPriceCopper = maxGold * 10000 + maxSilver * 100 + maxCopper
    local hasPriceFilter = (maxPriceCopper > 0)

    local searchQuery = categoryName
    local filters = {}

    if hasLevelFilter or hasQualityFilter then
        local minLvl = (minLevelText ~= " ") and tonumber(minLevelText) or 1
        local maxLvl = (maxLevelText ~= " ") and tonumber(maxLevelText) or 100

        if hasLevelFilter and hasQualityFilter then
            table.insert(filters, string.format("[%d %d %d]", minLvl, maxLvl, qualityValue))
        elseif hasLevelFilter then
            table.insert(filters, string.format("[%d %d]", minLvl, maxLvl))
        elseif hasQualityFilter then
            table.insert(filters, string.format("[1 100 %d]", qualityValue))
        end
    end

    if hasPriceFilter then
        table.insert(filters, string.format("{0 %d}", maxPriceCopper))
    end

    if #filters > 0 then
        searchQuery = categoryName .. "  " .. table.concat(filters, "  ")
    end

    self.lastSearchQuery = searchQuery
    self.currentPage = 1
    self.searchMode = "online"
    self.pendingSearchItem = categoryName
    self.pendingSearchTimer = 5
    self.pendingSearchFrame:Show()

    self.findButtonCooldown = true
    self.findButtonTimer = 25
    self.findBtn:Disable()
    self.cooldownFrame:Show()
    self.findBtn:SetText("Найти (25)")

    for _, btnData in ipairs(self.categoryButtons) do
        if btnData.button and not btnData.button.isSection then
            btnData.button:Disable()
        end
    end

    EnsureAuctionChannel(function(chanID)
        if chanID then
            local cmd = self:GetCommandPrefix("КПО")
            SendChatMessage(cmd .. "  " .. searchQuery, "CHANNEL", nil, chanID)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000NSAuk: Не удалось подключиться к каналу 'Аукцион'.|r")
        end
    end)
end

function NSAukClass:RegisterChatHandler()
    local chatFrame = CreateFrame("Frame")
    chatFrame:RegisterEvent("CHAT_MSG_CHANNEL")
    chatFrame:SetScript("OnEvent", function(_, event, message, author, _, channelFullName, _, _, _, channelNumber, channelBaseName)
        if not ((channelFullName and type(channelFullName) == "string" and channelFullName:lower():find("аукцион")) or
            (channelBaseName and type(channelBaseName) == "string" and channelBaseName:lower():find("аукцион"))) then
            return
        end
        local playerName = UnitName("player")
        if not playerName then return end

        NSAuk = NSAuk or {}
        if type(NSAuk) ~= "table" then NSAuk = {} end
        NSAuk.items = NSAuk.items or {}

        local function normalize(name)
            if not name then return " " end
            local base = name:match("^([^%-]+)") or name
            return base:lower()
        end

        local playerBase = normalize(playerName)

        -- === ОБРАБОТКА ОТВЕТОВ Т?/Т?-/Т?~ (офлайн) ===
        local responseType, responsePrefix, seller, buyer, quantity, price, itemID, itemName = message:match("^%s*(Т%?)([-~]?)%s+(%S+)%s+(%S+)%s+(%d+)%s+(%S+)%s+(%d+)%s+(.+)$")
        if responseType and seller and buyer and quantity and price and itemID and itemName then
            local sellerBase = normalize(seller)
            local buyerBase = normalize(buyer)
            local numericItemID = tonumber(itemID)

            -- Определяем тип продавца по префиксу ответа
            local sellerType = "Обычный"
            if responsePrefix == "-" then
                sellerType = "HK"
            elseif responsePrefix == "~" then
                sellerType = "HK+"
            end

            if playerBase == buyerBase then
                self:AddResult(seller, buyer, quantity, price, itemName, true, numericItemID, sellerType)
            end

            if playerBase == sellerBase then
                EnsureAuctionChannel(function(chanID)
                    if chanID then
                        local confirmPrefix = self:GetCommandPrefix("Т!")
                        SendChatMessage(string.format("%s %s %s %s %s %d %s",
                            confirmPrefix, seller, buyer, quantity, price, numericItemID, itemName),
                            "CHANNEL", nil, chanID)
                    end
                end)
            end
            return
        end

        -- === ОБРАБОТКА ОТВЕТОВ Т!/Т!-/Т!~ (онлайн) ===
        local responseType2, responsePrefix2, seller2, buyer2, quantity2, pricePerItem, itemID2, itemName2 = message:match("^%s*(Т!)([-~]?)%s+(%S+)%s+(%S+)%s+(%d+)%s+(%S+)%s+(%d+)%s+(.+)$")
        if responseType2 and seller2 and buyer2 and quantity2 and pricePerItem and itemID2 and itemName2 then
            local buyerBase2 = normalize(buyer2)
            local numericItemID2 = tonumber(itemID2)

            -- Определяем тип продавца по префиксу ответа
            local sellerType2 = "Обычный"
            if responsePrefix2 == "-" then
                sellerType2 = "HK"
            elseif responsePrefix2 == "~" then
                sellerType2 = "HK+"
            end

            if playerBase == buyerBase2 then
                self:AddResult(seller2, buyer2, quantity2, pricePerItem, itemName2, false, numericItemID2, sellerType2)
            end
            return
        end

        -- === ОБРАБОТКА КОМАНД ПР/ПР-/ПР~ (продажа) ===
        local function ParseSellCommand(commandStr)
            local prefix, rest = commandStr:match("^%s*(ПР)([-~]?)%s+(.+)$")
            if not prefix then return nil end

            local fullPrefix = prefix .. (rest and rest:match("^[-~]") or "")
            local words = mysplit(rest)
            if #words < 7 then return nil end

            local quantity = tonumber(words[1])
            local priceStr = words[2]
            local itemType = words[3]:match("%((.-)%)")
            local itemSubType = words[4]:match("%((.-)%)")
            local quality = tonumber(words[5])
            local itemLevel = tonumber(words[6])
            local itemID = tonumber(words[7])
            local itemName = table.concat(words, "  ", 8)

            local sellerType = "Обычный"
            if fullPrefix == "ПР-" then
                sellerType = "HK"
            elseif fullPrefix == "ПР~" then
                sellerType = "HK+"
            end

            return {
                prefix = fullPrefix,
                quantity = quantity,
                priceStr = priceStr,
                itemType = itemType,
                itemSubType = itemSubType,
                quality = quality,
                itemLevel = itemLevel,
                itemID = itemID,
                itemName = itemName,
                sellerType = sellerType
            }
        end

        local prMatch = message:match("^%s*(ПР)([-~]?)%s+(.+)$")
        if prMatch then
            local data = ParseSellCommand(message)
            if data then
                NSAuk.items[data.itemName] = {
                    quantity = data.quantity,
                    gold = ParsePrice(data.priceStr),
                    silver = select(2, ParsePrice(data.priceStr)),
                    copper = select(3, ParsePrice(data.priceStr)),
                    priceStr = data.priceStr,
                    itemID = data.itemID,
                    itemType = data.itemType,
                    itemSubType = data.itemSubType,
                    quality = data.quality,
                    itemLevel = data.itemLevel,
                    timestamp = GetTime(),
                    sellerType = data.sellerType
                }
            end
            return
        end

        -- === ОБРАБОТКА КОМАНД ДЛ/ДЛ-/ДЛ~ (удаление) ===
        local dlPrefix, dlSuffix, dlItemName = message:match("^%s*(ДЛ)([-~]?)%s+(.+)$")
        if dlPrefix and dlItemName then
            NSAuk.items[dlItemName] = nil
            return
        end

        -- === ОБРАБОТКА КОМАНД КПО/КПО-/КПО~/КПОН/КПОН-/КПОН~/КП/КП-/КП~ (запросы поиска) ===
        local function FindMatchingItems(searchQuery, minLevel, maxLevel, quality, minPrice, maxPrice, requesterType)
            local matchingItems = {}
            for itemName, lot in pairs(NSAuk.items) do
                -- === ФИЛЬТР ПО ТИПУ ИГРОКА ===
                if requesterType and lot.sellerType and lot.sellerType ~= requesterType then
                    -- Игрок видит только лоты своего типа
                else
                    local matches = false
                    if itemName:lower():find(searchQuery, 1, true) or
                        (lot.itemSubType and lot.itemSubType:lower():find(searchQuery, 1, true)) or
                        (lot.itemType and lot.itemType:lower():find(searchQuery, 1, true)) then
                        matches = true
                    end

                    if matches then
                        local itemLevel = lot.itemLevel or 0
                        if (minLevel and itemLevel < minLevel) or (maxLevel and itemLevel > maxLevel) then
                            matches = false
                        end
                        if matches and quality ~= -1 and (lot.quality or 0) ~= quality then
                            matches = false
                        end
                        if matches and (minPrice or maxPrice) then
                            local itemPriceCopper = (lot.gold or 0) * 10000 + (lot.silver or 0) * 100 + (lot.copper or 0)
                            if (minPrice and itemPriceCopper < minPrice) or (maxPrice and itemPriceCopper > maxPrice) then
                                matches = false
                            end
                        end
                    end

                    if matches then
                        table.insert(matchingItems, {
                            name = itemName,
                            lot = lot,
                            timestamp = lot.timestamp or 0
                        })
                    end
                end
            end

            table.sort(matchingItems, function(a, b)
                return a.timestamp > b.timestamp
            end)
            return matchingItems
        end

        local function ParseCommandWithFilters(commandStr)
            local words = mysplit(commandStr)
            local searchWords = {}
            local filterStartIndex = nil

            for i = 1, #words do
                if words[i]:match("[%[%{]") then
                    filterStartIndex = i
                    break
                else
                    table.insert(searchWords, words[i])
                end
            end

            local searchQuery = table.concat(searchWords, "  "):lower()
            local minLevel, maxLevel, quality = nil, nil, -1
            local minPrice, maxPrice = nil, nil

            if filterStartIndex then
                local filterStr = table.concat(words, "  ", filterStartIndex)
                local squareFilter = filterStr:match("%[(.-)%]")
                if squareFilter then
                    local parts = mysplit(squareFilter)
                    minLevel = tonumber(parts[1])
                    maxLevel = tonumber(parts[2])
                    if #parts >= 3 then quality = tonumber(parts[3]) end
                end
                local curlyFilter = filterStr:match("%{(.-)%}")
                if curlyFilter then
                    local parts = mysplit(curlyFilter)
                    minPrice = tonumber(parts[1])
                    maxPrice = tonumber(parts[2])
                end
            end

            return searchQuery, minLevel, maxLevel, quality, minPrice, maxPrice
        end

        -- Определяем тип игрока, сделавшего запрос (ИСПРАВЛЕНО)
        local function GetRequesterType(msg, baseCmd)
            local prefix, suffix = msg:match("^%s*(" .. baseCmd .. ")([-~]?)")
            if suffix == "-" then
                return "HK"
            elseif suffix == "~" then
                return "HK+"
            end
            return "Обычный"
        end

        -- === КПО / КПО- / КПО~ ===
        local kpoCmd, kpoSuffix, kpoRest = message:match("^%s*(КПО)([-~]?)%s+(.+)$")
        if kpoCmd and kpoRest then
            local requesterType = GetRequesterType(message, "КПО")
            local searchQuery, minLevel, maxLevel, quality, minPrice, maxPrice = ParseCommandWithFilters(kpoRest)
            local matchingItems = FindMatchingItems(searchQuery, minLevel, maxLevel, quality, minPrice, maxPrice, requesterType)
            for i = 1, math.min(10, #matchingItems) do
                local item = matchingItems[i]
                local delayFrame = CreateFrame("Frame")
                delayFrame.delay = 2 * i
                delayFrame.item = item
                delayFrame.playerName = playerName
                delayFrame.author = author
                delayFrame.elapsed = 0
                delayFrame:SetScript("OnUpdate", function(self, elapsed)
                    self.elapsed = self.elapsed + elapsed
                    if self.elapsed >= self.delay then
                        self:SetScript("OnUpdate", nil)
                        EnsureAuctionChannel(function(chanID)
                            if chanID then
                                local responsePrefix = self.owner:GetCommandPrefix("Т?")
                                SendChatMessage(string.format("%s %s %s %d %s %d %s",
                                    responsePrefix, self.playerName, self.author, self.item.lot.quantity, self.item.lot.priceStr,
                                    self.item.lot.itemID, self.item.name),
                                    "CHANNEL", nil, chanID)
                            end
                        end)
                    end
                end)
                delayFrame.owner = self
            end
            return
        end

        -- === КПОН / КПОН- / КПОН~ ===
        local kponCmd, kponSuffix, kponRest = message:match("^%s*(КПОН)([-~]?)%s+(.+)$")
        if kponCmd and kponRest then
            local requesterType = GetRequesterType(message, "КПОН")
            local words = mysplit(kponRest)
            if #words < 1 then return end
            local pageNum = tonumber(words[1]) or 1
            local searchRest = table.concat(words, "  ", 2)
            local searchQuery, minLevel, maxLevel, quality, minPrice, maxPrice = ParseCommandWithFilters(searchRest)
            local matchingItems = FindMatchingItems(searchQuery, minLevel, maxLevel, quality, minPrice, maxPrice, requesterType)
            local itemsPerPage = 10
            local startIndex = (pageNum - 1) * itemsPerPage + 1
            local endIndex = math.min(pageNum * itemsPerPage, #matchingItems)
            local delayCounter = 0
            for i = startIndex, endIndex do
                local item = matchingItems[i]
                if item then
                    local delayFrame = CreateFrame("Frame")
                    delayFrame.delay = 2 * delayCounter
                    delayFrame.item = item
                    delayFrame.playerName = playerName
                    delayFrame.author = author
                    delayFrame.elapsed = 0
                    delayFrame:SetScript("OnUpdate", function(self, elapsed)
                        self.elapsed = self.elapsed + elapsed
                        if self.elapsed >= self.delay then
                            self:SetScript("OnUpdate", nil)
                            EnsureAuctionChannel(function(chanID)
                                if chanID then
                                    local responsePrefix = self.owner:GetCommandPrefix("Т?")
                                    SendChatMessage(string.format("%s %s %s %d %s %d %s",
                                        responsePrefix, self.playerName, self.author, self.item.lot.quantity, self.item.lot.priceStr,
                                        self.item.lot.itemID, self.item.name),
                                        "CHANNEL", nil, chanID)
                                end
                            end)
                        end
                    end)
                    delayFrame.owner = self
                    delayCounter = delayCounter + 1
                end
            end
            return
        end

        -- === КП / КП- / КП~ ===
        local kpCmd, kpSuffix, kpRest = message:match("^%s*(КП)([-~]?)%s+(.+)$")
        if kpCmd and kpRest then
            local requesterType = GetRequesterType(message, "КП")
            local searchQuery, minLevel, maxLevel, quality, minPrice, maxPrice = ParseCommandWithFilters(kpRest)
            local matchingItems = FindMatchingItems(searchQuery, minLevel, maxLevel, quality, minPrice, maxPrice, requesterType)
            for i = 1, math.min(10, #matchingItems) do
                local item = matchingItems[i]
                local delayFrame = CreateFrame("Frame")
                delayFrame.delay = 2 * i
                delayFrame.item = item
                delayFrame.playerName = playerName
                delayFrame.author = author
                delayFrame.elapsed = 0
                delayFrame:SetScript("OnUpdate", function(self, elapsed)
                    self.elapsed = self.elapsed + elapsed
                    if self.elapsed >= self.delay then
                        self:SetScript("OnUpdate", nil)
                        EnsureAuctionChannel(function(chanID)
                            if chanID then
                                local responsePrefix = self.owner:GetCommandPrefix("Т?")
                                SendChatMessage(string.format("%s %s %s %d %s %d %s",
                                    responsePrefix, self.playerName, self.author, self.item.lot.quantity, self.item.lot.priceStr,
                                    self.item.lot.itemID, self.item.name),
                                    "CHANNEL", nil, chanID)
                            end
                        end)
                    end
                end)
                delayFrame.owner = self
            end
            return
        end
    end)
end

local addon = NSAukClass.new()
SLASH_NSAUK1 = "/nsauk"
SlashCmdList["NSAUK"] = function()
    addon:Toggle()
end

-- === АВТОМАТИЧЕСКОЕ ПОДКЛЮЧЕНИЕ К КАНАЛУ "Аукцион" ПРИ ЗАГРУЗКЕ ===
local NSAukAutoJoin = CreateFrame("Frame")
NSAukAutoJoin.timer = 0
NSAukAutoJoin.joined = false
NSAukAutoJoin:SetScript("OnUpdate", function(self, elapsed)
    if self.joined then return end
    self.timer = self.timer + elapsed
    if self.timer < 3 then return end
    self.joined = true
    self:SetScript("OnUpdate", nil)
    local alreadyInChannel = false
    for i = 1, 32 do
        local name = GetChannelName(i)
        if type(name) == "string" and name:lower():find("аукцион") then
            alreadyInChannel = true
            break
        end
    end

    if not alreadyInChannel then
        JoinChannelByName("Аукцион")
    end
end)