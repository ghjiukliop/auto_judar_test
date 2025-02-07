local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LOCAL_PLAYER = Players.LocalPlayer
local GAME_ID = 14229762361
local JUDAR_JSON_FILE = "JudarData.json"
local UNIT_STORAGE = workspace:FindFirstChild("_UNITS")

-- Load services
local Loader = require(ReplicatedStorage.src.Loader)
local ItemInventoryServiceClient = Loader.load_client_service(script, "ItemInventoryServiceClient")

-- Function to load team loadout
local function loadTeamLoadout(loadout)
    ReplicatedStorage.endpoints.client_to_server.load_team_loadout:InvokeServer(tostring(loadout))
end

-- **Step 1: Check Game ID & Load Team**
if game.PlaceId == GAME_ID then
    loadTeamLoadout(1)
    print("Loaded Team 1 for target game.")
    return
else
    loadTeamLoadout(6)
    print("Loaded Team 6 for non-target game.")
end

-- **Step 2: Fetch and Save All Judar Data to JSON**
local function getUnitsOwner()
    return ItemInventoryServiceClient.session.collection.collection_profile_data.owned_units
end

local function saveJudarData()
    local judarData = {}

    for _, unit in pairs(getUnitsOwner()) do
        if unit.unit_id:lower() == "judar" then
            table.insert(judarData, { uuid = unit.uuid, total_takedowns = unit.total_takedowns or 0 })
        end
    end

    local jsonString = HttpService:JSONEncode(judarData)
    writefile(JUDAR_JSON_FILE, jsonString)
    print("Saved Judar data to JSON:", JUDAR_JSON_FILE)
end

saveJudarData()

-- **Step 3: Auto-Equip a Judar with <10K Takedowns**
local function autoEquipJudar()
    if isfile(JUDAR_JSON_FILE) then
        local data = readfile(JUDAR_JSON_FILE)
        local judarList = HttpService:JSONDecode(data) or {}

        for _, judar in ipairs(judarList) do
            if judar.total_takedowns < 10000 then
                ReplicatedStorage.endpoints.client_to_server.equip_unit:InvokeServer(judar.uuid)
                print("Equipped Judar with UUID:", judar.uuid)
                break -- Equip only one
            end
        end
    else
        warn("Judar JSON file not found! Skipping auto-equip.")
    end
end

autoEquipJudar()

-- **Step 4: Find the Closest Object Near 50% Along the Lane**
local function getLaneMidpoint()
    local lane = workspace._BASES.pve.LANES["1"]
    local spawnPos = lane.spawn.Position
    local finalPos = lane.final.Position
    local totalDist = (finalPos - spawnPos).magnitude
    local midpoint = spawnPos + (finalPos - spawnPos).unit * (0.5 * totalDist)

    local closestObject, closestDist = nil, math.huge
    for _, obj in ipairs(lane:GetChildren()) do
        if obj:IsA("BasePart") then
            local dist = (obj.Position - midpoint).magnitude
            if dist < closestDist then
                closestDist = dist
                closestObject = obj
            end
        end
    end

    return closestObject and closestObject.Position or midpoint
end

local targetPosition = getLaneMidpoint()

-- **Step 5: Place Judar Near 50% Mark (Avoid Overlapping)**
local function placeJudar()
    if not UNIT_STORAGE or UNIT_STORAGE:FindFirstChild("judar") then return end

    local placementOffset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
    local placeArgs = { targetPosition + placementOffset }
    ReplicatedStorage.endpoints.client_to_server.spawn_unit:InvokeServer(unpack(placeArgs))

    print("Placed Judar near 50% mark!")
end

-- **Step 6: Auto-Upgrade Judar When 3 Exist**
local function upgradeJudar()
    if UNIT_STORAGE then
        local judarUnits = {}
        for _, unit in ipairs(UNIT_STORAGE:GetChildren()) do
            if unit.Name == "judar" then
                table.insert(judarUnits, unit)
            end
        end

        if #judarUnits >= 3 then
            for _, judar in ipairs(judarUnits) do
                local args = { judar }
                ReplicatedStorage.endpoints.client_to_server.upgrade_unit_ingame:InvokeServer(unpack(args))
                print("Upgraded Judar:", judar)
            end
        end
    end
end

-- **Step 7: Loop to Ensure Judar Placement and Upgrades**
while true do
    task.wait(2) -- Prevents lag

    -- Ensure a Judar is placed if missing
    if UNIT_STORAGE and not UNIT_STORAGE:FindFirstChild("judar") then
        placeJudar()
    end

    -- Upgrade if at least 3 Judars exist
    upgradeJudar()
end
