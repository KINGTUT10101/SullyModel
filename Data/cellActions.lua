local cellActionVars = {
    "local origInputVal = 0",
    "local enemyTileX, enemyTileY = 1, 1",
    "local babyTileX, babyTileY = 1, 1",
    "local otherTileX, otherTileY = 1, 1",
    "local allSimilar = false",
    "local currCellColor, otherCellColor = {1, 1, 1, 1}, {1, 1, 1, 1}",
    "local parentHalfHealth, parentHalfEnergy = 0, 0",
}

local cellActions = {
    readInput = {
        desc = "Reads the value from the input tile in the cell's view",
        type = "assign",
        params = {
            assignTo = true,
        },
        hyperparams = {},
        funcString = 
[[
$assignTo = map:getInputTile (tileX, tileY) or 0
]]
    },
    consumeInput = {
        desc = "Takes some of the input value to increase the energy level of the cell",
        type = "action",
        params = {},
        hyperparams = {
            energyFromTile = 25,
            energyCost = 2,
        },
        funcString = 
[[
-- Energy cost of consuming a tile
map:adjustCellEnergy (tileX, tileY, -$energyCost)

if map:isTaken(tileX, tileY) == false then
    print ("Cell death: Consume input", tileX, tileY)
    return
else
    local inputVal = map:getInputTile (tileX, tileY)

    if inputVal <= $energyFromTile then
        cellObj.energy = cellObj.energy + inputVal
        cellObj.totalEnergy = cellObj.totalEnergy + inputVal
        inputVal = 0
    else
        cellObj.energy = cellObj.energy + $energyFromTile
        cellObj.totalEnergy = cellObj.totalEnergy + $energyFromTile
        inputVal = inputVal - $energyFromTile
    end

    if cellObj.energy > map.cellManager.maxEnergy then -- Cell energy max
        cellObj.totalEnergy = cellObj.totalEnergy - (cellObj.energy - map.cellManager.maxEnergy)
        inputVal = inputVal + cellObj.energy - map.cellManager.maxEnergy
        cellObj.energy = map.cellManager.maxEnergy
    end

    map:setInputTile (tileX, tileY, inputVal)
end
]]
    },
    moveCellForward = {
        desc = "Moves the cell in the direction it's facing",
        type = "action",
        params = {},
        hyperparams = {
            energyCost = 3,
        },
        funcString = 
[[
tileX, tileY = map:moveCellForward (tileX, tileY)
map:adjustCellEnergy (tileX, tileY, -$energyCost)
if map:isTaken(tileX, tileY) == false then
    print ("Cell death: Move forward", tileX, tileY)
    return
end
]]
    },
    turnCellLeft = {
        desc = "Turns the cell left",
        type = "action",
        params = {},
        hyperparams = {},
        funcString = 
[[
map:turnCellLeft (tileX, tileY)
]]
    },
    turnCellRight = {
        desc = "Turns the cell right",
        type = "action",
        params = {},
        hyperparams = {},
        funcString = 
[[
map:turnCellRight (tileX, tileY)
]]
    },
--     moveViewForward = {
--         desc = "Moves the cell's view in the direction it's facing",
--         type = "action",
--         params = {},
--         hyperparams = {
--             energyCost = 0,
--         },
--         funcString = 
-- [[
-- map:moveViewForward (tileX, tileY)
-- map:adjustCellEnergy (tileX, tileY, -$energyCost)
-- if map:isTaken(tileX, tileY) == false then
--     print ("Cell death: Move forward", tileX, tileY)
--     return
-- end
-- ]]
--     },
--     turnViewLeft = {
--         desc = "Turns the cell's view left",
--         type = "action",
--         params = {},
--         hyperparams = {},
--         funcString = 
-- [[
-- map:turnViewLeft (tileX, tileY)
-- ]]
--     },
--     turnViewRight = {
--         desc = "Turns the cell's view right",
--         type = "action",
--         params = {},
--         hyperparams = {},
--         funcString = 
-- [[
-- map:turnViewRight (tileX, tileY)
-- ]]
--     },
--     zeroView = {
--         desc = "Zeros the cell's view",
--         type = "action",
--         params = {},
--         hyperparams = {},
--         funcString = 
-- [[
-- cellObj.relViewX, cellObj.relViewY = 0, 0
-- ]]
--     },
    getDirection = {
        desc = "Returns the cell's direction for either its view or movement",
        type = "action",
        params = {
            assignTo = true,
            dirType = {
                "moveDir",
                -- "viewDir",
            },
        },
        hyperparams = {},
        funcString = 
[[
$assignTo = cellObj.$dirType
]]
    },
    applyDamage = {
        desc = "Applies damage to the cell the current cell is facing",
        type = "action",
        params = {},
        hyperparams = {
            damage = 5,
            energyCost = 4,
        },
        funcString = 
[[
enemyTileX, enemyTileY = map:getForwardPos (tileX, tileY, cellObj.moveDir)
if map:isTaken (enemyTileX, enemyTileY) == true then
    map:adjustCellEnergy (tileX, tileY, -$energyCost)
    
    if map:isTaken(tileX, tileY) == false then
        print ("Cell death: Apply damage", tileX, tileY)
        return
    else
        map:adjustCellHealth (enemyTileX, enemyTileY, -$damage)
    end
end
]]
    },
--     healSelf = {
--         desc = "Uses energy to heal the cell",
--         type = "action",
--         params = {},
--         hyperparams = {
--             healing = 10,
--             energyCost = 12,
--         },
--         funcString = 
-- [[
-- map:adjustCellEnergy (tileX, tileY, -$energyCost)
-- if map:isTaken(tileX, tileY) == false then
--     print ("Cell death: Heal self", tileX, tileY)
--     return
-- else
--     map:adjustCellHealth (tileX, tileY, $healing)
-- end
-- ]]
--     },
--     energizeSelf = {
--         desc = "Uses health to energize the cell",
--         type = "action",
--         params = {},
--         hyperparams = {
--             energyTransferred = 12,
--             healthCost = 12,
--         },
--         funcString = 
-- [[
-- map:adjustCellHealth (tileX, tileY, -$healthCost)
-- if map:isTaken (tileX, tileY) == true then
--     map:adjustCellEnergy (tileX, tileY, $energyTransferred)
-- else
--     print ("Cell death: Energize self", tileX, tileY)
--     return
-- end
--     ]]
--     },
    ifStruct = {
        desc = "An if statement that compares two variables",
        type = "control",
        params = {
            term1 = true,
            term2 = true,
            op = {
                "==",
                "~=",
                ">",
                "<",
            },
        },
        funcString =
[[
if $term1 $op $term2 then
]]
    },
    forStruct = {
        desc = "A for loop that iterates from 1 until it reaches the value of the provided variable",
        type = "control",
        params = {
            loopTo = true,
        },
        hyperparams = {
            maxLoops = 10,
        },
        funcString =
[[
for i = 1, math.min ($maxLoops, $loopTo) do
]]
    },
    reproduce = {
        desc = "Halves the cell's energy to split and create a new cell",
        type = "action",
        params = {},
        hyperparams = {
            energyCost = 500,
        },
        funcString =
[[
babyTileX, babyTileY = map:getForwardPos (tileX, tileY, cellObj.moveDir)
if map:isClear (babyTileX, babyTileY) == true then
    if map:getCellTotalResources (tileX, tileY) > $energyCost then
        if map:spawnCell (babyTileX, babyTileY, $energyCost / 2, $energyCost / 2, cellObj) == true then
            map:adjustCellEnergy (tileX, tileY, -$energyCost)
        end
        print ("Cell spawned")
    end
end
]]
    },
    shareEnergy = {
        desc = "Shares some energy with the cell in front of the current cell",
        type = "action",
        params = {},
        hyperparams = {
            sharedEnergy = 25,
            energyCost = 0,
        },
        funcString =
[[
otherTileX, otherTileY = map:getForwardPos (tileX, tileY, cellObj.moveDir)

if map:isTaken (otherTileX, otherTileY) == true then
    if map:getCellTotalResources (tileX, tileY) > ($sharedEnergy + $energyCost) then
        map:adjustCellEnergy (tileX, tileY, -($sharedEnergy + $energyCost))
        map:adjustCellEnergy (otherTileX, otherTileY, $sharedEnergy)
    else
        map:adjustCellEnergy (tileX, tileY, -$energyCost)
        map:adjustCellEnergy (otherTileX, otherTileY, map:getCellTotalResources (tileX, tileY))

        print ("Cell death: Share energy", tileX, tileY)
        return
    end
end
]]
    },
    isTaken = {
        desc = "Determines if the position in front of the current cell contains another cell",
        type = "assign",
        params = {
            assignTo = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = (map:isTaken (map:getForwardPos (tileX, tileY, cellObj.moveDir))) and 1 or -1
]]
    },
    isSimilar = {
        desc = "Determines if the position in front of the current cell contains another cell with a similar color",
        type = "assign",
        params = {
            assignTo = true,
            similarRating = {
                0.01,
                0.05,
                0.15,
                0.25,
            }
        },
        hyperparams = {},
        funcString =
[[
otherTileX, otherTileY = map:getForwardPos (tileX, tileY, cellObj.moveDir)
allSimilar = false
if map:isTaken (otherTileX, otherTileY) == true then
    currCellColor = cellObj.color
    otherCellColor = map.cellGrid[otherTileX][otherTileY].color

    allSimilar = true
    for i = 1, 3 do
        if math.abs (currCellColor[i] - otherCellColor[i]) > $similarRating then
            allSimilar = false
        end
    end
end
$assignTo = (allSimilar == true) and 1 or -1
]]
    },
    copyVariable = {
        desc = "Copies the value of a variable",
        type = "assign",
        params = {
            assignTo = true,
            copyFrom = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = $copyFrom
]]
    },
    addVariables = {
        desc = "Adds two variables together",
        type = "assign",
        params = {
            assignTo = true,
            term1 = true,
            term2 = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = $term1 + $term2
if $assignTo ~= $assignTo then $assignTo = 0 end
]]
    },
    subVariables = {
        desc = "Subtracts ones variable from another",
        type = "assign",
        params = {
            assignTo = true,
            term1 = true,
            term2 = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = $term1 - $term2
if $assignTo ~= $assignTo then $assignTo = 0 end
]]
    },
    multVariables = {
        desc = "Multiplies ones variable by another",
        type = "assign",
        params = {
            assignTo = true,
            term1 = true,
            term2 = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = $term1 * $term2
if $assignTo ~= $assignTo then $assignTo = 0 end
]]
    },
    divVariables = {
        desc = "Divides ones variable from another",
        type = "assign",
        params = {
            assignTo = true,
            term1 = true,
            term2 = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = $term1 / $term2
if $assignTo ~= $assignTo then $assignTo = 0 end
]]
    },
    zeroVariable = {
        desc = "Sets the value of a variable to zero",
        type = "assign",
        params = {
            assignTo = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = 0
]]
    },
