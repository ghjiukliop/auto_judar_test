local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LOCAL_PLAYER = Players.LocalPlayer
local GAME_ID = 14229762361
local JUDAR_JSON_FILE = "JudarData.json"

local Loader = require(game:GetService('ReplicatedStorage').src.Loader)
local ItemInventoryServiceClient = Loader.load_client_service(script, "ItemInventoryServiceClient")

-- Function to check if player is in the target game
local function isInTargetGame()
    return game.PlaceId == GAME_ID
end

-- Function to load team loadout
local function loadTeamLoadout(loadout)
    local args = {[1] = tostring(loadout)}
    ReplicatedStorage.endpoints.client_to_server.load_team_loadout:InvokeServer(unpack(args))
end

-- Function to equip a unit by UUID
local function equipUnit(uuid)
    local args = {[1] = uuid}
    ReplicatedStorage.endpoints.client_to_server.equip_unit:InvokeServer(unpack(args))
end

-- Function to get the units owned by the player
local function getUnitsOwner()
    return ItemInventoryServiceClient["session"]["collection"]["collection_profile_data"]["owned_units"]
end

-- Function to log Judar's UUID and total takedowns
local function logJudarInfo()
    local judarData = {}
    for _, unit in pairs(getUnitsOwner()) do
        if unit["unit_id"]:lower() == "judar" then
            local takedowns = unit["total_takedowns"] or 0
            local uuid = unit["uuid"]
            table.insert(judarData, { uuid = uuid, total_takedowns = takedowns })
        end
    end
    return judarData
end

-- Function to create a JSON file
local function createJsonFile(fileName, jsonData)
    local jsonString = HttpService:JSONEncode(jsonData)
    writefile(fileName, jsonString)
end

-- Function to save filtered Judar data
local function saveFilteredJudarData()
    local judarData = logJudarInfo()
    createJsonFile(JUDAR_JSON_FILE, judarData)
end

-- Function to auto-equip Judar
local function autoEquipJudar()
    if isfile(JUDAR_JSON_FILE) then
        local judarData = readfile(JUDAR_JSON_FILE)
        local decodedData = HttpService:JSONDecode(judarData) or {}
        
        for _, judar in ipairs(decodedData) do
            if judar.total_takedowns < 10000 then
                equipUnit(judar.uuid)
                break
            end
        end
    end
end

-- Function to create a glow effect on a part
local function createGlowEffect(part, color)
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Adornee = part
    surfaceGui.Face = Enum.NormalId.Top
    surfaceGui.AlwaysOnTop = true

    local glowFrame = Instance.new("Frame")
    glowFrame.Size = UDim2.new(1, 0, 1, 0)
    glowFrame.BackgroundColor3 = color
    glowFrame.BackgroundTransparency = 0.5

    glowFrame.Parent = surfaceGui
    surfaceGui.Parent = part
end

-- Function to find the closest object at 50% distance
local function findHalfwayObject()
    local lane = workspace._BASES.pve.LANES["1"]
    local spawn = lane.spawn
    local final = lane.final
    local spawnPosition = spawn.Position
    local finalPosition = final.Position
    local totalDistance = (finalPosition - spawnPosition).magnitude
    local targetDistance = 0.5 * totalDistance
    
    local closestPart = nil
    local closestDistance = math.huge
    
    for _, part in ipairs(lane:GetChildren()) do
        if part:IsA("BasePart") then
            local partDistance = (part.Position - spawnPosition).magnitude
            local distanceDiff = math.abs(partDistance - targetDistance)
            
            if distanceDiff < closestDistance then
                closestDistance = distanceDiff
                closestPart = part
            end
        end
    end
    
    if closestPart then
        createGlowEffect(closestPart, Color3.new(1, 1, 0))
    end
    
    return closestPart
end

-- Function to place Judar at 50% location
local function placeJudarNearTarget()
    local targetPart = findHalfwayObject()
    if targetPart then
        ReplicatedStorage.endpoints.client_to_server.place_unit:InvokeServer(targetPart.Position)
    end
end

-- Function to check for Judar and auto-place if missing
local function checkAndPlaceJudar()
    while true do
        if not workspace._UNITS:FindFirstChild("judar") then
            placeJudarNearTarget()
        end
        wait(1) -- Adjust as needed
    end
end

-- Function to upgrade Judar when there are 3 in workspace._UNITS
local function autoUpgradeJudar()
    while true do
        local judars = {}
        for _, unit in ipairs(workspace._UNITS:GetChildren()) do
            if unit.Name == "judar" then
                table.insert(judars, unit)
            end
        end

        if #judars >= 3 then
            for _, judar in ipairs(judars) do
                local args = {[1] = judar}
                ReplicatedStorage.endpoints.client_to_server.upgrade_unit_ingame:InvokeServer(unpack(args))
                wait(1)
            end
        end
        wait(2)
    end
end

-- Main execution logic
if isInTargetGame() then
    loadTeamLoadout(1)
else
    loadTeamLoadout(6)
    saveFilteredJudarData()
    autoEquipJudar()
end

spawn(checkAndPlaceJudar)
spawn(autoUpgradeJudar)
