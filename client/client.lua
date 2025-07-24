local QBX = exports['qbx_core']
local utils = require 'modules.utils'
local placement = require 'modules.placement'

-- Local variables
local currentStationType = nil
local isCraftingOpen = false
local placedBenches = {}
local removedBenches = {}
local isRemovingBench = false
local benchesLoaded = false

-- Repair System Variables
local isRepairOpen = false
local currentRepairStationType = nil

-- Load static crafting stations from database
CreateThread(function()
    if benchesLoaded then
        return
    end
    
    benchesLoaded = true
    
    local staticStations = lib.callback.await('SJCrafting:getStaticStations', false)
    
    if not staticStations then
        return
    end
    
    for _, station in pairs(staticStations) do
        local benchExists = lib.callback.await('SJCrafting:checkBenchExists', false, station.id, station.isStatic and 'admin' or 'player')
        if not benchExists then
            removedBenches[station.id] = true
            goto continue
        end
        
        local benchActive = lib.callback.await('SJCrafting:checkBenchActive', false, station.id, station.isStatic and 'admin' or 'player')
        if not benchActive then
            removedBenches[station.id] = true
            goto continue
        end
        
        if removedBenches[station.id] then
            goto continue
        end
        
        local tableSource = station.isStatic and "admin" or "player"
        local uniqueKey = station.id .. '_' .. tableSource
        
        if placedBenches[uniqueKey] then
            goto continue
        end
        
        for key, data in pairs(placedBenches) do
            if data.id == station.id then
                goto continue
            end
        end
        
        local coords = json.decode(station.coords)
        local entities = GetGamePool('CObject')
        local entityExists = false
        
        for _, entity in pairs(entities) do
            if DoesEntityExist(entity) then
                local entityCoords = GetEntityCoords(entity)
                local distance = #(vector3(coords.x, coords.y, coords.z) - entityCoords)
                
                if distance < 1.0 then
                    local entityModel = GetEntityModel(entity)
                    local expectedModel = GetHashKey(propModel)
                    
                    if entityModel == expectedModel then
                        entityExists = true
                        break
                    end
                end
            end
        end
        
        local propModel = "prop_tool_bench02"
        if station.custom_prop and station.custom_prop ~= "" then
            propModel = station.custom_prop
        elseif Config.CraftingStations and Config.CraftingStations.placeable and Config.CraftingStations.placeable[station.bench_type] then
            propModel = Config.CraftingStations.placeable[station.bench_type].prop
        end
        
        local coords = json.decode(station.coords)
        local entities = GetGamePool('CObject')
        local entityExists = false
        
        for _, entity in pairs(entities) do
            if DoesEntityExist(entity) then
                local entityCoords = GetEntityCoords(entity)
                local distance = #(vector3(coords.x, coords.y, coords.z) - entityCoords)
                
                if distance < 1.0 then
                    local entityModel = GetEntityModel(entity)
                    local expectedModel = GetHashKey(propModel)
                    
                    if entityModel == expectedModel then
                        entityExists = true
                        break
                    end
                end
            end
        end
        
        if entityExists then
            local coords = json.decode(station.coords)
            local zoneId = 'crafting_bench_' .. station.id
            
            local craftingType = station.bench_type
            if not station.isStatic and Config.CraftingStations.placeable[station.bench_type] then
                craftingType = Config.CraftingStations.placeable[station.bench_type].type
            end
            
            local options = {
                {
                    name = 'crafting_station_' .. station.bench_type,
                    icon = 'fas fa-hammer',
                    label = station.label,
                    onSelect = function()
                        OpenCraftingStation(craftingType, station.allowed_jobs)
                    end
                }
            }
    
            local shouldShowRepair = false
            
            if station.weapon_repair == true then
                shouldShowRepair = true
            elseif station.weapon_repair == nil and Config.CraftingStations.placeable[station.bench_type] and Config.CraftingStations.placeable[station.bench_type].weaponRepair then
                shouldShowRepair = true
            end
            
            if shouldShowRepair then
                table.insert(options, {
                    name = 'weapon_repair_' .. station.bench_type,
                    icon = 'fas fa-wrench',
                    label = 'Repair Weapon',
                    onSelect = function()
                        OpenRepairStation(station.bench_type)
                    end
                })
            end
            
            if not station.isStatic then
                table.insert(options, {
                    name = 'pickup_bench_' .. station.id,
                    icon = 'fas fa-hand-paper',
                    label = 'Pick Up Bench',
                    canInteract = function()
                        local canPickup = lib.callback.await('SJCrafting:checkPickupPermission', false, station.id)
                        return canPickup
                    end,
                    onSelect = function()
                        TriggerServerEvent('SJCrafting:server:pickupBench', station.id)
                    end
                })
            end
            
            local zoneId = exports.ox_target:addBoxZone({
                coords = vector4(coords.x, coords.y, coords.z, coords.w),
                size = vector3(1.5, 1.5, 2.0),
                rotation = coords.w,
                debug = Config.Debug,
                options = options
            })
            
            local tableSource = station.isStatic and "admin" or "player"
            local uniqueKey = station.id .. '_' .. tableSource
            placedBenches[uniqueKey] = {
                entity = nil, 
                zoneId = zoneId,
                coords = coords,
                id = station.id,
                isStatic = station.isStatic,
                tableSource = tableSource,
                propModel = propModel
            }
            
            goto continue
        end
        
        local model = GetHashKey(propModel)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(0)
        end
        
        local coords = json.decode(station.coords)
        local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(prop, coords.w)
        FreezeEntityPosition(prop, true)
        SetEntityAsMissionEntity(prop, true, true)
        
        local zoneId = 'crafting_bench_' .. station.id
        
        local craftingType = station.bench_type
        if not station.isStatic and Config.CraftingStations.placeable[station.bench_type] then
            craftingType = Config.CraftingStations.placeable[station.bench_type].type
        end
        
        local options = {
            {
                name = 'crafting_station_' .. station.bench_type,
                icon = 'fas fa-hammer',
                label = station.label,
                onSelect = function()
                    OpenCraftingStation(craftingType, station.allowed_jobs)
                end
            }
        }
        
        local shouldShowRepair = false
        if station.weapon_repair then
            shouldShowRepair = true
        elseif Config.CraftingStations.placeable[station.bench_type] and Config.CraftingStations.placeable[station.bench_type].weaponRepair then
            shouldShowRepair = true
        end
        
        if shouldShowRepair then
            table.insert(options, {
                name = 'repair_station_' .. station.bench_type,
                icon = 'fas fa-wrench',
                label = 'Repair Weapons',
                onSelect = function()
                    OpenRepairStation(craftingType, station.allowed_jobs)
                end
            })
        end
        
        if not station.isStatic then
            table.insert(options, {
                name = 'pickup_bench_' .. station.id,
                icon = 'fas fa-hand-paper',
                label = 'Pick Up Bench',
                canInteract = function()
                    local canPickup = lib.callback.await('SJCrafting:checkPickupPermission', false, station.id)
                    return canPickup
                end,
                onSelect = function()
                    TriggerServerEvent('SJCrafting:server:pickupBench', station.id)
                end
            })
        end
        
        local zoneId = exports.ox_target:addBoxZone({
            coords = vector4(coords.x, coords.y, coords.z, coords.w),
            size = vector3(1.5, 1.5, 2.0),
            rotation = coords.w,
            debug = Config.Debug,
            options = options
        })
        
        local tableSource = station.isStatic and "admin" or "player"
        local uniqueKey = station.id .. '_' .. tableSource
        placedBenches[uniqueKey] = {
            entity = prop,
            zoneId = zoneId,
            coords = coords,
            id = station.id,
            isStatic = station.isStatic,
            tableSource = tableSource,
            propModel = propModel
        }
        
        ::continue::
    end
    
end)

