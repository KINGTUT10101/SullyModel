local clamp = require ("Libraries.lume").clamp
local round = require ("Libraries.lume").round
local randomchoice = require ("Libraries.lume").randomchoice
local weightedchoice = require ("Libraries.lume").weightedchoice
local copyTable = require ("Helpers.copyTable")
local mapToScale = require ("Helpers.mapToScale")
local addLineNumbers = require ("Helpers.addLineNumbers")
local NeuralNet = require ("Helpers.NeuralNet")
local Neuron = require ("Helpers.Neuron")
local mutationHandlers = require ("Helpers.mutationHandlers")
local actFuncs = require ("Helpers.actFuncs")

local cell = {
    map = nil, -- A reference to the map manager
    actionsByKey = nil,
    actionsByIndex = nil,
    actionsByType = nil,
    actionVars = nil,
    minScriptVars = 0,
    scriptVars = 0,
    memVars = 0,
    displayVars = 0,
    maxHealth = 0, -- The maximum health of a cell object
    maxEnergy = 0, -- The maximum energy of a cell object
    tickCost = 0,
    maxCells = 0,
    minMutRate = 0,
    network = {
        layers = 0,
        maxNeurons = 0,
    },
    mutsPerChild = {
        min = 0,
        max = 0,
        mean = 0,
    },
    initialMutRates = {
        -- major = 0,
        -- moderate = 0,
        -- minor = 0,
        -- meta = 0,
    },
    cellAge = {
        min = 0,
        max = 0,
        mean = 0,
    },
}

--- Initializes the cell class
--- @param map table A reference to the map manager
--- @param inputs table<string, function> A table containing functions that provide input data to the cell's neural network
--- @param actions table<string, function> A table of action functions that can be triggered by the cell's neural network output
--- @param options any
function cell:init (map, inputs, actions, options)
    options = options or {}
    assert (type (options) == "table", "Provided options argument is not a table")

    self.map = map
    self.inputs = inputs
    self.actions = actions

    self.memVars = options.memVars or 2
    self.displayVars = options.displayVars or 1

    options.network = options.network or {}
    self.network.layers = options.network.layers or 3
    self.network.maxNeurons = options.network.maxNeurons or 10
    self.network.weightAdjust = options.network.weightAdjust or 0.1

    self.maxHealth = options.maxHealth or 500
    self.maxEnergy = options.maxEnergy or 500
    self.eggTimer = options.eggTimer or 350
    self.tickCost = options.tickCost or 1
    self.maxCells = options.maxCells or math.huge
    self.minMutRate = options.minMutRate or 1

    options.mutsPerChild = options.mutsPerChild or {}
    self.mutsPerChild.min = options.mutsPerChild.min or 0
    self.mutsPerChild.max = options.mutsPerChild.max or 10

    options.initialMutRates = options.initialMutRates or {}
    self.initialMutRates.addNeuron = clamp (options.initialMutRates.addNeuron or 5, self.minMutRate, 100)
    self.initialMutRates.removeNeuron = clamp (options.initialMutRates.removeNeuron or 2, self.minMutRate, 100)
    self.initialMutRates.increaseWeight = clamp (options.initialMutRates.increaseWeight or 25, self.minMutRate, 100)
    self.initialMutRates.decreaseWeight = clamp (options.initialMutRates.decreaseWeight or 25, self.minMutRate, 100)
    self.initialMutRates.randomizeWeight = clamp (options.initialMutRates.randomizeWeight or 15, self.minMutRate, 100)
    self.initialMutRates.zeroWeight = clamp (options.initialMutRates.zeroWeight or 3, self.minMutRate, 100)
    self.initialMutRates.addConnection = clamp (options.initialMutRates.addConnection or 20, self.minMutRate, 100)
    self.initialMutRates.removeConnection = clamp (options.initialMutRates.removeConnection or 5, self.minMutRate, 100)
    self.initialMutRates.meta = clamp (options.initialMutRates.meta or 5, self.minMutRate, 100)

    options.cellAge = options.cellAge or {}
    self.cellAge.min = options.cellAge.min or 3000
    self.cellAge.max = options.cellAge.max or 6500

    mutationHandlers.init (self)
end


