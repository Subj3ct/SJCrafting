local QBX = exports['qbx_core']
local utils = require 'modules.utils'

-- Player crafting data storage
local PlayerCraftingData = {}

-- Validate items exist in ox_inventory
local function ValidateItems()
    local oxItems = exports.ox_inventory:Items()
    local missingItems = {}
    
    for stationType, items in pairs(Config.CraftingItems) do
        for _, item in pairs(items) do
            -- Check if the crafted item exists
            if not oxItems[item.name] then
                table.insert(missingItems, {
                    type = 'crafted',
                    station = stationType,
                    item = item.name,
                    label = item.label
                })
            end
            
            -- Check if recipe items exist
            for _, ingredient in pairs(item.recipe) do
                if not oxItems[ingredient.item] then
                    table.insert(missingItems, {
                        type = 'ingredient',
                        station = stationType,
                        item = ingredient.item,
                        craftedItem = item.name
                    })
                end
            end
        end
    end
    
    if #missingItems > 0 then
        print('^1[SJ Crafting]^7 ERROR: Missing items in ox_inventory:')
        for _, missing in pairs(missingItems) do
            if missing.type == 'crafted' then
                print('^1[SJ Crafting]^7 - Crafted item "' .. missing.item .. '" (' .. missing.label .. ') in station "' .. missing.station .. '" does not exist in ox_inventory')
            else
                print('^1[SJ Crafting]^7 - Ingredient "' .. missing.item .. '" for crafted item "' .. missing.craftedItem .. '" in station "' .. missing.station .. '" does not exist in ox_inventory')
            end
        end
        print('^1[SJ Crafting]^7 Please add these items to your ox_inventory data/items.lua or remove them from the crafting config')
        return false
    end
    
    print('^2[SJ Crafting]^7 All items validated successfully!')
    return true
end

