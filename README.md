# SJCrafting

A FiveM crafting system with placeable benches, weapon repair, and ox_inventory integration.

## Installation

1. Download and place the `sjcrafting` folder in your server's resources directory
2. Add `ensure sjcrafting` to your server.cfg
3. Ensure you have the following dependencies:

## Dependencies
- Qbox
- Ox_lib
- Ox_inventory  
- Ox_target

## Setup

### 1. Build the Web UI

Navigate to the web directory and install dependencies:

```bash
cd web
npm install
npm run build
```

### 2. Configure ox_inventory Items

Add these items to your ox_inventory items.lua:

```lua
['crafting_bench_w'] = {
    label = 'Weapon Crafting Bench',
    weight = 5000,
    stack = false,
    close = true,
    description = 'Placeable weapon crafting bench',
    consume = 0,
    buttons = {
        {
            label = 'Place Crafting Bench',
            action = function(slot)
                exports.sjcrafting:placeCraftingBench(slot)
            end
        }
    }
},

['police_crafting_bench'] = {
    label = 'Police Equipment Bench', 
    weight = 5000,
    stack = false,
    close = true,
    description = 'Placeable police equipment bench',
    consume = 0,
    buttons = {
        {
            label = 'Place Crafting Bench',
            action = function(slot)
                exports.sjcrafting:placeCraftingBench(slot)
            end
        }
    }
}
```

### Database Setup

The script will automatically create the required database tables on startup. If you encounter any database issues, you can manually run the `database.sql` file in your MySQL database.

## Adding More Placeable Items

To add additional placeable crafting benches:

1. Add the item to ox_inventory items.lua with the placement button:

```lua
['your_crafting_bench'] = {
    label = 'Your Crafting Bench',
    weight = 5000,
    stack = false,
    close = true,
    description = 'Placeable crafting bench',
    consume = 0,
    buttons = {
        {
            label = 'Place Crafting Bench',
            action = function(slot)
                exports.sjcrafting:placeCraftingBench(slot)
            end
        }
    }
}
```

2. Add the bench type to `Config.CraftingStations.placeable` in `modules/config.lua`:

```lua
your_bench_type = {
    label = "Your Crafting Bench",
    description = "Description of your bench",
    item = "your_crafting_bench",
    prop = "prop_tool_bench02",
    type = "your_type",
    weaponRepair = false,
    allowedJobs = {
        {job = "your_job", grade = 0}
    }
}
```

3. Add crafting recipes to `Config.CraftingItems.your_type` section

## Configuration

### Adding New Recipes

Add recipes to the appropriate section and type in `Config.CraftingItems`:

```lua
{
    name = "item_name",
    label = "Item Label",
    description = "Item description",
    time = 30, -- seconds
    requiredLevel = 1,
    maxAmount = 10,
    successChance = 100, -- percentage
    xpReward = 10,
    recipe = {
        {item = "material1", amount = 2},
        {item = "material2", amount = 1}
    }
}
```

## Features

- Placeable crafting benches
- Weapon repair system
- Job-based access control
- Level and XP system
- Queue-based crafting
- ox_inventory integration
- ox_target interaction

## Commands
- /createcrafting to create a new crafting table
- /managecrafting to view, teleport to, and delete all crafting tables

## Usage

1. Use a crafting bench item from inventory(or place as admin)
2. Approach the placed bench and third eye to interact
3. Select items to craft or repair
4. Wait for crafting/repair to complete

## Exports

- `placeCraftingBench(slot)` - Places a crafting bench from inventory slot 
