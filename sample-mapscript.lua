-- # (4) Battle Isle Sample Script ------------------------------+
-- | This is a sample mapscript for the (4) Battle Isle Map.     |
-- | Make sure you set the AI's entities to a playerId above 4   |
-- | otherwise the entities get deletet because the id's 1-4 are |
-- | reserved for the human players.                             |
-- | This setup was tested with 3 human players vs 1 AI, the AI  |
-- | is going to attack the players next to it after ~20min when |
-- | winter is going to enable the travelling to them.           |
-- +-------------------------------------------------------------|

function GameCallback_OnGameStart()
    Script.Load(Folders.MapTools.."MultiPlayer\\MultiplayerTools.lua")
    Script.Load(Folders.MapTools.."Comfort.lua")
    Script.Load(Folders.MapTools.."PlayerColors.lua")
    Script.Load(Folders.MapTools.."WeatherSets.lua")
    Script.Load(Folders.MapTools.."MapEditorTools.lua")

	Display.LoadAllModels()
    
    Mission_InitWeatherGfxSets()
    Mission_InitWeather()

    MultiplayerTools.InitResources("normal")
    MultiplayerTools.InitCameraPositionsForPlayers()
    MultiplayerTools.SetUpGameLogicOnMPGameConfig()
    MultiplayerTools.GiveBuyableHerosToHumanPlayer(3)

    if XNetwork.Manager_DoesExist() == 0 then
        for i = 1, 4, 1 do MultiplayerTools.DeleteFastGameStuff(i) end

        local playerId = GUI.GetPlayerID()

        Logic.PlayerSetIsHumanFlag(playerId, 1)
        Logic.PlayerSetGameStateToPlaying(playerId)
    end

    LocalMusic.UseSet = EVELANCEMUSIC

    -- # Debug shit
    -- XGUIEng.ShowWidget("3dOnScreenDebug", 1)

    -- Display.SetRenderFogOfWar(-1)
    -- GUI.MiniMap_SetRenderFogOfWar(-1)

    -- StartJob("Modifier")

    -- XGUIEng.ShowWidget("DebugWindow", 1)
    -- DebugString = "Test"
    -- XGUIEng.SetText("DebugWindow", DebugString)

    -- Input.KeyBindDown(Keys.NumPad1, "CreateMilitaryGroup(1, Entities.CU_BanditLeaderSword2, 8, GetPosition(\"P2_StartPos\"))", 2)
    -- Input.KeyBindDown(Keys.NumPad2, "CreateMilitaryGroup(1, Entities.CU_BanditLeaderSword2, 8, GetPosition(\"P3_StartPos\"))", 2)
    -- Input.KeyBindDown(Keys.NumPad3, "CreateMilitaryGroup(1, Entities.CU_BanditLeaderSword2, 8, GetPosition(\"P4_StartPos\"))", 2)
    -- Input.KeyBindDown(Keys.NumPad4, "MakeStrongerAi()", 2)

    -- # Blazing fast game
    -- for i = 1, 64, 1 do
    --     SpeedUpGame()
    -- end       

	-- gvCamera.ZoomDistanceMin = 1200
	-- gvCamera.ZoomDistanceMax = 6000
    -- Camera.ZoomSetFactor(1.5)

    GUI.AddNote("Map setup successful...")

    -- # Shared Camera Vision for Player 1, 2 and 3
    Logic.SetShareExplorationWithPlayerFlag(1, 2, 1);    
    Logic.SetShareExplorationWithPlayerFlag(2, 1, 1);   

    Logic.SetShareExplorationWithPlayerFlag(1, 3, 1);
    Logic.SetShareExplorationWithPlayerFlag(3, 1, 1);

    Logic.SetShareExplorationWithPlayerFlag(3, 2, 1);
    Logic.SetShareExplorationWithPlayerFlag(2, 3, 1);

    SetFriendly(1, 2)
    SetFriendly(1, 3)
    SetFriendly(2, 3)

    SetHostile(1, 4)
    SetHostile(2, 4)
    SetHostile(3, 4)

    -- # AngusAI setup
    AngusAI_Init()
    AngusAI_Add(5, "Der Wingl", "P4_StartPos", NPC_COLOR, 200, 450, 3, 1000000)
end

function Mission_InitWeatherGfxSets()
    Display.SetRenderUseGfxSets(1)

    WeatherSets_SetupEvelance(1)
    WeatherSets_SetupEvelanceRain(2)
    WeatherSets_SetupEvelanceSnow(3)
end

