local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local togs = {
    farm = {
        field = "Mushroom Field",
        autodig = false,
        farm = false,
        tokens = false,
        autoconvert = false,
        autosprinklers = false,
        isconverting = false,
        placingsprinklers = false,
        walkPattern = "None",
        convertPercent = 95,
        sprinklerLayout = "Single",
    }
}

local navService = {
    isActive = false,
    targetPos = nil,
    hum = nil,
    char = nil
}

local lastJump = 0
local JUMP_CD = 0.6
local activeField = nil
local isFollowingPath = false
local jumpThreadActive = false
local patternThreadActive = false
local currentToken = nil
local tokenThreadActive = false
local sprinklersPlaced = false

local function getstats()
    return ReplicatedStorage.Events.RetrievePlayerStats:InvokeServer()
end

local function rget(t, ...)
    local cur = t
    for _, k in ipairs({...}) do
        if type(cur) ~= "table" then return nil end
        cur = cur[k]
    end
    return cur
end

local function formatHoney(amount)
    if not amount or amount == 0 then return "0" end
    local suffixes = {"", "K", "M", "B", "T", "Qd", "Qt", "Sx", "Sp", "Oc", "No", "Dc"}
    local idx = 1
    local val = tonumber(amount) or 0
    while val >= 1000 and idx < #suffixes do
        val = val / 1000
        idx = idx + 1
    end
    return string.format("%.2f%s", val, suffixes[idx])
end

local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%dh %dm %ds", h, m, s)
    elseif m > 0 then return string.format("%dm %ds", m, s)
    else return string.format("%ds", s) end
end

local function pct(val, max)
    if not max or max == 0 then return "0%" end
    return string.format("%.1f%%", (val / max) * 100)
end

local function CheckJump()
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if os.clock() - lastJump < JUMP_CD then return false end
    local rayOrigin = hrp.Position + Vector3.new(0, 2.5, 0)
    local lookDir = hrp.CFrame.LookVector
    local rayDirection = (lookDir * 3.5) + Vector3.new(0, -2, 0)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local result = Workspace:Raycast(rayOrigin, rayDirection, params)
    if not result then return false end
    local hit = result.Instance
    if hit and hit.CanCollide then
        local dist = (result.Position - rayOrigin).Magnitude
        if dist < 3.2 then
            lastJump = os.clock()
            return true
        end
    end
    return false
end

local function DoJump()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    local jp = hum.JumpPower
    hum.JumpPower = 100
    keypress(0x20)
    task.wait(0.08)
    keyrelease(0x20)
    task.wait(0.25)
    hum.JumpPower = jp
end

local function StartJumpThread()
    if jumpThreadActive then return end
    jumpThreadActive = true
    task.spawn(function()
        while jumpThreadActive do
            if navService.isActive then
                if CheckJump() then DoJump() end
            end
            task.wait(0.05)
        end
    end)
end

local function StopJumpThread()
    jumpThreadActive = false
end

local function NavWalk(hum, pos)
    if not hum or not pos then return false end
    local char = hum.Parent
    if not char then return false end
    navService.hum = hum
    navService.char = char
    navService.targetPos = pos
    navService.isActive = true
    hum:MoveTo(pos)
    return true
end

local function NavStop()
    navService.isActive = false
    if navService.hum then
        navService.hum:MoveTo(navService.hum.RootPart and navService.hum.RootPart.Position or Vector3.new(0, 0, 0))
    end
    navService.targetPos = nil
end

local function WalkTo(pos)
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    return NavWalk(hum, pos)
end

local function StopNav()
    NavStop()
end

