local scriptPrefixes = {

}

local actionDefs = {
    readGlobal = {
        desc = "Reads the value from the selected global variable",
        type = "assign",
        params = {
            assignTo = "variable",
            copyFrom = "global",
        },
        hyperparams = {},
        funcString = 
[[
$assignTo = $copyFrom
]]
    },
    changePred = {
        desc = "Increments the selected global variable",
        type = "assign",
        params = {
            vote = {
                "1",
                -- "0",
                "-1",
            }
        },
        hyperparams = {},
        funcString = 
[[
map.currPred = map.currPred + $vote - cellObj.contributions
cellObj.contributions = $vote
]]
    },
    changeGlobal = {
        desc = "Increments the selected global variable",
        type = "assign",
        params = {
            assignTo = "global",
            op = {
                "+",
                "-",
            }
        },
        hyperparams = {},
        funcString =
        [[
$assignTo = $assignTo $op 1
]]
    },
    readInput = {
        desc = "Reads the value from the input tile below the cell",
        type = "assign",
        params = {
            assignTo = "variable",
        },
        hyperparams = {},
        funcString = 
[[
$assignTo = map:getInputTile (map:getForwardPos (tileX, tileY, 1)) or 0
]]
    },
--     consumeInput = {
--         desc = "Takes some of the input value to increase the energy level of the cell",
--         type = "action",
--         params = {},
--         hyperparams = {
--             energyFromTile = 25,
--             energyCost = 2,
--         },
--         funcString = 
-- [[
-- map:transferInputToCell (tileX, tileY, $energyFromTile, $energyCost)
-- if map:isTaken(tileX, tileY) == false then
--     -- print ("Cell death: Consume input", tileX, tileY)
--     return
-- end
-- ]]
--     },
    getOtherDisplayVar = {
        desc = "Gets the display value of another cell",
        type = "assign",
        params = {
            assignTo = "variable",
            displayIndex = "display"
        },
        hyperparams = {},
        funcString =
[[
otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
if map:isTaken (otherTileX, otherTileY) == true then
    $assignTo = map.cellGrid[otherTileX][otherTileY].displayVars[$displayIndex]
end
]]
    },
    setDisplayVar = {
        desc = "Sets the value of one of the cell's display values",
        type = "action",
        params = {
            displayIndex = "display",
            copyFrom = "variable",
        },
        hyperparams = {},
        funcString = 
[[
cellObj.displayVars[$displayIndex] = $copyFrom
]]
    },
    moveForward = {
        desc = "Moves the cell in the direction it's facing",
        type = "action",
        params = {},
        hyperparams = {
            energyCost = 3,
        },
        funcString = 
[[
tileX, tileY, result = map:moveForward (tileX, tileY)
if result == true then
    map:adjustCellEnergy (tileX, tileY, -$energyCost)
    if map:isTaken(tileX, tileY) == false then
        -- print ("Cell death: Move forward", tileX, tileY)
        return
    end
end
]]
    },
    turn = {
        desc = "Turns the cell either left or right",
        type = "action",
        params = {
            turnMethod = {
                "turnLeft",
                "turnRight"
            }
        },
        hyperparams = {},
        funcString = 
[[
map:$turnMethod (tileX, tileY)
]]
    },
--     applyDamage = {
--         desc = "Applies damage to the cell the current cell is facing",
--         type = "action",
--         params = {},
--         hyperparams = {
--             damage = 5,
--             energyCost = 4,
--         },
--         funcString = 
-- [[
-- enemyTileX, enemyTileY = map:getForwardPos (tileX, tileY, 1)
-- map:adjustCellEnergy (tileX, tileY, -$energyCost)
-- map:adjustCellHealth (enemyTileX, enemyTileY, -$damage)
-- if map:isTaken(tileX, tileY) == false then
--     -- print ("Cell death: Apply damage", tileX, tileY)
--     return
-- end
-- ]]
--     },
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
-- if map:getCellTotalResources (tileX, tileY) - $energyCost > 0 then
--     map:adjustCellEnergy (tileX, tileY, -$energyCost)
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
--     -- print ("Cell death: Energize self", tileX, tileY)
--     return
-- end
--     ]]
--     },
    ifStruct = {
        desc = "An if statement that compares two variables",
        type = "control",
        params = {
            term1 = "variable",
            term2 = "variable",
            op = {
                "==",
                "~=",
                ">",
                "<",
            }
        },
        hyperparams = {},
        funcString =
[[
if $term1 $op $term2 then
]]
    },
    isSign = {
        desc = "Determines if the provided value is positive or negative",
        type = "control",
        params = {
            term = "variable",
            op = {
                "<",
                ">"
            }
        },
        hyperparams = {},
        funcString =
[[
if $term $op 0 then
]]
    },
    isTaken = {
        desc = "Determines if the position in front of the current cell contains another cell",
        type = "control",
        params = {},
        hyperparams = {},
        funcString =
[[
if map:isTaken (map:getForwardPos (tileX, tileY, 1)) then
]]
    },
    isSimilar = {
        desc = "Determines if the position in front of the current cell contains another cell with a similar color",
        type = "control",
        params = {
            assignTo = "variable",
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
otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
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
if allSimilar == true then
]]
    },
    forStruct = {
        desc = "A for loop that iterates from 1 until it reaches the value of the provided variable",
        type = "control",
        params = {
            loopTo= "variable",
        },
        hyperparams = {
            maxLoops = 25
        },
        funcString =
[[
for i = 1, math.min ($loopTo, $maxLoops) do
]]
    },
