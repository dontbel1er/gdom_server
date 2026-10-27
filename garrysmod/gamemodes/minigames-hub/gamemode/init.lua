AddCSLuaFile("shared.lua")
include("shared.lua")

-- Сетевые сообщения
util.AddNetworkString("MinigamesHub_VotePhase")
util.AddNetworkString("MinigamesHub_VoteData")
util.AddNetworkString("MinigamesHub_WinnerAnnounce")
util.AddNetworkString("MinigamesHub_RequestVote")

-- ==========================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==========================================

local function GetHub()
    return GAMEMODE or GM
end

-- ==========================================
-- ГОЛОСОВАНИЕ (2 этапа)
-- ==========================================

local VotePhase = 0
local PhaseTimer = nil
local CurrentModeVotes = {}
local CurrentMapVotes = {}
local SelectedMode = nil
local VoteInProgress = false
local AutoVoteTimer = nil
local PhaseEndTime = 0

-- ==========================================
-- ФУНКЦИИ ОТПРАВКИ ДАННЫХ (объявляем первыми)
-- ==========================================

local function SendPhase(phase)
    net.Start("MinigamesHub_VotePhase")
        net.WriteUInt(phase, 3)
        if phase == 2 and SelectedMode then
            net.WriteString(SelectedMode)
        else
            net.WriteString("")
        end
        net.WriteFloat(PhaseEndTime)
    net.Broadcast()
end

local function SendVoteData(phase)
    local votes = {}
    local voteTable = (phase == 1) and CurrentModeVotes or CurrentMapVotes

    for steamID, choice in pairs(voteTable) do
        votes[choice] = votes[choice] or {}
        for _, ply in pairs(player.GetAll()) do
            if ply:SteamID() == steamID then
                table.insert(votes[choice], {
                    nick = ply:Nick(),
                    steamID64 = ply:SteamID64()
                })
                break
            end
        end
    end

    net.Start("MinigamesHub_VoteData")
        net.WriteUInt(phase, 3)
        net.WriteTable(votes)
    net.Broadcast()
end

-- ==========================================
-- ОЧИСТКА ЧУЖИХ ХУКОВ
-- ==========================================
-- В GMod хуки НЕ очищаются при смене gamemode.
-- Хуки из других режимов остаются активными и могут ломать игру
-- (например отключать урон). Удаляем их перед переключением.

local FOREIGN_HOOKS = {
    ["PlayerShouldTakeDamage"] = { "Flood_PlayerShouldTakeDamge" },
    ["EntityTakeDamage"] = { "PhysboxTakeDamage", "PH_EntityTakeDamage", "unstuckblocker" },
    ["EntityRemoved"] = { "PhysboxRemoved" },
}

local function ClearForeignHooks()
    for event, names in pairs(FOREIGN_HOOKS) do
        for _, name in ipairs(names) do
            if hook.GetTable()[event] and hook.GetTable()[event][name] then
                hook.Remove(event, name)
                print("[Minigames Hub] Удалён чужой хук: " .. event .. " / " .. name)
            end
        end
    end
end

-- ==========================================
-- ПЕРЕКЛЮЧЕНИЕ НА КАРТУ
-- ==========================================

function SwitchToMap(mode, mapName)
    local hub = GetHub()
    if not hub then return end

    if not mode or not mapName then return end
    if not hub.GameModes[mode] then
        print("[Minigames Hub] Ошибка: режим '" .. mode .. "' не найден!")
        return
    end

    print("[Minigames Hub] Переключаемся на: " .. hub.GameModes[mode].name)
    print("[Minigames Hub] Карта: " .. mapName)

    file.Write("minigameshub_active.txt", mode)
    file.Write("minigameshub_roundtime.txt", tostring(hub.RoundTime))

    ClearForeignHooks()

    game.ConsoleCommand("gamemode " .. mode .. "\n")
    timer.Simple(0.5, function()
        game.ConsoleCommand("changelevel " .. mapName .. "\n")
    end)
end

local function ReturnToHub()
    print("[Minigames Hub] Возвращаемся в хаб...")
    file.Delete("minigameshub_active.txt")
    file.Delete("minigameshub_roundtime.txt")
    local hub = GetHub()
    local hubMap = hub and hub.HubMap or "rp_lego_city"
    game.ConsoleCommand("gamemode minigames-hub\n")
    timer.Simple(0.5, function()
        game.ConsoleCommand("changelevel " .. hubMap .. "\n")
    end)
end

-- ==========================================
-- ФАЗЫ ГОЛОСОВАНИЯ
-- ==========================================

