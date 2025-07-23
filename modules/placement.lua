local placementMode = false
local currentBenchData = nil
local previewObject = nil
local previewRotation = 0.0
local previewCoords = vector3(0, 0, 0)

local dataview = setmetatable({
    EndBig = ">",
    EndLittle = "<",
    Types = {
        Int8 = { code = "i1" },
        Uint8 = { code = "I1" },
        Int16 = { code = "i2" },
        Uint16 = { code = "I2" },
        Int32 = { code = "i4" },
        Uint32 = { code = "I4" },
        Int64 = { code = "i8" },
        Uint64 = { code = "I8" },
        Float32 = { code = "f", size = 4 },
        Float64 = { code = "d", size = 8 },
        LuaInt = { code = "j" },
        UluaInt = { code = "J" },
        LuaNum = { code = "n" },
        String = { code = "z", size = -1, },
    },
    FixedTypes = {
        String = { code = "c" },
        Int = { code = "i" },
        Uint = { code = "I" },
    },
}, {
    __call = function(_, length)
        return dataview.ArrayBuffer(length)
    end
})
dataview.__index = dataview

function dataview.ArrayBuffer(length)
    return setmetatable({
        blob = string.blob(length),
        length = length,
        offset = 1,
        cangrow = true,
    }, dataview)
end

function dataview:Buffer() return self.blob end

local function ef(big) return (big and dataview.EndBig) or dataview.EndLittle end

local function packblob(self, offset, value, code)
    local packed = self.blob:blob_pack(offset, code, value)
    if self.cangrow or packed == self.blob then
        self.blob = packed
        self.length = packed:len()
        return true
    else
        return false
    end
end

dataview.Types.Float32.size = string.packsize(dataview.Types.Float32.code)

function dataview:GetFloat32(offset, endian)
    offset = offset or 0
    if offset >= 0 then
        local o = self.offset + offset
        local v,_ = self.blob:blob_unpack(o, ef(endian) .. dataview.Types.Float32.code)
        return v
    end
    return nil
end

function dataview:SetFloat32(offset, value, endian)
    if offset >= 0 and value then
        local o = self.offset + offset
        local v_size = dataview.Types.Float32.size
        if self.cangrow or ((o + (v_size - 1)) <= self.length) then
            if not packblob(self, o, value, ef(endian) .. dataview.Types.Float32.code) then
                error("cannot grow subview")
            end
        else
            error("cannot grow dataview")
        end
    end
    return self
end

local enableScale = false
local isCursorActive = false
local gizmoEnabled = false
local currentMode = 'translate'
local isRelative = false
local currentEntity

-- GIZMO HELPER FUNCTIONS
local function normalize(x, y, z)
    local length = math.sqrt(x * x + y * y + z * z)
    if length == 0 then
        return 0, 0, 0
    end
    return x / length, y / length, z / length
end

local function makeEntityMatrix(entity)
    local f, r, u, a = GetEntityMatrix(entity)
    local view = dataview.ArrayBuffer(60)

    view:SetFloat32(0, r[1])
        :SetFloat32(4, r[2])
        :SetFloat32(8, r[3])
        :SetFloat32(12, 0)
        :SetFloat32(16, f[1])
        :SetFloat32(20, f[2])
        :SetFloat32(24, f[3])
        :SetFloat32(28, 0)
        :SetFloat32(32, u[1])
        :SetFloat32(36, u[2])
        :SetFloat32(40, u[3])
        :SetFloat32(44, 0)
        :SetFloat32(48, a[1])
        :SetFloat32(52, a[2])
        :SetFloat32(56, a[3])
        :SetFloat32(60, 1)

    return view
end

local function applyEntityMatrix(entity, view)
    local x1, y1, z1 = view:GetFloat32(16), view:GetFloat32(20), view:GetFloat32(24)
    local x2, y2, z2 = view:GetFloat32(0), view:GetFloat32(4), view:GetFloat32(8)
    local x3, y3, z3 = view:GetFloat32(32), view:GetFloat32(36), view:GetFloat32(40)
    local tx, ty, tz = view:GetFloat32(48), view:GetFloat32(52), view:GetFloat32(56)

    if not enableScale then
        x1, y1, z1 = normalize(x1, y1, z1)
        x2, y2, z2 = normalize(x2, y2, z2)
        x3, y3, z3 = normalize(x3, y3, z3)
    end

    SetEntityMatrix(entity,
        x1, y1, z1,
        x2, y2, z2,
        x3, y3, z3,
        tx, ty, tz
    )