local nodes = {
    sf1 = Vector3.new(-224, 4, 256), sf2 = Vector3.new(-186, 4, 299), dand_mush_w1 = Vector3.new(-40, 4, 252),
    dand_mush_w2 = Vector3.new(-15, 4, 296), clover_ladder_1_before = Vector3.new(47, 4, 217),
    clover_ladder_1_after = Vector3.new(67, 18, 217), clover_ladder_2_before = Vector3.new(90, 18, 180),
    clover_ladder_2_after = Vector3.new(110, 33, 180), sunflower_fence_1 = Vector3.new(-161, 4, 162),
    dand_mush_mid = Vector3.new(-70, 4, 171), gate_5_ramp = Vector3.new(-2, 4, 170), gate_5 = Vector3.new(-3, 21, 77),
    Blue_Front = Vector3.new(39, 4, 120), spider_bamboo_hub = Vector3.new(-4, 20, 14),
    instant_converter_1 = Vector3.new(-147, 4, 193), instant_converter_2 = Vector3.new(282, 68, -63),
    instant_converter_3 = Vector3.new(143, 182, -222), snow_bear = Vector3.new(42, 21, 35),
    gumdrop_shop = Vector3.new(70, 22, 27), stringer_shop = Vector3.new(119, 33, 438),
    spider_bamboo_mid = Vector3.new(32, 20, -20), spider_straw_mid = Vector3.new(-117, 20, 10),
    bamboo_ramp_to_area_10 = Vector3.new(177, 20, -19), area_5_ladder_1_before = Vector3.new(171, 20, 48),
    area_5_ladder_1_after = Vector3.new(157, 35, 48), ramp_to_area_10_1 = Vector3.new(206, 20, -21),
    ramp_to_area_10_2 = Vector3.new(210, 42, 49), ramp_to_area_10_3 = Vector3.new(221, 42, 46),
    gate_10 = Vector3.new(230, 69, -50), stump_path_start = Vector3.new(310, 68, -205),
    stump_path_end = Vector3.new(380, 96, -194), area_10_ramp_to_cannon_start = Vector3.new(314, 68, -143),
    area_10_ramp_to_cannon_end = Vector3.new(318, 103, -29), area_10_elevated_area_main = Vector3.new(300, 103, -10),
    area_10_elevated_area_cannon_jump = Vector3.new(282, 103, -16), area_10_cannon = Vector3.new(268, 110, -24),
    wealth_clock_1 = Vector3.new(273, 33, 169), wealth_clock_2 = Vector3.new(290, 47, 215),
    wealth_clock_3 = Vector3.new(294, 47, 191), wealth_clock_final = Vector3.new(329.4962, 48.4412, 192.2157),
    leaderboard_daily_honey = Vector3.new(-158, 4, 272), leaderboard_all_time_honey = Vector3.new(-87, 4, 278),
    leaderboard_battle_points = Vector3.new(133, 35, 39), brown_bear = Vector3.new(281, 45, 237),
    panda_bear = Vector3.new(105, 36, 49), science_bear = Vector3.new(269, 103, 19),
    polar_bear = Vector3.new(-106, 119, -77), start_area_to_area_15_jump = Vector3.new(-255, 4, 210),
    dispenser_honeystorm = Vector3.new(235, 34, 161), dispenser_honey = Vector3.new(45, 5, 321),
    dispenser_blueberry = Vector3.new(309, 4, 138), dispenser_sprout = Vector3.new(-270, 27, 264),
    dispenser_strawberry = Vector3.new(-319, 47, 270), dispenser_treat = Vector3.new(194, 69, -125),
    red_hq_entrance = Vector3.new(-280, 20, 215), red_hq_shop = Vector3.new(-330, 20, 214),
    red_hq_portal = Vector3.new(-358, 21, 186), red_hq_booster = Vector3.new(-318, 21, 245),
    red_hq_ladder_1_before = Vector3.new(-366, 20, 236), red_hq_ladder_1_after = Vector3.new(-371, 46, 279),
    red_hq_ladder_2_before = Vector3.new(-340, 46, 272), red_hq_ladder_2_after = Vector3.new(-340, 68, 249),
    red_hq_riley_jump = Vector3.new(-355, 68, 229), red_hq_riley_1 = Vector3.new(-379, 73, 217),
    red_hq_riley_final = Vector3.new(-358, 73, 211), red_hq_ledge = Vector3.new(-305, 46, 294),
    area_10_main = Vector3.new(234, 68, -123), area_10_ledge = Vector3.new(157, 68, -76),
    area_10_shop_entrance = Vector3.new(166, 68, -129), area_10_shop = Vector3.new(165, 69, -170),
    start_area_to_area_20_1 = Vector3.new(17, 4, 324), start_area_to_area_20_2_jump = Vector3.new(21, 7, 342),
    start_area_to_area_20_3 = Vector3.new(21, 15, 361), start_area_to_area_20_ladder_1_before = Vector3.new(4, 15, 404),
    start_area_to_area_20_ladder_1_after = Vector3.new(4, 32, 428), gate_20 = Vector3.new(45, 33, 432),
    area_20_hub = Vector3.new(82, 33, 499), area_20_ant_pass_free = Vector3.new(126, 33, 495),
    area_20_ant_pass_paid = Vector3.new(142, 33, 514), area_20_ant_leaderboard = Vector3.new(151, 32, 540),
    area_20_ant_challenge = Vector3.new(90, 33, 551), area_20_ant_npc = Vector3.new(43, 33, 544),
    rose_ramp_start = Vector3.new(-262, 20, 163), rose_ramp_end = Vector3.new(-262, 51, 83),
    royal_jelly_shop = Vector3.new(-298, 52, 74), rj_ladder_1_before = Vector3.new(-314, 51, 56),
    rj_ladder_1_after = Vector3.new(-314, 69, 38), blue_cannon_area_1 = Vector3.new(-311, 68, -38),
    area_15_rose_entrance = Vector3.new(-324, 68, -101), area_15_cactus = Vector3.new(-273, 68, -106),
    area_15_hub = Vector3.new(-273, 68, -180), area_5_to_area_15_ramp_start = Vector3.new(-117, 20, 53),
    area_5_to_area_15_ramp_mid = Vector3.new(-233, 35, 53), area_5_to_area_15_ramp_end = Vector3.new(-240, 68, -72),
    beesmas_stocking = Vector3.new(-401, 47, 280), beesmas_stocking_real = Vector3.new(234, 35, 233),
    beesmas_feast = Vector3.new(-107, 128, -113), beesmas_snow_machine = Vector3.new(277, 93, 104),
    beesmas_samovar = Vector3.new(425, 131, -337), beesmas_lid_art = Vector3.new(34, 235, -512),
    blue_hq_entrance = Vector3.new(243, 4, 97), blue_hq_shop = Vector3.new(297, 4, 97),
    blue_hq_portal = Vector3.new(322, 4, 110), area_25_ramp_start = Vector3.new(-247, 68, -237),
    area_25_ramp_1 = Vector3.new(-118, 118, -222), area_25_ramp_2 = Vector3.new(-84, 118, -157),
    area_25_ramp_3 = Vector3.new(-76, 118, -99), area_25_ramp_final = Vector3.new(96, 177, -77),
    dispenser_sprout_jump = Vector3.new(-272, 20, 245), beesmas_feast_jump = Vector3.new(-107, 119, -95),
    spawn = Vector3.new(-114, 5, 271), redcannon1 = Vector3.new(-211.5706787109375, 3.216403007507324, 312.3182373046875),
    redcannon2 = Vector3.new(-210.3050537109375, 16.276533126831055, 359.8916931152344),
    redcannonfinal = Vector3.new(-240.91615295410156, 16.69258689880371, 345.23077392578125),
    mountain_glide_start = Vector3.new(-363.0756530761719, 49.69074630737305, 378.2399597167969),
    mountain1 = Vector3.new(-424.2453308105469, 58.76872253417969, 417.800048828125),
    mountain2 = Vector3.new(-408.0086364746094, 70.68871307373047, 451.1204528808594),
    mountain3 = Vector3.new(-342.8199462890625, 80.64872741699219, 455.4044494628906),
    coconut1 = Vector3.new(-348.4117431640625, 96.73873901367188, 478.349365234375),
    coconut2 = Vector3.new(-417.2453308105469, 96.73873901367188, 491.0121765136719),
    coconut3 = Vector3.new(-430.0044860839844, 110.16871643066406, 507.6119689941403),
    coconut4 = Vector3.new(-443.28302001953125, 122.41875457763672, 512.27783203125)
}

