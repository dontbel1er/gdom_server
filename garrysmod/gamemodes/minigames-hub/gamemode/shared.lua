GM.Name = "Minigames Hub"
GM.Author = "Ты"
GM.Email = ""
GM.Website = ""

-- ==========================================
-- РЕЖИМЫ И КАРТЫ
-- ==========================================
GM.GameModes = {
    ["prop_hunt"] = {
        name = "Prop Hunt",
        color = Color(255, 150, 50),
        icon = "🎯",
        maps = {
            ["ph_highflooroffice"]  = { name = "High Floor Office", available = true },
            ["ph_stockroom"]        = { name = "Stockroom",         available = true },
            ["ph_office_v2"]        = { name = "Office V2",         available = false },
            ["ph_minecraft"]        = { name = "Minecraft",         available = false },
        }
    },
    ["zombieescape"] = {
        name = "Zombie Escape",
        color = Color(255, 50, 50),
        icon = "🧟",
        maps = {
            ["ze_thelostworld_redux"] = { name = "The Lost World", available = true },
            ["gm_bunkermaze"]         = { name = "Bunker Maze",    available = true },
            ["ze_minecraft"]          = { name = "Minecraft",      available = false },
            ["ze_pirates"]            = { name = "Pirates",        available = false },
        }
    },
    ["deathrun"] = {
        name = "Deathrun",
        color = Color(50, 150, 255),
        icon = "🏃",
        maps = {
            ["deathrun_diggerworld_b2"] = { name = "Diggerworld",   available = true },
            ["deathrun_crash_snow"]     = { name = "Crash Snow",    available = true },
            ["deathrun_internet"]       = { name = "Internet",      available = true },
            ["deathrun_minecraft"]      = { name = "Minecraft",     available = false },
        }
    },
    ["flood"] = {
        name = "Flood",
        color = Color(50, 255, 150),
        icon = "🌊",
        maps = {
            ["fm_buildaboat_canal_medieval"] = { name = "Build a Boat Medieval", available = true },
            ["flood_construct"]              = { name = "Flood Construct",       available = true },
            ["fm_sink_v2"]                   = { name = "Sink V2",               available = true },
            ["flood_basement"]               = { name = "Basement",              available = false },
        }
    },
}

-- Карта хаба (лобби)
GM.HubMap = "rp_lego_city"

-- ==========================================
-- НАСТРОЙКИ ТАЙМИНГОВ
-- ==========================================
GM.Phase1Time = 15  -- время голосования за режим
GM.Phase2Time = 15  -- время голосования за карту
GM.RoundTime = 600
GM.AutoVoteDelay = 60
GM.PostRoundTime = 15
GM.MinPlayersForVote = 1
