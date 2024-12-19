local clamp = require ("Libraries.lume").clamp

local cell = {
    map = nil,
}

local actionList = {
    readInput = {
        desc = "Reads the value from the input tile below the cell",
        type = "assign",
        params = 1,
        funcString = 
[[
%s = map:getInputTile (tileX, tileY)
]]
    },
    consumeInput = {
        desc = "Takes some of the input value to increase the energy level of the cell",
        type = "action",
        params = 0,
        funcString = 
[[
local origInputVal = map:getInputTile (tileX, tileY)
map:incrInputTile (tileX, tileY, -10)
cell.energy = math.max (100, cell.energy + (origInputVal - map:getInputTile (tileX, tileY)) - 2)
]]
    },
    moveForward = {
        desc = "Moves the cell in the direction it's facing",
        type = "action",
        params = 0,
        funcString = 
[[
tileX, tileY = map:moveForward (tileX, tileY)
map:adjustCellEnergy (tileX, tileY, -3)
]]
    },
    turnLeft = {
        desc = "Turns the cell left",
        type = "action",
        params = 0,
        funcString = 
[[
map:turnLeft (tileX, tileY)
map:adjustCellEnergy (tileX, tileY, -1)
]]
    },
    turnRight = {
        desc = "Turns the cell right",
        type = "action",
        params = 0,
        funcString = 
[[
map:turnRight (tileX, tileY)
map:adjustCellEnergy (tileX, tileY, -1)
]]
    },
    applyDamage = {
        desc = "Applies damage to the cell the current cell is facing",
        type = "action",
        params = 0,
        funcString = 
[[
local enemyTileX, enemyTileY = map:getForwardPos (tileX, tileY, 1)
map:adjustCellEnergy (tileX, tileY, -4)
map:adjustCellHealth (enemyTileX, enemyTileY, -5)
]]
    },
    healSelf = {
        desc = "Uses energy to heal the cell",
        type = "action",
        params = 0,
        funcString = 
[[
map:adjustCellEnergy (tileX, tileY, -12)
map:adjustCellHealth (tileX, tileY, 10)
]]
    },
    energizeSelf = {
        desc = "Uses health to energize the cell",
        type = "action",
        params = 0,
        funcString = 
[[
map:adjustCellHealth (tileX, tileY, -12)
if map:isTaken (tileX, tileY) == true then
    map:adjustCellEnergy (tileX, tileY, -12)
end
    ]]
    },
    ifStruct = {
        desc = "An if statement that compares two variables",
        type = "control",
        params = 2,
        hyperparams = {
            {
                "==",
                "~=",
                ">",
                "<",
            },
        },
        interOrder = {"param", "hyper", "param"},
        funcString =
[[
if %s %s %s then
]]
    },
    forStruct = {
        desc = "A for loop that iterates from 1 until it reaches the value of the provided variable",
        type = "control",
        params = 1,
        funcString =
[[
for i = 1, %s do
]]
    },
    reproduce = {
        desc = "Uses some energy to create a clone of the current cell. The child cell will split the energy equally among health/energy. It will fail if the parent dies.",
        type = "action",
        params = 0,
        funcString =
[[
local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
if map:isClear (babyTileX, babyTileY) == true then
    map:adjustCellEnergy (tileX, tileY, -100)
    if map:isTaken (tileX, tileY) == true then
        map:spawnCell (babyTileX, babyTileY, 50, 50)
    end
end
]]
    },
    isTaken = {
        desc = "Determines if the position in front of the current cell contains another cell",
        type = "assign",
        params = 0,
        funcString =
[[
%s = (map:isTaken (map:getForwardPos (tileX, tileY, 1))) and 1 or 0
]]
    },
    isSimilar = {
        desc = "Determines if the position in front of the current cell contains another cell with a similar color",
        type = "assign",
        params = 1,
        hyperparams = {
            {
                0.01,
                0.05,
                0.15,
                0.25,
            }
        },
        interOrder = {"hyper", "param"},
        funcString =
[[
local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
local allSimilar = false
if map:isTaken (otherTileX, otherTileY) == true then
    local currCellColor = cell.color
    local otherCellColor = map.cellGrid[otherTileX][otherTileY].color

    allSimilar = true
    for i = 1, 3 do
        if math.abs (currCellColor[i] - otherCellColor[i]) > %s then
            allSimilar = false
        end
    end
end
%s = (allSimilar == true) and 1 or 0
]]
    },
    copyVariable = {
        desc = "Copies the value of a variable",
        type = "assign",
        params = 2,
        funcString =
[[
%s = %s
]]
    },
    addVariables = {
        desc = "Adds two variables together",
        type = "assign",
        params = 3,
        funcString =
[[
%s = %s + $s
]]
    },
    subVariables = {
        desc = "Subtracts ones variable from another",
        type = "assign",
        params = 3,
        funcString =
[[
%s = %s - $s
]]
    },
    zeroVariable = {
        desc = "Sets the value of a variable to zero",
        type = "assign",
        params = 1,
        funcString =
[[
%s = 0
]]
    },
    getHealth = {
        desc = "Saves the cell's health to a variable",
        type = "assign",
        params = 1,
        funcString =
[[
%s = cell.health
]]
    },
    getEnergy = {
        desc = "Saves the cell's energy to a variable",
        type = "assign",
        params = 1,
        funcString =
[[
%s = cell.energy
]]
    },
}

