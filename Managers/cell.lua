local clamp = require ("Libraries.lume").clamp
local round = require ("Libraries.lume").round
local randomchoice = require ("Libraries.lume").randomchoice
local weightedchoice = require ("Libraries.lume").weightedchoice
local copyTable = require ("Helpers.copyTable")
local mapToScale = require ("Helpers.mapToScale")
local cellActions = require ("Data.cellActions")

-- Gathers all the cell actions into arrays based on their types
-- This is used by major mutations to replace cell actions with another action of the same type
local cellActionsByType = {}
for id, actionDef in pairs (cellActions) do
    local actionType = actionDef.type

    -- Creates a new array if one hasn't been defined for the current type
    if cellActionsByType[actionType] == nil then
        cellActionsByType[actionType] = {}
    end

    -- Adds the action to the corresponding array
    table.insert (cellActionsByType[actionType], actionDef)
end

-- Cell manager
local cell = {
    map = nil,
}

--- Initializes the cell manager. Must be called before using any other methods.
--- @param map table The map manager.
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
        vars = {0,0,0,0,0},
        health = clamp (health or 500, 0, 500),
        energy = clamp (energy or 500, 0, 500),
        direction = 1,
        lastUpdate  = 0,
        mutationRates = {
            major = 0.1,
            moderate = 0.1,
            minor = 0.1,
            meta = 0.1,
        }
    }

    return newCell
end

--- Updates a single cell during a game tick
function cell:update (tileX, tileY, cellObj, map)
    -- Energy cost
    cellObj.energy = cellObj.energy - 1

    if cellObj.energy < 0 then
        self.map:adjustCellHealth (tileX, tileY, cellObj.energy)
    end

    if cellObj.health <= 0 or self.map:isTaken (tileX, tileY) == false then
        -- Delete cell
        self.map:deleteCell (tileX, tileY)
    else
        -- Run cell script
        cellObj.scriptFunc (tileX, tileY, cellObj, map)
    end
end