local nodeLinks = {
    sf1 = {"sf2", "sunflower_fence_1", "start_area_to_area_15_jump", "start_area_to_area_20_1", "redcannon1"},
    sf2 = {"sf1", "dand_mush_w2", "dispenser_honey", "spawn", "leaderboard_daily_honey", "leaderboard_all_time_honey"},
    dand_mush_w1 = {"dand_mush_w2", "gate_5_ramp"}, dand_mush_w2 = {"dand_mush_w1", "dand_mush_mid", "sf2", "dispenser_honey", "start_area_to_area_20_1"},
    clover_ladder_1_before = {"dand_mush_w1", "clover_ladder_1_after", "instant_converter_1"},
    clover_ladder_1_after = {"clover_ladder_1_before", "clover_ladder_2_before", "instant_converter_1"},
    clover_ladder_2_before = {"clover_ladder_1_after", "clover_ladder_2_after", "instant_converter_1"},
    clover_ladder_2_after = {"clover_ladder_2_before", "gate_5_ramp", "sunflower_fence_1", "dand_mush_w1", "instant_converter_1", "dispenser_honeystorm", "wealth_clock_1", "beesmas_stocking_real"},
    sunflower_fence_1 = {"dand_mush_mid", "gate_5_ramp", "clover_ladder_1_before", "instant_converter_1", "start_area_to_area_15_jump"},
    dand_mush_mid = {"dand_mush_w1", "sunflower_fence_1", "gate_5_ramp", "instant_converter_1", "dand_mush_w2", "spawn"},
    gate_5_ramp = {"clover_ladder_1_before", "dand_mush_mid", "Blue_Front", "sunflower_fence_1", "instant_converter_1", "gate_5", "dand_mush_w1"},
    gate_5 = {"spider_bamboo_hub", "Blue_Front", "dand_mush_mid", "gate_5_ramp"}, Blue_Front = {"gate_5_ramp", "clover_ladder_1_before", "dand_mush_w1", "blue_hq_entrance"},
    spider_bamboo_hub = {"gate_5", "spider_bamboo_mid", "snow_bear", "gumdrop_shop", "spider_straw_mid", "area_5_to_area_15_ramp_start"},
    spider_straw_mid = {"spider_bamboo_hub", "spider_bamboo_mid", "dand_mush_mid", "bamboo_ramp_to_area_10", "area_5_to_area_15_ramp_start"},
    instant_converter_1 = {"sunflower_fence_1", "dand_mush_mid", "gate_5_ramp", "clover_ladder_1_before"},
    instant_converter_2 = {"area_10_main"}, dispenser_honeystorm = {"clover_ladder_2_after", "wealth_clock_1", "beesmas_stocking_real"},
    dispenser_honey = {"sf2", "dand_mush_w2", "start_area_to_area_20_1"}, dispenser_blueberry = {"blue_hq_shop", "blue_hq_portal"},
    wealth_clock_1 = {"brown_bear", "dispenser_honeystorm", "clover_ladder_2_after"},
    wealth_clock_2 = {"wealth_clock_1", "wealth_clock_3", "brown_bear", "clover_ladder_2_after"},
    wealth_clock_3 = {"wealth_clock_1", "wealth_clock_2", "wealth_clock_final", "brown_bear", "clover_ladder_2_after"},
    wealth_clock_final = {"wealth_clock_3", "clover_ladder_2_after"}, brown_bear = {"wealth_clock_1", "wealth_clock_2", "clover_ladder_2_after"},
    spawn = {"dand_mush_mid", "sf2", "leaderboard_daily_honey", "leaderboard_all_time_honey"},
    leaderboard_all_time_honey = {"spawn", "sf2"}, leaderboard_daily_honey = {"spawn", "sf2"},
    blue_hq_entrance = {"Blue_Front", "blue_hq_shop", "blue_hq_portal"}, blue_hq_shop = {"blue_hq_entrance", "blue_hq_portal", "dispenser_blueberry"},
    blue_hq_portal = {"blue_hq_shop", "dispenser_blueberry"}, snow_bear = {"gumdrop_shop", "spider_bamboo_hub", "spider_bamboo_mid"},
    gumdrop_shop = {"snow_bear", "spider_bamboo_hub", "spider_bamboo_mid"},
    spider_bamboo_mid = {"spider_bamboo_hub", "snow_bear", "gumdrop_shop", "spider_straw_mid", "bamboo_ramp_to_area_10", "area_5_to_area_15_ramp_start"},
    start_area_to_area_15_jump = {"sf1", "sunflower_fence_1", "red_hq_entrance", "redcannon1"},
    red_hq_entrance = {"start_area_to_area_15_jump", "red_hq_shop", "dispenser_sprout_jump", "rose_ramp_start", "redcannon1"},
    dispenser_sprout_jump = {"red_hq_entrance", "dispenser_sprout"}, red_hq_shop = {"red_hq_entrance", "red_hq_portal", "red_hq_booster", "red_hq_ladder_1_before"},
    red_hq_portal = {"red_hq_shop", "red_hq_booster"}, red_hq_booster = {"red_hq_shop", "red_hq_portal"},
    dispenser_sprout = {"dispenser_sprout_jump", "sf1"}, red_hq_ladder_1_before = {"red_hq_shop", "red_hq_ladder_1_after"},
    red_hq_ladder_1_after = {"red_hq_ladder_1_before", "red_hq_ladder_2_before", "beesmas_stocking", "red_hq_ledge", "dispenser_strawberry"},
    red_hq_ladder_2_before = {"red_hq_ladder_1_after", "red_hq_ladder_2_after"}, red_hq_ladder_2_after = {"red_hq_ladder_2_before", "red_hq_riley_jump"},
    red_hq_riley_jump = {"red_hq_ladder_2_after", "red_hq_riley_1"}, red_hq_riley_1 = {"red_hq_riley_jump", "red_hq_riley_final"},
    red_hq_riley_final = {"red_hq_ladder_2_after"}, beesmas_stocking = {"red_hq_ladder_1_after"},
    red_hq_ledge = {"red_hq_ladder_1_after", "dispenser_strawberry", "sf2"}, dispenser_strawberry = {"red_hq_ledge", "red_hq_ladder_1_after"},
    start_area_to_area_20_1 = {"sf2", "dispenser_honey", "dand_mush_w2", "start_area_to_area_20_2_jump"},
    start_area_to_area_20_2_jump = {"start_area_to_area_20_1", "start_area_to_area_20_3"},
    start_area_to_area_20_3 = {"start_area_to_area_20_1", "start_area_to_area_20_ladder_1_before"},
    start_area_to_area_20_ladder_1_before = {"start_area_to_area_20_3", "start_area_to_area_20_ladder_1_after"},
    start_area_to_area_20_ladder_1_after = {"start_area_to_area_20_ladder_1_before", "gate_20"},
    gate_20 = {"start_area_to_area_20_ladder_1_after", "area_20_hub", "start_area_to_area_20_1"},
    area_20_hub = {"gate_20", "area_20_ant_pass_free", "area_20_ant_pass_paid", "area_20_ant_leaderboard", "area_20_ant_challenge", "area_20_ant_npc", "stringer_shop"},
    area_20_ant_pass_free = {"area_20_hub"}, area_20_ant_pass_paid = {"area_20_hub"}, area_20_ant_leaderboard = {"area_20_hub"},
    area_20_ant_challenge = {"area_20_hub"}, area_20_ant_npc = {"area_20_hub"}, stringer_shop = {"area_20_hub"},
    panda_bear = {"area_5_ladder_1_after", "Blue_Front", "blue_hq_entrance", "gumdrop_shop", "leaderboard_battle_points"},
    leaderboard_battle_points = {"panda_bear", "Blue_Front", "blue_hq_entrance", "area_5_ladder_1_after"},
    bamboo_ramp_to_area_10 = {"spider_straw_mid", "area_5_ladder_1_before", "spider_bamboo_mid", "ramp_to_area_10_1"},
    area_5_ladder_1_before = {"bamboo_ramp_to_area_10", "area_5_ladder_1_after"},
    area_5_ladder_1_after = {"area_5_ladder_1_before", "panda_bear", "leaderboard_battle_points"},
    ramp_to_area_10_1 = {"bamboo_ramp_to_area_10", "ramp_to_area_10_2"}, ramp_to_area_10_2 = {"ramp_to_area_10_1", "ramp_to_area_10_3"},
    ramp_to_area_10_3 = {"ramp_to_area_10_2", "gate_10"}, gate_10 = {"ramp_to_area_10_3", "area_10_main"},
    area_10_main = {"gate_10", "area_10_ledge", "area_10_shop_entrance", "instant_converter_2", "dispenser_treat", "stump_path_start"},
    area_10_ledge = {"area_10_main", "bamboo_ramp_to_area_10"}, area_10_shop_entrance = {"area_10_main", "area_10_shop", "dispenser_treat"},
    area_10_shop = {"area_10_shop_entrance"}, dispenser_treat = {"area_10_main", "area_10_shop_entrance"},
    stump_path_start = {"area_10_main", "stump_path_end", "area_10_ramp_to_cannon_start"}, stump_path_end = {"stump_path_start"},
    area_10_ramp_to_cannon_start = {"area_10_main", "area_10_ramp_to_cannon_end", "stump_path_start"},
    area_10_ramp_to_cannon_end = {"area_10_ramp_to_cannon_start", "area_10_elevated_area_main"},
    area_10_elevated_area_main = {"area_10_ramp_to_cannon_end", "area_10_elevated_area_cannon_jump", "science_bear"},
    area_10_elevated_area_cannon_jump = {"area_10_cannon"}, area_10_cannon = {"area_10_elevated_area_cannon_jump", "spawn"},
    science_bear = {"area_10_elevated_area_main"}, rose_ramp_start = {"red_hq_entrance", "rose_ramp_end"},
    rose_ramp_end = {"rose_ramp_start", "royal_jelly_shop"}, royal_jelly_shop = {"rose_ramp_end", "rj_ladder_1_before"},
    rj_ladder_1_before = {"royal_jelly_shop", "rj_ladder_1_after"}, rj_ladder_1_after = {"rj_ladder_1_before", "blue_cannon_area_1"},
    blue_cannon_area_1 = {"rj_ladder_1_after", "area_15_rose_entrance"},
    area_15_rose_entrance = {"blue_cannon_area_1", "area_15_cactus", "area_15_hub"},
    area_15_cactus = {"area_15_rose_entrance", "area_15_hub", "area_5_to_area_15_ramp_end"},
    area_15_hub = {"area_15_rose_entrance", "area_15_cactus", "area_25_ramp_start"},
    area_5_to_area_15_ramp_start = {"spider_straw_mid", "spider_bamboo_hub", "spider_bamboo_mid", "area_5_to_area_15_ramp_mid"},
    area_5_to_area_15_ramp_mid = {"area_5_to_area_15_ramp_start", "area_5_to_area_15_ramp_end"},
    area_5_to_area_15_ramp_end = {"area_5_to_area_15_ramp_mid", "area_15_cactus"},
    beesmas_stocking_real = {"clover_ladder_2_after", "dispenser_honeystorm"},
    area_25_ramp_start = {"area_15_hub", "area_25_ramp_1"}, area_25_ramp_1 = {"area_25_ramp_start", "area_25_ramp_2"},
    area_25_ramp_2 = {"area_25_ramp_1", "area_25_ramp_3"}, area_25_ramp_3 = {"area_25_ramp_2", "polar_bear", "area_25_ramp_final"},
    area_25_ramp_final = {"area_25_ramp_3"}, polar_bear = {"area_25_ramp_3", "beesmas_feast_jump"},
    beesmas_feast_jump = {"beesmas_feast", "polar_bear"}, beesmas_feast = {"area_25_ramp_3", "beesmas_feast_jump"},
    redcannon1 = {"red_hq_entrance", "redcannon2", "start_area_to_area_15_jump"}, redcannon2 = {"redcannon1", "redcannonfinal"},
    redcannonfinal = {"redcannon2", "mountain_glide_start"}, mountain_glide_start = {"redcannonfinal", "mountain1"},
    mountain1 = {"mountain_glide_start", "mountain2"}, mountain2 = {"mountain1", "mountain3"},
    mountain3 = {"mountain2", "coconut1"}, coconut1 = {"mountain3", "coconut2"}, coconut2 = {"coconut1", "coconut3"},
    coconut3 = {"coconut2", "coconut4"}, coconut4 = {"coconut3"}
}