local function EndPhase2()
    if VotePhase ~= 2 then return end
    VotePhase = 0
    VoteInProgress = false
    timer.Remove("MinigamesHub_PhaseTimer")
    SendPhase(0)

    local hub = GetHub()
    if not hub or not SelectedMode then return end

    local modeInfo = hub.GameModes[SelectedMode]

    local counts = {}
    for _, mapKey in pairs(CurrentMapVotes) do
        if modeInfo.maps[mapKey] and modeInfo.maps[mapKey].available then
            counts[mapKey] = (counts[mapKey] or 0) + 1
        end
    end

    local winnerMap = nil
    local maxVotes = -1
    for mapKey, count in pairs(counts) do
        if count > maxVotes then
            maxVotes = count
            winnerMap = mapKey
        end
    end

    if not winnerMap then
        for mapKey, mapInfo in SortedPairs(modeInfo.maps) do
            if mapInfo.available then
                winnerMap = mapKey
                break
            end
        end
    end

    if winnerMap then
        local mapInfo = modeInfo.maps[winnerMap]
        PrintMessage(HUD_PRINTTALK, "=======================================")
        PrintMessage(HUD_PRINTTALK, "  ПОБЕДИЛА КАРТА: " .. mapInfo.name)
        PrintMessage(HUD_PRINTTALK, "  Режим: " .. modeInfo.name)
        PrintMessage(HUD_PRINTTALK, "=======================================")
        SwitchToMap(SelectedMode, winnerMap)
    else
        PrintMessage(HUD_PRINTTALK, "Нет доступных карт. Остаемся в хабе.")
    end
end

