local utils = {}

function utils.SendReactMessage(action, data)
	SendNUIMessage({
		action = action,
		data = data
	})
end

function utils.ShowNUI(action, shouldShow)
    if shouldShow then
        SetNuiFocus(true, true)
    else
        SetNuiFocus(false, false)
    end
	SendNUIMessage({
		action = action,
		data = shouldShow
	})
end

function utils.GetCraftingItems(stationType)
    if not Config.CraftingItems[stationType] then
        return {}
    end
    
    local items = {}
    for _, item in pairs(Config.CraftingItems[stationType]) do
        local imagePath = "nui://ox_inventory/web/images/" .. item.name .. ".png"
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
            recipe = item.recipe
        })
    end
    
    return items
end

function utils.GetItemImage(itemName)
    return "nui://ox_inventory/web/images/" .. itemName .. ".png"
end

function utils.FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%02d:%02d", minutes, secs)
    end
end

return utils