local fieldHubs = {
    ["Sunflower Field"] = "sunflower_fence_1", ["Dandelion Field"] = "dand_mush_mid", ["Mushroom Field"] = "dand_mush_mid",
    ["Blue Flower Field"] = "Blue_Front", ["Clover Field"] = "clover_ladder_2_after", ["Spider Field"] = "spider_bamboo_hub",
    ["Bamboo Field"] = "spider_bamboo_hub", ["Strawberry Field"] = "spider_straw_mid", ["Pineapple Patch"] = "area_10_main",
    ["Stump Field"] = "stump_path_end", ["Rose Field"] = "rose_ramp_start", ["Pumpkin Patch"] = "area_15_hub",
    ["Pine Tree Forest"] = "area_15_hub", ["Cactus Field"] = "area_15_cactus", ["Pepper Patch"] = "coconut4",
    ["Mountain Top Field"] = "mountain3", ["Coconut Field"] = "mountain3"
}

local cannonFields = {["Mountain Top Field"] = true, ["Coconut Field"] = true, ["Pepper Patch"] = true}

local specialNodes = {
    area_10_cannon = {action = "pressE", timing = "before"},
    redcannonfinal = {action = "pressE", timing = "before"}
}

local actions = {
    pressE = function() keypress(0x45) task.wait(0.1) keyrelease(0x45) end
}

local function RunNodeAction(node)
    local cfg = specialNodes[node]
    if not cfg then return false end
    if not cannonFields[activeField] then return false end
    local func = actions[cfg.action]
    if not func then return false end
    while not isrbxactive() do task.wait(0.5) end
    func()
    return true
end

local function FindPath(start, goal)
    if start == goal then return {start} end
    local dists, prev, open = {}, {}, {}
    for n in pairs(nodes) do dists[n] = math.huge; open[n] = true end
    dists[start] = 0
    while next(open) do
        local cur, minD = nil, math.huge
        for n in pairs(open) do
            if dists[n] < minD then minD = dists[n]; cur = n end
        end
        if not cur or minD == math.huge then break end
        if cur == goal then
            local p, n = {}, goal
            while n do table.insert(p, 1, n); n = prev[n] end
            return p
        end
        open[cur] = nil
        local neigh = nodeLinks[cur]
        if neigh then
            for _, nb in ipairs(neigh) do
                if open[nb] then
                    local cpos, npos = nodes[cur], nodes[nb]
                    local dx, dz = npos.X - cpos.X, npos.Z - cpos.Z
                    local edist = (cur == "area_10_cannon" and nb == "spawn") and 10 or math.sqrt(dx*dx + dz*dz)
                    local newD = dists[cur] + edist
                    if newD < dists[nb] then dists[nb] = newD; prev[nb] = cur end
                end
            end
        end
    end
    return nil
end

