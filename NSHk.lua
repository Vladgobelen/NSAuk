-- NSHardcoreDeath.lua
-- Автономный аддон для отображения окна смерти в хардкор-режиме (WoW 3.3.5)
-- Версия 2.0.6 (исправлен таймер отображения)
nsHD = nsHD or {}

-- Значения по умолчанию
local defaultSettings = {
    classTextureSize = 40,
    classTextureOffsetX = 3,
    classTextureOffsetY = -18,
    showTime = 6,
    fadeTime = 3,
    closeOnHover = true,
    hoverDelay = 0.5
}

local deathFrame = nil
local fadeFrame = nil

-- Загрузка настроек
local function getCurrentSettings()
    local result = {}
    if nsHD.death and type(nsHD.death) == "table" then
        result.classTextureSize = nsHD.death.classTextureSize or defaultSettings.classTextureSize
        result.classTextureOffsetX = nsHD.death.classTextureOffsetX or defaultSettings.classTextureOffsetX
        result.classTextureOffsetY = nsHD.death.classTextureOffsetY or defaultSettings.classTextureOffsetY
        result.showTime = nsHD.death.showTime or defaultSettings.showTime
        result.fadeTime = nsHD.death.fadeTime or defaultSettings.fadeTime
        result.hoverDelay = nsHD.death.hoverDelay or defaultSettings.hoverDelay
        
        if nsHD.death.closeOnHover ~= nil then
            result.closeOnHover = nsHD.death.closeOnHover
        else
            result.closeOnHover = defaultSettings.closeOnHover
        end
    else
        for k, v in pairs(defaultSettings) do
            result[k] = v
        end
    end
    return result
end

-- Сохранение настроек
local function saveSettings(settings)
    nsHD.death = nsHD.death or {}
    nsHD.death.classTextureSize = settings.classTextureSize
    nsHD.death.classTextureOffsetX = settings.classTextureOffsetX
    nsHD.death.classTextureOffsetY = settings.classTextureOffsetY
    nsHD.death.showTime = settings.showTime
    nsHD.death.fadeTime = settings.fadeTime
    nsHD.death.closeOnHover = settings.closeOnHover
    nsHD.death.hoverDelay = settings.hoverDelay
end

-- Безопасное удаление скрипта
local function safeRemoveScript(frame, scriptName)
    if frame and frame:GetScript(scriptName) then
        frame:SetScript(scriptName, nil)
        return true
    end
    return false
end

-- Применение настроек к фрейму
local function applySettingsToFrame(settings)
    if not deathFrame then return end
    deathFrame.classTex:SetSize(settings.classTextureSize, settings.classTextureSize)
    deathFrame.classTex:SetPoint("TOP", deathFrame, "TOP", settings.classTextureOffsetX, settings.classTextureOffsetY)

    if settings.closeOnHover then
        deathFrame:EnableMouse(true)
        safeRemoveScript(deathFrame, "OnEnter")
        
        local hoverDelayFrame = CreateFrame("Frame")
        hoverDelayFrame.delay = settings.hoverDelay
        hoverDelayFrame:SetScript("OnUpdate", function(self, elapsed)
            self.delay = self.delay - elapsed
            if self.delay <= 0 then
                self:Hide()
                deathFrame:SetScript("OnEnter", function(self)
                    if fadeFrame then
                        fadeFrame:Hide()
                        fadeFrame.startTime = nil
                    end
                    self:Hide()
                end)
            end
        end)
        hoverDelayFrame:Show()
    else
        deathFrame:EnableMouse(false)
        safeRemoveScript(deathFrame, "OnEnter")
    end
end

