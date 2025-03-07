local actionDefs = {
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
    applyDamage = {
        desc = "Applies damage to the cell the current cell is facing",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString = 
[[
enemyTileX, enemyTileY = map:getForwardPos (tileX, tileY, 1)
map:adjustCellEnergy (tileX, tileY, -4)
map:adjustCellHealth (enemyTileX, enemyTileY, -5)
if map:isTaken(tileX, tileY) == false then
    print ("Cell death: Apply damage", tileX, tileY)
    return
end
]]
    },
    healSelf = {
        desc = "Uses energy to heal the cell",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString = 
[[
if map:getCellTotalResources (tileX, tileY) - 12 > 0 then
    map:adjustCellEnergy (tileX, tileY, -12)
    map:adjustCellHealth (tileX, tileY, 10)
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
for i = 1, math.min (%s, 25) do
]]
    },
    reproduce = {
        desc = "Halves the cell's energy to split and create a new cell",
        type = "action",
        params = 0,
        hyperparams = {},
        interOrder = {},
        funcString =
[[
babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
if map.stats.cells < 200 and map:isClear (babyTileX, babyTileY) == true then
    local parentEnergy = map:getCellEnergy (tileX, tileY)
    local parentHealth = map:getCellHealth (tileX, tileY)
    
    if parentEnergy + parentHealth > 500 then
        map:adjustCellEnergy (tileX, tileY, -500)
        map:spawnCell (babyTileX, babyTileY, 250, 250, cellObj)
        print ("Cell spawned")
    end
end
]]
    },
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
result = %s + %s
%s = (result == result) and result or 0
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
result = %s - %s
%s = (result == result) and result or 0
]]
    },
    multVariables = {
        desc = "Multiplies ones variable by another",
        type = "assign",
        params = 3,
        hyperparams = {},
        interOrder = {"param", "param", "param"},
        funcString =
[[
result = %s * %s
%s = (result == result) and result or 0
]]
    },
    divVariables = {
        desc = "Divides ones variable by another",
        type = "assign",
        params = 3,
        hyperparams = {},
        interOrder = {"param", "param", "param"},
        funcString =
[[
result = %s / %s
%s = (result == result) and result or 0
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
--     randomNumber = {
--         desc = "Assigns a random value to a variable that is between two provided variables",
--         type = "assign",
--         params = 3,
--         hyperparams = {},
--         interOrder = {"param", "param", "param"},
--         funcString =
-- [[
-- bound1, bound2 = %s, %s

-- if bound1 > bound2 then
--     bound1, bound2 = bound2, bound1
-- end
-- %s = math.random (math.floor (bound1), math.floor (bound2))
-- ]]
--     },
    randomNumber = {
        desc = "Assigns a random value to a variable that is between two provided variables",
        type = "assign",
        params = 1,
        hyperparams = {},
        interOrder = {"param"},
        funcString =
[[
%s = math.random (-1000, 1000)
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
    getAge = {
        desc = "Saves the cell's remaining ticks left to a variable",
        type = "assign",
        params = 1,
        hyperparams = {},
        interOrder = {"param"},
        funcString =
[[
%s = cellObj.ticksLeft
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

local scriptPrefixes = {

}

return {
    actionDefs = actionDefs,
    scriptPrefixes = scriptPrefixes,
}