--     reproduce = {
--         desc = "Halves the cell's energy to split and create a new cell",
--         type = "action",
--         params = {},
--         hyperparams = {
--             energyCost = 500,
--             babyHealth = 250,
--             babyEnergy = 250,
--         },
--         funcString =
-- [[
-- babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
-- if map.stats.cells < map.cellManager.maxCells and map:isClear (babyTileX, babyTileY) == true then
--     if cellObj.energy + cellObj.health > $energyCost then
--         map:adjustCellEnergy (tileX, tileY, -$energyCost)
--         map:spawnCell (babyTileX, babyTileY, $babyEnergy, $babyHealth, cellObj)
--         -- print ("Cell spawned")
--     end
-- end
-- ]]
--     },
--     shareEnergy = {
--         desc = "Shares some energy with the cell in front of the current cell",
--         type = "action",
--         params = {},
--         hyperparams = {
--             sharedEnergy = 25,
--             energyCost = 3,
--         },
--         funcString =
-- [[
-- otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
-- map:shareInputToCell (tileX, tileY, otherTileX, otherTileY, $sharedEnergy, $energyCost)
-- if map:isTaken(tileX, tileY) == false then
--     -- print ("Cell death: Share energy", tileX, tileY)
--     return
-- end
-- ]]
--     },
    copyVariable = {
        desc = "Copies the value of a variable",
        type = "assign",
        params = {
            assignTo = "variable",
            copyFrom = "variable",
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
            assignTo = "variable",
            term1 = "variable",
            term2 = "variable",
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
            assignTo = "variable",
            term1 = "variable",
            term2 = "variable",
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
            assignTo = "variable",
            term1 = "variable",
            term2 = "variable",
        },
        hyperparams = {},
        funcString =
[[
$assignTo = $term1 * $term2
if $assignTo ~= $assignTo then $assignTo = 0 end
]]
    },
    divVariables = {
        desc = "Divides ones variable by another",
        type = "assign",
        params = {
            assignTo = "variable",
            term1 = "variable",
            term2 = "variable",
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
            assignTo = "variable",
        },
        hyperparams = {},
        funcString =
[[
$assignTo = 0
]]
    },
    randomNumber = {
        desc = "Assigns a random value to a variable that is between two provided variables",
        type = "assign",
        params = {
            assignTo = "variable",
            bounds = {
                "-1000, 1000",
                "-1, 1",
                "",
                "0, 1",
            },
        },
        hyperparams = {},
        funcString =
[[
$assignTo = math.random ($bounds)
]]
    },
--     getHealth = {
--         desc = "Saves the cell's health to a variable",
--         type = "assign",
--         params = {
--             assignTo = "variable",
--         },
--         hyperparams = {},
--         funcString =
-- [[
-- $assignTo = cellObj.health
-- ]]
--     },
--     getEnergy = {
--         desc = "Saves the cell's energy to a variable",
--         type = "assign",
--         params = {
--             assignTo = "variable",
--         },
--         hyperparams = {},
--         funcString =
-- [[
-- $assignTo = cellObj.energy
-- ]]
--     },
--     getAge = {
--         desc = "Saves the cell's remaining ticks left to a variable",
--         type = "assign",
--         params = {
--             assignTo = "variable",
--         },
--         hyperparams = {},
--         funcString =
-- [[
-- $assignTo = cellObj.ticksLeft
-- ]]
--     },
--     getOtherCellEnergy = {
--         desc = "Saves the energy of the cell in front of the current cell to a variable",
--         type = "assign",
--         params = {
--             assignTo = "variable",
--         },
--         hyperparams = {},
--         funcString =
-- [[
-- $assignTo = map:getCellEnergy (map:getForwardPos (tileX, tileY, 1))
-- ]]
--     },
--     getOtherCellHealth = {
--         desc = "Saves the health of the cell in front of the current cell to a variable",
--         type = "assign",
--         params = {
--             assignTo = "variable",
--         },
--         hyperparams = {},
--         funcString =
-- [[
-- $assignTo = map:getCellHealth (map:getForwardPos (tileX, tileY, 1))
-- ]]
--     },
    getLastPred = {
        desc = "Saves the cell's last prediction to a variable",
        type = "assign",
        params = {
            assignTo = "variable",
        },
        hyperparams = {},
        funcString =
[[
$assignTo = cellObj.lastContribution
]]
    },
    getPosition = {
        desc = "Saves the position of the cell to a pair of variables",
        type = "assign",
        params = {
            assignTo1 = "variable",
            assignTo2 = "variable",
        },
        hyperparams = {},
        funcString =
[[
$assignTo1, $assignTo2 = tileX, tileY
]]
    },
    earlyStop = {
        desc = "Stops the cell's script early",
        type = "action",
        params = {},
        hyperparams = {},
        funcString =
[[
if true then
    return
end
]]
    },
}

return {
    actionDefs = actionDefs,
    scriptPrefixes = scriptPrefixes,
}