--- Generates a default cell with no actions
--- @return table cellObj The new default cell object
function cell:new (health, energy, type)
    local newCell = {
        type = type or "normal",
        lastUpdate = 0,
        color = {0.5, 0.5, 0.5, 1},
        vars = {},
        displayVars = {},
        health = clamp (health or self.maxHealth, 0, self.maxHealth),
        energy = clamp (energy or self.maxEnergy, 0, self.maxEnergy),
        totalEnergy = 0,
        ticksLeft = round (mapToScale (love.math.randomNormal () / 10, -3, 3, self.cellAge.min, self.cellAge.max)),
        direction = 1,
        mutationRates = {},
        network = NeuralNet:new(self.network.layers),
    }

    -- Initializes the cell's network
    for inputID, inputFunc in pairs (self.inputs) do
        newCell.network:addHidden (inputID, Neuron:new (actFuncs.relu), 1)
    end
    for actionID, actionFunc in pairs (self.actions) do
        newCell.network:addHidden (actionID, Neuron:new (actFuncs.relu), newCell.network:getLayerCount ())
    end

    -- newCell.network:addHidden ("test", Neuron:new (actFuncs.relu), 2) -- TEMP

    -- Initialize memory variables
    for i = 1, self.memVars do
        newCell.vars[i] = 0
    end

    -- Initialize display variables
    for i = 1, self.displayVars do
        newCell.displayVars[i] = 0
    end

    -- Initialize mutation rates
    for key, value in pairs(self.initialMutRates) do
        newCell.mutationRates[key] = value
    end

    return newCell
end


--- Updates a single cell during a game tick
function cell:update (tileX, tileY, cellObj, map)
    if cellObj.type == "normal" or cellObj.type == "egg" then
        -- Energy cost
        self.map:adjustCellEnergy (tileX, tileY, -self.tickCost)
    end
    
    -- Age the cell by one tick
    cellObj.ticksLeft = cellObj.ticksLeft - 1
    
    if cellObj.health <= 0 or cellObj.ticksLeft <= 0 then
        -- Delete cell
        self.map:deleteCell (tileX, tileY)

    elseif cellObj.type == "normal" then
        -- Gather input values
        local inputs = {}

        -- Execute the input functions and add their keys/values to the input table
        for key, inputFunc in pairs(self.inputs) do
            inputs[key] = inputFunc(tileX, tileY, cellObj, self.map)
        end

        -- Run the NN and get outputs
        local outputs = cellObj.network:predict(inputs)

        -- Select the output with the highest value
        -- TODO: If multiple outputs have the same max value, choose one at random instead of the last one found
        local maxOutputKey, maxOutputValue = nil, -math.huge
        for key, value in pairs(outputs) do
            if value > maxOutputValue then
                maxOutputKey, maxOutputValue = key, value
            end
        end

        -- Trigger the action associated with the highest output
        if maxOutputValue > 0 then
            self.actions[maxOutputKey] (tileX, tileY, cellObj, self.map)
        end

    elseif cellObj.type == "egg" then
        error ("TODO: cell eggs in cell:update ()")
        -- cellObj.tickTimer = cellObj.tickTimer - 1

        -- if cellObj.tickTimer <= 0 then
        --     local childCellObj = cellObj.childCell
        --     childCellObj.energy = cellObj.energy
        --     childCellObj.health = cellObj.health

        --     childCellObj.totalEnergy = self.actionsByKey.layEgg.hyperparams.energyCost - cellObj.energy - cellObj.health

        --     self.map.cellGrid[tileX][tileY] = childCellObj
        -- end
    end
end

function cell:mutate (cellObj)
    -- Mutate color slightly
    if math.random () < 0.01 then
        local colorIndex = math.random (1, 3)
        local colorTbl = cellObj.color
        colorTbl[colorIndex] = clamp (colorTbl[colorIndex] + (math.random () < 0.50 and -10 or 10) / 100, 0.10, 0.85)
    end

    -- Pick a mutation type based on mutation rates
    local mutationType = weightedchoice (cellObj.mutationRates)
    -- print (mutationType)
    mutationHandlers[mutationType](cellObj)
end


function cell:newChild (parentCellObj)
    local childCellObj = self:new ()
    childCellObj.type = parentCellObj.type
    childCellObj.color = copyTable(parentCellObj.color)
    childCellObj.mutationRates = copyTable(parentCellObj.mutationRates)
    childCellObj.network = parentCellObj.network:copy()

    return childCellObj
end


function cell:printCellInfo (cellObj)
    print ("==========" .. "Cell Info - " .. tostring (cellObj) .. "==========")
    for k, v in pairs (cellObj) do
        if k ~= "network" then
            if k == "scriptList" then
                print (tostring(k) .. ": " .. #v .. " actions")
            else
                print (tostring(k) .. ": " .. tostring(v))
                if type (v) == "table" then
                    for k, v in pairs (v) do
                        print ("  " .. tostring(k) .. ": " .. tostring(v))
                    end
                end
            end
        end
    end
    print ()
end


function cell:printNetwork (cellObj)
    -- print ("==========" .. "Cell Network - " .. tostring (cellObj) .. "==========")
    cellObj.network:print ()
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
    -- print ("==========" .. "Cell Script List - " .. tostring (cellObj) .. "==========")
    -- print (addLineNumbers (self:compileScript (cellObj, true)))
    -- print ()
    print ("TODO")
end

return cell