local function FollowPath(pathList, field)
    isFollowingPath = true
    activeField = field
    StopNav()
    task.wait(0.3)
    local char = LocalPlayer.Character
    if not char then isFollowingPath = false; return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then isFollowingPath = false; return false end
    StartJumpThread()
    for _, node in ipairs(pathList) do
        local tpos = nodes[node]
        if not tpos then StopJumpThread(); isFollowingPath = false; return false end
        navService.isActive = true
        navService.targetPos = tpos
        navService.hum = hum
        navService.char = char
        hum:MoveTo(tpos)
        local st = os.clock()
        while os.clock() - st < 30 do
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dx, dz = tpos.X - hrp.Position.X, tpos.Z - hrp.Position.Z
                if math.sqrt(dx*dx + dz*dz) < 6 then break end
            end
            task.wait(0.05)
        end
        navService.isActive = false
        if specialNodes[node] and specialNodes[node].action == "pressE" then
            task.wait(1)
            RunNodeAction(node)
            task.wait(0.5)
            if node == "redcannonfinal" then
                if field == "Mountain Top Field" then
                    StopJumpThread(); activeField = nil; isFollowingPath = false; return true
                else
                    keypress(0x20); keyrelease(0x20)
                    keypress(0x20); keyrelease(0x20)
                end
            end
        end
    end
    StopJumpThread(); activeField = nil; isFollowingPath = false
    return true
end

local function GotoField(fName)
    local hub = fieldHubs[fName]
    if not hub then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bestNode, bestDist = nil, math.huge
    for nName, nPos in pairs(nodes) do
        local dx, dz = hrp.Position.X - nPos.X, hrp.Position.Z - nPos.Z
        local d = math.sqrt(dx*dx + dz*dz)
        if d < bestDist then bestDist = d; bestNode = nName end
    end
    if bestNode then
        local route = FindPath(bestNode, hub)
        if route then FollowPath(route, fName) end
    end
end

local function GotoSpawn()
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local bestNode, bestDist = nil, math.huge
    for nName, nPos in pairs(nodes) do
        local dx, dz = hrp.Position.X - nPos.X, hrp.Position.Z - nPos.Z
        local d = math.sqrt(dx*dx + dz*dz)
        if d < bestDist then bestDist = d; bestNode = nName end
    end
    if bestNode then
        local route = FindPath(bestNode, "spawn")
        if route then FollowPath(route, nil); return true
        else WalkTo(nodes.spawn); return true end
    end
    return false
end

local function honeyCheck()
    local screenGui = LocalPlayer.PlayerGui:FindFirstChild("ScreenGui")
    if not screenGui then return false end
    local btn = screenGui:FindFirstChild("ActivateButton")
    if not btn then return false end
    return btn.TextBox.Text == "Stop Making Honey"
        or btn.BackgroundColor3 == Color3.new(201, 39, 28)
end

local fieldTable = {}
for _, v in next, Workspace.FlowerZones:GetChildren() do
    if not v.Name:find("Brick") and not v.Name:find("Hub") and not v.Name:find("Ant") then
        table.insert(fieldTable, v.Name)
        v.Size += Vector3.new(0, 70, 0)
    end
end

local function isPlayerInField(fieldName)
    local field = Workspace.FlowerZones:FindFirstChild(fieldName)
    if not field then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    for _, part in ipairs(Workspace:GetPartBoundsInBox(field.CFrame, field.Size)) do
        if part == hrp then return true end
    end
    return false
end

local function isCollectibleInField(fieldName, collectible)
    local field = Workspace.FlowerZones:FindFirstChild(fieldName)
    if not field then return false end
    for _, part in ipairs(Workspace:GetPartBoundsInBox(field.CFrame, field.Size)) do
        if part == collectible then return true end
    end
    return false
end

local function GetFieldCenter()
    local field = Workspace.FlowerZones:FindFirstChild(togs.farm.field)
    if not field then return nil end
    return field.Position
end

local function GetFieldSize()
    local field = Workspace.FlowerZones:FindFirstChild(togs.farm.field)
    if not field then return Vector3.new(50, 0, 50) end
    return field.Size
end

local function WalkToBlocking(pos)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    navService.isActive = true; navService.targetPos = pos; navService.hum = hum; navService.char = char
    hum:MoveTo(pos)
    local st = os.clock()
    while patternThreadActive and os.clock() - st < 12 do
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dx, dz = pos.X - hrp.Position.X, pos.Z - hrp.Position.Z
            if math.sqrt(dx*dx + dz*dz) < 4 then break end
        end
        task.wait(0.03)
    end
    navService.isActive = false
end

local function RunCirclePattern()
    local center = GetFieldCenter(); if not center then return end
    local fieldSize = GetFieldSize()
    local radius = math.min(fieldSize.X, fieldSize.Z) * 0.3
    local steps = 12
    while patternThreadActive and togs.farm.walkPattern == "Circle" and togs.farm.farm do
        for i = 1, steps do
            if not patternThreadActive or togs.farm.walkPattern ~= "Circle" or not togs.farm.farm then break end
            local angle = (i / steps) * math.pi * 2
            WalkToBlocking(Vector3.new(center.X + math.cos(angle) * radius, center.Y, center.Z + math.sin(angle) * radius))
        end
    end
end

local function RunZigzagPattern()
    local center = GetFieldCenter(); if not center then return end
    local fieldSize = GetFieldSize()
    local halfX = math.min(fieldSize.X * 0.35, 30)
    local halfZ = math.min(fieldSize.Z * 0.35, 30)
    local strips, dir = 5, 1
    while patternThreadActive and togs.farm.walkPattern == "Zigzag" and togs.farm.farm do
        for i = 0, strips do
            if not patternThreadActive or togs.farm.walkPattern ~= "Zigzag" or not togs.farm.farm then break end
            local zOffset = -halfZ + (i / strips) * halfZ * 2
            WalkToBlocking(Vector3.new(center.X + halfX * dir, center.Y, center.Z + zOffset))
            dir = dir * -1
        end
    end
end

local function RunRandomWanderPattern()
    local center = GetFieldCenter(); if not center then return end
    local fieldSize = GetFieldSize()
    local halfX = math.min(fieldSize.X * 0.4, 35)
    local halfZ = math.min(fieldSize.Z * 0.4, 35)
    while patternThreadActive and togs.farm.walkPattern == "Random Wander" and togs.farm.farm do
        WalkToBlocking(Vector3.new(center.X + (math.random() * 2 - 1) * halfX, center.Y, center.Z + (math.random() * 2 - 1) * halfZ))
    end
end

local function RunSnakePattern()
    local center = GetFieldCenter(); if not center then return end
    local fieldSize = GetFieldSize()
    local halfX = math.min(fieldSize.X * 0.4, 35)
    local halfZ = math.min(fieldSize.Z * 0.4, 35)
    local rows = 6
    while patternThreadActive and togs.farm.walkPattern == "Snake" and togs.farm.farm do
        for i = 0, rows do
            if not patternThreadActive or togs.farm.walkPattern ~= "Snake" or not togs.farm.farm then break end
            local xOffset = -halfX + (i / rows) * halfX * 2
            local side = (i % 2 == 0) and 1 or -1
            WalkToBlocking(Vector3.new(center.X + xOffset, center.Y, center.Z + halfZ * side))
            WalkToBlocking(Vector3.new(center.X + xOffset, center.Y, center.Z - halfZ * side))
        end
    end
