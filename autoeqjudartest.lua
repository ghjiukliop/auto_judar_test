local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LOCAL_PLAYER = Players.LocalPlayer
local UNIT_STORAGE = workspace:FindFirstChild("_UNITS")
local GAME_ID = 14229762361
local JUDAR_JSON_FILE = "JudarData.json"

-- Load services
local Loader = require(ReplicatedStorage.src.Loader)
local ItemInventoryServiceClient = Loader.load_client_service(script, "ItemInventoryServiceClient")

-- Function to check if player is in the target game
local function isInTargetGame()
    return game.PlaceId == GAME_ID
end

-- Function to load team loadout
local function loadTeamLoadout(loadout)
    ReplicatedStorage.endpoints.client_to_server.load_team_loadout:InvokeServer(tostring(loadout))
end

-- Function to equip a unit by UUID
local function equipUnit(uuid)
    ReplicatedStorage.endpoints.client_to_server.equip_unit:InvokeServer(uuid)
end

-- Function to get the units owned by the player
local function getUnitsOwner()
    return ItemInventoryServiceClient["session"]["collection"]["collection_profile_data"]["owned_units"]
end

-- Function to log and return Judar's UUID and total takedowns
local function logJudarInfo()
    local judarData = {}

    for _, unit in pairs(getUnitsOwner()) do
        if unit["unit_id"]:lower() == "judar" then
            table.insert(judarData, { uuid = unit["uuid"], total_takedowns = unit["total_takedowns"] or 0 })
        end
    end

    return judarData
end

-- Function to create a JSON file
local function createJsonFile(fileName, jsonData)
    local jsonString = HttpService:JSONEncode(jsonData)
    writefile(fileName, jsonString)
    print("JSON file created: " .. fileName)
end

-- Function to save all Judar data
local function saveFilteredJudarData()
    local judarData = logJudarInfo()
    createJsonFile(JUDAR_JSON_FILE, judarData)
end

-- Function to get the best Judar (highest takedowns but below 10K)
local function getBestJudarUUID()
    if isfile(JUDAR_JSON_FILE) then
        local data = readfile(JUDAR_JSON_FILE)
        local judarList = HttpService:JSONDecode(data) or {}

        local bestJudar = nil
        for _, judar in ipairs(judarList) do
            if judar.total_takedowns < 10000 then
                if not bestJudar or judar.total_takedowns > bestJudar.total_takedowns then
                    bestJudar = judar
                end
            end
        end

        return bestJudar and bestJudar.uuid or nil
    end
    return nil
end

-- Function to locate the 40% mark in lane for placement
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

-- Function to place 3 Judars
local function placeJudars(basePosition, judarUUID)
    local positions = {
        Vector3.new(0, 0, 0),
        Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)),
        Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
    }

    for _, offset in ipairs(positions) do
        local spawnPosition = basePosition + offset
        ReplicatedStorage.endpoints.client_to_server.spawn_unit:InvokeServer(judarUUID, CFrame.new(spawnPosition))
        print("Placed Judar at:", spawnPosition)
        task.wait(1)
    end
end

-- Function to upgrade all Judars
local function upgradeJudars()
    if UNIT_STORAGE then
        for i = 1, 3 do
            for _, unit in ipairs(UNIT_STORAGE:GetChildren()) do
                if unit.Name == "judar" then
                    ReplicatedStorage.endpoints.client_to_server.upgrade_unit_ingame:InvokeServer(unit)
                    print("Upgraded Judar:", unit)
                end
            end
            task.wait(1)
        end
    end
end

-- Main execution logic
if isInTargetGame() then
    loadTeamLoadout(1)
    print("Selected team loadout 1 for the target game.")
else
    loadTeamLoadout(6)
    print("Selected team loadout 6 for non-target game.")

    saveFilteredJudarData()

    local bestJudarUUID = getBestJudarUUID()
    if bestJudarUUID then
        equipUnit(bestJudarUUID)
        print("Equipped best Judar with UUID: " .. bestJudarUUID)
    else
        warn("No suitable Judar found!")
        return
    end
end

-- Place and upgrade Judars in a loop
local bestJudarUUID = getBestJudarUUID()
if not bestJudarUUID then
    warn("No saved Judar UUID found in JSON!")
    return
end

equipUnit(bestJudarUUID)
print("Equipped Judar with UUID:", bestJudarUUID)

local basePosition = getLaneMidpoint()

while true do
    placeJudars(basePosition, bestJudarUUID)
    task.wait(2)
    upgradeJudars()
    task.wait(3)
end