function Mission_InitWeather()
    Logic.SetupGfxSet(1)

    -- summer Peacetime
    Logic.AddWeatherElement(1, math.random(500, 760), 1, 1, 5, 10)

    -- add some random weather after the peacetime weather
    for i = 1, 16 do
        Logic.AddWeatherElement(1, math.random(300, 450), 1, 1, 5, 10)	-- Summer
        Logic.AddWeatherElement(3, math.random(400, 670), 1, 3, 5, 10)	-- Winter with Snow
        Logic.AddWeatherElement(2, math.random(50, 120), 1, 2, 5, 10)	-- Foggy with Rain
    end
end

-- # AngusAI --------------------------------------------------------------------------+
-- | see this for more info: https://github.com/Jnnshschl/Settlers5-AngusAI            |
-- |                                                                                   |
-- | This is going to be a comfort script to setup random Settlers 5 AI's with ease    |
-- | Version: 0.1                                                                      |
-- +-----------------------------------------------------------------------------------+

-- # Globals
AngusAI_G_Enabled = {}
AngusAI_G_Names = {}

-- # Upgrades
AngusAI_G_AvailableUpgrades = {
    { UpgradeCategories.LeaderPoleArm, UpgradeCategories.SoldierPoleArm,},
	{ UpgradeCategories.LeaderSword, UpgradeCategories.SoldierSword,},
	{ UpgradeCategories.LeaderBow, UpgradeCategories.SoldierBow,},
	{ UpgradeCategories.LeaderCavalry, UpgradeCategories.SoldierCavalry,},
	{ UpgradeCategories.LeaderHeavyCavalry, UpgradeCategories.SoldierHeavyCavalry,},
	{ UpgradeCategories.LeaderRifle, UpgradeCategories.SoldierRifle },
}

AngusAI_G_TimeElapsed = 0
AngusAI_G_TimeUntilUpgradeMin = {}
AngusAI_G_TimeUntilUpgradeMax = {}
AngusAI_G_NextUpgradeTime = {}
AngusAI_G_UpgradeStatus = {}

-- # Public API
function AngusAI_Init()
    GUI.AddNote("@color:255,180,40 [AngusAI] @color:255,255,255 Initializing")
    Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, nil, "AngusAI_Callback_Upgrades", 1, nil, nil)
end