end

-- GIZMO LOOPS
local function gizmoLoop(entity)
    if not gizmoEnabled then
        return LeaveCursorMode()
    end

    EnterCursorMode()
    isCursorActive = true

    if IsEntityAPed(entity) then
        SetEntityAlpha(entity, 200)
    else
        SetEntityDrawOutline(entity, true)
    end
    
    while gizmoEnabled and DoesEntityExist(entity) do
        Wait(0)
        if IsControlJustPressed(0, 47) then -- G
            if isCursorActive then
                LeaveCursorMode()
                isCursorActive = false
            else
                EnterCursorMode()
                isCursorActive = true
            end
        end
        DisableControlAction(0, 24, true)  -- lmb
        DisableControlAction(0, 25, true)  -- rmb
        DisableControlAction(0, 140, true) -- r
        DisablePlayerFiring(cache.playerId, true)

        local matrixBuffer = makeEntityMatrix(entity)
        local changed = Citizen.InvokeNative(0xEB2EDCA2, matrixBuffer:Buffer(), 'Editor1',
            Citizen.ReturnResultAnyway())

        if changed then
            applyEntityMatrix(entity, matrixBuffer)
        end
    end
    
    if isCursorActive then
        LeaveCursorMode()
    end
    isCursorActive = false

    if DoesEntityExist(entity) then
        if IsEntityAPed(entity) then SetEntityAlpha(entity, 255) end
        SetEntityDrawOutline(entity, false)
    end

    gizmoEnabled = false
    currentEntity = nil
end

local function GetVectorText(vectorType) 
    if not currentEntity then return 'ERR_NO_ENTITY_' .. (vectorType or "UNK") end
    local label = (vectorType == "coords" and "Position" or "Rotation")
    local vec = (vectorType == "coords" and GetEntityCoords(currentEntity) or GetEntityRotation(currentEntity))
    return ('%s: %.2f, %.2f, %.2f'):format(label, vec.x, vec.y, vec.z)
end

local function textUILoop()
    CreateThread(function()
        while gizmoEnabled do
            Wait(100)

            local scaleText = (enableScale and '[S] - Scale Mode  \n') or ''
            local modeLine = 'Current Mode: ' .. currentMode .. ' | ' .. (isRelative and 'Relative' or 'World') .. '  \n'

            lib.showTextUI(
                modeLine ..
                GetVectorText("coords") .. '  \n' ..
                GetVectorText("rotation") .. '  \n' ..
                '[G]     - ' .. (isCursorActive and "Disable Cursor" or "Enable Cursor") .. '  \n' ..
                '[W]     - Translate Mode  \n' ..
                '[R]     - Rotate Mode  \n' ..
                scaleText ..
                '[Q]     - Toggle Space  \n' ..
                '[LALT]  - Snap to Ground  \n' ..
                '[ENTER] - Done Editing  \n'
            )
        end
        lib.hideTextUI()
    end)
end

-- GIZMO MAIN FUNCTION
local function useGizmo(entity)
    gizmoEnabled = true
    currentEntity = entity
    
    textUILoop()
    gizmoLoop(entity)

    Wait(50)
    
    local finalCoords = GetEntityCoords(entity)
    local finalRotation = GetEntityRotation(entity)

    return {
        handle = entity,
        position = finalCoords,
        rotation = finalRotation
    }
end

-- Bench placement functions
function startCraftingBenchPlacement(benchType, label, allowedJobs, itemName, customProp, weaponRepair)
    if placementMode then return end
    
    placementMode = true
    currentBenchData = {
        type = benchType,
        label = label,
        allowedJobs = allowedJobs,
        itemName = itemName,
        customProp = customProp,
        weaponRepair = weaponRepair
    }
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    local forwardX = playerCoords.x + math.sin(math.rad(playerHeading)) * 3.0
    local forwardY = playerCoords.y + math.cos(math.rad(playerHeading)) * 3.0
    local groundZ = playerCoords.z
    
    local propModel = "prop_tool_bench02"
    
    if currentBenchData.customProp and currentBenchData.customProp ~= "" then
        propModel = currentBenchData.customProp
    elseif currentBenchData.itemName then
        for type, benchData in pairs(Config.CraftingStations.placeable) do
            if benchData.item == currentBenchData.itemName then
                propModel = benchData.prop
                break
            end
        end
    end
    
    local modelHash = GetHashKey(propModel)
    lib.requestModel(modelHash)
    
    previewObject = CreateObject(modelHash, forwardX, forwardY, groundZ, false, false, false)
    SetEntityAlpha(previewObject, 150, false)
    SetEntityCollision(previewObject, false, false)
    SetEntityCanBeDamaged(previewObject, false)
    FreezeEntityPosition(previewObject, true)
    
    local result = useGizmo(previewObject)
    
    placeBench(result)