end

local function RunSpiralPattern()
    local center = GetFieldCenter(); if not center then return end
    local fieldSize = GetFieldSize()
    local maxRadius = math.min(fieldSize.X, fieldSize.Z) * 0.225
    local stepSize, angle = 4, 0
    while patternThreadActive and togs.farm.walkPattern == "Spiral" and togs.farm.farm do
        for layer = 1, 5 do
            if not patternThreadActive or togs.farm.walkPattern ~= "Spiral" or not togs.farm.farm then break end
            local radius = math.min(layer * stepSize, maxRadius)
            local points = 12 + layer * 2
            for i = 1, points do
                if not patternThreadActive or togs.farm.walkPattern ~= "Spiral" or not togs.farm.farm then break end
                angle = (i / points) * math.pi * 2
                WalkToBlocking(Vector3.new(center.X + math.cos(angle) * radius, center.Y, center.Z + math.sin(angle) * radius))
            end
        end
        WalkToBlocking(center)
    end
end

local function RunCornerSnakePattern()
    local center = GetFieldCenter(); if not center then return end
    local fieldSize = GetFieldSize()
    local halfX = math.min(fieldSize.X * 0.25, 25)
    local halfZ = math.min(fieldSize.Z * 0.25, 25)
    local rows, dir = 4, 1
    while patternThreadActive and togs.farm.walkPattern == "Corner Snake" and togs.farm.farm do
        for i = 0, rows do
            if not patternThreadActive or togs.farm.walkPattern ~= "Corner Snake" or not togs.farm.farm then break end
            local zOffset = -halfZ + (i / rows) * halfZ * 2
            WalkToBlocking(Vector3.new(center.X - halfX + halfX * dir, center.Y, center.Z + zOffset))
            dir = dir * -1
        end
    end
end

local function StopPatternThread()
    patternThreadActive = false
end

local function StartPatternThread(patternName)
    StopPatternThread()
    task.wait(0.1)
    patternThreadActive = true
    task.spawn(function()
        StartJumpThread()
        if patternName == "Circle" then RunCirclePattern()
        elseif patternName == "Zigzag" then RunZigzagPattern()
        elseif patternName == "Random Wander" then RunRandomWanderPattern()
        elseif patternName == "Snake" then RunSnakePattern()
        elseif patternName == "Spiral" then RunSpiralPattern()
        elseif patternName == "Corner Snake" then RunCornerSnakePattern()
        end
        StopJumpThread()
        patternThreadActive = false
    end)
end

local visitedCoins = {}

local function StopTokenThread()
    tokenThreadActive = false
end

local function StartTokenThread()
    if tokenThreadActive then return end
    tokenThreadActive = true
    task.spawn(function()
        StartJumpThread()
        while tokenThreadActive and togs.farm.tokens and togs.farm.farm do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then task.wait(0.1); continue end
            if currentToken then
                local gone = not currentToken.Parent
                    or currentToken.Transparency == 0.699999988079071
                    or (hrp.Position - currentToken.Position).Magnitude < 8
                if gone then currentToken = nil end
            end
            if not currentToken then
                local candidates = {}
                for _, v in next, Workspace.Collectibles:GetChildren() do
                    if v.Name == "C" and v.Transparency ~= 0.699999988079071 and not visitedCoins[v] and isCollectibleInField(togs.farm.field, v) then
                        table.insert(candidates, {coin = v, distance = (v.Position - hrp.Position).Magnitude})
                    end
                end
                if #candidates > 0 then
                    table.sort(candidates, function(a, b) return a.distance < b.distance end)
                    currentToken = candidates[1].coin
                    visitedCoins[currentToken] = true
                else
                    visitedCoins = {}
                end
            end
            if currentToken and currentToken.Parent then
                local char2 = LocalPlayer.Character
                local hum = char2 and char2:FindFirstChild("Humanoid")
                if hum then
                    navService.isActive = true; navService.targetPos = currentToken.Position
                    navService.hum = hum; navService.char = char2
					togs.farm.iswalking = true
                    hum:MoveTo(currentToken.Position)
                end
                local st = os.clock()
                while tokenThreadActive and togs.farm.tokens and togs.farm.farm and os.clock() - st < 8 do
                    local c = LocalPlayer.Character
                    local h = c and c:FindFirstChild("HumanoidRootPart")
                    if not h then break end
                    if not currentToken.Parent or currentToken.Transparency == 0.699999988079071
                        or (h.Position - currentToken.Position).Magnitude < 8 then break end
                    task.wait(0.05)
                end
                navService.isActive = false
            else
                task.wait(0.1)
            end
        end
        StopJumpThread()
        tokenThreadActive = false
    end)
end

local function getMobTimerLabel(spawner)
    for _, v in ipairs(spawner:GetDescendants()) do
        if v:IsA("TextLabel") then return v end
    end
    return nil
end

local sprinklerRanges = {
    ["Basic Sprinkler"] = 8,
    ["Silver Soakers"] = 7,
    ["Golden Gushers"] = 8,
    ["Diamond Drenchers"] = 8,
    ["The Supreme Saturator"] = 16,
}

local sprinklerCounts = {
    ["Basic Sprinkler"] = 1,
    ["The Supreme Saturator"] = 1,
    ["Silver Soakers"] = 2,
    ["Golden Gushers"] = 3,
    ["Diamond Drenchers"] = 4,
}

local function getSprinklerOffsets(layout, count, range)
    local diameter = range * 2
    if layout == "Single" then
        return {Vector3.new(0, 0, 0)}
    elseif layout == "Line" then
        local offsets = {}
        for i = 1, count do
            local x = (i - 1) * diameter - ((count - 1) * diameter / 2)
            table.insert(offsets, Vector3.new(x, 0, 0))
        end
        return offsets
    elseif layout == "Triangle" then
        if count == 1 then
            return {Vector3.new(0, 0, 0)}
        elseif count == 2 then
            return {Vector3.new(-diameter / 2, 0, 0), Vector3.new(diameter / 2, 0, 0)}
        elseif count == 3 then
            local h = diameter * math.sqrt(3) / 2
            return {
                Vector3.new(0, 0, -h * 0.5),
                Vector3.new(-diameter / 2, 0, h * 0.5),
                Vector3.new(diameter / 2, 0, h * 0.5),
            }
        elseif count == 4 then
            local h = diameter * math.sqrt(3) / 2
            return {
                Vector3.new(0, 0, -h * (2/3)),
                Vector3.new(-diameter / 2, 0, 0),
                Vector3.new(diameter / 2, 0, 0),
                Vector3.new(0, 0, h * (2/3)),
            }
        end
    elseif layout == "Square" then
        if count == 1 then
            return {Vector3.new(0, 0, 0)}
        elseif count == 2 then
            return {Vector3.new(-diameter / 2, 0, 0), Vector3.new(diameter / 2, 0, 0)}
        elseif count == 3 then
            return {
                Vector3.new(-diameter / 2, 0, -diameter / 2),
                Vector3.new(diameter / 2, 0, -diameter / 2),
                Vector3.new(0, 0, diameter / 2),
            }
        elseif count == 4 then
            return {
                Vector3.new(-diameter / 2, 0, -diameter / 2),
                Vector3.new(diameter / 2, 0, -diameter / 2),
                Vector3.new(-diameter / 2, 0, diameter / 2),
                Vector3.new(diameter / 2, 0, diameter / 2),
            }
        end
    end
    return {Vector3.new(0, 0, 0)}