function AngusAI_Add(playerId, playerName, playerPosition, playerColor, minUpgradeTime, maxUpgradeTime, playerStrength, playerRange)
    GUI.AddNote("@color:255,180,40 [AngusAI] @color:255,255,255 Enabling player: ["..playerId.."] @color:190,255,0 "..playerName)

    AngusAI_G_Enabled[playerId] = true
    AngusAI_G_Names[playerId] = playerName
    AngusAI_G_TimeUntilUpgradeMin[playerId] = minUpgradeTime
    AngusAI_G_TimeUntilUpgradeMax[playerId] = maxUpgradeTime

    SetPlayerName(playerId, playerName);

    if playerColor ~= nil then
        Display.SetPlayerColorMapping(playerId, playerColor)
    end

    AngusAI_G_UpgradeStatus[playerId] = {}

    for i = 1, table.getn(AngusAI_G_AvailableUpgrades) do
        AngusAI_G_UpgradeStatus[playerId][AngusAI_G_AvailableUpgrades[i]] = 0
    end

    AngusAI_G_NextUpgradeTime[playerId] = AngusAI_G_TimeElapsed + math.random(minUpgradeTime, maxUpgradeTime)

    -- Settler 5 AI
    local description = {
        serfLimit = 32,
        extracting = 1,
        constructing = true,
        repairing = true,
        resources = { gold = 3000, clay = 1000, iron = 1000, sulfur = 1000, stone = 1000, wood = 1500 },
    }

    -- Settler 5 Contruction Plans
    local position = invalidPosition -- GetPosition("P2_StartPos")

    construction = {
        {type = Entities.PB_University1, pos = GetPosition("P4_StartPos"), level = 1},
        {type = Entities.PB_Residence1, pos = position},
        {type = Entities.PB_Farm1, pos = position},

        {type = Entities.PB_IronMine1, pos = position},
        {type = Entities.PB_Residence1, pos = position},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Residence1, pos = position, level = 1},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Brickworks1, pos = position, level = 1},
        {type = Entities.PB_Sawmill1, pos = position, level = 1},

        {type = Entities.PB_Foundry1, pos = position, level = 1},
        {type = Entities.PB_Blacksmith1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Bank1, pos = position, level = 1},
        {type = Entities.PB_Residence1, pos = position, level = 1},
        {type = Entities.PB_Farm1, pos = position, level = 1},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_VillageCenter1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Archery1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Stable1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Barracks1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Monastery1, pos = position, level = 2},
        {type = Entities.PB_Residence1, pos = position, level = 1},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Residence1, pos = position, level = 1},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Market1, pos = position, level = 1},
        {type = Entities.PB_Residence1, pos = position, level = 1},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Residence1, pos = position, level = 1},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_VillageCenter1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_StoneMason1, pos = position, level = 1},
        {type = Entities.PB_Residence1, pos = position, level = 1},
        {type = Entities.PB_Farm1, pos = position, level = 1},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Alchemist1, pos = position, level = 1},
        {type = Entities.PB_Residence1, pos = position, level = 1},
        {type = Entities.PB_Farm1, pos = position, level = 1},

        {type = Entities.PB_IronMine1, pos = position},
        {type = Entities.PB_Residence1, pos = position},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_SulfurMine1, pos = position},
        {type = Entities.PB_Residence1, pos = position},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_StoneMine1, pos = position},
        {type = Entities.PB_Residence1, pos = position},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_SulfurMine1, pos = position},
        {type = Entities.PB_Residence1, pos = position},
        {type = Entities.PB_Farm1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_VillageCenter1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_PowerPlant1, pos = position, level = 2},
        {type = Entities.PB_PowerPlant1, pos = position, level = 2},
        {type = Entities.PB_PowerPlant1, pos = position, level = 2},
        {type = Entities.PB_PowerPlant1, pos = position, level = 2},
        {type = Entities.PB_PowerPlant1, pos = position, level = 2},
        {type = Entities.PB_PowerPlant1, pos = position, level = 2},
        {type = Entities.PB_PowerPlant1, pos = position, level = 2},
        {type = Entities.PB_PowerPlant1, pos = position, level = 2},
        {type = Entities.PB_WeatherTower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_VillageCenter1, pos = position, level = 1},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},

        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
        {type = Entities.PB_Tower1, pos = position, level = 2},
    }

    local researchFile = {
        {type = Entities.PB_VillageCenter1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Residence1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Residence1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Farm1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Residence1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Farm1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Farm1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Residence1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Farm1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Barracks1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Archery1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower2, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower2, prob = 100, command = UPGRADE},
        {type = Entities.PB_Residence1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Residence1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Residence1, prob = 100, command = UPGRADE},
        {type = Entities.PB_ClayMine1, prob = 100, command = UPGRADE},
        {type = Entities.PB_StoneMine1, prob = 100, command = UPGRADE},
        {type = Entities.PB_University1, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower2, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower2, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower2, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower3, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower3, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower3, prob = 100, command = UPGRADE},
        {type = Entities.PB_Tower3, prob = 100, command = UPGRADE}
    }

    MapEditor_SetupAI(playerId, playerStrength, playerRange, 0, playerPosition, playerStrength, 0)
    SetupPlayerAi(playerId, description)

    FeedAiWithConstructionPlanFile(playerId, construction)
    FeedAiWithResearchPlanFile(playerId, researchFile)
end

function AngusAI_IsEnbaled(playerId)
    return AngusAI_G_Enabled[playerId] ~= nil and AngusAI_G_Enabled[playerId]
end

function AngusAI_GetUpgradeStatus(playerId, catergory)
    return AngusAI_G_UpgradeStatus[playerId][catergory]
end

function AngusAI_RandomUpgrade(playerId)
    local category = AngusAI_G_AvailableUpgrades[math.random(1, table.getn(AngusAI_G_AvailableUpgrades))]
    local currentStatus = AngusAI_GetUpgradeStatus(playerId, category)

    if currentStatus < 3 then
        Logic.UpgradeSettlerCategory(category[1], playerId)
        Logic.UpgradeSettlerCategory(category[2], playerId)
        AngusAI_G_UpgradeStatus[playerId][category] = AngusAI_G_UpgradeStatus[playerId][category] + 1
    end
end

-- # Internal Stuff
function AngusAI_Callback_Upgrades()
    AngusAI_G_TimeElapsed = AngusAI_G_TimeElapsed + 1

    for i = 1, 8 do
        if AngusAI_IsEnbaled(i) then
            local timeNeeded = AngusAI_G_NextUpgradeTime[i]
            local timeLeft = timeNeeded - AngusAI_G_TimeElapsed

            if timeLeft <= 0 then
                AngusAI_RandomUpgrade(i)
                AngusAI_G_NextUpgradeTime[i] = AngusAI_G_TimeElapsed + math.random(AngusAI_G_TimeUntilUpgradeMin[i], AngusAI_G_TimeUntilUpgradeMax[i])
            end
        end
    end
end

-- # End AngusAI