--     getConstantNum = {
--         desc = "Sets the value of a variable to one of several predefined numbers",
--         type = "assign",
--         params = {
--             assignTo = true,
--             constNum = {
--                 math.huge,
--                 math.pi,
--                 math.exp(1),
--             },
--         },
--         hyperparams = {},
--         funcString =
-- [[
-- $assignTo = $constNum
-- ]]
--     },
    getRandomNum = {
        desc = "Sets the value of a variable to a random number between two variables",
        type = "assign",
        params = {
            assignTo = true,
            bounds = {
                "-1000, 1000",
                "-1, 1",
                "",
                "0, 1",
            }
        },
        hyperparams = {},
        funcString =
[[
$assignTo = math.random ($bounds)
]]
    },
    getOtherEnergy = {
        desc = "Saves the cell's energy to a variable",
        type = "assign",
        params = {
            assignTo = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = map:getCellEnergy (map:getForwardPos (tileX, tileY, cellObj.moveDir))
]]
    },
    getOtherHealth = {
        desc = "Saves the cell's health to a variable",
        type = "assign",
        params = {
            assignTo = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = map:getCellHealth (map:getForwardPos (tileX, tileY, cellObj.moveDir))
]]
    },
    getOtherAge = {
        desc = "Saves the cell's age to a variable",
        type = "assign",
        params = {
            assignTo = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = map:getCellAge (map:getForwardPos (tileX, tileY, cellObj.moveDir))
]]
    },
    getEnergy = {
        desc = "Saves the cell's energy to a variable",
        type = "assign",
        params = {
            assignTo = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = cellObj.energy
]]
},
    getHealth = {
        desc = "Saves the cell's health to a variable",
        type = "assign",
        params = {
            assignTo = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = cellObj.health
]]
},
    getAge = {
        desc = "Saves the cell's age to a variable",
        type = "assign",
        params = {
            assignTo = true,
        },
        hyperparams = {},
        funcString =
[[
$assignTo = cellObj.ticksLeft
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

return {
    actions = cellActions,
    actionVars = cellActionVars,
}