local function EndPhase1()
    if VotePhase ~= 1 then return end
    timer.Remove("MinigamesHub_PhaseTimer")

    local hub = GetHub()
    if not hub then return end

    local counts = {}
    for _, mode in pairs(CurrentModeVotes) do
        counts[mode] = (counts[mode] or 0) + 1
    end

    local winner = nil
    local maxVotes = -1
    for mode, count in pairs(counts) do
        if count > maxVotes then
            maxVotes = count
            winner = mode
        end
    end

    if not winner then
        local modes = {}
        for k in pairs(hub.GameModes) do table.insert(modes, k) end
        winner = modes[math.random(#modes)]
    end

    SelectedMode = winner
    local modeInfo = hub.GameModes[winner]

    PrintMessage(HUD_PRINTTALK, "=======================================")
    PrintMessage(HUD_PRINTTALK, "  Выбран режим: " .. modeInfo.name)
    PrintMessage(HUD_PRINTTALK, "  Голосование за карту...")
    PrintMessage(HUD_PRINTTALK, "=======================================")

    VotePhase = 2
    CurrentMapVotes = {}
    PhaseEndTime = CurTime() + hub.Phase2Time
    SendPhase(2)
    SendVoteData(2)

    PrintMessage(HUD_PRINTTALK, "Напишите !vote <номер> или нажмите F3/F4")
    local i = 1
    for mapKey, mapInfo in SortedPairs(modeInfo.maps) do
        local status = mapInfo.available and "" or " [Coming Soon]"
        PrintMessage(HUD_PRINTTALK, "  " .. i .. ". " .. mapInfo.name .. status)
        i = i + 1
    end

    PhaseTimer = timer.Create("MinigamesHub_PhaseTimer", hub.Phase2Time, 1, function()
        EndPhase2()
    end)
end

function StartVote()
    if VoteInProgress then return end
    local hub = GetHub()
    if not hub then return end

    if #player.GetAll() < hub.MinPlayersForVote then
        print("[Minigames Hub] Недостаточно игроков для голосования.")
        return
    end

    VoteInProgress = true
    VotePhase = 1
    CurrentModeVotes = {}
    CurrentMapVotes = {}
    SelectedMode = nil
    PhaseEndTime = CurTime() + hub.Phase1Time

    SendPhase(1)
    SendVoteData(1)

    PrintMessage(HUD_PRINTTALK, "=======================================")
    PrintMessage(HUD_PRINTTALK, "  ГОЛОСОВАНИЕ: Выбор режима")
    PrintMessage(HUD_PRINTTALK, "=======================================")
    PrintMessage(HUD_PRINTTALK, "Напишите !vote <номер> или нажмите F3/F4")
    local i = 1
    for key, info in SortedPairs(hub.GameModes) do
        PrintMessage(HUD_PRINTTALK, "  " .. i .. ". " .. info.name)
        i = i + 1
    end
    PrintMessage(HUD_PRINTTALK, "Время: " .. hub.Phase1Time .. " сек")

    PhaseTimer = timer.Create("MinigamesHub_PhaseTimer", hub.Phase1Time, 1, function()
        EndPhase1()
    end)
end

-- ==========================================
-- АВТОЗАПУСК ГОЛОСОВАНИЯ
-- ==========================================

local function ScheduleAutoVote()
    local hub = GetHub()
    if not hub or hub.AutoVoteDelay <= 0 then return end

    if AutoVoteTimer then timer.Remove("MinigamesHub_AutoVote") end
    AutoVoteTimer = timer.Create("MinigamesHub_AutoVote", hub.AutoVoteDelay, 1, function()
        if not VoteInProgress then
            PrintMessage(HUD_PRINTTALK, "[Minigames Hub] Автоголосование через 10 сек...")
            timer.Simple(10, function()
                StartVote()
            end)
        end
    end)
end

-- ==========================================
-- СЕТЕВЫЕ СООБЩЕНИЯ ОТ КЛИЕНТА
-- ==========================================

net.Receive("MinigamesHub_RequestVote", function(len, ply)
    if not IsValid(ply) then return end
    if not VoteInProgress then
        ply:ChatPrint("Голосование не активно.")
        return
    end

    local choice = net.ReadString()
    local hub = GetHub()
    if not hub then return end

    if VotePhase == 1 then
        if hub.GameModes[choice] then
            CurrentModeVotes[ply:SteamID()] = choice
            PrintMessage(HUD_PRINTTALK, ply:Nick() .. " проголосовал за " .. hub.GameModes[choice].name)
            SendVoteData(1)
        end
    elseif VotePhase == 2 and SelectedMode then
        local modeInfo = hub.GameModes[SelectedMode]
        if modeInfo and modeInfo.maps[choice] then
            CurrentMapVotes[ply:SteamID()] = choice
            PrintMessage(HUD_PRINTTALK, ply:Nick() .. " проголосовал за " .. modeInfo.maps[choice].name)
            SendVoteData(2)
        end
    end
end)

-- ==========================================
-- КОМАНДЫ
-- ==========================================

concommand.Add("switch_map", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then return end
    if args[1] and args[2] then
        SwitchToMap(args[1], args[2])
    end
end)

concommand.Add("mg_start_vote", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then
        ply:ChatPrint("Только админ может запустить голосование.")
        return
    end
    StartVote()
end)

concommand.Add("mg_force_return", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then
        ply:ChatPrint("Только админ может форсировать возврат.")
        return
    end
    ReturnToHub()
end)

-- ==========================================
-- ОБРАБОТКА ЧАТА
-- ==========================================

hook.Add("PlayerSay", "MinigamesHub_Chat", function(ply, text)
    local cmd = string.lower(string.Trim(text))

    if string.sub(cmd, 1, 5) == "!vote" then
        if not VoteInProgress then
            ply:ChatPrint("Сейчас нет активного голосования.")
            return ""
        end

        local num = tonumber(string.sub(cmd, 7))
        if not num then
            ply:ChatPrint("Использование: !vote <номер>")
            return ""
        end

        local hub = GetHub()
        if not hub then return "" end

        if VotePhase == 1 then
            local i = 1
            for key, info in SortedPairs(hub.GameModes) do
                if i == num then
                    CurrentModeVotes[ply:SteamID()] = key
                    PrintMessage(HUD_PRINTTALK, ply:Nick() .. " проголосовал за " .. info.name)
                    SendVoteData(1)
                    return ""
                end
                i = i + 1
            end
        elseif VotePhase == 2 and SelectedMode then
            local modeInfo = hub.GameModes[SelectedMode]
            local i = 1
            for mapKey, mapInfo in SortedPairs(modeInfo.maps) do
                if i == num then
                    CurrentMapVotes[ply:SteamID()] = mapKey
                    PrintMessage(HUD_PRINTTALK, ply:Nick() .. " проголосовал за " .. mapInfo.name)
                    SendVoteData(2)
                    return ""
                end
                i = i + 1
            end
        end

        ply:ChatPrint("Неверный номер.")
        return ""
    end

    if cmd == "!modes" or cmd == "!maps" then
        local hub = GetHub()
        if not hub then return "" end
        ply:ChatPrint("Доступные режимы:")
        for key, info in SortedPairs(hub.GameModes) do
            ply:ChatPrint("  - " .. info.name)
        end
        return ""
    end

    if cmd == "!start" then
        StartVote()
        return ""
    end
end)

-- ==========================================
-- ЛОББИ
-- ==========================================

function GM:PlayerSpawn(ply)
    self.BaseClass:PlayerSpawn(ply)
    ply:StripWeapons()
    ply:Give("weapon_pistol")
end

function GM:PlayerInitialSpawn(ply)
    timer.Simple(3, function()
        if IsValid(ply) then
            ply:ChatPrint("Добро пожаловать в Minigames Hub!")
            ply:ChatPrint("Напишите !modes - список режимов")
            ply:ChatPrint("Нажмите F3/F4 - меню голосования")
            ply:ChatPrint("Админ: !start - запустить голосование")
        end
    end)

    local active = file.Read("minigameshub_active.txt", "DATA")
    if (not active or active == "") and not VoteInProgress then
        ScheduleAutoVote()
    end
end

-- Сохраняем HubMap
local hub = GetHub()
if hub and hub.HubMap then
    file.Write("minigameshub_hubmap.txt", hub.HubMap)
end