end

function cancelPlacement()
    placementMode = false
    gizmoEnabled = false
    currentBenchData = nil
    
    if DoesEntityExist(previewObject) then
        DeleteEntity(previewObject)
        previewObject = nil
    end
end

function placeBench(gizmoResult)
    if not currentBenchData or not gizmoResult then 
        cancelPlacement()
        return 
    end
    
    local coords = gizmoResult.position
    local rotation = gizmoResult.rotation
    
    if currentBenchData.itemName then
        TriggerServerEvent('sjcrafting:server:placeBenchFromItem', 
            currentBenchData.itemName,
            coords, 
            rotation
        )
    else
        TriggerServerEvent('sjcrafting:server:placeStaticBench', 
            currentBenchData.type, 
            coords, 
            rotation, 
            currentBenchData.label, 
            currentBenchData.allowedJobs,
            currentBenchData.customProp,
            currentBenchData.weaponRepair
        )
    end
    
    cancelPlacement()
end

-- Initialize
CreateThread(function()
    while true do
        if placementMode then
            DisableControlAction(0, 32, true) -- W (forward)
            DisableControlAction(0, 33, true) -- S (backward)
            DisableControlAction(0, 34, true) -- A (left)
            DisableControlAction(0, 35, true) -- D (right)
            DisableControlAction(0, 19, true) -- R (rotation mode)
            DisableControlAction(0, 191, true) -- ENTER (place)
            DisableControlAction(0, 200, true) -- ESC (cancel)
        end
        Wait(0)
    end
end)

-- GIZMO KEYBINDS
lib.addKeybind({
    name = '_gizmoSelect',
    description = 'Select gizmo element',
    defaultMapper = 'MOUSE_BUTTON',
    defaultKey = 'MOUSE_LEFT',
    onPressed = function(self)
        if not gizmoEnabled then return end
        ExecuteCommand('+gizmoSelect')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoSelect')
    end
})

lib.addKeybind({
    name = '_gizmoTranslation',
    description = 'Translation mode',
    defaultKey = 'W',
    onPressed = function(self)
        if not gizmoEnabled then return end
        currentMode = 'Translate'
        ExecuteCommand('+gizmoTranslation')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoTranslation')
    end
})

lib.addKeybind({
    name = '_gizmoRotation',
    description = 'Rotation mode',
    defaultKey = 'R',
    onPressed = function(self)
        if not gizmoEnabled then return end
        currentMode = 'Rotate'
        ExecuteCommand('+gizmoRotation')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoRotation')
    end
})

lib.addKeybind({
    name = '_gizmoLocal',
    description = 'Toggle space',
    defaultKey = 'Q',
    onPressed = function(self)
        if not gizmoEnabled then return end
        isRelative = not isRelative
        ExecuteCommand('+gizmoLocal')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoLocal')
    end
})

lib.addKeybind({
    name = 'gizmoclose',
    description = 'Close gizmo',
    defaultKey = 'RETURN',
    onPressed = function(self)
        if not gizmoEnabled then return end
        gizmoEnabled = false
    end,
})

lib.addKeybind({
    name = 'gizmoSnapToGround',
    description = 'Snap to ground',
    defaultKey = 'LMENU',
    onPressed = function(self)
        if not gizmoEnabled then return end
        PlaceObjectOnGroundProperly_2(currentEntity)
    end,
})

if enableScale then
    lib.addKeybind({
        name = '_gizmoScale',
        description = 'Scale mode',
        defaultKey = 'S',
        onPressed = function(self)
            if not gizmoEnabled then return end
            currentMode = 'Scale'
            ExecuteCommand('+gizmoScale')
        end,
        onReleased = function (self)
            ExecuteCommand('-gizmoScale')
        end
    })
end

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if placementMode then
            cancelPlacement()
        end
        
        lib.hideTextUI()
    end
end)

-- Return the placement module
local placement = {
    startCraftingBenchPlacement = startCraftingBenchPlacement
}

return placement 