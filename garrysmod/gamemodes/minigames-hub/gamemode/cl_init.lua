-- ==========================================
-- КЛИЕНТСКИЙ КОД Minigames Hub
-- ==========================================

include("shared.lua")

print("[Minigames Hub] Клиент загружен.")

local MenuOpen     = false
local IsMinimized  = false
local VotePhase    = 0
local SelectedMode = nil
local CurrentVoteData = {}
local VoteEndTime  = 0

local VoteFrame     = nil
local MinimizedPanel = nil
local ContentPanel  = nil
local TimerLabel    = nil

-- ==========================================
-- BLUR BACKGROUND
-- ==========================================

local blur = Material("pp/blurscreen")
local function DrawBlur(panel, amount)
    local x, y = panel:LocalToScreen(0, 0)
    local w, h = panel:GetSize()

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(blur)

    for i = 0.33, 1, 0.33 do
        blur:SetFloat("$blur", i * amount)
        blur:Recompute()
        if render then render.UpdateScreenEffectTexture() end
        surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
    end

    surface.SetDrawColor(20, 22, 28, 220)
    surface.DrawRect(0, 0, w, h)
end

-- ==========================================
-- СЕТЕВЫЕ СООБЩЕНИЯ
-- ==========================================

net.Receive("MinigamesHub_VotePhase", function(len)
    local phase = net.ReadUInt(3)
    local mode = net.ReadString()
    local endTime = net.ReadFloat()

    VotePhase = phase
    VoteEndTime = endTime
    if phase == 2 then
        SelectedMode = mode
    end

    if phase == 1 then
        chat.AddText(Color(100, 255, 100), "[Minigames Hub] Началось голосование за режим!")
        OpenVoteMenu()
    elseif phase == 2 then
        chat.AddText(Color(100, 255, 100), "[Minigames Hub] Выбран режим! Голосование за карту...")
        if MenuOpen and not IsMinimized then
            RefreshVoteMenu()
        elseif MenuOpen and IsMinimized then
            -- оставляем свернутым, обновим свернутую панель
            UpdateMinimizedPanel()
        else
            OpenVoteMenu()
        end
    elseif phase == 0 then
        CloseVoteMenu()
    end
end)

net.Receive("MinigamesHub_VoteData", function(len)
    local phase = net.ReadUInt(3)
    CurrentVoteData = net.ReadTable() or {}
    if MenuOpen and not IsMinimized then
        RefreshVoteMenu()
    elseif MenuOpen and IsMinimized then
        UpdateMinimizedPanel()
    end
end)

-- ==========================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==========================================

local function GetHub()
    return GAMEMODE or GM
end

local function GetPlayerVote(plyNick)
    for choice, voters in pairs(CurrentVoteData) do
        for _, voter in pairs(voters) do
            if voter.nick == plyNick then
                return choice
            end
        end
    end
    return nil
end

-- ==========================================
-- СВЕРНУТАЯ ПАНЕЛЬ
-- ==========================================

function UpdateMinimizedPanel()
    if not IsValid(MinimizedPanel) then return end
    -- контент обновится через Think
end

