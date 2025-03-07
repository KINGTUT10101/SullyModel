local clamp = require ("Libraries.lume").clamp
local round = require ("Libraries.lume").round
local randomchoice = require ("Libraries.lume").randomchoice
local weightedchoice = require ("Libraries.lume").weightedchoice
local memoize = require ("Libraries.lume").memoize
local copyTable = require ("Helpers.copyTable")
local mapToScale = require ("Helpers.mapToScale")
local addLineNumbers = require ("Helpers.addLineNumbers")

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

-- Cell manager
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

--- Initializes the cell manager. Must be called before using any other methods.
--- @param map table A reference to the map manager
function cell:init (map, actions, actionVars, options)
    options = options or {}
    assert (type (options) == "table", "Provided options argument is not a table")

    self.map = map

    self.minScriptVars = self:validateCompileActions (actions, options.hyperargs)
    self.actionsByKey = actions
    self.actionsByIndex = {}
    self.actionVars = actionVars

    self.scriptVars = options.scriptVars or 5
    self.memVars = options.memVars or 2
    assert (self.scriptVars + self.memVars >= self.minScriptVars, "More variables are needed to meet the minimum required arguments for the provided action set")

    -- Gathers all the cell actions into arrays based on their types and place them into the actionsByIndex array
    -- This is used by major mutations to replace cell actions with another action of the same type
    self.actionsByType = {}
    for id, actionDef in pairs (actions) do
        local actionType = actionDef.type

        -- Creates a new array if one hasn't been defined for the current type
        if self.actionsByType[actionType] == nil then
            self.actionsByType[actionType] = {}
        end

        -- Adds the action to the corresponding array
        table.insert (self.actionsByType[actionType], actionDef)
        table.insert (self.actionsByIndex, actionDef)
    end

    self.maxHealth = options.maxHealth or 500
    self.maxEnergy = options.maxEnergy or 500
    self.tickCost = options.tickCost or 1
    self.maxCells = options.maxCells or math.huge
    self.maxActions = options.maxActions or 1000
    self.minMutRate = options.minMutRate or 0.10
    self.varsPerLevel = options.varsPerLevel or 2

    options.mutsPerChild = options.mutsPerChild or {}
    self.mutsPerChild.min = options.mutsPerChild.min or 0
    self.mutsPerChild.max = options.mutsPerChild.max or 10
    self.mutsPerChild.mean = options.mutsPerChild.mean or 5

    options.initialMutRates = options.initialMutRates or {}
    self.initialMutRates.major = clamp (options.initialMutRates.major or 0.35, self.minMutRate, 1)
    self.initialMutRates.moderate = clamp (options.initialMutRates.moderate or 0.25, self.minMutRate, 1)
    self.initialMutRates.minor = clamp (options.initialMutRates.minor or 0.15, self.minMutRate, 1)
    self.initialMutRates.meta = clamp (options.initialMutRates.meta or 0.25, self.minMutRate, 1)

    options.cellAge = options.cellAge or {}
    self.cellAge.min = options.cellAge.min or 500
    self.cellAge.max = options.cellAge.max or 500
    self.cellAge.mean = options.cellAge.mean or 500
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
        lastUpdate = 0,
        ticksLeft = math.random (self.cellAge.min, self.cellAge.max),
        health = clamp (health or self.maxHealth, 0, self.maxHealth),
        energy = clamp (energy or self.maxEnergy, 0, self.maxEnergy),
        totalEnergy = 0,
        color = {0.5, 0.5, 0.5, 1},
        scriptList = {},
        scriptFunc = function () end,
        vars = {},
        moveDir = 1,
        viewDir = 1,
        relViewX = 0,
        relViewY = 0,
        mutationRates = {
            major = self.initialMutRates.major,
            moderate = self.initialMutRates.moderate,
            minor = self.initialMutRates.minor,
            meta = self.initialMutRates.meta,
        },
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
    local newActionDef = cell.actionsByIndex[math.random (1, #cell.actionsByIndex)]
    local newAction = {}
    newAction.id = newActionDef.id

    -- Add random arguments
    newAction.args = {}
    for key, value in pairs (newActionDef.params) do
        if value == true then
            -- Variable parameter
            newAction.args[key] = "var" .. math.random (1, #childVars)
        else
            -- Option parameter
            newAction.args[key] = value[math.random (1, #value)]
        end
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
                })
            end
            
        elseif changeType == "delete" or changeType == "replace" then
            local actionToDelete = childScriptList[actionIndex]
            local actionDef = self.actionsByKey[actionToDelete.id]

            if actionToDelete.id == "endStruct" then
                local aboveActionDef = self.actionsByKey[childScriptList[actionIndex - 1].id]

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
                    })
                end
            end
        elseif changeType == "swap" then
            if #childScriptList >= 2 then
                if actionIndex == #childScriptList then
                    actionIndex = actionIndex - 1
                end

                local actionToSwap = childScriptList[actionIndex]
                local actionDef = self.actionsByKey[actionToSwap.id]

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

            local action = childScriptList[math.random (1, #childScriptList)] -- Choose a random action from the cell's list
            local actionDef = self.actionsByKey[action.id] -- Get the action def from the action set
            
            if action.id ~= "endStruct" and #actionDef.paramKeys > 0 then
                local argKey = actionDef.paramKeys[math.random (1, #actionDef.paramKeys)]

                if actionDef.params[argKey] == true then
                    -- Assign a random variable key
                    action.args[argKey] = "var" .. math.random (1, #childVars)
                else
                    -- Assign a random option key
                    action.args[argKey] = actionDef.params[argKey][math.random (1, #actionDef.params[argKey])]
                end
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

function cell:compileScript (cellObj, stringOnly)
    stringOnly = stringOnly or false

    local scriptList = cellObj.scriptList
    local cellVars = cellObj.vars

    local scope = 0 -- Level of indentation
    -- Add arguments to script
    local scriptLines = {
        "local tileX, tileY, cellObj, map = ...\n\n",
        "local inf = math.huge\n", -- Bandaid fix to prevent crashes when a variable equals infinity
    }

    -- Add the lines from the action variables
    for i = 1, #self.actionVars do
        scriptLines[#scriptLines+1] = self.actionVars[i] .. "\n"
    end
    scriptLines[#scriptLines+1] = "\n"
    
    -- Add cell variables to script
    -- Script variables
    for i = 1, #cellVars do
        scriptLines[#scriptLines+1] = string.format ("local var%s = %s\n", i, cellVars[i])
    end
    scriptLines[#scriptLines+1] = "\n"
    -- Memory variables
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
            local actionDef = self.actionsByKey[action.id]
            local filledFuncString = nil
            if #actionDef.paramKeys > 0 then
                -- Fill the function string with the interpolated parameters
                filledFuncString = actionDef.funcString:gsub("%$([%w_]+)", function(key)
                    -- Return the replacement value if it exists in lookup_table; otherwise, keep the original substring.
                    return action.args[key] or error ()
                end)
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

    -- Set the value of persistent variables in the vars list
    for i = self.scriptVars + 1, self.scriptVars + self.memVars do
        scriptLines[#scriptLines+1] = string.format ("cellObj.vars[%s] = (var%s == math.huge) and 0 or var%s\n", i, i, i)
    end

    -- Assemble full script string
    local scriptStr = table.concat (scriptLines, "")

    local scriptFunc, err = load (scriptStr)
    assert (err == nil, err)

    if stringOnly == true then
        return scriptStr
    else
        cellObj.scriptFunc = scriptFunc
    end 
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
        local numArgs = 0
        for k, v in pairs (action.args) do
            print ("    " .. k .. ": " .. v)
            numArgs = numArgs + 1
        end
        if numArgs <= 0 then
            print ("    No arguments used")
        end
    end
    print ()
end

function cell:printCellScriptString (cellObj)
    print ("==========" .. "Cell Script List - " .. tostring (cellObj) .. "==========")
    print (addLineNumbers (self:compileScript (cellObj, true)))
    print ()
end

return cell