function OpenCraftingStation(stationType, allowedJobs)
    if isCraftingOpen or isRepairOpen then return end
    
    local jobCheck = lib.callback.await('SJCrafting:checkJobAccess', false, stationType, allowedJobs)
    if not jobCheck.success then
        lib.notify({
            title = 'Access Denied',
            description = jobCheck.message,
            type = 'error'
        })
        return
    end
    
    currentStationType = stationType
    isCraftingOpen = true
    
    local items = lib.callback.await('SJCrafting:getCraftingItems', false, stationType)
    
    utils.ShowNUI('UPDATE_VISIBILITY', true)
    
    Wait(100)
    
    utils.SendReactMessage('OPEN_CRAFTING', {
        stationType = stationType,
        items = items
    })
    
end

function CloseCraftingStation()
    if not isCraftingOpen then return end
    
    isCraftingOpen = false
    currentStationType = nil
    
    utils.SendReactMessage('CLOSE_CRAFTING', {})
    utils.ShowNUI('UPDATE_VISIBILITY', false)
    
    SetNuiFocus(false, false)
end

RegisterNUICallback('hideApp', function(data, cb)
    CloseCraftingStation()
    cb(true)
end)

RegisterNUICallback('ready', function(data, cb)
    cb(true)
end)

RegisterNUICallback('test', function(data, cb)
    cb('test response')
end)