-- Bandaid fix to ensure all action defs have a interpolation order
for id, actionDef in pairs (actionList) do
    if actionDef.interOrder == nil then
        assert (actionDef.hyperparams == nil, "Action defined with hyperparameters but without an interpolation order")

        actionDef.interOrder = {}
        for i = 1, actionDef.params do
            actionDef.interOrder[i] = "param"
        end
    end
end

function cell:init (map)
    self.map = map
end

--- Generates a default cell with no actions
--- @return table cellObj The new default cell object
function cell:new (health, energy)
    local newCell = {
        color = {0.5, 0.5, 0.5, 1},
        scriptList = {},
        scriptFunc = function () end,
        vars = {},
        numVars = 1,
        health = clamp (health or 100, 0, 100),
        energy = clamp (energy or 100, 0, 100),
        direction = 1,
    }

    return newCell
end

--- Updates a single cell during a game tick
function cell:update (cellObj, tileX, tileY)
    -- Energy cost
    cellObj.energy = cellObj.energy - 1

    if cellObj.energy < 0 then
        self.map:adjustCellHealth (tileX, tileY, cellObj.energy)
    end

    if self.map:isTaken (tileX, tileY) == true then
        if cellObj.health <= 0 then
            -- Delete cell
            self.map:deleteCell (tileX, tileY)
            -- Add cell's remaining energy and health to the ground
            self.map:incrInputTile (tileX, tileY, cell.health + math.min (10, cell.energy))
        else
            -- Run cell script
            cellObj.scriptFunc (tileX, tileY)
        end
    end
end

function cell:mutate (cellObj)
    -- Mutate color slightly
    -- Copy script list
    -- Randomly choose several indices and changes to perform (add, remove, or swap actions)
    -- Return the new script list
end

function cell:compileScript (cellObj)
    local cellVars = cellObj.vars
    local scriptList = cellObj.scriptList

    local scope = 0 -- Level of indentation
    -- Add arguments to script
    local scriptLines = {
        "local tileX, tileY, cell, map = ...\n\n"
    }
    
    -- Add cell variables to script
    for i = 1, #cellVars do
        scriptLines[#scriptLines+1] = string.format ("local var%s = %s\n", i, cellVars[i])
    end
    scriptLines[#scriptLines+1] = "\n"

    -- Add the body of the script
    for i = 1, #scriptList do
        local action = scriptList[i]

        if action.id == "endStruct" then
            scope = scope - 1

            scriptLines[#scriptLines+1] = string.rep ("    ", scope) .. "end"
        else
            local actionDef = actionList[action.id]

            -- Get a list of arguments and hyperarguments
            local args = {}
            local argIndex, hyperargIndex = 1, 1
            for i = 1, #actionDef.interOrder do
                if actionDef.interOrder[i] == "hyper" then
                    args[i] = action.hyperargs[hyperargIndex]
                    hyperargIndex = hyperargIndex + 1
                else
                    args[i] = action.args[argIndex]
                    argIndex = argIndex + 1
                end
            end

            local indent = string.rep ("    ", scope)
            scriptLines[#scriptLines+1] = string.gsub(string.format (actionDef.funcString, unpack (args)), "([^\n]+)", indent .. "%1")

            if actionDef.type == "control" then
                scope = scope + 1
            end
        end
    end

    -- Assemble full script string
    local scriptStr = table.concat (scriptLines, "")

    print(scriptStr)

    local scriptFunc, err = load (scriptStr)
    assert (err == nil, err)

    return scriptFunc
end

local cellScriptRecursive, cellScriptLinear, variables = loadfile ("testCellScript.lua") ()

cell:compileScript ({
    scriptList = cellScriptLinear,
    vars = variables,
})

return cell