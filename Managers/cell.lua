local clamp = require ("Libraries.lume").clamp
local round = require ("Libraries.lume").round
local randomchoice = require ("Libraries.lume").randomchoice
local weightedchoice = require ("Libraries.lume").weightedchoice
local copyTable = require ("Helpers.copyTable")
local mapToScale = require ("Helpers.mapToScale")

local cell = {
    map = nil, -- A reference to the map manager
    actionsByKey = nil,
    actionsByIndex = nil,
    actionsByType = nil,
    actionVars = nil,
    minScriptVars = 0,
    scriptVars = 0,
    memVars = 0,
    maxHealth = 0, -- The maximum health of a cell object
    maxEnergy = 0, -- The maximum energy of a cell object
    tickCost = 0,
    maxCells = 0,
    maxActions = 0,
    minMutRate = 0,
    mutsPerChild = {
        min = 0,
        max = 0,
        mean = 0,
    },
    initialMutRates = {
        major = 0,
        moderate = 0,
        minor = 0,
        meta = 0,
    },
    cellAge = {
        min = 0,
        max = 0,
        mean = 0,
    },
}

local actionDict
local actionList = {}

function cell:init (map, cellActions, scriptPrefixes, options)
    options = options or {}
    assert (type (options) == "table", "Provided options argument is not a table")

    self.map = map

    -- TEMP
    actionDict = cellActions
    actionList = {}
    for id, actionDef in pairs (actionDict) do
        actionDef.id = id
        actionList[#actionList+1] = actionDef
    end
    -- Bandaid fix to ensure all action defs have a interpolation order
    for id, actionDef in pairs (actionDict) do
        if actionDef.interOrder == nil then
            assert (actionDef.hyperparams == nil, "Action defined with hyperparameters but without an interpolation order")
    
            actionDef.interOrder = {}
            for i = 1, actionDef.params do
                actionDef.interOrder[i] = "param"
            end
        end
    end

    -- self.minScriptVars = self:validateCompileActions (actions, options.hyperargs)
    -- self.actionsByKey = actions
    -- self.actionsByIndex = {}
    -- self.actionVars = actionVars

    self.scriptVars = options.scriptVars or 5
    self.memVars = options.memVars or 2
    -- assert (self.scriptVars + self.memVars >= self.minScriptVars, "More variables are needed to meet the minimum required arguments for the provided action set")

    -- Gathers all the cell actions into arrays based on their types and place them into the actionsByIndex array
    -- This is used by major mutations to replace cell actions with another action of the same type
    -- self.actionsByType = {}
    -- for id, actionDef in pairs (actions) do
    --     local actionType = actionDef.type

    --     -- Creates a new array if one hasn't been defined for the current type
    --     if self.actionsByType[actionType] == nil then
    --         self.actionsByType[actionType] = {}
    --     end

    --     -- Adds the action to the corresponding array
    --     table.insert (self.actionsByType[actionType], actionDef)
    --     table.insert (self.actionsByIndex, actionDef)
    -- end

    self.maxHealth = options.maxHealth or 500
    self.maxEnergy = options.maxEnergy or 500
    self.tickCost = options.tickCost or 1
    self.maxCells = options.maxCells or math.huge
    self.maxActions = options.maxActions or 1000
    self.minMutRate = options.minMutRate or 0.10

    options.mutsPerChild = options.mutsPerChild or {}
    self.mutsPerChild.min = options.mutsPerChild.min or 0
    self.mutsPerChild.max = options.mutsPerChild.max or 10

    options.initialMutRates = options.initialMutRates or {}
    self.initialMutRates.major = clamp (options.initialMutRates.major or 0.35, self.minMutRate, 1)
    self.initialMutRates.moderate = clamp (options.initialMutRates.moderate or 0.25, self.minMutRate, 1)
    self.initialMutRates.minor = clamp (options.initialMutRates.minor or 0.15, self.minMutRate, 1)
    self.initialMutRates.meta = clamp (options.initialMutRates.meta or 0.25, self.minMutRate, 1)

    options.cellAge = options.cellAge or {}
    self.cellAge.min = options.cellAge.min or 3000
    self.cellAge.max = options.cellAge.max or 6500
end

function cell:validateCompileActions (cellActions, actionHyperargs)
    cellActions = cellActions or {}
    actionHyperargs = actionHyperargs or {}

    local highestMinVars = 0

    -- Flags actions that're missing required attributes and sets default values where sensible
    for id, actionDef in pairs (cellActions) do
        -- Sets some default values for the action definition
        actionDef.params = (type(actionDef.params) == "table") and actionDef.params or {}
        actionDef.hyperparams = (type(actionDef.hyperparams) == "table") and actionDef.hyperparams or {}

        -- Checks if the action type is valid
        if actionTypes[actionDef.type] ~= true then
            error (string.format ("Provided action type is %s, which is invalid", actionDef.type))
        end
    
        -- Checks the required parameters
        for attribute, dataType in pairs (requiredAttributes) do
            -- Raises an error if the attribute has the wrong type
            if type (actionDef[attribute]) ~= dataType then
                error (string.format ("Provided action attribute %s has the wrong type (currently %s, should be %s)", attribute, type (actionDef[attribute]), dataType))
            end
        end

        -- Inserts values into the hyperparams of the provided action
        actionHyperargs[id] = actionHyperargs[id] or {}
        actionDef.funcString = actionDef.funcString:gsub("%$([%w_]+)", function(key)
            if actionHyperargs[id][key] ~= nil then
                return actionHyperargs[id][key] -- Replace value with provided hyperargument

            elseif actionDef.hyperparams[key] ~= nil then
                return actionDef.hyperparams[key] -- Replace value with default hyperargument

            else
                return "$" .. key -- Assume the value is a parameter and keep it the same
            end
        end)
    
        -- Checks if the params used in the function string are defined properly in the params table
        for match in actionDef.funcString:gmatch("%$([%w_]+)") do
            local paramVal = actionDef.params[match]
            
            if type (paramVal) ~= "table" and paramVal ~= true then
                error (string.format ("Found an interpolated function string value (%s) in action function string %s with no compatible parameters", match, id))
            end
        end
            
        -- Find the number of variable parameters needed for this action and determine if it's more than the current max
        local numVarParams = 0 -- The number of variable parameters needed for this action
        for key, value in pairs (actionDef.params) do
            if value == true then
                numVarParams = numVarParams + 1
            end
        end
        highestMinVars = (highestMinVars < numVarParams) and numVarParams or highestMinVars

        -- Adds the parameter keys to a list inside the action
        actionDef.paramKeys = {}
        for key, value in pairs (actionDef.params) do
            table.insert (actionDef.paramKeys, key)
        end
    
        -- Adds the action's ID to its definition
        actionDef.id = id      
    end

    return highestMinVars
end

--- Generates a default cell with no actions
--- @return table cellObj The new default cell object
function cell:new (health, energy)
    local newCell = {
        color = {0.5, 0.5, 0.5, 1},
        scriptList = {},
        scriptFunc = function () end,
        vars = {},
        health = clamp (health or self.maxHealth, 0, self.maxHealth),
        energy = clamp (energy or self.maxEnergy, 0, self.maxEnergy),
        direction = 1,
        lastUpdate  = 0,
        mutationRates = {
            major = self.initialMutRates.major,
            moderate = self.initialMutRates.moderate,
            minor = self.initialMutRates.minor,
            meta = self.initialMutRates.meta,
        },
        totalEnergy = 0,
        ticksLeft = round (mapToScale (love.math.randomNormal ()/ 10, -3, 3, 3000, 6500)),
    }

    for i = 1, self.scriptVars + self.memVars do
        newCell.vars[i] = 0
    end

    return newCell
end

--- Updates a single cell during a game tick
function cell:update (tileX, tileY, cellObj, map)
    -- Energy cost
    self.map:adjustCellEnergy (tileX, tileY, -self.tickCost)

    -- Age the cell by one tick
    cellObj.ticksLeft = cellObj.ticksLeft - 1

    if cellObj.health <= 0 or cellObj.ticksLeft <= 0 then
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
    if math.random () < 0.95 then
        -- Mutate color slightly
        local colorIndex = math.random (1, 3)
        local newColor = copyTable (parentCellObj.color)
        newColor[colorIndex] = clamp (newColor[colorIndex] + math.random (-5, 5) / 100, 0.10, 0.85)
        childCellObj.color = newColor
    end

    -- Copy script list and variables
    local childScriptList = copyTable (parentCellObj.scriptList)
    local childVars = copyTable (parentCellObj.vars)
    local childMutRates = copyTable (parentCellObj.mutationRates)

    -- Major mutations
    if math.random () < childMutRates.major then
        local weightedChoices = {add = 65, delete = 20, replace = 10, swap = 5}

        -- Remove the ability to add to the script list if the script list is too long
        if #childScriptList > self.maxActions then
            weightedChoices.add = nil
        end

        local changeType = weightedchoice (weightedChoices)
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
            -- Small chance to multiply a value
            if math.random () < 0.10 then
                local multSign = (math.random () < 0.50) and 1 or -1

                childVars[varIndex] = childVars[varIndex] * (multSign * mapToScale (love.math.randomNormal (), -3, 6, -1, 6))
            else
                childVars[varIndex] = childVars[varIndex] + round (mapToScale (love.math.randomNormal () / 10, -3, 3, -100, 100))
            end
        end
    end

    -- Meta mutations
    if math.random () < childMutRates.meta then
        local mutKey = randomchoice ({"major", "moderate", "minor", "meta"})

        childMutRates[mutKey] = clamp (childMutRates[mutKey] + mapToScale (love.math.randomNormal () / 20, -3, 3, -1, 1), 0.05, 1)
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
        "local bound1, bound2 = 0, 0\n",
        "local inf = math.huge\n",
        "local result = 0\n",
        "\n",
    }
    
    -- Add cell variables to script
    for i = 1, self.scriptVars do
        scriptLines[#scriptLines+1] = string.format ("local var%s = %s\n", i, tostring(cellVars[i]))
    end
    scriptLines[#scriptLines+1] = "\n"

    for i = self.scriptVars + 1, self.scriptVars + self.memVars do
        scriptLines[#scriptLines+1] = string.format ("local var%s = cellObj.vars[%s]\n", i, i)
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

    -- Set the value of persistent variable in the vars list
    for i = self.scriptVars + 1, self.scriptVars + self.memVars do
        scriptLines[#scriptLines+1] = string.format ("cellObj.vars[%s] = (var%s == math.huge) and 0 or var%s\n", i, i, i)
    end

    -- Assemble full script string
    local scriptStr = table.concat (scriptLines, "")

    -- print ("======================")
    -- print(scriptStr)
    -- print ()

    cellObj.scriptStr = scriptStr

    local scriptFunc, err = load (scriptStr)
    assert (err == nil, err)

    cellObj.scriptFunc = scriptFunc
end

function cell:printCellInfo (cellObj)
    print ("==========" .. "Cell Info - " .. tostring (cellObj) .. "==========")
    for k, v in pairs (cellObj) do
        if k ~= "scriptStr" then
            print (tostring(k) .. ": " .. tostring(v))
            if type (v) == "table" then
                for k, v in pairs (v) do
                    print ("  " .. tostring(k) .. ": " .. tostring(v))
                end
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