RegisterNUICallback('showNotification', function(data, cb)
    lib.notify({
        title = data.title,
        description = data.description,
        type = data.type
    })
    cb(true)
end)

RegisterNUICallback('getCraftingData', function(data, cb)
    local result = lib.callback.await('SJCrafting:getCraftingData', false)
    cb(result)
end)

RegisterNUICallback('addToQueue', function(data, cb)
    local result = lib.callback.await('SJCrafting:addToQueue', false, data.itemName, data.stationType, data.amount)
    cb(result)
end)

RegisterNUICallback('cancelQueueItem', function(data, cb)
    local result = lib.callback.await('SJCrafting:cancelQueueItem', false, data.queueIndex)
    cb(result)
end)

-- Server events
RegisterNetEvent('SJCrafting:levelUp', function(newLevel)
    lib.notify({
        title = 'Level Up!',
        description = 'Crafting Level Up! You are now level ' .. newLevel,
        type = 'success'
    })
    
    if isCraftingOpen then
        utils.SendReactMessage('LEVEL_UP', {level = newLevel})
    end
end)

RegisterNetEvent('SJCrafting:craftingComplete', function(itemName, amount, success)
    if success then
        lib.notify({
            title = 'Crafting Complete',
            description = 'Successfully crafted ' .. amount .. 'x ' .. itemName,
            type = 'success'
        })
    else
        lib.notify({
            title = 'Crafting Failed',
            description = 'Failed to craft ' .. amount .. 'x ' .. itemName,
            type = 'error'
        })
    end
    
    if isCraftingOpen then
        utils.SendReactMessage('CRAFTING_COMPLETE', {
            itemName = itemName,
            amount = amount,
            success = success
        })
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if isCraftingOpen then
            if IsControlJustPressed(0, 202) then
                CloseCraftingStation()
            end
        else
            Wait(500)
        end
    end
end)

