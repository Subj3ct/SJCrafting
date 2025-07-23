Config = {}

-- General Settings
Config.Debug = false
Config.MaxQueueSize = 10 -- Maximum items in queue per player

-- Placeable Crafting Stations
Config.CraftingStations = {
    placeable = {
        -- Placeable Weapon Crafting Station
        weapon_bench = {
            label = "Weapon Crafting Bench", -- Ox Target Label
            description = "Craft weapons and ammunition",
            item = "crafting_bench_w", -- Ox Inventory Item
            prop = "prop_tool_bench02", -- Prop Model
            type = "weapon", -- Crafting Type
            weaponRepair = true, -- Enable weapon repair functionality
            allowedJobs = {} -- Jobs that can use this crafting station
        },
        -- Placeable Police Crafting Station
        police_bench = {
            label = "Police Equipment Bench",
            description = "Craft police equipment and tools",
            item = "police_crafting_bench",
            prop = "prop_tool_bench02",
            type = "police",
            weaponRepair = false, -- Disable weapon repair
            allowedJobs = {
                {job = "police", grade = 0},
                {job = "sheriff", grade = 0}
            }
        }
    }
}

-- Crafting Items, Recipes, and Crafting Types
Config.CraftingItems = {
    -- Police Crafting Type
    police = {
        {
            name = "lockpick", -- Ox Inventory Item
            label = "Lockpick", -- Display Name
            description = "A tool for picking locks", -- Description
            time = 30, -- seconds
            requiredLevel = 1, -- Required Level
            maxAmount = 10, -- Max Amount crafted at once
            successChance = 100, -- Success Chance
            xpReward = 10, -- XP Reward
            recipe = {
                {item = "metal", amount = 2}, -- Recipe
                {item = "plastic", amount = 1}
            }
        },
        {
            name = "handcuffs",
            label = "Handcuffs",
            description = "Restraining device for suspects",
            time = 45,
            requiredLevel = 2,
            maxAmount = 5,
            successChance = 90,
            xpReward = 15,
            recipe = {
                {item = "metal", amount = 3},
                {item = "plastic", amount = 2}
            }
        },
        {
            name = "radio",
            label = "Police Radio",
            description = "Communication device for law enforcement",
            time = 60,
            requiredLevel = 3,
            maxAmount = 3,
            successChance = 85,
            xpReward = 25,
            recipe = {
                {item = "metal", amount = 4},
                {item = "plastic", amount = 3},
                {item = "electronics", amount = 2}
            }
        }
    },
    
    -- Restaurant Crafting Type
    restaurant = {
        {
            name = "burger",
            label = "Burger",
            description = "Delicious beef burger",
            time = 20,
            requiredLevel = 1,
            maxAmount = 20,
            successChance = 95,
            xpReward = 5,
            recipe = {
                {item = "beef", amount = 1},
                {item = "bread", amount = 2},
                {item = "lettuce", amount = 1}
            }
        },
        {
            name = "pizza",
            label = "Pizza",
            description = "Fresh baked pizza",
            time = 35,
            requiredLevel = 2,
            maxAmount = 15,
            successChance = 90,
            xpReward = 12,
            recipe = {
                {item = "dough", amount = 1},
                {item = "cheese", amount = 2},
                {item = "tomato", amount = 1}
            }
        }
    },
    
    -- Generic Crafting Type
    generic = {
        {
            name = "bandage",
            label = "Bandage",
            description = "Medical bandage for treating wounds",
            time = 25,
            requiredLevel = 1,
            maxAmount = 15,
            successChance = 100,
            xpReward = 8,
            recipe = {
                {item = "cloth", amount = 2}
            }
        },
        {
            name = "firstaid",
            label = "First Aid Kit",
            description = "Advanced medical kit",   
            time = 10,
            requiredLevel = 1,
            maxAmount = 8,
            successChance = 85,
            xpReward = 20,
            recipe = {
                {item = "bandage", amount = 2}
            }
        }
    },
    
    -- Weapon Crafting Type
    weapon = {
        {
            name = "WEAPON_PISTOL",
            label = "Blicky Blammo Pistol",
            description = "A pistol that shoots bullets n stuff",
            time = 25,
            requiredLevel = 1,
            maxAmount = 15,
            successChance = 100,
            xpReward = 8,
            recipe = {
                {item = "metalscrap", amount = 2}
            }
        }
    }
}

-- Level System Configuration
Config.LevelSystem = {
    xpPerLevel = 100, -- Base XP required per level
    maxLevel = 50, -- Maximum level a player can reach
    
    -- Level multiplier
    xpMultiplier = 1.1, -- Each level requires 10% more XP than the previous
}

-- Weapon Repair Recipes
Config.RepairRecipes = {
    -- Weapon repairs only
    ['WEAPON_PISTOL'] = {
        time = 30, -- seconds
        requiredLevel = 1, -- Required Level
        successChance = 85, -- Success Chance
        materials = {
            {item = "steel", amount = 2}, -- Materials
            {item = "gunpowder", amount = 1} -- Materials
        }
    },
    ['WEAPON_SMG'] = {
        time = 45,
        requiredLevel = 2,
        successChance = 80,
        materials = {
            {item = "steel", amount = 3},
            {item = "gunpowder", amount = 2},
            {item = "electronics", amount = 1}
        }
    },
    ['WEAPON_CARBINERIFLE'] = {
        time = 60,
        requiredLevel = 3,
        successChance = 75,
        materials = {
            {item = "steel", amount = 4},
            {item = "gunpowder", amount = 3},
            {item = "electronics", amount = 2}
        }
    },
    ['WEAPON_SHOTGUN'] = {
        time = 40,
        requiredLevel = 2,
        successChance = 80,
        materials = {
            {item = "steel", amount = 3},
            {item = "gunpowder", amount = 2}
        }
    },
}

return Config 