-- Initialize database tables
CreateThread(function()
    -- Player crafting data table
    exports.oxmysql:executeSync([[
        CREATE TABLE IF NOT EXISTS player_crafting (
            citizenid VARCHAR(50) PRIMARY KEY,
            level INT DEFAULT 1,
            xp INT DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    
    -- Admin-placed crafting benches table
    exports.oxmysql:executeSync([[
        CREATE TABLE IF NOT EXISTS admin_crafting_benches (
            id INT AUTO_INCREMENT PRIMARY KEY,
            bench_type VARCHAR(50) NOT NULL,
            label VARCHAR(100) NOT NULL,
            coords TEXT NOT NULL,
            allowed_jobs TEXT,
            placed_by VARCHAR(50) NOT NULL,
            custom_prop VARCHAR(100),
            weapon_repair BOOLEAN DEFAULT FALSE,
            placed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_active BOOLEAN DEFAULT TRUE,
            
            INDEX idx_type (bench_type),
            INDEX idx_active (is_active)
        )
    ]])
    
    -- Player-placed crafting benches table
    exports.oxmysql:executeSync([[
        CREATE TABLE IF NOT EXISTS player_crafting_benches (
            id INT AUTO_INCREMENT PRIMARY KEY,
            bench_type VARCHAR(50) NOT NULL,
            label VARCHAR(100) NOT NULL,
            coords TEXT NOT NULL,
            allowed_jobs TEXT,
            placed_by VARCHAR(50) NOT NULL,
            placed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_active BOOLEAN DEFAULT TRUE,
            
            INDEX idx_type (bench_type),
            INDEX idx_active (is_active)
        )
    ]])
    
    print('^2[SJ Crafting]^7 Database tables initialized')
end)

-- Initialize player crafting data
local function InitializePlayerData(source)
    local Player = QBX:GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    if not PlayerCraftingData[citizenid] then
        PlayerCraftingData[citizenid] = {
            level = 1,
            xp = 0,
            queue = {},
            craftingHistory = {}
        }
        
        -- Load from database if exists
        local result = exports.oxmysql:executeSync('SELECT * FROM player_crafting WHERE citizenid = ?', {citizenid})
        if result and result[1] then
            PlayerCraftingData[citizenid].level = result[1].level or 1
            PlayerCraftingData[citizenid].xp = result[1].xp or 0
        else
            -- Insert new player data
            exports.oxmysql:executeSync('INSERT INTO player_crafting (citizenid, level, xp) VALUES (?, ?, ?)', {
                citizenid, 1, 0
            })
        end
    end
end

-- Save player data to database
local function SavePlayerData(citizenid)
    if PlayerCraftingData[citizenid] then
        exports.oxmysql:executeSync('UPDATE player_crafting SET level = ?, xp = ? WHERE citizenid = ?', {
            PlayerCraftingData[citizenid].level,
            PlayerCraftingData[citizenid].xp,
            citizenid
        })
    end
end

-- Calculate XP required for next level
local function GetXPForLevel(level)
    return math.floor(Config.LevelSystem.xpPerLevel * (Config.LevelSystem.xpMultiplier ^ (level - 1)))
end

-- Add XP to player
local function AddXP(source, amount)
    local Player = QBX:GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    if not PlayerCraftingData[citizenid] then
        InitializePlayerData(source)
    end
    
    PlayerCraftingData[citizenid].xp = PlayerCraftingData[citizenid].xp + amount
    
    -- Check for level up
    local currentLevel = PlayerCraftingData[citizenid].level
    local xpRequired = GetXPForLevel(currentLevel)
    
    while PlayerCraftingData[citizenid].xp >= xpRequired and currentLevel < Config.LevelSystem.maxLevel do
        PlayerCraftingData[citizenid].xp = PlayerCraftingData[citizenid].xp - xpRequired
        currentLevel = currentLevel + 1
        PlayerCraftingData[citizenid].level = currentLevel
        xpRequired = GetXPForLevel(currentLevel)
        
        -- Notify player of level up
        TriggerClientEvent('sjcrafting:levelUp', source, currentLevel)
    end
    
    SavePlayerData(citizenid)
end

-- Check if player can craft item
local function CanCraftItem(source, itemName, stationType, amount)
    local Player = QBX:GetPlayer(source)
    if not Player then return false, "Player not found" end
    
    -- Get item config
    local items = Config.CraftingItems[stationType]
    if not items then return false, "Invalid station type" end
    
    local itemConfig = nil
    for _, item in pairs(items) do
        if item.name == itemName then
            itemConfig = item
            break
        end
    end
    
    if not itemConfig then return false, "Item not found" end
    
    -- Check level requirement
    local citizenid = Player.PlayerData.citizenid
    if not PlayerCraftingData[citizenid] then
        InitializePlayerData(source)
    end
    
    if PlayerCraftingData[citizenid].level < itemConfig.requiredLevel then
        return false, "Level too low. Required: " .. itemConfig.requiredLevel
    end
    
    -- Check amount limit
    if amount > itemConfig.maxAmount then
        return false, "Amount exceeds maximum"
    end
    
    -- Check queue size
    if #PlayerCraftingData[citizenid].queue >= Config.MaxQueueSize then
        return false, "Queue is full"
    end
    
    -- Check ingredients
    for _, ingredient in pairs(itemConfig.recipe) do
        local hasItem = exports.ox_inventory:GetItem(source, ingredient.item, nil, true)
        if hasItem < (ingredient.amount * amount) then
            return false, "Not enough " .. ingredient.item
        end
    end
    
    return true, "Success"
end

-- Add item to crafting queue
local function AddToQueue(source, itemName, stationType, amount)
    local Player = QBX:GetPlayer(source)
    if not Player then return false, "Player not found" end
    
    -- Validate item exists in ox_inventory
    local oxItems = exports.ox_inventory:Items()
    if not oxItems[itemName] then
        return false, "Item '" .. itemName .. "' does not exist in ox_inventory"
    end
    
    local canCraft, message = CanCraftItem(source, itemName, stationType, amount)
    if not canCraft then
        return false, message
    end
    
    local citizenid = Player.PlayerData.citizenid
    local items = Config.CraftingItems[stationType]
    local itemConfig = nil
    
    for _, item in pairs(items) do
        if item.name == itemName then
            itemConfig = item
            break
        end
    end
    
    -- Remove ingredients
    for _, ingredient in pairs(itemConfig.recipe) do
        exports.ox_inventory:RemoveItem(source, ingredient.item, ingredient.amount * amount)
    end
    
    -- Generate unique ID based on timestamp and random number
    local uniqueId = os.time() * 1000 + math.random(1000, 9999)
    
    -- Add to queue
    local queueItem = {
        id = uniqueId,
        itemName = itemName,
        itemLabel = itemConfig.label,
        stationType = stationType,
        amount = amount,
        timeRemaining = itemConfig.time * amount,
        totalTime = itemConfig.time * amount,
        successChance = itemConfig.successChance,
        xpReward = itemConfig.xpReward * amount,
        startTime = os.time()
    }
    
    table.insert(PlayerCraftingData[citizenid].queue, queueItem)
    
    return true, "Added to queue"
end

-- Process crafting queue
CreateThread(function()
    while true do
        Wait(1000)
        
        for citizenid, playerData in pairs(PlayerCraftingData) do
            if #playerData.queue > 0 then
                
                -- Find the player by citizenid
                local player = QBX:GetPlayerByCitizenId(citizenid)
                if player and player.PlayerData.source then
                    local playerId = player.PlayerData.source
                    -- Only process the first item in queue
                    local queueItem = playerData.queue[1]
                    
                    queueItem.timeRemaining = queueItem.timeRemaining - 1
                    
                    if queueItem.timeRemaining <= 0 then
                        -- Crafting complete - remove from queue
                        table.remove(playerData.queue, 1)
                        
                        -- Check success chance
                        local randomRoll = math.random(100)
                        local success = randomRoll <= queueItem.successChance
                        
                        if success then
                            local addSuccess, response = exports.ox_inventory:AddItem(playerId, queueItem.itemName, queueItem.amount)
                            
                            AddXP(playerId, queueItem.xpReward)
                            
                            table.insert(playerData.craftingHistory, {
                                itemName = queueItem.itemName,
                                itemLabel = queueItem.itemLabel,
                                amount = queueItem.amount,
                                success = true,
                                timestamp = os.time()
                            })
                            
                            TriggerClientEvent('sjcrafting:craftingComplete', playerId, queueItem.itemName, queueItem.amount, true)
                        else
                            TriggerClientEvent('sjcrafting:craftingComplete', playerId, queueItem.itemName, queueItem.amount, false)
                        end
                    end
                end
            end
        end
    end
end)

-- Server Callbacks
lib.callback.register('sjcrafting:getCraftingData', function(source)
    local Player = QBX:GetPlayer(source)
    if not Player then return {success = false} end
    
    InitializePlayerData(source)
    local citizenid = Player.PlayerData.citizenid
    
    return {
        success = true,
        data = {
            level = PlayerCraftingData[citizenid].level,
            xp = PlayerCraftingData[citizenid].xp,
            queue = PlayerCraftingData[citizenid].queue,
            maxQueueSize = Config.MaxQueueSize
        }
    }
end)

lib.callback.register('sjcrafting:addToQueue', function(source, itemName, stationType, amount)
    local success, message = AddToQueue(source, itemName, stationType, amount)
    
    return {
        success = success,
        message = message
    }
end)

lib.callback.register('sjcrafting:cancelQueueItem', function(source, itemId)
    local Player = QBX:GetPlayer(source)
    if not Player then return {success = false} end
    
    local citizenid = Player.PlayerData.citizenid
    
    if PlayerCraftingData[citizenid] then
        local queueIndex = nil
        local queueItem = nil
        
        -- Find item by ID
        for i, item in pairs(PlayerCraftingData[citizenid].queue) do
            if item.id == itemId then
                queueIndex = i
                queueItem = item
                break
            end
        end
        
        if queueItem then
            -- Return ingredients
            local items = Config.CraftingItems[queueItem.stationType]
            local itemConfig = nil
            
            for _, item in pairs(items) do
                if item.name == queueItem.itemName then
                    itemConfig = item
                    break
                end
            end
            
            if itemConfig then
                for _, ingredient in pairs(itemConfig.recipe) do
                    exports.ox_inventory:AddItem(source, ingredient.item, ingredient.amount * queueItem.amount)
                end
            end
            
            table.remove(PlayerCraftingData[citizenid].queue, queueIndex)
            
            return {success = true}
        else
            return {success = false, message = "Item not found in queue"}
        end
    else
        return {success = false, message = "Player data not found"}
    end
end)

-- Check admin permission
lib.callback.register('sjcrafting:checkAdminPermission', function(source)
    return IsPlayerAceAllowed(source, 'admin')
end)

-- Check job access for crafting station
lib.callback.register('sjcrafting:checkJobAccess', function(source, stationType, allowedJobs)
    local Player = QBX:GetPlayer(source)
    if not Player then 
        return {success = false, message = "Player not found"}
    end
    
    if not allowedJobs or allowedJobs == "" or allowedJobs == "[]" then
        return {success = true}
    end
    
    local playerJob = Player.PlayerData.job.name
    local playerGrade = Player.PlayerData.job.grade.level
    
    local jobs = json.decode(allowedJobs)
    if not jobs or #jobs == 0 then
        return {success = true}
    end
    
    local hasAccess = false
    for _, jobData in pairs(jobs) do
        if playerJob == jobData.job and playerGrade >= jobData.grade then
            hasAccess = true
            break
        end
    end
    
    if not hasAccess then
        return {success = false, message = "You do not have the required job to view this crafting table."}
    end
    
    return {success = true}
end)

-- Callback to get crafting items with proper labels
lib.callback.register('sjcrafting:getCraftingItems', function(source, stationType)
    if not Config.CraftingItems[stationType] then
        return {}
    end
    
    local items = {}
    local oxItems = exports.ox_inventory:Items()
    
    for _, item in pairs(Config.CraftingItems[stationType]) do
        local imagePath = "nui://ox_inventory/web/images/" .. item.name .. ".png"
        
        local processedRecipe = {}
        for _, ingredient in pairs(item.recipe) do
            local ingredientLabel = ingredient.item -- Default to item name
            if oxItems[ingredient.item] and oxItems[ingredient.item].label then
                ingredientLabel = oxItems[ingredient.item].label
            end
            
            table.insert(processedRecipe, {
                item = ingredient.item,
                label = ingredientLabel,
                amount = ingredient.amount
            })
        end
        
        table.insert(items, {
            name = item.name,
            label = item.label,
            description = item.description,
            image = imagePath,
            time = item.time,
            requiredLevel = item.requiredLevel,
            maxAmount = item.maxAmount,
            successChance = item.successChance,
            xpReward = item.xpReward,
            recipe = processedRecipe
        })
    end
    
    return items
end)

-- Get static crafting stations
lib.callback.register('sjcrafting:getStaticStations', function()
    Wait(100)
    
    local adminBenches = exports.oxmysql:executeSync('SELECT * FROM admin_crafting_benches WHERE is_active = 1')
    local playerBenches = exports.oxmysql:executeSync('SELECT * FROM player_crafting_benches WHERE is_active = 1')
    
    local result = {}
    
    if adminBenches then
        for _, bench in pairs(adminBenches) do
            bench.isStatic = true
            table.insert(result, bench)
        end
    end
    
    if playerBenches then
        for _, bench in pairs(playerBenches) do
            bench.isStatic = false
            table.insert(result, bench)
        end
    end
    
    return result
end)

-- Get all placed benches for admin management
lib.callback.register('sjcrafting:getAllPlacedBenches', function(source)
    if not IsPlayerAceAllowed(source, 'admin') then
        return {}
    end
    
    local adminBenches = exports.oxmysql:executeSync('SELECT * FROM admin_crafting_benches WHERE is_active = 1 ORDER BY placed_at DESC')
    local playerBenches = exports.oxmysql:executeSync('SELECT * FROM player_crafting_benches WHERE is_active = 1 ORDER BY placed_at DESC')
    
    local result = {}
    
    if adminBenches then
        for _, bench in pairs(adminBenches) do
            bench.table_source = "admin"
            table.insert(result, bench)
        end
    end
    
    if playerBenches then
        for _, bench in pairs(playerBenches) do
            bench.table_source = "player"
            table.insert(result, bench)
        end
    end
    
    if result then
        return result
    else
        return {}
    end
end)

-- Check if a bench exists in the database
lib.callback.register('sjcrafting:checkBenchExists', function(source, benchId, tableSource)
    local result = nil
    if tableSource == "admin" then
        result = exports.oxmysql:executeSync('SELECT id FROM admin_crafting_benches WHERE id = ?', {benchId})
    elseif tableSource == "player" then
        result = exports.oxmysql:executeSync('SELECT id FROM player_crafting_benches WHERE id = ?', {benchId})
    end
    
    local exists = result and #result > 0
    return exists
end)

-- Check if a bench is active in the database
lib.callback.register('sjcrafting:checkBenchActive', function(source, benchId, tableSource)
    local result = nil
    if tableSource == "admin" then
        result = exports.oxmysql:executeSync('SELECT id FROM admin_crafting_benches WHERE id = ? AND is_active = 1', {benchId})
    elseif tableSource == "player" then
        result = exports.oxmysql:executeSync('SELECT id FROM player_crafting_benches WHERE id = ? AND is_active = 1', {benchId})
    end
    
    local active = result and #result > 0
    return active
end)

-- Delete a placed bench
lib.callback.register('sjcrafting:deletePlacedBench', function(source, benchId, tableSource)
    if not IsPlayerAceAllowed(source, 'admin') then
        return false
    end
    
    local success = false
    
    if tableSource == "admin" then
        success = exports.oxmysql:executeSync('DELETE FROM admin_crafting_benches WHERE id = ?', {benchId})
        if success then
            print('^2[SJ Crafting]^7 Successfully deleted from admin_crafting_benches')
        end
    elseif tableSource == "player" then
        success = exports.oxmysql:executeSync('DELETE FROM player_crafting_benches WHERE id = ?', {benchId})
        if success then
            print('^2[SJ Crafting]^7 Successfully deleted from player_crafting_benches')
        end
    else
        print('^1[SJ Crafting]^7 Invalid table source: ' .. tostring(tableSource))
    end
    
    if success then
        -- Notify all clients to remove the bench
        TriggerClientEvent('sjcrafting:client:removeBench', -1, benchId, tableSource)
        return true
    else
        print('^1[SJ Crafting]^7 Failed to delete bench from database')
    end
    
    return false
end)

-- Place static crafting bench
RegisterNetEvent('sjcrafting:server:placeStaticBench', function(benchType, coords, rotation, label, allowedJobs, customProp, weaponRepair)
    local source = source
    local Player = QBX:GetPlayer(source)
    
    if not Player then return end
    
    if not IsPlayerAceAllowed(source, 'admin') then
        lib.notify(source, {
            title = 'Access Denied',
            description = 'You do not have permission to place crafting benches.',
            type = 'error'
        })
        return
    end
    
    if not Config.CraftingItems[benchType] then
        lib.notify(source, {
            title = 'Error',
            description = 'Invalid bench type: ' .. benchType,
            type = 'error'
        })
        return
    end
    
    local coordsString = json.encode({
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = rotation.z
    })
    
    local result = exports.oxmysql:executeSync('INSERT INTO admin_crafting_benches (bench_type, label, coords, allowed_jobs, placed_by, custom_prop, weapon_repair) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        benchType,
        label,
        coordsString,
        allowedJobs,
        Player.PlayerData.citizenid,
        customProp or nil,
        weaponRepair or false
    })
    
    local insertId = result and result.insertId or result
    
    lib.notify(source, {
        title = 'Success',
        description = 'Crafting bench placed successfully!',
        type = 'success'
    })
    
    print('^2[SJ Crafting]^7 Admin ' .. Player.PlayerData.citizenid .. ' placed crafting bench: ' .. benchType .. ' at ' .. coordsString .. ' with ID: ' .. tostring(insertId))
    
    TriggerClientEvent('sjcrafting:client:spawnNewBench', -1, {
        id = insertId,
        bench_type = benchType,
        label = label,
        coords = coordsString,
        allowed_jobs = allowedJobs,
        custom_prop = customProp,
        weapon_repair = weaponRepair or false,
        isStatic = true
    })
end)

-- Place bench from inventory item
RegisterNetEvent('sjcrafting:server:placeBenchFromItem', function(itemName, coords, rotation)
    local source = source
    local Player = QBX:GetPlayer(source)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    local benchType = nil
    for type, benchData in pairs(Config.CraftingStations.placeable) do
        if benchData.item == itemName then
            benchType = type
            break
        end
    end
    
    if not benchType then
        lib.notify(source, {
            title = 'Error',
            description = 'Invalid crafting bench item',
            type = 'error'
        })
        return
    end
    
    local benchConfig = Config.CraftingStations.placeable[benchType]
    if not benchConfig then
        lib.notify(source, {
            title = 'Error',
            description = 'Invalid bench type: ' .. benchType,
            type = 'error'
        })
        return
    end
    
    if not Config.CraftingItems[benchConfig.type] then
        lib.notify(source, {
            title = 'Error',
            description = 'Invalid crafting station type: ' .. benchConfig.type,
            type = 'error'
        })
        return
    end
    
    local coordsString = json.encode({
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = rotation.z
    })
    
    local allowedJobs = '[]'
    if Config.CraftingStations.placeable[benchType].allowedJobs then
        allowedJobs = json.encode(Config.CraftingStations.placeable[benchType].allowedJobs)
    end
    
    local success = exports.oxmysql:executeSync('INSERT INTO player_crafting_benches (bench_type, label, coords, allowed_jobs, placed_by) VALUES (?, ?, ?, ?, ?)', {
        benchType,
        Config.CraftingStations.placeable[benchType].label,
        coordsString,
        allowedJobs,
        citizenid
    })
    
    if not success then
        lib.notify(source, {
            title = 'Error',
            description = 'Failed to place bench',
            type = 'error'
        })
        return
    end
    
    lib.notify(source, {
        title = 'Success',
        description = 'Crafting bench placed successfully!',
        type = 'success'
    })
    
    print('^2[SJ Crafting]^7 Player ' .. citizenid .. ' placed crafting bench: ' .. benchType .. ' at ' .. coordsString)
    
    local benchConfig = Config.CraftingStations.placeable[benchType]
    local craftingType = benchConfig.type
    
    local benchId = exports.oxmysql:executeSync('SELECT LAST_INSERT_ID() as id')[1].id
    
    TriggerClientEvent('sjcrafting:client:spawnNewBench', -1, {
        id = benchId,
        bench_type = benchType,
        crafting_type = craftingType,
        label = benchConfig.label,
        coords = coordsString,
        allowed_jobs = allowedJobs,
        placed_by = citizenid,
        weapon_repair = benchConfig.weaponRepair or false,
        isStatic = false
    })
end)

-- Pick up placed bench
RegisterNetEvent('sjcrafting:server:pickupBench', function(benchId)
    local source = source
    local Player = QBX:GetPlayer(source)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local playerJob = Player.PlayerData.job.name
    
    print('^3[SJ Crafting]^7 Pickup attempt - Bench ID: ' .. tostring(benchId) .. ' by player: ' .. citizenid)
    
    local benchData = exports.oxmysql:executeSync('SELECT * FROM player_crafting_benches WHERE id = ?', {benchId})
    if not benchData or #benchData == 0 then
        benchData = exports.oxmysql:executeSync('SELECT * FROM admin_crafting_benches WHERE id = ?', {benchId})
    end
    if not benchData or #benchData == 0 then
        print('^1[SJ Crafting]^7 Bench not found in database - ID: ' .. tostring(benchId))
        lib.notify(source, {
            title = 'Error',
            description = 'Bench not found',
            type = 'error'
        })
        return
    end
    
    print('^2[SJ Crafting]^7 Bench found - Type: ' .. benchData[1].bench_type .. ' Placed by: ' .. benchData[1].placed_by)
    
    local bench = benchData[1]
    
    local canPickup = false
    
    if bench.placed_by == citizenid then
        canPickup = true
    end
    
    if IsPlayerAceAllowed(source, 'admin') then
        canPickup = true
    end
    
    if Player.PlayerData.job.type == 'leo' then
        canPickup = true
    end
    
    if not canPickup then
        lib.notify(source, {
            title = 'Access Denied',
            description = 'You cannot pick up this bench',
            type = 'error'
        })
        return
    end
    
    local itemName = nil
    for type, benchData in pairs(Config.CraftingStations.placeable) do
        if type == bench.bench_type then
            itemName = benchData.item
            break
        end
    end
    
    if not itemName then
        lib.notify(source, {
            title = 'Error',
            description = 'Invalid bench type',
            type = 'error'
        })
        return
    end
        
    local canCarry = exports.ox_inventory:CanCarryItem(source, itemName, 1)
    if not canCarry then
        print('^1[SJ Crafting]^7 Player cannot carry item - Item: ' .. itemName)
        lib.notify(source, {
            title = 'Error',
            description = 'You cannot carry this item',
            type = 'error'
        })
        return
    end
    
    local addSuccess = exports.ox_inventory:AddItem(source, itemName, 1)
    if not addSuccess then
        print('^1[SJ Crafting]^7 Failed to return item to inventory - Item: ' .. itemName)
        lib.notify(source, {
            title = 'Error',
            description = 'Failed to return item to inventory',
            type = 'error'
        })
        return
    end
    
    -- Delete the bench from database
    local deleteSuccess = exports.oxmysql:executeSync('DELETE FROM player_crafting_benches WHERE id = ?', {benchId})
    local tableSource = "player"
    if deleteSuccess then
        print('^2[SJ Crafting]^7 Pickup: Successfully deleted from player_crafting_benches')
    else
        deleteSuccess = exports.oxmysql:executeSync('DELETE FROM admin_crafting_benches WHERE id = ?', {benchId})
        if deleteSuccess then
            print('^2[SJ Crafting]^7 Pickup: Successfully deleted from admin_crafting_benches')
            tableSource = "admin"
        else
            print('^1[SJ Crafting]^7 Pickup: Not found in either table')
        end
    end
    if not deleteSuccess then
        lib.notify(source, {
            title = 'Error',
            description = 'Failed to remove bench',
            type = 'error'
        })
        return
    end
    
    lib.notify(source, {
        title = 'Success',
        description = 'Bench picked up successfully!',
        type = 'success'
    })
    
    TriggerClientEvent('sjcrafting:client:markBenchRemoved', -1, benchId)
    
    TriggerClientEvent('sjcrafting:client:removeBench', -1, benchId, tableSource)
end)

-- Admin command to reset player level
RegisterCommand('resetcraftinglevel', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        lib.notify(source, {
            title = 'Error',
            description = 'Invalid player ID',
            type = 'error'
        })
        return
    end
    
    local targetPlayer = QBX:GetPlayer(targetId)
    if not targetPlayer then
        lib.notify(source, {
            title = 'Error',
            description = 'Player not found',
            type = 'error'
        })
        return
    end
    
    local citizenid = targetPlayer.PlayerData.citizenid
    if PlayerCraftingData[citizenid] then
        PlayerCraftingData[citizenid].level = 1
        PlayerCraftingData[citizenid].xp = 0
        PlayerCraftingData[citizenid].queue = {}
        SavePlayerData(citizenid)
        
        lib.notify(source, {
            title = 'Success',
            description = 'Reset crafting level for ' .. targetPlayer.PlayerData.name,
            type = 'success'
        })
        lib.notify(targetId, {
            title = 'Info',
            description = 'Your crafting level has been reset',
            type = 'inform'
        })
    end
end, false)

-- Admin command to set player level
RegisterCommand('setcraftinglevel', function(source, args)
    local targetId = tonumber(args[1])
    local level = tonumber(args[2])
    
    if not targetId or not level then
        lib.notify(source, {
            title = 'Error',
            description = 'Usage: /setcraftinglevel [player_id] [level]',
            type = 'error'
        })
        return
    end
    
    if level < 1 or level > Config.LevelSystem.maxLevel then
        lib.notify(source, {
            title = 'Error',
            description = 'Level must be between 1 and ' .. Config.LevelSystem.maxLevel,
            type = 'error'
        })
        return
    end
    
    local targetPlayer = QBX:GetPlayer(targetId)
    if not targetPlayer then
        lib.notify(source, {
            title = 'Error',
            description = 'Player not found',
            type = 'error'
        })
        return
    end
    
    local citizenid = targetPlayer.PlayerData.citizenid
    if not PlayerCraftingData[citizenid] then
        InitializePlayerData(targetId)
    end
    
    PlayerCraftingData[citizenid].level = level
    PlayerCraftingData[citizenid].xp = 0
    SavePlayerData(citizenid)
    
    lib.notify(source, {
        title = 'Success',
        description = 'Set crafting level to ' .. level .. ' for ' .. targetPlayer.PlayerData.name,
        type = 'success'
    })
    lib.notify(targetId, {
        title = 'Info',
        description = 'Your crafting level has been set to ' .. level,
        type = 'inform'
    })
end, false)

-- Player disconnect cleanup
AddEventHandler('playerDropped', function()
    local source = source
    local Player = QBX:GetPlayer(source)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        if PlayerCraftingData[citizenid] then
            SavePlayerData(citizenid)
            PlayerCraftingData[citizenid] = nil
        end
    end
end)

-- Initialize database table
CreateThread(function()
    exports.oxmysql:executeSync([[
        CREATE TABLE IF NOT EXISTS player_crafting (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) UNIQUE NOT NULL,
            level INT DEFAULT 1,
            xp INT DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    
    Wait(1000)
    if not ValidateItems() then
        print('^1[SJ Crafting]^7 Resource started with validation errors. Please fix the missing items.')
    end
end)

-- Callback to get bench prop model
lib.callback.register('sjcrafting:getBenchProp', function(source, benchType)
    if Config.CraftingStations and Config.CraftingStations.placeable and Config.CraftingStations.placeable[benchType] then
        return Config.CraftingStations.placeable[benchType].prop
    end
    return "prop_tool_bench02"
end)

-- Callback to get bench data for item
lib.callback.register('sjcrafting:getBenchDataForItem', function(source, itemName)
    for type, benchData in pairs(Config.CraftingStations.placeable) do
        if benchData.item == itemName then
            return {
                type = type,
                label = benchData.label,
                prop = benchData.prop
            }
        end
    end
    return nil
end)

-- Callback to get bench data for item
lib.callback.register('sjcrafting:checkItemAndGetBenchData', function(source, itemName)
    for type, benchData in pairs(Config.CraftingStations.placeable) do
        if benchData.item == itemName then
            return {
                success = true,
                type = type,
                label = benchData.label,
                prop = benchData.prop
            }
        end
    end
    
    return { success = false, message = "Invalid crafting bench item" }
end)

-- Callback to check pickup permission
lib.callback.register('sjcrafting:checkPickupPermission', function(source, benchId)
    local Player = QBX:GetPlayer(source)
    if not Player then return false end
    
    local citizenid = Player.PlayerData.citizenid
    local playerJob = Player.PlayerData.job.name
    
    local benchData = exports.oxmysql:executeSync('SELECT * FROM player_crafting_benches WHERE id = ?', {benchId})
    if not benchData or #benchData == 0 then
        benchData = exports.oxmysql:executeSync('SELECT * FROM admin_crafting_benches WHERE id = ?', {benchId})
    end
    if not benchData or #benchData == 0 then
        return false
    end
    
    local bench = benchData[1]
    
    local canPickup = false
    
    if bench.placed_by == citizenid then
        canPickup = true
    end
    
    if IsPlayerAceAllowed(source, 'admin') then
        canPickup = true
    end
    
    if Player.PlayerData.job.type == 'leo' then
        canPickup = true
    end
    
    return canPickup
end)

-- Callback to get crafting bench item from specific slot
lib.callback.register('sjcrafting:getCraftingBenchItemFromSlot', function(source, slot)
    local Player = QBX:GetPlayer(source)
    if not Player then return nil end
    
    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item then return nil end
    
    for type, benchData in pairs(Config.CraftingStations.placeable) do
        if benchData.item == item.name then
            return {
                name = item.name,
                slot = slot
            }
        end
    end
    
    return nil
end)

-- Callback to remove crafting bench item from inventory
lib.callback.register('sjcrafting:removeCraftingBenchItem', function(source, itemName)
    local Player = QBX:GetPlayer(source)
    if not Player then return false end
    
    -- Remove the item from inventory
    local removeSuccess = exports.ox_inventory:RemoveItem(source, itemName, 1)
    return removeSuccess
end)

local PlayerRepairData = {}

-- Initialize player repair data
local function InitializePlayerRepairData(source)
    local Player = QBX:GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    if not PlayerRepairData[citizenid] then
        PlayerRepairData[citizenid] = {
            queue = {},
            repairHistory = {}
        }
    end
end

-- Check if player can repair item
local function CanRepairItem(source, itemName, slot)
    local Player = QBX:GetPlayer(source)
    if not Player then return false, "Player not found" end
    
    local citizenid = Player.PlayerData.citizenid
    if not PlayerRepairData[citizenid] then
        InitializePlayerRepairData(source)
    end
    
    local repairRecipe = GetRepairRecipe(itemName)
    if not repairRecipe then
        return false, "Item cannot be repaired"
    end
    
    if PlayerCraftingData[citizenid] and PlayerCraftingData[citizenid].level < repairRecipe.requiredLevel then
        return false, "Level too low. Required: " .. repairRecipe.requiredLevel
    end
    
    if #PlayerRepairData[citizenid].queue >= Config.MaxQueueSize then
        return false, "Repair queue is full"
    end
    
    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item or not item.metadata or not item.metadata.durability then
        return false, "Item not found or has no durability"
    end
    
    if item.metadata.durability >= 100 then
        return false, "Item is already at full durability"
    end
    
    for _, material in pairs(repairRecipe.materials) do
        local hasItem = exports.ox_inventory:GetItem(source, material.item, nil, true)
        if hasItem < material.amount then
            return false, "Not enough " .. material.item
        end
    end
    
    return true, "Success"
end

-- Helper function to get repair recipe with case-insensitive matching
local function GetRepairRecipe(itemName)
    if Config.RepairRecipes[itemName] then
        return Config.RepairRecipes[itemName]
    end
    
    for weaponName, recipe in pairs(Config.RepairRecipes) do
        if string.lower(weaponName) == string.lower(itemName) then
            return recipe
        end
    end
    
    return nil
end

-- Add item to repair queue
local function AddToRepairQueue(source, itemName, slot, stationType)
    local Player = QBX:GetPlayer(source)
    if not Player then return false, "Player not found" end
    
    local canRepair, message = CanRepairItem(source, itemName, slot)
    if not canRepair then
        return false, message
    end
    
    local citizenid = Player.PlayerData.citizenid
    local repairRecipe = GetRepairRecipe(itemName)
    
    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item then
        return false, "Item not found in inventory"
    end
    
    local itemSerial = item.metadata and item.metadata.serial or tostring(slot)
    
    if PlayerRepairData[citizenid] and PlayerRepairData[citizenid].queue then
        for _, queueItem in pairs(PlayerRepairData[citizenid].queue) do
            if queueItem.slot == slot then
                return false, "This weapon is already in the repair queue"
            end
            if queueItem.itemSerial and queueItem.itemSerial == itemSerial then
                return false, "This weapon is already in the repair queue"
            end
        end
    end
    
    -- Store the complete item data before removing it
    local itemData = {
        name = item.name,
        label = item.label,
        metadata = item.metadata,
        count = item.count
    }
    
    -- Remove the weapon from inventory
    exports.ox_inventory:RemoveItem(source, itemName, 1, item.metadata)
    
    -- Remove materials
    for _, material in pairs(repairRecipe.materials) do
        exports.ox_inventory:RemoveItem(source, material.item, material.amount)
    end
    
    -- Generate unique ID based on timestamp and random number
    local uniqueId = os.time() * 1000 + math.random(1000, 9999)
    
    -- Add to queue
    local queueItem = {
        id = uniqueId,
        itemName = itemName,
        itemLabel = item.label or itemName,
        stationType = stationType,
        slot = slot,
        itemSerial = itemSerial,
        itemData = itemData,
        timeRemaining = repairRecipe.time,
        totalTime = repairRecipe.time,
        successChance = repairRecipe.successChance,
        startTime = os.time()
    }
    
    table.insert(PlayerRepairData[citizenid].queue, queueItem)
    
    return true, "Added to repair queue"
end

-- Process repair queue
CreateThread(function()
    while true do
        Wait(1000)
        
        for citizenid, playerData in pairs(PlayerRepairData) do
            if #playerData.queue > 0 then
                local player = QBX:GetPlayerByCitizenId(citizenid)
                if player and player.PlayerData.source then
                    local playerId = player.PlayerData.source
                    local queueItem = playerData.queue[1]
                    
                    queueItem.timeRemaining = queueItem.timeRemaining - 1
                    
                    if queueItem.timeRemaining <= 0 then
                        table.remove(playerData.queue, 1)
                        
                        local randomRoll = math.random(100)
                        local success = randomRoll <= queueItem.successChance
                        
                        if success then
                            local restoredMetadata = queueItem.itemData.metadata or {}
                            restoredMetadata.durability = 100
                            
                            exports.ox_inventory:AddItem(playerId, queueItem.itemName, 1, restoredMetadata)
                            
                            table.insert(playerData.repairHistory, {
                                itemName = queueItem.itemName,
                                itemLabel = queueItem.itemLabel,
                                success = true,
                                timestamp = os.time()
                            })
                            
                            TriggerClientEvent('sjcrafting:repairComplete', playerId, queueItem.itemName, true)
                        else
                            exports.ox_inventory:AddItem(playerId, queueItem.itemName, 1, queueItem.itemData.metadata)
                            table.insert(playerData.repairHistory, {
                                itemName = queueItem.itemName,
                                itemLabel = queueItem.itemLabel,
                                success = false,
                                timestamp = os.time()
                            })
                            
                            TriggerClientEvent('sjcrafting:repairComplete', playerId, queueItem.itemName, false)
                        end
                    end
                end
            end
        end
    end
end)

-- Server Callbacks for Repair System

-- Callback to get repairable weapon items from player inventory
lib.callback.register('sjcrafting:getRepairableItems', function(source, stationType)
    local Player = QBX:GetPlayer(source)
    if not Player then return {} end
    
    local playerItems = exports.ox_inventory:GetInventoryItems(source)
    local repairableItems = {}
    
    for slotId, item in pairs(playerItems) do
        if item.metadata and item.metadata.durability then
            if item.metadata.durability < 100 then
                        if GetRepairRecipe(item.name) then
            local repairRecipe = GetRepairRecipe(item.name)
                    local oxItems = exports.ox_inventory:Items()
                    local processedMaterials = {}
                    for _, material in pairs(repairRecipe.materials) do
                        local materialLabel = material.item -- Default to item name
                        if oxItems[material.item] and oxItems[material.item].label then
                            materialLabel = oxItems[material.item].label
                        end
                        
                        table.insert(processedMaterials, {
                            item = material.item,
                            label = materialLabel,
                            amount = material.amount
                        })
                    end
                    
                    table.insert(repairableItems, {
                        name = item.name,
                        label = item.label or item.name,
                        slot = item.slot,
                        durability = item.metadata.durability,
                        time = repairRecipe.time,
                        requiredLevel = repairRecipe.requiredLevel,
                        successChance = repairRecipe.successChance,
                        materials = processedMaterials
                    })
                else
                end
            else
            end
        else
        end
    end
    
    return repairableItems
end)

-- Callback to add item to repair queue
lib.callback.register('sjcrafting:addToRepairQueue', function(source, itemName, slot, stationType)
    local success, message = AddToRepairQueue(source, itemName, slot, stationType)
    
    return {
        success = success,
        message = message
    }
end)

-- Callback to cancel repair queue item
lib.callback.register('sjcrafting:cancelRepairQueueItem', function(source, itemId)
    local Player = QBX:GetPlayer(source)
    if not Player then return {success = false} end
    
    local citizenid = Player.PlayerData.citizenid
    
    if PlayerRepairData[citizenid] then
        local queueIndex = nil
        local queueItem = nil
        
        for i, item in pairs(PlayerRepairData[citizenid].queue) do
            if item.id == itemId then
                queueIndex = i
                queueItem = item
                break
            end
        end
        
        if queueItem then
            if queueItem.itemData then
                exports.ox_inventory:AddItem(source, queueItem.itemName, 1, queueItem.itemData.metadata)
            end
            
                                    local repairRecipe = GetRepairRecipe(queueItem.itemName)
            if repairRecipe then
                for _, material in pairs(repairRecipe.materials) do
                    exports.ox_inventory:AddItem(source, material.item, material.amount)
                end
            end
            
            table.remove(PlayerRepairData[citizenid].queue, queueIndex)
            
            return {success = true}
        else
            return {success = false, message = "Item not found in repair queue"}
        end
    else
        return {success = false, message = "Player repair data not found"}
    end
end)

-- Callback to get repair queue
lib.callback.register('sjcrafting:getRepairQueue', function(source)
    local Player = QBX:GetPlayer(source)
    if not Player then return {} end
    
    local citizenid = Player.PlayerData.citizenid
    if PlayerRepairData[citizenid] then
        return PlayerRepairData[citizenid].queue
    end
    
    return {}
end)
