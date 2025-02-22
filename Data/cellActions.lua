local cellActions = {
    readInput = {
        desc = "Reads the value from the input tile below the cell",
        type = "assign",
        params = 1,
        hyperparams = {},
        interOrder = {"param",},
        funcString = 
[[
%s = map:getInputTile (tileX, tileY)
]]
    },
    consumeInput = {
        desc = "Takes some of the input value to increase the energy level of the cell",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString = 
[[
map:transferInputToCell (tileX, tileY, 25)
if map:isTaken(tileX, tileY) == false then
    print ("Cell death: Consume input", tileX, tileY)
    return
end
]]
    },
    moveForward = {
        desc = "Moves the cell in the direction it's facing",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString = 
[[
tileX, tileY = map:moveForward (tileX, tileY)
map:adjustCellEnergy (tileX, tileY, -3)
if map:isTaken(tileX, tileY) == false then
    print ("Cell death: Move forward", tileX, tileY)
    return
end
]]
    },
    turnLeft = {
        desc = "Turns the cell left",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString = 
[[
map:turnLeft (tileX, tileY)
-- map:adjustCellEnergy (tileX, tileY, -1)
-- if map:isTaken(tileX, tileY) == false then
--     return
-- end
]]
    },
    turnRight = {
        desc = "Turns the cell right",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString = 
[[
map:turnRight (tileX, tileY)
-- map:adjustCellEnergy (tileX, tileY, -1)
-- if map:isTaken(tileX, tileY) == false then
--     return
-- end
]]
    },
--     applyDamage = {
--         desc = "Applies damage to the cell the current cell is facing",
--         type = "action",
--         params = 0,
--         hyperparams = {},
--         interOrder = {},
--         funcString = 
-- [[
-- enemyTileX, enemyTileY = map:getForwardPos (tileX, tileY, 1)
-- map:adjustCellEnergy (tileX, tileY, -4)
-- map:adjustCellHealth (enemyTileX, enemyTileY, -5)
-- if map:isTaken(tileX, tileY) == false then
--     print ("Cell death: Apply damage", tileX, tileY)
--     return
-- end
-- ]]
--     },
    healSelf = {
        desc = "Uses energy to heal the cell",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString = 
[[
map:adjustCellEnergy (tileX, tileY, -12)
map:adjustCellHealth (tileX, tileY, 10)
if map:isTaken(tileX, tileY) == false then
    print ("Cell death: Heal self", tileX, tileY)
    return
end
]]
    },
    energizeSelf = {
        desc = "Uses health to energize the cell",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString = 
[[
map:adjustCellHealth (tileX, tileY, -12)
if map:isTaken (tileX, tileY) == true then
    map:adjustCellEnergy (tileX, tileY, -12)
end
if map:isTaken(tileX, tileY) == false then
    print ("Cell death: Energize self", tileX, tileY)
    return
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
        hyperparams = {},
        interOrder = {"param"},
        funcString =
[[
for i = 1, %s do
]]
    },
--     reproduce = {
--         desc = "Halves the cell's health and energy to split and create a new cell",
--         type = "action",
--         params = 0,
--         hyperparams = {},
--         interOrder = {},
--         funcString =
-- [[
-- babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
-- if map:isClear (babyTileX, babyTileY) == true then
--     parentHalfHealth = map:getCellHealth (tileX, tileY) / 2
--     parentHalfEnergy = map:getCellEnergy (tileX, tileY) / 2
--     map:adjustCellEnergy (tileX, tileY, -math.ceil (parentHalfEnergy) * 2)
    
--     if map:isTaken(tileX, tileY) == true then
--         map:adjustCellHealth (tileX, tileY, -math.ceil (parentHalfHealth) * 2)
        
--         if map:isTaken(tileX, tileY) == true then
--             map:spawnCell (babyTileX, babyTileY, math.floor (parentHalfHealth), math.floor (parentHalfEnergy), cellObj)
--             print ("Cell spawned")
--         else
--             return
--         end
--     else
--         return
--     end
-- end
-- ]]
--     },
    shareEnergy = {
        desc = "Shares some energy with the cell in front of the current cell",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString =
[[
otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
map:shareInputToCell (tileX, tileY, otherTileX, otherTileY, 25)
if map:isTaken(tileX, tileY) == false then
    print ("Cell death: Share energy", tileX, tileY)
    return
end
]]
    },
    isTaken = {
        desc = "Determines if the position in front of the current cell contains another cell",
        type = "assign",
        params = 1,
        hyperparams = {},
        interOrder = {"param"},
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
otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
allSimilar = false
if map:isTaken (otherTileX, otherTileY) == true then
    currCellColor = cellObj.color
    otherCellColor = map.cellGrid[otherTileX][otherTileY].color

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
        hyperparams = {},
        interOrder = {"param", "param"},
        funcString =
[[
%s = %s
]]
    },
    addVariables = {
        desc = "Adds two variables together",
        type = "assign",
        params = 3,
        hyperparams = {},
        interOrder = {"param", "param", "param"},
        funcString =
[[
%s = %s + %s
]]
    },
    subVariables = {
        desc = "Subtracts ones variable from another",
        type = "assign",
        params = 3,
        hyperparams = {},
        interOrder = {"param", "param", "param"},
        funcString =
[[
%s = %s - %s
]]
    },
    zeroVariable = {
        desc = "Sets the value of a variable to zero",
        type = "assign",
        params = 1,
        hyperparams = {},
        interOrder = {"param"},
        funcString =
[[
%s = 0
]]
    },
    getConstantNum = {
        desc = "Sets the value of a variable to one of several predefined numbers",
        type = "assign",
        params = 1,
        hyperparams = {
            {
                math.huge,
                math.pi,
                math.exp(1),
            },
        },
        interOrder = {"param"},
        funcString =
[[
%s = %s
]]
    },
    getHealth = {
        desc = "Saves the cell's health to a variable",
        type = "assign",
        params = 1,
        hyperparams = {},
        interOrder = {"param"},
        funcString =
[[
%s = cellObj.health
]]
    },
    getEnergy = {
        desc = "Saves the cell's energy to a variable",
        type = "assign",
        params = 1,
        hyperparams = {},
        interOrder = {"param"},
        funcString =
[[
%s = cellObj.energy
]]
    },
    getOtherCellEnergy = {
        desc = "Saves the energy of the cell in front of the current cell to a variable",
        type = "assign",
        params = 1,
        hyperparams = {},
        interOrder = {"param"},
        funcString =
[[
otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
%s = map:getCellEnergy (otherTileX, otherTileY)
]]
    },
    earlyStop = {
        desc = "Stops the cell's script early",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString =
[[
if true then
    return
end
]]
    },
}

-- TODO: Change actions to use this definition scheme for variables
-- (In an action definition)
-- funcString = "($param1 + $param2) * $rate",
-- params = {
--     param1 = true,
--     param2 = true,
--     rate = {
--         "0.01",
--         "0.05",
--         "0.25",
--     },
-- }

-- (In a spawned cell)
-- args = {
--     param1 = "var3_1",
--     param2 = "var1_5",
--     rate = "0.05",
-- }


local requiredAttributes = {
    desc = "string",
    type = "string",
    funcString = "string",
}
local actionTypes = {
    action = true, -- Performs an operation that doesn't save data to cell object's variables.
    assign = true, -- Performs an operation that modifies at least one of the cell object's variable.
    control = true, -- A programming control structure that starts a new scope in the cell object's script.
}

-- Flags actions that're missing required attributes and sets default values where sensible
for id, actionDef in pairs (cellActions) do
    -- Checks the required parameters
    for attribute, dataType in pairs (requiredAttributes) do
        -- Raises an error if the attribute has the wrong type
        if type (actionDef[attribute]) ~= dataType then
            error (string.format ("Provided action attribute %s has the wrong type (currently %s, should be %s)", attribute, type (actionDef[attribute]), dataType))
        end
    end

    -- Checks if the provided interpolation dictionary is valid
    -- TODO: Add code to find matches
    -- actionDef.interDict = actionDef.interDict or {}
    -- for match in actionDef.funcString do
    --     local dictVal = actionDef.interDict[match]
    --     if type (dictVal) ~= "table" or type (dictVal) ~= "boolean" then
    --         error (string.format ("Found an interpolated function string value (%s) with an incorrect interpolation dictionary definition", match))
    --     end
    -- end

    -- Adds the action's ID to its definition
    actionDef.id = id
end

return cellActions