-- Парсер строки
local function mysplit(inputstr, sep)
    if type(inputstr) ~= "string" then return {} end
    if sep == nil then sep = "%s" end
    local processedStr = inputstr:gsub("([%a])'([%a])", "%1###%2")

    local t = {}
    for str in string.gmatch(processedStr, "([^" .. sep .. "]+)") do
        if type(str) == "string" then
            local restored = str:gsub("###", "'")
            t[#t + 1] = restored
        end
    end
    return t
end

-- Цвета рас и классов
local raceColors = {
    ["человек"] = "ff5a5a5a", ["люди"] = "ff5a5a5a",
    ["орк"] = "ff336633", ["орки"] = "ff336633",
    ["дворф"] = "ff7f7f00", ["дворфы"] = "ff7f7f00",
    ["ночной эльф"] = "ff007f7f", ["ночные эльфы"] = "ff007f7f",
    ["нежить"] = "ff7f007f",
    ["таурен"] = "ff7f3f00", ["таурены"] = "ff7f3f00",
    ["гном"] = "ff007f7f", ["гномы"] = "ff007f7f",
    ["тролль"] = "ff7f0000", ["тролли"] = "ff7f0000",
    ["дреней"] = "ff3f3fff", ["дренеи"] = "ff3f3fff",
    ["эльф крови"] = "ffcc0000", ["эльфы крови"] = "ffcc0000",
}

local classColors = {
    ["воин"] = "ffff0000", ["воины"] = "ffff0000",
    ["паладин"] = "ff4cff4c", ["паладины"] = "ff4cff4c",
    ["охотник"] = "ffaad372", ["охотники"] = "ffaad372",
    ["разбойник"] = "fffff468", ["разбойники"] = "fffff468",
    ["жрец"] = "ffffffff", ["жрецы"] = "ffffffff",
    ["шаман"] = "ff0070dd", ["шаманы"] = "ff0070dd",
    ["маг"] = "ff3fc7eb", ["маги"] = "ff3fc7eb",
    ["чернокнижник"] = "ff8788ee", ["чернокнижники"] = "ff8788ee",
    ["друид"] = "ffff7c0a", ["друиды"] = "ffff7c0a",
    ["рыцарь смерти"] = "ffc41f3b",
}

local classTextures = {
    ["жрец"] = "Interface\\AddOns\\NSAuk\\libs\\priest",
    ["друид"] = "Interface\\AddOns\\NSAuk\\libs\\dru", 
    ["охотник"] = "Interface\\AddOns\\NSAuk\\libs\\hunt",
    ["разбойник"] = "Interface\\AddOns\\NSAuk\\libs\\rog",
    ["маг"] = "Interface\\AddOns\\NSAuk\\libs\\mage",
    ["паладин"] = "Interface\\AddOns\\NSAuk\\libs\\pal",
    ["шаман"] = "Interface\\AddOns\\NSAuk\\libs\\sham",
    ["воин"] = "Interface\\AddOns\\NSAuk\\libs\\war",
    ["чернокнижник"] = "Interface\\AddOns\\NSAuk\\libs\\lok",
    ["рыцарь смерти"] = "Interface\\AddOns\\NSAuk\\libs\\war",
}

-- Парсинг сообщения для извлечения данных
local function ParseDeathMessage(msgWithoutName, words, deathIndex)
    local raceClassPart = {}
    for i = 1, deathIndex - 1 do
        local w = words[i]
        if type(w) == "string" then raceClassPart[#raceClassPart + 1] = w:gsub(", ", " ") end
    end

    local race = " "
    local class = " "
    local fullRaceClass = table.concat(raceClassPart, " ")

    local twoWordRaces = {
         "эльф крови", "ночной эльф", "эльфы крови", "ночные эльфы"
    }

    local foundTwoWordRace = false
    for _, twoWordRace in ipairs(twoWordRaces) do
        if fullRaceClass:lower():find(twoWordRace:lower()) then
            local raceStart, raceEnd = fullRaceClass:lower():find(twoWordRace:lower())
            if raceStart then
                race = fullRaceClass:sub(raceStart, raceEnd)
                local dashPos = fullRaceClass:find("-", raceEnd + 1)
                if dashPos then
                    class = fullRaceClass:sub(dashPos + 1):gsub("^%s+", ""):gsub("%s+$", "")
                    foundTwoWordRace = true
                    break
                end
            end
        end
    end

    if not foundTwoWordRace then
        local foundDash = false
        for i, part in ipairs(raceClassPart) do
            if type(part) == "string" and part:find("-") then
                local parts = mysplit(part, "-")
                if #parts == 2 and type(parts[1]) == "string" and type(parts[2]) == "string" then
                    race = parts[1]
                    class = parts[2]
                    foundDash = true
                    break
                end
            end
        end
        
        if not foundDash and #raceClassPart >= 2 then
            class = raceClassPart[#raceClassPart]
            local raceParts = {}
            for i = 1, #raceClassPart - 1 do raceParts[#raceParts + 1] = raceClassPart[i] end
            race = table.concat(raceParts, " ")
        elseif not foundDash and #raceClassPart == 1 then
            class = raceClassPart[1]
        end
    end

    race = (race or " "):gsub("[,%.]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    class = (class or " "):gsub("[,%.]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    
    local level = "0"
    for i = deathIndex + 1, #words do
        if words[i] == "на" and i + 2 <= #words and words[i + 1]:match("^%d+$") and words[i + 2] == "уровне" then
            level = words[i + 1]
            break
        end
    end

    local location = "неизвестная локация"
    for i = 1, #words do
        if words[i] == "в" and i + 1 <= #words and words[i + 1] == "локации" and i + 2 <= #words then
            local locWords = {}
            for k = i + 2, #words do
                local w = words[k]
                if type(w) ~= "string" then break end
                if w == "-" or w == "," or w == "." or w == "его" or w == "её" or 
                   w == "победил" or w == "победила" or w == "убил" or w == "убила" or
                   w == "гравитация" then break end
                table.insert(locWords, w)
            end
            if #locWords > 0 then
                location = table.concat(locWords, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                break
            end
        end
    end

    if location == "неизвестная локация" then
        for i = 1, #words do
            if words[i] == "в" and i + 1 <= #words then
                local nextWord = words[i + 1]
                if type(nextWord) == "string" and not nextWord:match("^[%.%,]-$") then
                    local locWords = {}
                    for j = i + 1, #words do
                        local w = words[j]
                        if type(w) ~= "string" then break end
                        if w == "-" or w == "," or w == "." or w == "его" or w == "её" or 
                           w == "победил" or w == "победила" or w == "убил" or w == "убила" or
                           w == "гравитация" then break end
                        table.insert(locWords, w)
                    end
                    if #locWords > 0 then
                        location = table.concat(locWords, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                        break
                    end
                end
            end
        end
    end

    local killer = "неизвестной причины"
    if msgWithoutName:find("гравитация оказалась сильнее") then
        killer = "гравитации"
    else
        local killerPhrases = {
            { "его", "победил" }, { "её", "победил" }, { "его", "победила" }, { "её", "победила" },
            { "его", "убил" }, { "её", "убила" }, { "его", "разорвал" }, { "её", "разорвала" },
            { "его", "сокрушил" }, { "её", "сокрушила" }, { "его", "раздавил" }, { "её", "раздавила" },
            { "его", "погубил" }, { "её", "погубила" },
            { "победил" }, { "победила" }, { "убил" }, { "убила" }, { "разорвал" }, { "разорвала" },
            { "сокрушил" }, { "сокрушила" }, { "раздавил" }, { "раздавила" }, { "погубил" }, { "погубила" }
        }
        
        local dashIndex = nil
        for i, w in ipairs(words) do
            if w == "-" then dashIndex = i break end
        end
        
        if dashIndex then
            local killerStart = nil
            for i = dashIndex + 1, #words do
                for _, phrase in ipairs(killerPhrases) do
                    if #phrase == 1 then
                        if words[i] == phrase[1] then killerStart = i + 1 break end
                    elseif #phrase == 2 then
                         if i + 1 <= #words and words[i] == phrase[1] and words[i + 1] == phrase[2] then
                            killerStart = i + 2 break
                        end
                    end
                end 
                if killerStart then break end
            end
            
            if killerStart then
                local killerWords = {}
                for i = killerStart, #words do
                     if type(words[i]) == "string" then
                        local word = words[i]:gsub("[%.]", "")
                        if word ~= " " then
                            if word:find("'") and i < #words and words[i+1]:find("Ладим") then
                                table.insert(killerWords, word .. " " .. words[i+1])
                                i = i + 1
                            else
                                table.insert(killerWords, word)
                            end
                         end
                    end
                end
                killer = table.concat(killerWords, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            end
        end
        
        if killer == "неизвестной причины" then
            local killerStart = nil
            for i = deathIndex + 1, #words do
                if words[i] == "на" and i + 2 <= #words and words[i + 1]:match("^%d+$") and words[i + 2] == "уровне" then
                    i = i + 2
                end
                for _, phrase in ipairs(killerPhrases) do
                    if #phrase == 1 then
                        if words[i] == phrase[1] then killerStart = i + 1 break end
                    elseif #phrase == 2 then
                        if i + 1 <= #words and words[i] == phrase[1] and words[i + 1] == phrase[2] then
                            killerStart = i + 2 break
                        end
                    end
                end 
                if killerStart then break end
            end
            
            if not killerStart then
                for i = #words, 1, -1 do
                    for _, phrase in ipairs(killerPhrases) do
                        if #phrase == 1 then
                            if words[i] == phrase[1] then killerStart = i + 1 break end
                        elseif #phrase == 2 then 
                            if i >= 2 and words[i-1] == phrase[1] and words[i] == phrase[2] then
                                killerStart = i + 1 break
                            end
                        end
                     end
                    if killerStart then break end
                end
            end
            
            if killerStart then
                local killerEnd = #words
                for i = killerStart, #words do
                    if words[i] == "в" and i + 1 <= #words and words[i + 1] == "локации" then
                        killerEnd = i - 1 break
                    end
                    if words[i] == "-" then killerEnd = i - 1 break end
                end
                
                local killerWords = {}
                for i = killerStart, killerEnd do
                    if i <= #words and type(words[i]) == "string" then
                        local word = words[i]:gsub("[,%.]", "")
                        if word ~= " " then
                            if word:find("'") and i < #words and words[i+1]:find("Ладим") then
                                table.insert(killerWords, word .. " " .. words[i+1])
                                i = i + 1
                            else
                                table.insert(killerWords, word)
                            end
                         end
                    end
                end
                killer = table.concat(killerWords, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                if killer == " " then killer = "неизвестной причины" end
            end
        end
        
        if killer == "неизвестной причины" then
            for i = #words, 1, -1 do
                if words[i] == "." and i > 1 then
                    local prevWord = words[i-1]:gsub("[%.]", "")
                    if prevWord ~= " " then
                        if prevWord:find("'") and i > 2 then
                            killer = words[i-2] .. " " .. prevWord
                        else
                            killer = prevWord
                        end
                        break
                    end
                end
            end
         end
    end
    
    return race, class, level, killer, location
end

-- Обработка сообщения о смерти
local function ProcessDeathMessage(fullMessage)
    local settings = getCurrentSettings()
    if not (fullMessage:find("погиб") or fullMessage:find("погибла")) then return end

    -- Проверка на HC+ (наличие [~])
    local isHCPlus = fullMessage:match("%[~%]")
    
    -- Извлечение имени игрока
    local playerName = fullMessage:match("%[([^%]]+)%]")
    if not playerName then return end
    
    -- Для HC+ добавляем маркер [~] к имени для отображения
    if isHCPlus then
        playerName = playerName .. "[~]"
    end

    local msgWithoutName = fullMessage:gsub("%[([^%]]+)%]", " ", 1):gsub("^%s*,%s*", " ")
    local words = mysplit(msgWithoutName)
    local safeWords = {}
    for _, w in ipairs(words) do
        if type(w) == "string" then safeWords[#safeWords + 1] = w end
    end
    words = safeWords

    local deathIndex = nil
    for i, w in ipairs(words) do
        if w == "погиб" or w == "погибла" then
            deathIndex = i
            break
        end
    end
    if not deathIndex then return end

    -- Парсинг данных (работает и для HC, и для HC+)
    local race, class, level, killer, location = ParseDeathMessage(msgWithoutName, words, deathIndex)
    
    if class == " " then return end

    -- Инициализация фрейма
    if not deathFrame then
        deathFrame = CreateFrame("Frame", "NSHardcoreDeathFrame", UIParent)
        deathFrame:SetSize(400, 200)
        deathFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
        deathFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        deathFrame:Hide()
        
        local bg = deathFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\AddOns\\NSAuk\\libs\\death.tga")
        
        local classTex = deathFrame:CreateTexture(nil, "ARTWORK")
        classTex:SetSize(settings.classTextureSize, settings.classTextureSize)
        classTex:SetPoint("TOP", deathFrame, "TOP", settings.classTextureOffsetX, settings.classTextureOffsetY)
        deathFrame.classTex = classTex
        
        local deathText = deathFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        deathText:SetPoint("CENTER")
        deathText:SetJustifyH("CENTER")
        deathText:SetJustifyV("CENTER")
        deathText:SetWidth(360)
        deathText:SetHeight(50)
        deathText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        deathFrame.deathText = deathText
    end

    applySettingsToFrame(settings)

    local normRace = race:lower()
    local normClass = class:lower()

    local raceColor = raceColors[normRace] or "ffc0c0c0"
    local classColor = classColors[normClass] or "ffffffff"
    local classTexture = classTextures[normClass] or classTextures["жрец"]

    local raceText = race ~= " " and "|c" .. raceColor .. race .. "|r " or " "
    local formattedText = string.format("%s|c%s%s|r |cffa0a0a0(%s ур.)|r |cffffffffпогиб(ла)|r от |cffff0000%s|r |cffffffffв локации|r |cff7f7fff%s|r",
        raceText, classColor, playerName, level, killer, location)

    deathFrame.deathText:SetText(formattedText)

    local texturePath = classTexture
    if not texturePath:match("%.tga$") then texturePath = texturePath .. ".tga" end
    deathFrame.classTex:SetTexture(texturePath)

    deathFrame.classTex:Show()
    deathFrame:SetAlpha(1)
    deathFrame:Show()

    pcall(function() PlaySoundFile("Interface\\AddOns\\NSAuk\\libs\\death.mp3", "Master") end)

    if not fadeFrame then
        fadeFrame = CreateFrame("Frame")
        fadeFrame:SetScript("OnUpdate", function(self, elapsed)
            if not deathFrame or not deathFrame:IsShown() then
                self:Hide()
                self.startTime = nil
                return
            end
            if not self.startTime then
                self.startTime = GetTime()
                return
            end
            local elapsedTime = GetTime() - self.startTime
            if elapsedTime < settings.showTime then return end
            if elapsedTime >= settings.showTime + settings.fadeTime then
                deathFrame:Hide()
                self:Hide()
                self.startTime = nil
                return
            end
            local fadeProgress = (elapsedTime - settings.showTime) / settings.fadeTime
            deathFrame:SetAlpha(1 - fadeProgress)
        end)
        fadeFrame:Hide()
    else
        fadeFrame.startTime = nil
    end
    fadeFrame:Show()
end

-- Очистка форматирования
local function stripFormatting(msg)
    if not msg or msg == " " then return " " end
    local cleaned = msg:gsub("|H[^|]+|h(.-)|h", "%1")
    cleaned = cleaned:gsub("|c%x%x%x%x%x%x%x%x(.-)|r", "%1")
    cleaned = cleaned:gsub("|[%a][^|]*", "")
    cleaned = cleaned:gsub("|", "")
    cleaned = cleaned:gsub("[%z\1-\31]", "")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
    return cleaned
end

-- Проверка ключевых слов смерти
local function hasDeathKeywords(msg)
    if not msg or msg == "" then return false end
    local lower = string.lower(msg)
    return (lower:find("поги[бл]") and lower:find("на %d+ уровне"))
end

-- Обработчик системного чата
local GC_Sniffer = CreateFrame("Frame")
GC_Sniffer:RegisterEvent("CHAT_MSG_SYSTEM")
GC_Sniffer:SetScript("OnEvent", function(self, event, message)
    if hasDeathKeywords(message) then
        local cleanMsg = stripFormatting(message):gsub("^%s*,%s*", "")
        if cleanMsg ~= "" then
            ProcessDeathMessage(cleanMsg)
        end
    end
end)

-- Команды настройки
SLASH_NSHK1 = "/ns_hk"
SlashCmdList["NSHK"] = function(msg)
    msg = msg:trim()
    if msg == "" or msg:lower() == "help" then
        print("|cffffd700NS Hardcore Death|r — команды настройки:")
        print("  /ns_hk size <число>       — размер текстуры класса (по умолчанию 40)")
        print("  /ns_hk offset <x> <y>     — смещение текстуры (по умолчанию 3 -18)")
        print("  /ns_hk showtime <число>   — время показа до затухания (сек, по умолчанию 6)")
        print("  /ns_hk fadetime <число>   — длительность затухания (сек, по умолчанию 3)")
        print("  /ns_hk hover <on/off>     — закрытие при наведении (по умолчанию on)")
        print("  /ns_hk delay <число>      — задержка активации наведения (сек, по умолчанию 0.5)")
        print("  /ns_hk reset              — сброс всех настроек")
        print("  /ns_hk help               — эта справка")
        return
    end
    local settings = getCurrentSettings()
    local args = {strsplit(" ", msg)}
    local cmd = args[1]:lower()

    if cmd == "size" and tonumber(args[2]) then
        settings.classTextureSize = tonumber(args[2])
        saveSettings(settings)
        print(string.format("|cffffd700NS Hardcore Death:|r размер текстуры установлен в %d", settings.classTextureSize))
        
    elseif cmd == "offset" and tonumber(args[2]) and tonumber(args[3]) then
        settings.classTextureOffsetX = tonumber(args[2])
        settings.classTextureOffsetY = tonumber(args[3])
        saveSettings(settings)
        print(string.format("|cffffd700NS Hardcore Death:|r смещение текстуры установлено в (%d, %d)", settings.classTextureOffsetX, settings.classTextureOffsetY))
        
    elseif cmd == "showtime" and tonumber(args[2]) then
        settings.showTime = tonumber(args[2])
        saveSettings(settings)
        print(string.format("|cffffd700NS Hardcore Death:|r время показа установлено в %d сек", settings.showTime))
        
    elseif cmd == "fadetime" and tonumber(args[2]) then
        settings.fadeTime = tonumber(args[2])
        saveSettings(settings)
        print(string.format("|cffffd700NS Hardcore Death:|r время затухания установлено в %d сек", settings.fadeTime))
        
    elseif cmd == "hover" then
        if args[2]:lower() == "on" or args[2] == "1" then
            settings.closeOnHover = true
            saveSettings(settings)
            print("|cffffd700NS Hardcore Death:|r закрытие при наведении включено")
        elseif args[2]:lower() == "off" or args[2] == "0" then
            settings.closeOnHover = false
            saveSettings(settings)
            print("|cffffd700NS Hardcore Death:|r закрытие при наведении отключено")
        else
            print("|cffff0000Ошибка:|r используйте /ns_hk hover on|off")
        end
        
    elseif cmd == "delay" and tonumber(args[2]) then
        settings.hoverDelay = tonumber(args[2])
        saveSettings(settings)
        print(string.format("|cffffd700NS Hardcore Death:|r задержка наведения установлена в %.1f сек", settings.hoverDelay))
        
    elseif cmd == "reset" then
        nsHD.death = nil
        print("|cffffd700NS Hardcore Death:|r настройки сброшены до значений по умолчанию")
        
    else
        print("|cffff0000Ошибка:|r неизвестная команда. Введите /ns_hk help для справки")
    end
end

-- Подсказка при загрузке
local loadedFrame = CreateFrame("Frame")
loadedFrame:RegisterEvent("PLAYER_LOGIN")
loadedFrame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    print("|cffffd700NS Hardcore Death|r загружен. Введите /ns_hk help для настройки окна смерти.")
end)