end

local function waitForPlayerStopped()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local deadline = os.clock() + 10
    while os.clock() < deadline do
        local vel = hrp.Velocity
        if math.abs(vel.X) < 1 and math.abs(vel.Z) < 1 then
            task.wait(0.3)
            vel = hrp.Velocity
            if math.abs(vel.X) < 1 and math.abs(vel.Z) < 1 then return end
        end
        task.wait(0.05)
    end
end

local function walkToAndStop(targetPos)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    hum:MoveTo(targetPos)
    local deadline = os.clock() + 8
    while os.clock() < deadline do
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then break end
        local dx, dz = targetPos.X - hrp.Position.X, targetPos.Z - hrp.Position.Z
        if math.sqrt(dx * dx + dz * dz) < 2 then break end
        task.wait(0.05)
    end
    waitForPlayerStopped()
end

local function makesprinklers()
    togs.farm.placingsprinklers = true
    local stats = getstats()
    local sprinklerName = (stats and stats.EquippedSprinkler) or "Basic Sprinkler"
    local count = sprinklerCounts[sprinklerName] or 1
    local range = sprinklerRanges[sprinklerName] or 5.5

    waitForPlayerStopped()

    local char = LocalPlayer.Character
    if not char then togs.farm.placingsprinklers = false; return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then togs.farm.placingsprinklers = false; return end

    local layout = togs.farm.sprinklerLayout
    local offsets = getSprinklerOffsets(layout, count, range)
    local basePos = hrp.Position

    for i, offset in ipairs(offsets) do
        char = LocalPlayer.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if not hrp or not hum then break end

        if offset.Magnitude > 1 then
            walkToAndStop(Vector3.new(basePos.X + offset.X, basePos.Y, basePos.Z + offset.Z))
        end

        char = LocalPlayer.Character
        hum = char and char:FindFirstChild("Humanoid")
        if not hum then break end

        if count > 1 then
            local savedJP = hum.JumpPower
            hum.JumpPower = 70
            hum.Jump = true
            task.wait(0.2)
            hum.JumpPower = savedJP
        end

        ReplicatedStorage.Events.PlayerActivesCommand:FireServer({["Name"] = "Sprinkler Builder"})
        task.wait(1)
    end

    togs.farm.placingsprinklers = false
end

local repo = "https://raw.githubusercontent.com/GoogleCreator/ObsidianUi/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local Options = Library.Options
local Toggles = Library.Toggle
local Window = Library:CreateWindow({
    Title = `<font color='rgb(255, 75, 75)'>Red</font>wyre`,
    Footer = "redwyre.vercel.app",
    Icon = 121032629321494,
    NotifySide = "Right",
    ShowCustomCursor = false,
    Center = true,
    ToggleKeybind = Enum.KeyCode.RightControl,
    Size = UDim2.fromOffset(720, 480)
})