RegisterCommand('createcrafting', function()
    local isAdmin = lib.callback.await('SJCrafting:checkAdminPermission', false)
    if not isAdmin then
        lib.notify({
            title = 'Access Denied',
            description = 'You do not have permission to use this command.',
            type = 'error'
        })
        return
    end
    
    local benchTypes = {}
    for key, _ in pairs(Config.CraftingItems) do
        table.insert(benchTypes, {
            label = key:upper(),
            value = key
        })
    end
    
    local jobs = exports.qbx_core:GetJobs()
    local jobOptions = {}
    for jobName, jobData in pairs(jobs) do
        for gradeLevel, gradeData in pairs(jobData.grades) do
            table.insert(jobOptions, {
                label = gradeData.name .. ' (' .. jobName .. ')',
                value = json.encode({job = jobName, grade = tonumber(gradeLevel)})
            })
        end
    end
    
    local input = lib.inputDialog('Place Crafting Bench', {
        {
            type = 'select',
            label = 'Bench Type',
            description = 'Select the type of crafting bench',
            options = benchTypes,
            required = true
        },
        {
            type = 'input',
            label = 'Label',
            description = 'Enter a label for this bench',
            required = true
        },
        {
            type = 'multi-select',
            label = 'Allowed Jobs',
            description = 'Select jobs that can access this bench (leave empty for public)',
            options = jobOptions
        },
        {
            type = 'checkbox',
            label = 'Enable Weapon Repair',
            description = 'Allow this bench to repair weapons',
            default = false
        },
        {
            type = 'input',
            label = 'Custom Prop (Optional)',
            description = 'Enter a custom prop model (e.g., prop_workbench_01). Leave empty to use default.',
            required = false
        }
    })
    
    if not input then return end
    
    local benchType = input[1]
    local label = input[2]
    local selectedJobs = input[3] or {}
    local weaponRepair = input[4] or false
    local customProp = input[5] or ""
    
    local allowedJobs = {}
    for _, jobValue in pairs(selectedJobs) do
        local jobData = json.decode(jobValue)
        table.insert(allowedJobs, jobData)
    end
    
    placement.startCraftingBenchPlacement(benchType, label, json.encode(allowedJobs), nil, customProp, weaponRepair)
end, false)

RegisterCommand('managecrafting', function()
    local isAdmin = lib.callback.await('SJCrafting:checkAdminPermission', false)
    if not isAdmin then
        lib.notify({
            title = 'Access Denied',
            description = 'You do not have permission to use this command.',
            type = 'error'
        })
        return
    end
    
    local benches = lib.callback.await('SJCrafting:getAllPlacedBenches', false)
    if not benches then
        lib.notify({
            title = 'Error',
            description = 'Failed to get benches from server.',
            type = 'error'
        })
        return
    end
    
    if #benches == 0 then
        local staticStations = lib.callback.await('SJCrafting:getStaticStations', false)
        if staticStations and #staticStations > 0 then
            lib.notify({
                title = 'Access Denied',
                description = 'You do not have permission to use this command.',
                type = 'error'
            })
        else
            lib.notify({
                title = 'No Benches',
                description = 'No crafting benches have been placed.',
                type = 'inform'
            })
        end
        return
    end
    
    local options = {}
    
    for _, bench in pairs(benches) do
        local coords = json.decode(bench.coords)
        local allowedJobsText = "Public"
        if bench.allowed_jobs and bench.allowed_jobs ~= "" and bench.allowed_jobs ~= "[]" then
            local jobs = json.decode(bench.allowed_jobs)
            if jobs and #jobs > 0 then
                local jobNames = {}
                for _, jobData in pairs(jobs) do
                    table.insert(jobNames, jobData.job)
                end
                allowedJobsText = table.concat(jobNames, ", ")
            end
        end
        
        local benchTypeText = bench.table_source and bench.table_source:upper() or "UNKNOWN"
        
        table.insert(options, {
            title = bench.label,
            description = string.format('Type: %s | Source: %s | Jobs: %s | Coords: %.1f, %.1f, %.1f', 
                bench.bench_type:upper(), benchTypeText, allowedJobsText, coords.x, coords.y, coords.z),
            icon = 'fas fa-hammer',
            onSelect = function()
                lib.registerContext({
                    id = 'bench_management_' .. bench.id,
                    title = 'Manage: ' .. bench.label,
                    menu = 'managecrafting_menu',
                    options = {
                        {
                            title = 'Teleport to Bench',
                            description = 'Teleport to the bench location',
                            icon = 'fas fa-map-marker-alt',
                            onSelect = function()
                                local coords = json.decode(bench.coords)
                                SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z + 1.0, false, false, false, true)
                                lib.notify({
                                    title = 'Teleported',
                                    description = 'Teleported to ' .. bench.label,
                                    type = 'success'
                                })
                            end
                        },
                        {
                            title = 'Delete Bench',
                            description = 'Permanently delete this bench from the database',
                            icon = 'fas fa-trash',
                            onSelect = function()
                                local confirmed = lib.alertDialog({
                                    header = 'Confirm Deletion',
                                    content = 'Are you sure you want to permanently delete "' .. bench.label .. '"?\n\nThis action cannot be undone.',
                                    centered = true,
                                    cancel = true
                                })
                                
                                if confirmed == 'confirm' then
                                    local success = lib.callback.await('SJCrafting:deletePlacedBench', false, bench.id, bench.table_source)
                                    if success then
                                        lib.notify({
                                            title = 'Deleted',
                                            description = 'Successfully deleted ' .. bench.label,
                                            type = 'success'
                                        })
                                        ExecuteCommand('managecrafting')
                                    else
                                        lib.notify({
                                            title = 'Error',
                                            description = 'Failed to delete bench',
                                            type = 'error'
                                        })
                                    end
                                end
                            end
                        },
                        {
                            title = 'Back to List',
                            description = 'Return to the bench list',
                            icon = 'fas fa-arrow-left',
                            onSelect = function()
                                lib.showContext('managecrafting_menu')
                            end
                        }
                    }
                })
                
                lib.showContext('bench_management_' .. bench.id)
            end
        })
    end
    
    lib.registerContext({
        id = 'managecrafting_menu',
        title = 'Manage Crafting Benches',
        options = options
    })
    
    lib.showContext('managecrafting_menu')