function CreateMinimizedPanel()
    if IsValid(MinimizedPanel) then return end

    MinimizedPanel = vgui.Create("DPanel")
    MinimizedPanel:SetSize(240, 80)
    MinimizedPanel:SetPos(ScrW() - 250, 10)
    MinimizedPanel:SetVisible(false)

    MinimizedPanel.Paint = function(self, w, h)
        DrawBlur(self, 3)
        surface.SetDrawColor(60, 65, 80, 200)
        surface.DrawRect(0, 0, w, 28)
        surface.SetDrawColor(80, 85, 100)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText("Голосование идет", "DermaDefaultBold", 10, 4, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- Таймер
    local tLbl = vgui.Create("DLabel", MinimizedPanel)
    tLbl:SetPos(10, 34)
    tLbl:SetSize(120, 20)
    tLbl:SetFont("DermaDefault")
    tLbl:SetTextColor(Color(255, 200, 100))
    tLbl.Think = function(self)
        local remaining = math.max(0, VoteEndTime - CurTime())
        self:SetText("Осталось: " .. math.ceil(remaining) .. " сек")
    end

    -- Кнопка развернуть
    local btn = vgui.Create("DButton", MinimizedPanel)
    btn:SetPos(10, 52)
    btn:SetSize(220, 24)
    btn:SetText("Развернуть (F3/F4)")
    btn:SetFont("DermaDefault")
    btn:SetTextColor(Color(255, 255, 255))
    btn.Paint = function(self, w, h)
        surface.SetDrawColor(self:IsHovered() and Color(80, 160, 80) or Color(60, 120, 60))
        surface.DrawRect(0, 0, w, h)
    end
    btn.DoClick = function()
        MaximizeVoteMenu()
    end
end

-- ==========================================
-- УПРАВЛЕНИЕ ОКНОМ
-- ==========================================

function MinimizeVoteMenu()
    if not MenuOpen then return end
    IsMinimized = true

    if IsValid(VoteFrame) then
        VoteFrame:SetVisible(false)
    end

    CreateMinimizedPanel()
    if IsValid(MinimizedPanel) then
        MinimizedPanel:SetVisible(true)
    end

    -- Возвращаем управление мышью игре (камера, стрельба)
    gui.EnableScreenClicker(false)

    chat.AddText(Color(200, 200, 200), "[Minigames Hub] Меню свернуто. Нажмите F3/F4 чтобы развернуть.")
end

function MaximizeVoteMenu()
    if not MenuOpen then
        OpenVoteMenu()
        return
    end

    IsMinimized = false

    if IsValid(MinimizedPanel) then
        MinimizedPanel:SetVisible(false)
    end

    if not IsValid(VoteFrame) then
        BuildVoteFrame()
    else
        VoteFrame:SetVisible(true)
        VoteFrame:MakePopup()
        VoteFrame:SetKeyboardInputEnabled(false)
    end

    -- Мышь управляет UI
    gui.EnableScreenClicker(true)
end

function CloseVoteMenu()
    if IsValid(VoteFrame) then
        VoteFrame:Remove()
        VoteFrame = nil
    end
    if IsValid(MinimizedPanel) then
        MinimizedPanel:Remove()
        MinimizedPanel = nil
    end
    MenuOpen = false
    IsMinimized = false
    gui.EnableScreenClicker(false)
end

-- ==========================================
-- СОЗДАНИЕ АВАТАРОК
-- ==========================================

local function CreateAvatarRow(parent, voters, maxCount)
    maxCount = maxCount or 6
    local row = vgui.Create("DPanel", parent)
    row:SetTall(32)
    row:Dock(BOTTOM)
    row:DockMargin(6, 2, 6, 6)
    row.Paint = function() end

    local count = 0
    for _, voter in pairs(voters or {}) do
        if count >= maxCount then
            local plus = vgui.Create("DLabel", row)
            plus:SetPos(count * 26 + 2, 2)
            plus:SetSize(24, 24)
            plus:SetFont("DermaDefault")
            plus:SetText("+" .. (#voters - maxCount))
            plus:SetTextColor(Color(200, 200, 200))
            break
        end

        local avatar = vgui.Create("AvatarImage", row)
        avatar:SetSize(24, 24)
        avatar:SetPos(count * 26 + 2, 2)
        avatar:SetSteamID(voter.steamID64, 24)
        avatar:SetTooltip(voter.nick)

        count = count + 1
    end

    return row
end

-- ==========================================
-- UI ГОЛОСОВАНИЯ (ПОЛНОЕ)
-- ==========================================

function RefreshVoteMenu()
    if not IsValid(ContentPanel) then return end
    ContentPanel:Clear()

    local hub = GetHub()
    if not hub then return end

    -- Заголовок этапа
    local phaseTitle = vgui.Create("DLabel", ContentPanel)
    phaseTitle:Dock(TOP)
    phaseTitle:DockMargin(16, 10, 16, 6)
    phaseTitle:SetTall(26)
    phaseTitle:SetFont("DermaLarge")
    if VotePhase == 1 then
        phaseTitle:SetText("Выберите режим")
    elseif VotePhase == 2 then
        local modeInfo = hub.GameModes[SelectedMode]
        phaseTitle:SetText("Выберите карту — " .. (modeInfo and modeInfo.name or ""))
    end
    phaseTitle:SetTextColor(Color(255, 255, 255))

    -- Сетка карточек
    local grid = vgui.Create("DIconLayout", ContentPanel)
    grid:Dock(FILL)
    grid:DockMargin(12, 4, 12, 8)
    grid:SetSpaceX(10)
    grid:SetSpaceY(10)

    if VotePhase == 1 then
        for key, info in SortedPairs(hub.GameModes) do
            local votes = CurrentVoteData[key] or {}
            local voteCount = #votes
            local isVoted = GetPlayerVote(LocalPlayer():Nick()) == key

            local card = grid:Add("DPanel")
            card:SetSize(170, 200)
            card.Paint = function(self, w, h)
                local bgCol = isVoted and Color(55, 75, 55, 240) or Color(40, 42, 50, 240)
                surface.SetDrawColor(bgCol)
                surface.DrawRect(0, 0, w, h)

                local borderCol = isVoted and Color(100, 255, 100) or Color(70, 75, 90)
                surface.SetDrawColor(borderCol)
                surface.DrawOutlinedRect(0, 0, w, h, isVoted and 2 or 1)

                surface.SetDrawColor(info.color)
                surface.DrawRect(0, 0, w, 5)

                draw.SimpleText(info.icon or "?", "DermaLarge", w/2, 45, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(info.name, "DermaDefaultBold", w/2, 85, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                local voteText = voteCount .. " " .. (voteCount == 1 and "голос" or "голосов")
                draw.SimpleText(voteText, "DermaDefault", w/2, 108, Color(180,180,180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            local btn = vgui.Create("DButton", card)
            btn:SetSize(170, 200)
            btn:SetText("")
            btn.Paint = function() end
            btn.DoClick = function()
                if VotePhase == 1 then
                    net.Start("MinigamesHub_RequestVote")
                        net.WriteString(key)
                    net.SendToServer()
                    surface.PlaySound("buttons/button9.wav")
                end
            end

            CreateAvatarRow(card, votes, 5)
        end

    elseif VotePhase == 2 and SelectedMode then
        local modeInfo = hub.GameModes[SelectedMode]
        if modeInfo then
            for mapKey, mapInfo in SortedPairs(modeInfo.maps) do
                local votes = CurrentVoteData[mapKey] or {}
                local voteCount = #votes
                local isVoted = GetPlayerVote(LocalPlayer():Nick()) == mapKey
                local isAvailable = mapInfo.available

                local card = grid:Add("DPanel")
                card:SetSize(170, 200)
                card.Paint = function(self, w, h)
                    if not isAvailable then
                        surface.SetDrawColor(30, 32, 40, 240)
                        surface.DrawRect(0, 0, w, h)
                        surface.SetDrawColor(50, 50, 60)
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                    else
                        local bgCol = isVoted and Color(55, 75, 55, 240) or Color(40, 42, 50, 240)
                        surface.SetDrawColor(bgCol)
                        surface.DrawRect(0, 0, w, h)
                        local borderCol = isVoted and Color(100, 255, 100) or Color(70, 75, 90)
                        surface.SetDrawColor(borderCol)
                        surface.DrawOutlinedRect(0, 0, w, h, isVoted and 2 or 1)
                    end

                    surface.SetDrawColor(modeInfo.color)
                    surface.DrawRect(0, 0, w, 5)

                    if not isAvailable then
                        draw.SimpleText("?", "DermaLarge", w/2, 40, Color(100,100,100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        draw.SimpleText(mapInfo.name, "DermaDefaultBold", w/2, 80, Color(130,130,130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        draw.SimpleText("COMING SOON", "DermaDefault", w/2, 105, Color(80,80,80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    else
                        draw.SimpleText("?", "DermaLarge", w/2, 40, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        draw.SimpleText(mapInfo.name, "DermaDefaultBold", w/2, 80, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        local voteText = voteCount .. " " .. (voteCount == 1 and "голос" or "голосов")
                        draw.SimpleText(voteText, "DermaDefault", w/2, 103, Color(180,180,180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end

                if isAvailable then
                    local btn = vgui.Create("DButton", card)
                    btn:SetSize(170, 200)
                    btn:SetText("")
                    btn.Paint = function() end
                    btn.DoClick = function()
                        if VotePhase == 2 then
                            net.Start("MinigamesHub_RequestVote")
                                net.WriteString(mapKey)
                            net.SendToServer()
                            surface.PlaySound("buttons/button9.wav")
                        end
                    end

                    CreateAvatarRow(card, votes, 5)
                end
            end
        end
    end
end

function BuildVoteFrame()
    VoteFrame = vgui.Create("DFrame")
    VoteFrame:SetSize(780, 520)
    VoteFrame:Center()
    VoteFrame:SetTitle("")
    VoteFrame:ShowCloseButton(false)
    VoteFrame:SetDraggable(false)
    VoteFrame:SetSizable(false)
    VoteFrame:SetDeleteOnClose(true)

    VoteFrame.Paint = function(self, w, h)
        DrawBlur(self, 4)
        surface.SetDrawColor(60, 65, 80, 200)
        surface.DrawRect(0, 0, w, 42)
    end

    -- Заголовок
    local header = vgui.Create("DLabel", VoteFrame)
    header:SetPos(20, 8)
    header:SetSize(400, 26)
    header:SetFont("DermaLarge")
    header:SetText("Minigames Hub — Голосование")
    header:SetTextColor(Color(255, 255, 255))

    -- Кнопка свернуть (_)
    local minBtn = vgui.Create("DButton", VoteFrame)
    minBtn:SetPos(VoteFrame:GetWide() - 60, 8)
    minBtn:SetSize(24, 24)
    minBtn:SetText("_")
    minBtn:SetFont("DermaDefaultBold")
    minBtn:SetTextColor(Color(255, 255, 255))
    minBtn.Paint = function(self, w, h)
        surface.SetDrawColor(self:IsHovered() and Color(100, 100, 120) or Color(70, 70, 90))
        surface.DrawRect(0, 0, w, h)
    end
    minBtn.DoClick = function()
        MinimizeVoteMenu()
    end

    -- Таймер
    TimerLabel = vgui.Create("DLabel", VoteFrame)
    TimerLabel:SetPos(VoteFrame:GetWide() - 200, 8)
    TimerLabel:SetSize(130, 26)
    TimerLabel:SetFont("DermaLarge")
    TimerLabel:SetTextColor(Color(255, 200, 100))
    TimerLabel:SetText("15 сек")
    TimerLabel.Think = function(self)
        local remaining = math.max(0, VoteEndTime - CurTime())
        self:SetText(string.format("%d сек", math.ceil(remaining)))
        if remaining <= 5 then
            self:SetTextColor(Color(255, 100, 100))
        else
            self:SetTextColor(Color(255, 200, 100))
        end
    end

    -- Скролл панель
    ContentPanel = vgui.Create("DScrollPanel", VoteFrame)
    ContentPanel:SetPos(0, 46)
    ContentPanel:SetSize(VoteFrame:GetWide(), VoteFrame:GetTall() - 46)
    ContentPanel.Paint = function(self, w, h)
        surface.SetDrawColor(25, 28, 35, 150)
        surface.DrawRect(0, 0, w, h)
    end
end

function OpenVoteMenu()
    if MenuOpen and not IsMinimized then return end

    MenuOpen = true
    IsMinimized = false

    if not IsValid(VoteFrame) then
        BuildVoteFrame()
    end

    VoteFrame:SetVisible(true)
    VoteFrame:MakePopup()
    VoteFrame:SetKeyboardInputEnabled(false) -- WASD работает

    gui.EnableScreenClicker(true)

    RefreshVoteMenu()
end

-- ==========================================
-- БИНДЫ И КОМАНДЫ
-- ==========================================

hook.Add("PlayerBindPress", "MinigamesHub_OpenMenu", function(ply, bind, pressed)
    if pressed and (bind == "gm_showspare2" or bind == "gm_showspare1") then
        if VotePhase > 0 then
            if not MenuOpen then
                OpenVoteMenu()
            elseif IsMinimized then
                MaximizeVoteMenu()
            else
                MinimizeVoteMenu()
            end
        else
            chat.AddText(Color(255, 200, 100), "[Minigames Hub] Сейчас нет активного голосования.")
        end
        return true
    end
end)

-- ESC сворачивает меню
hook.Add("PlayerBindPress", "MinigamesHub_ESC", function(ply, bind, pressed)
    if pressed and bind == "+showscores" then return end -- пропускаем TAB

    if pressed and (bind == "cancelselect" or bind == "+menu") then
        if MenuOpen and not IsMinimized then
            MinimizeVoteMenu()
            return true
        end
    end
end)

concommand.Add("mg_menu", function()
    if VotePhase > 0 then
        if not MenuOpen then
            OpenVoteMenu()
        elseif IsMinimized then
            MaximizeVoteMenu()
        else
            MinimizeVoteMenu()
        end
    else
        chat.AddText(Color(255, 200, 100), "[Minigames Hub] Сейчас нет активного голосования.")
    end
end)

hook.Add("OnPlayerChat", "MinigamesHub_ChatMenu", function(ply, text)
    if string.lower(string.Trim(text)) == "!menu" then
        if ply == LocalPlayer() then
            if VotePhase > 0 then
                if not MenuOpen then
                    OpenVoteMenu()
                elseif IsMinimized then
                    MaximizeVoteMenu()
                else
                    MinimizeVoteMenu()
                end
            else
                chat.AddText(Color(255, 200, 100), "[Minigames Hub] Сейчас нет активного голосования.")
            end
        end
        return true
    end
end)
