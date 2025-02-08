local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LOCAL_PLAYER = Players.LocalPlayer
local UNIT_STORAGE = workspace:FindFirstChild("_UNITS")
local GAME_ID = 14229762361
local JUDAR_JSON_FILE = "JudarData.json"

-- **Ensure Required Services are Loaded**
local Loader = require(ReplicatedStorage.src.Loader)
local ItemInventoryServiceClient = nil
repeat
    task.wait(1) -- Wait until the service is available
    ItemInventoryServiceClient = Loader.load_client_service(script, "ItemInventoryServiceClient")
until ItemInventoryServiceClient

if not ItemInventoryServiceClient then
    error("Failed to load ItemInventoryServiceClient!")
end

print("ItemInventoryServiceClient loaded successfully.")

-- **Check if Player is in the Target Game**
local function isInTargetGame()
    return game.PlaceId == GAME_ID
end

-- **Load Team Loadout**
local function loadTeamLoadout(loadout)
    if ReplicatedStorage.endpoints.client_to_server.load_team_loadout then
        ReplicatedStorage.endpoints.client_to_server.load_team_loadout:InvokeServer(tostring(loadout))
    else
        warn("Failed to load team loadout: Endpoint not found!")
    end
end

-- **Equip a Unit by UUID**
local function equipUnit(uuid)
    if ReplicatedStorage.endpoints.client_to_server.equip_unit then
        ReplicatedStorage.endpoints.client_to_server.equip_unit:InvokeServer(uuid)
    else
        warn("Failed to equip unit: Endpoint not found!")
    end

    -- **Ensure Equipped Units Refresh Properly**
    if ItemInventoryServiceClient and ItemInventoryServiceClient.refresh_equipped_units then
        ItemInventoryServiceClient.refresh_equipped_units()
    else
        warn("refresh_equipped_units function not available!")
    end
end

-- **Get All Owned Units**
local function getUnitsOwner()
    if ItemInventoryServiceClient then
        return ItemInventoryServiceClient["session"]["collection"]["collection_profile_data"]["owned_units"]
    end
    return {}
end

-- **Log Judar's UUID and Total Takedowns**
local function logJudarInfo()
    local judarData = {}

    for _, unit in pairs(getUnitsOwner()) do
        if unit["unit_id"]:lower() == "judar" then
            table.insert(judarData, { uuid = unit["uuid"], total_takedowns = unit["total_takedowns"] or 0 })
        end
    end

    return judarData
end

-- **Create JSON File**
local function createJsonFile(fileName, jsonData)
    local jsonString = HttpService:JSONEncode(jsonData)
    writefile(fileName, jsonString)
    print("JSON file created: " .. fileName)
end

-- **Save Judar Data**
local function saveFilteredJudarData()
    local judarData = logJudarInfo()
    createJsonFile(JUDAR_JSON_FILE, judarData)
end

-- **Fetch the Best Judar UUID (Highest Takedowns < 10k)**
local function getBestJudarUUID()
    if isfile(JUDAR_JSON_FILE) then
        local data = readfile(JUDAR_JSON_FILE)
        local judarList = HttpService:JSONDecode(data) or {}

        table.sort(judarList, function(a, b)
            return a.total_takedowns > b.total_takedowns -- Sort by highest takedowns
        end)

        for _, judar in ipairs(judarList) do
            if judar.total_takedowns < 10000 then
                return judar.uuid
            end
        end
    end
    return nil
end

-- **Find the 40% Mark in Lane for Placement**
local function getLaneMidpoint()
    local lane = workspace._BASES.pve.LANES["1"]
    local spawnPosition, finalPosition = lane.spawn.Position, lane.final.Position
    local targetDistance = (finalPosition - spawnPosition).magnitude * 0.40

    local closestPart, closestDifference = nil, math.huge
    for _, obj in ipairs(lane:GetChildren()) do
        if obj:IsA("BasePart") then
            local partDistance = (obj.Position - spawnPosition).magnitude
            local difference = math.abs(partDistance - targetDistance)
            if difference < closestDifference then
                closestDifference, closestPart = difference, obj
            end
        end
    end

    return closestPart and closestPart.Position or (spawnPosition + (finalPosition - spawnPosition).unit * targetDistance)
end

-- **Place 3 Judars**
local function placeJudars(basePosition, judarUUID)
    local positions = {
        Vector3.new(0, 0, 0),
        Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)),
        Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
    }

    for _, offset in ipairs(positions) do
        local spawnPosition = basePosition + offset
        if ReplicatedStorage.endpoints.client_to_server.spawn_unit then
            ReplicatedStorage.endpoints.client_to_server.spawn_unit:InvokeServer(judarUUID, CFrame.new(spawnPosition))
            print("Placed Judar at:", spawnPosition)
        else
            warn("Failed to place Judar: Endpoint not found!")
        end
        task.wait(1)
    end
end

-- **Upgrade All Judars**
local function upgradeJudars()
    if UNIT_STORAGE then
        for i = 1, 3 do
            for _, unit in ipairs(UNIT_STORAGE:GetChildren()) do
                if unit.Name == "judar" then
                    if ReplicatedStorage.endpoints.client_to_server.upgrade_unit_ingame then
                        ReplicatedStorage.endpoints.client_to_server.upgrade_unit_ingame:InvokeServer(unit)
                        print("Upgraded Judar:", unit)
                    else
                        warn("Failed to upgrade Judar: Endpoint not found!")
                    end
                end
            end
            task.wait(1)
        end
    end
end

-- **Main Execution Logic**
if isInTargetGame() then
    loadTeamLoadout(1)
    print("Selected team loadout 1 for the target game.")
    return -- **Exit Script to Stop All Other Functions**
else
    loadTeamLoadout(6)
    print("Selected team loadout 6 for non-target game.")

    saveFilteredJudarData()

    local bestJudarUUID = getBestJudarUUID()
    if bestJudarUUID then
        equipUnit(bestJudarUUID)
        print("Equipped Judar with UUID: " .. bestJudarUUID)
    else
        warn("No valid Judar found to equip!")
    end
end

-- **Place and Upgrade Judars in a Loop**
local judarUUID = getBestJudarUUID()
if not judarUUID then
    warn("No saved Judar UUID found in JSON!")
    return
end

equipUnit(judarUUID)
print("Equipped Judar with UUID:", judarUUID)

local basePosition = getLaneMidpoint()

while true do
    placeJudars(basePosition, judarUUID)
    task.wait(2)
    upgradeJudars()
    task.wait(3)
end