end, false)

exports('OpenCraftingStation', OpenCraftingStation)
exports('CloseCraftingStation', CloseCraftingStation)

RegisterNetEvent('SJCrafting:client:spawnNewBench', function(station)
    if removedBenches[station.id] then
        return
    end
    
    local tableSource = station.isStatic and "admin" or "player"
    local uniqueKey = station.id .. '_' .. tableSource
    
    if placedBenches[uniqueKey] then
        return
    end
    
    for key, data in pairs(placedBenches) do
        if data.id == station.id then
            return
        end
    end
    
    local propModel = "prop_tool_bench02"
    if station.custom_prop and station.custom_prop ~= "" then
        propModel = station.custom_prop
    elseif Config.CraftingStations and Config.CraftingStations.placeable and Config.CraftingStations.placeable[station.bench_type] then
        propModel = Config.CraftingStations.placeable[station.bench_type].prop
    end
    
    local model = GetHashKey(propModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    
    local coords = json.decode(station.coords)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(prop, coords.w)
    FreezeEntityPosition(prop, true)
    SetEntityAsMissionEntity(prop, true, true)
    
    local benchId = station.id or ('static_' .. station.bench_type .. '_' .. GetGameTimer())
    if type(benchId) == 'table' then
        benchId = tostring(benchId)
    end
    
    local isStaticBench = station.isStatic == true
    
    local options = {
        {
            name = 'crafting_station_' .. station.bench_type,
            icon = 'fas fa-hammer',
            label = station.label,
            onSelect = function()
                local stationType = station.crafting_type or station.bench_type
                OpenCraftingStation(stationType, station.allowed_jobs)
            end
        }
    }
    
    local stationType = station.crafting_type or station.bench_type
    if (Config.CraftingStations.placeable[station.bench_type] and Config.CraftingStations.placeable[station.bench_type].weaponRepair) or station.weapon_repair then
        table.insert(options, {
            name = 'repair_station_' .. station.bench_type,
            icon = 'fas fa-wrench',
            label = 'Repair Weapons',
            onSelect = function()
                    OpenRepairStation(stationType, station.allowed_jobs)
                end
        })
    end
    
    if not isStaticBench then
        table.insert(options, {
            name = 'pickup_bench_' .. benchId,
            icon = 'fas fa-hand-paper',
            label = 'Pick Up Bench',
            canInteract = function()
                local canPickup = lib.callback.await('SJCrafting:checkPickupPermission', false, benchId)
                return canPickup
            end,
            onSelect = function()
                TriggerServerEvent('SJCrafting:server:pickupBench', benchId)
            end
        })
    end
    
    local zoneId = exports.ox_target:addBoxZone({
        coords = vector4(coords.x, coords.y, coords.z, coords.w),
        size = vector3(1.5, 1.5, 2.0),
        rotation = coords.w,
        debug = Config.Debug,
        options = options
    })
    
    local tableSource = isStaticBench and "admin" or "player"
    local uniqueKey = benchId .. '_' .. tableSource
    placedBenches[uniqueKey] = {
        entity = prop,
        zoneId = zoneId,
        coords = coords,
        id = benchId,
        isStatic = isStaticBench,
        tableSource = tableSource,
        propModel = propModel
    }
    
end)

RegisterNetEvent('SJCrafting:client:markBenchRemoved', function(benchId)
    removedBenches[benchId] = true
end)

RegisterNetEvent('SJCrafting:client:removeBench', function(benchId, tableSource)
    isRemovingBench = true
    
    local uniqueKey = benchId .. '_' .. (tableSource or 'unknown')
    local benchData = placedBenches[uniqueKey]
    
    if not benchData then
        for key, data in pairs(placedBenches) do
            if data.id == benchId then
                benchData = data
                break
            end
        end
    end
    
    local benchCoords = nil
    local benchPropModel = nil
    
    if benchData then
        benchCoords = benchData.coords
        benchPropModel = benchData.propModel
    else
        isRemovingBench = false
        return
    end
    
    local entities = GetGamePool('CObject')
    local deletedCount = 0
    
    for _, entity in pairs(entities) do
        if DoesEntityExist(entity) then
            local entityCoords = GetEntityCoords(entity)
            local distance = #(vector3(benchCoords.x, benchCoords.y, benchCoords.z) - entityCoords)
            
            if distance < 2.0 then
                local entityModel = GetEntityModel(entity)
                local expectedModel = GetHashKey(benchPropModel)
                
                if entityModel == expectedModel then
                    SetEntityAsMissionEntity(entity, true, true)
                    DeleteEntity(entity)
                    
                    if DoesEntityExist(entity) then
                        DeleteEntity(entity)
                    else
                        deletedCount = deletedCount + 1
                    end
                end
            end
        end
    end
    
    if deletedCount == 0 then
        local entities2 = GetGamePool('CObject')
        for _, entity in pairs(entities2) do
            if DoesEntityExist(entity) then
                local entityCoords = GetEntityCoords(entity)
                local distance = #(vector3(benchCoords.x, benchCoords.y, benchCoords.z) - entityCoords)
                
                if distance < 3.0 then
                    SetEntityAsMissionEntity(entity, true, true)
                    DeleteEntity(entity)
                end
            end
        end
    end
    
    local uniqueKey = benchId .. '_' .. (tableSource or 'unknown')
    local benchData = placedBenches[uniqueKey]
    
    if benchData and benchData.zoneId then
        exports.ox_target:removeZone(benchData.zoneId)
    end
    
    placedBenches[uniqueKey] = nil
    placedBenches[benchId] = nil
    
    isRemovingBench = false
end)

exports('placeCraftingBench', function(slot)
    if not slot then
        lib.notify({
            title = 'Error',
            description = 'No slot provided',
            type = 'error'
        })
        return
    end
    
    local itemData = lib.callback.await('SJCrafting:getCraftingBenchItemFromSlot', false, slot)
    if not itemData then
        lib.notify({
            title = 'Error',
            description = 'No crafting bench item found in that slot',
            type = 'error'
        })
        return
    end
    
    local result = lib.callback.await('SJCrafting:checkItemAndGetBenchData', false, itemData.name)
    if not result or not result.success then
        lib.notify({
            title = 'Error',
            description = result and result.message or 'Failed to check item',
            type = 'error'
        })
        return
    end
    
    local removeSuccess = lib.callback.await('SJCrafting:removeCraftingBenchItem', false, itemData.name)
    if not removeSuccess then
        lib.notify({
            title = 'Error',
            description = 'Failed to remove item from inventory',
            type = 'error'
        })
        return
    end
    
    exports.ox_inventory:closeInventory()
    
    placement.startCraftingBenchPlacement(result.type, result.label, '[]', itemData.name)
end)

function OpenRepairStation(stationType, allowedJobs)
    if isRepairOpen or isCraftingOpen then return end
    
    local jobCheck = lib.callback.await('SJCrafting:checkJobAccess', false, stationType, allowedJobs)
    if not jobCheck.success then
        lib.notify({
            title = 'Access Denied',
            description = jobCheck.message,
            type = 'error'
        })
        return
    end
    
    currentRepairStationType = stationType
    isRepairOpen = true
    
    local repairableItems = lib.callback.await('SJCrafting:getRepairableItems', false, stationType)
    
    utils.SendReactMessage('OPEN_REPAIR', {
        stationType = stationType,
        items = repairableItems
    })
    
    Wait(50)
    
    utils.ShowNUI('UPDATE_VISIBILITY', true)
    
end

function CloseRepairStation()
    if not isRepairOpen then return end
    
    isRepairOpen = false
    currentRepairStationType = nil
    
    utils.SendReactMessage('CLOSE_REPAIR', {})
    utils.ShowNUI('UPDATE_VISIBILITY', false)
end

RegisterNUICallback('addToRepairQueue', function(data, cb)
    local result = lib.callback.await('SJCrafting:addToRepairQueue', false, data.itemName, data.slot, data.stationType)
    
    if result.success then
        local updatedRepairableItems = lib.callback.await('SJCrafting:getRepairableItems', false, data.stationType)
        
        utils.SendReactMessage('UPDATE_REPAIRABLE_ITEMS', {
            items = updatedRepairableItems
        })
    end
    
    cb(result)
end)

RegisterNUICallback('cancelRepairQueueItem', function(data, cb)
    local result = lib.callback.await('SJCrafting:cancelRepairQueueItem', false, data.queueIndex)
    
    if result.success then
        local updatedRepairableItems = lib.callback.await('SJCrafting:getRepairableItems', false, currentRepairStationType)
        
        utils.SendReactMessage('UPDATE_REPAIRABLE_ITEMS', {
            items = updatedRepairableItems
        })
    end
    
    cb(result)
end)

RegisterNUICallback('getRepairQueue', function(data, cb)
    local result = lib.callback.await('SJCrafting:getRepairQueue', false)
    cb(result)
end)

RegisterNUICallback('closeRepair', function(data, cb)
    CloseRepairStation()
    cb({success = true})
end)

CreateThread(function()
    while true do
        Wait(0)
        if isRepairOpen then
            if IsControlJustPressed(0, 322) then
                CloseRepairStation()
            end
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('SJCrafting:repairComplete', function(itemName, success)
    if success then
        lib.notify({
            title = 'Repair Complete',
            description = 'Successfully repaired ' .. itemName,
            type = 'success'
        })
    else
        lib.notify({
            title = 'Repair Failed',
            description = 'Failed to repair ' .. itemName,
            type = 'error'
        })
    end
    
    if isRepairOpen then
        utils.SendReactMessage('REPAIR_COMPLETE', {
            itemName = itemName,
            success = success
        })
    end
end)