local function randomAction (childVars)
    local newActionDef = actionList[math.random (1, #actionList)]
    local newAction = {}
    newAction.id = newActionDef.id

    -- Add random arguments
    newAction.args = {}
    for i = 1, newActionDef.params do
        newAction.args[#newAction.args+1] = "var" .. math.random (1, #childVars)
    end

    -- Add random hyperarguments
    newAction.hyperargs = {}
    for index, hyperparamSet in ipairs (newActionDef.hyperparams) do
        newAction.hyperargs[#newAction.hyperargs+1] = hyperparamSet[math.random (1, #hyperparamSet)]
    end

    return newAction, newActionDef
end

function cell:mutate (childCellObj, parentCellObj)
    -- Mutate color slightly
    local colorIndex = math.random (1, 3)
    local newColor = copyTable (parentCellObj.color)
    newColor[colorIndex] = newColor[colorIndex] + math.random (-5, 5) / 100
    childCellObj.color = newColor

    -- Copy script list and variables
    local childScriptList = copyTable (parentCellObj.scriptList)
    local childVars = copyTable (parentCellObj.vars)
    local childMutRates = copyTable (parentCellObj.mutationRates)

    -- Major mutations
    if math.random () < childMutRates.major then
        local changeType = weightedchoice ({add = 65, delete = 20, replace = 10, swap = 5})
        local actionIndex = math.random (1, #childScriptList)

        if changeType == "add" or #childScriptList <= 0 then
            local newAction, newActionDef = randomAction (childVars)

            table.insert (childScriptList, actionIndex, newAction)
            
            -- Insert end struct
            if newActionDef.type == "control" then
                table.insert (childScriptList, actionIndex + 1, {
                    id = "endStruct",
                    args = {},
                    hyperargs = {},
                })
            end
            
        elseif changeType == "delete" or changeType == "replace" then
            local actionToDelete = childScriptList[actionIndex]
            local actionDef = actionDict[actionToDelete.id]

            if actionToDelete.id == "endStruct" then
                local aboveActionDef = actionDict[childScriptList[actionIndex - 1].id]

                -- Delete two lines if above line is a control type
                if aboveActionDef ~= nil and aboveActionDef.type == "control" then
                    table.remove (childScriptList, actionIndex)
                    table.remove (childScriptList, actionIndex - 1)
                    actionIndex = actionIndex - 1
                
                -- Only delete line above
                else
                    -- table.remove (childScriptList, actionIndex - 1)
                end
            elseif actionDef.type == "control" then
                -- Delete two lines if below line is an endStruct
                if childScriptList[actionIndex + 1].id == "endStruct" then
                    table.remove (childScriptList, actionIndex + 1)
                    table.remove (childScriptList, actionIndex)
                
                -- Only delete line below
                else
                    -- table.remove (childScriptList, actionIndex + 1)
                end
            else
                table.remove (childScriptList, actionIndex)
            end
            
            if changeType == "replace" then
                local newAction, newActionDef = randomAction (childVars)

                table.insert (childScriptList, actionIndex, newAction)
                
                -- Insert end struct
                if newActionDef.type == "control" then
                    table.insert (childScriptList, actionIndex + 1, {
                        id = "endStruct",
                        args = {},
                        hyperargs = {},
                    })
                end
            end
        elseif changeType == "swap" then
            if #childScriptList >= 2 then
                if actionIndex == #childScriptList then
                    actionIndex = actionIndex - 1
                end

                local actionToSwap = childScriptList[actionIndex]
                local actionDef = actionDict[actionToSwap.id]

                if actionToSwap.id ~= "endStruct" and actionDef.type ~= "control" then
                    childScriptList[actionIndex], childScriptList[actionIndex + 1] = childScriptList[actionIndex + 1], childScriptList[actionIndex]
                end
            end
        end
    end

    -- Moderate mutations
    if math.random () < childMutRates.moderate then
        for i = 1, math.random (1, 7) do
            if #childScriptList <= 0 then
                break
            end

            local action = childScriptList[math.random (1, #childScriptList)]
            local actionDef = actionDict[action.id]
            local numArgs, numHyperargs = #action.args, #action.hyperargs

            if numArgs > 0 and numHyperargs > 0 then
                if math.random () < 0.5 then
                    action.args[math.random (1, numArgs)] = "var" .. math.random (1, #childVars)
                else
                    local hyperargIndex = math.random (1, numHyperargs)
                    action.hyperargs[hyperargIndex] = 
                    actionDef.hyperparams[hyperargIndex][math.random (1, #actionDef.hyperparams[hyperargIndex])]
                end
            elseif numArgs > 0 then
                action.args[math.random (1, numArgs)] = "var" .. math.random (1, #childVars)
            elseif numHyperargs > 0 then
                local hyperargIndex = math.random (1, numHyperargs)
                action.hyperargs[hyperargIndex] = actionDef.hyperargs[hyperargIndex][math.random (1, #actionDef.hyperargs[hyperargIndex])]
            end
        end
    end

    -- Minor mutations
    if math.random () < childMutRates.minor then
        -- Increment one of the variables with a random amount
        local varIndex = math.random (1, #childVars)

        -- Small chance to zero a variable instead
        if math.random () < 0.05 then
            childVars[varIndex] = 0
        else
            childVars[varIndex] = childVars[varIndex] + round (mapToScale (love.math.randomNormal () / 10, -3, 3, -100, 100))
        end
    end

    -- Meta mutations
    if math.random () < childMutRates.meta then
        local mutKey = randomchoice ({"major", "moderate", "minor", "meta"})

        childMutRates[mutKey] = clamp (childMutRates[mutKey] + mapToScale (love.math.randomNormal () / 20, -3, 3, -1, 1), 0, 1)
    end

    childCellObj.scriptList = childScriptList
    childCellObj.vars = childVars
    childCellObj.mutationRates = childMutRates
end

function cell:compileScript (cellObj)
    local scriptList = cellObj.scriptList
    local cellVars = cellObj.vars

    local scope = 0 -- Level of indentation
    -- Add arguments to script
    local scriptLines = {
        "local tileX, tileY, cellObj, map = ...\n\n",
        "local origInputVal = 0\n",
        "local enemyTileX, enemyTileY = 1, 1\n",
        "local babyTileX, babyTileY = 1, 1\n",
        "local otherTileX, otherTileY = 1, 1\n",
        "local allSimilar = false\n",
        "local currCellColor, otherCellColor = {1, 1, 1, 1}, {1, 1, 1, 1}\n",
        "local parentHalfHealth, parentHalfEnergy = 0, 0\n",
        "\n",
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

            scriptLines[#scriptLines+1] = string.rep ("    ", scope) .. "end\n"
        else
            local actionDef = actionDict[action.id]

            local filledFuncString = nil
            if #actionDef.interOrder > 0 then
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

                filledFuncString = string.format (actionDef.funcString, unpack (args))
            else
                filledFuncString = actionDef.funcString
            end

            local indent = string.rep ("    ", scope)
            scriptLines[#scriptLines+1] = string.gsub(filledFuncString, "([^\n]+)", indent .. "%1")

            if actionDef.type == "control" then
                scope = scope + 1
            end
        end
    end

    -- Assemble full script string
    local scriptStr = table.concat (scriptLines, "")

    -- print ("======================")
    -- print(scriptStr)
    -- print ()

    local scriptFunc, err = load (scriptStr)
    assert (err == nil, err)

    cellObj.scriptFunc = scriptFunc
end

function cell:printCellInfo (cellObj)
    print ("==========" .. "Cell Info - " .. tostring (cellObj) .. "==========")
    for k, v in pairs (cellObj) do
        print (tostring(k) .. ": " .. tostring(v))
        if type (v) == "table" then
            for k, v in pairs (v) do
                print ("  " .. tostring(k) .. ": " .. tostring(v))
            end
        end
    end
    print ()
end

function cell:printCellScriptList (cellObj)
    print ("==========" .. "Cell Script List - " .. tostring (cellObj) .. "==========")
    for i = 1, #cellObj.scriptList do
        -- Action number and type
        local action = cellObj.scriptList[i]
        print ("  Action " .. i .. " - " .. action.id)

        -- Parameters
        if #action.args > 0 then
            for k, v in ipairs (action.args) do
                print ("    " .. k .. ": " .. v)
            end
        else
            print ("    No arguments used")
        end

        -- Hyperparameters
        if #action.hyperargs > 0 then
            for k, v in ipairs (action.hyperargs) do
                print ("    " .. k .. ": " .. v)
            end
        else
            print ("    No hyperarguments used")
        end
    end
end

return cell