local Tabs = {
    Stats = Window:AddTab("Stats", "user"),
    Farm = Window:AddTab("Farm", "shovel"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local LeftGroupStats = Tabs.Stats:AddLeftGroupbox("Session", "user")
local LblWindyFavor   = LeftGroupStats:AddLabel("Windy Favor", true)
local LblHoneyAllTime = LeftGroupStats:AddLabel("Honey All Time", true)
local LblHoneySession = LeftGroupStats:AddLabel("Honey This Session", true)
local LblRuntime      = LeftGroupStats:AddLabel("Runtime", true)
local LblHPH          = LeftGroupStats:AddLabel("Honey/Hour", true)
local LblPollen       = LeftGroupStats:AddLabel("Pollen", true)
local LblCapacity     = LeftGroupStats:AddLabel("Capacity", true)

local MobGroupLeft = Tabs.Stats:AddRightGroupbox("Mob Spawns", "alert-triangle")
local mobLabels = {}
for _, spawner in ipairs(Workspace.MonsterSpawners:GetChildren()) do
    if spawner:IsA("Model") or spawner:IsA("Folder") or spawner:IsA("BasePart") then
        local name = spawner.Name
        mobLabels[name] = MobGroupLeft:AddLabel(name .. ": ...", true)
    end
end

local LeftGroupFarm = Tabs.Farm:AddLeftGroupbox("Farming", "user")

local Fields = LeftGroupFarm:AddDropdown("FieldDropdown", {
    Text = "Field",
    Values = fieldTable,
    Default = fieldTable[1],
    Multi = false,
    Tooltip = "Field to farm?",
    Callback = function(Value)
        togs.farm.field = Value
        sprinklersPlaced = false
    end
})

local walkPatterns = {"None", "Collect Tokens", "Circle", "Zigzag", "Random Wander", "Snake", "Spiral", "Corner Snake"}
LeftGroupFarm:AddDropdown("WalkPatternDropdown", {
    Text = "Walk Pattern",
    Values = walkPatterns,
    Default = "None",
    Multi = false,
    Tooltip = "Choose how the player moves while farming.",
    Callback = function(Value)
        togs.farm.walkPattern = Value
        if Value == "Collect Tokens" then
            togs.farm.tokens = true
            StopPatternThread()
            if togs.farm.farm then StartTokenThread() end
        else
            togs.farm.tokens = false
            StopTokenThread()
            StopPatternThread()
            if togs.farm.farm and Value ~= "None" and isPlayerInField(togs.farm.field) then
                StartPatternThread(Value)
            end
        end
    end
})

LeftGroupFarm:AddDropdown("SprinklerLayoutDropdown", {
    Text = "Sprinkler Layout",
    Values = {"Single", "Line", "Triangle", "Square"},
    Default = "Single",
    Multi = false,
    Tooltip = "Shape to sprinklers in.",
    Callback = function(Value)
        togs.farm.sprinklerLayout = Value
    end
})

LeftGroupFarm:AddToggle("FarmField", {
    Text = "Farm Field",
    Default = false,
    Tooltip = "Farm selected field.",
    Callback = function(Value)
        togs.farm.farm = Value
        if not Value then
            StopPatternThread()
            StopTokenThread()
            sprinklersPlaced = false
        end
    end
})

LeftGroupFarm:AddToggle("AutoCollect", {
    Text = "Auto Collect",
    Default = false,
    Tooltip = "Auto collects pollen.",
    Callback = function(Value)
        togs.farm.autodig = Value
    end
})

LeftGroupFarm:AddToggle("AutoSprinklers", {
    Text = "Place Sprinklers",
    Default = false,
    Tooltip = "Auto places your sprinklers.",
    Callback = function(Value)
        togs.farm.autosprinklers = Value
        if not Value then sprinklersPlaced = false end
    end
})

LeftGroupFarm:AddToggle("AutoConvert", {
    Text = "Auto Convert",
    Default = false,
    Tooltip = "Auto walk to spawn and convert when full.",
    Callback = function(Value)
        togs.farm.autoconvert = Value
    end
})

LeftGroupFarm:AddSlider("ConvertPercentSlider", {
    Text = "Convert %",
    Default = 95,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Tooltip = "Convert when pollen reaches this % of capacity.",
    Callback = function(Value)
        togs.farm.convertPercent = Value
    end
})

local startStats = getstats()
local startHoney = (startStats and startStats.Totals and startStats.Totals.Honey) or 0
local startTime  = tick()

local function updateStatsLabels()
    local rs = getstats()
    local allTimeHoney = getstats().Totals.Honey or 0
    local sessionHoney = allTimeHoney - startHoney
    local elapsed = tick() - startTime
    local pollenNow = LocalPlayer.CoreStats and LocalPlayer.CoreStats.Pollen and LocalPlayer.CoreStats.Pollen.Value or 0
    local capNow = LocalPlayer.CoreStats and LocalPlayer.CoreStats.Capacity and LocalPlayer.CoreStats.Capacity.Value or 1
    local hph = (elapsed > 10) and ((sessionHoney / elapsed) * 3600) or 0
    local windyFavor = getstats().WindShrine.WindyFavor or 0
    LblWindyFavor:SetText(`<font color='rgb(234, 112, 250)'>Windy Favor</font>: <b>{formatHoney(windyFavor)}</b>`)
    LblHoneyAllTime:SetText(`<font color='rgb(255, 215, 0)'>Honey All Time</font>: <b>{formatHoney(allTimeHoney)}</b>`)
    LblHoneySession:SetText(`<font color='rgb(255, 215, 0)'>Honey This Session</font>: <b>{formatHoney(sessionHoney)}</b>`)
    LblRuntime:SetText(`<font color='rgb(100, 200, 255)'>Runtime</font>: <b>{formatTime(elapsed)}</b>`)
    LblHPH:SetText(`<font color='rgb(0, 255, 150)'>Honey/Hour</font>: <b>{formatHoney(hph)}</b>`)
    LblPollen:SetText(`<font color='rgb(255, 180, 80)'>Pollen</font>: <b>{formatHoney(pollenNow)} ({pct(pollenNow, capNow)})</b>`)
    LblCapacity:SetText(`<font color='rgb(200, 200, 200)'>Capacity</font>: <b>{formatHoney(capNow)}</b>`)
end

local function updateMobLabels()
    for _, spawner in ipairs(Workspace.MonsterSpawners:GetChildren()) do
        local name = spawner.Name
        local lbl = mobLabels[name]
        if not lbl then continue end
        local timerLabel = getMobTimerLabel(spawner)
        if timerLabel then
            if timerLabel.Text == "1:00" or timerLabel.Text:find("1s") and not timerLabel.Text:find("11s") and not timerLabel.Text:find("21s") and not timerLabel.Text:find("31s") and not timerLabel.Text:find("41s") and not timerLabel.Text:find("51s") then
                lbl:SetText(name .. ":" .. `<font color='rgb(0, 255, 150)'> Ready!</font>`)
            else
                lbl:SetText(`<font color='rgb(255, 75, 75)'>` .. timerLabel.Text .. `</font>`)
            end
        else
            lbl:SetText(name .. ": ...")
        end
    end
end

local spawnPos = Instance.new("Part", Workspace)
spawnPos.Anchored = true
spawnPos.CanCollide = false
spawnPos.Transparency = 1
spawnPos.CFrame = LocalPlayer.SpawnPos.Value + Vector3.new(0, 0, 9)

pcall(updateStatsLabels)
pcall(updateMobLabels)

task.spawn(function()
    while task.wait() do
        if togs.farm.farm then
            LocalPlayer:WaitForChild("PlayerScripts").ControlScript.Disabled = true
        else
            LocalPlayer:WaitForChild("PlayerScripts").ControlScript.Disabled = false
            StopNav()
            StopJumpThread()
            isFollowingPath = false
            StopPatternThread()
            StopTokenThread()
            sprinklersPlaced = false
        end

        if togs.farm.farm and not isPlayerInField(togs.farm.field) and not isFollowingPath and not togs.farm.isconverting then
            StopPatternThread()
            StopTokenThread()
            GotoField(togs.farm.field)
            WalkTo(Workspace.FlowerZones[togs.farm.field].Position)
            local startWait = tick()
            while togs.farm.farm and not isPlayerInField(togs.farm.field) and (tick() - startWait) < 25 do
                task.wait(0.2)
            end
            sprinklersPlaced = false
        end

        if togs.farm.farm and isPlayerInField(togs.farm.field) and not isFollowingPath and not togs.farm.isconverting then
            if togs.farm.autosprinklers and not sprinklersPlaced then
                makesprinklers()
                sprinklersPlaced = true
            end
            if not togs.farm.placingsprinklers then
                local pat = togs.farm.walkPattern
                if pat ~= "None" and pat ~= "Collect Tokens" and not patternThreadActive then
                    StartPatternThread(pat)
                elseif pat == "Collect Tokens" and not tokenThreadActive then
                    StartTokenThread()
                end
            end
        end

        if togs.farm.farm and togs.farm.autoconvert then
            local capacity = LocalPlayer.CoreStats.Capacity.Value
            local pollen   = LocalPlayer.CoreStats.Pollen.Value
            local threshold = (togs.farm.convertPercent / 100) * capacity
            if pollen >= threshold and pollen > 0 and not togs.farm.isconverting then
                togs.farm.isconverting = true
                StopPatternThread()
                StopTokenThread()
                GotoSpawn()
                WalkTo(spawnPos.Position)
                repeat
                    task.wait()
                    pollen = getstats().Pollen or 0
                    if not honeyCheck() then
                        keypress(0x45); keyrelease(0x45)
                        task.wait(1)
                    end
                until pollen == 0
                togs.farm.isconverting = false
                sprinklersPlaced = false
            end
        end

        if togs.farm.autodig then
            ReplicatedStorage:WaitForChild("Events"):WaitForChild("ToolCollect"):FireServer()
        end
    end
end)

task.spawn(function()
    while task.wait() do
        pcall(updateStatsLabels)
        pcall(updateMobLabels)
    end
end)
