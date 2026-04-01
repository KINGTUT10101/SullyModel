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
local lume = require ("Libraries.lume")

local adjacentOffsets = {
    {0, -1},
    {1, 0},
    {0, 1},
    {-1, 0},
}

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
    maxCells = {},
    maxWalls = {},
    minMutRate = 0,
    network = {
        layers = 0,
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
    decision = {
        useSoftmax = false,   -- If true, turn output logits into probabilities
        temperature = 1.0,    -- Softmax temperature (>0). Lower is peakier; higher is flatter
        sample = false,       -- If true, sample an action by probability; else pick argmax
    },
    consumeOnTick = {
        amount = 0,
        cost = 0,
    },
    varBounds = {
        min = -1,
        max = 1,
    },
    -- actionThreshold = 0,
    actionsPerTurn = 1,
    age = {
        min = 0,
        max = 0,
    },
    reproductionEnergy = {
        min = 0,
        max = 0,
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

    -- self.actionThreshold = options.actionThreshold or 0.0
    self.actionsPerTurn = options.actionsPerTurn or 1

    self.memVars = options.memVars or 2
    self.displayVars = options.displayVars or 1

    options.varBounds = options.varBounds or {}
    self.varBounds.min = options.varBounds.min or -100
    self.varBounds.max = options.varBounds.max or 100

    self.canZeroVars = options.canZeroVars or false

    options.network = options.network or {}
    self.network.layers = options.network.layers or 3
    self.network.weightAdjust = options.network.weightAdjust or 0.1
    self.decision.useSoftmax = (options.decision and options.decision.useSoftmax) or false
    self.decision.temperature = (options.decision and options.decision.temperature) or 1.0
    self.decision.sample = (options.decision and options.decision.sample) or false

    if type(self.network.neuronsPerLayer) ~= "table" then
        assert (type (self.network.neuronsPerLayer) == "number" or self.network.neuronsPerLayer == nil, "Invalid neuronsPerLayer value")

        local singularValue = self.network.neuronsPerLayer or 10
        self.network.neuronsPerLayer = {}
        for i = 1, self.network.layers do
            self.network.neuronsPerLayer[i] = singularValue
        end

    else
        assert (self.network.layers == #self.network.neuronsPerLayer, "Mismatch between layers and neuronsPerLayer length")
    end

    options.consumeOnTick = options.consumeOnTick or {}
    self.consumeOnTick.amount = options.consumeOnTick.amount or 15
    self.consumeOnTick.cost = options.consumeOnTick.cost or 5

    self.maxHealth = options.maxHealth or 500
    self.maxEnergy = options.maxEnergy or 500
    self.maxWasteBuffer = options.maxWasteBuffer or 500
    self.eggTimer = options.eggTimer or 350
    self.tickCost = options.tickCost or 1
    self.minMutRate = options.minMutRate or 1
    self.superparents = options.superparents or 3
    self.superparentFoodTypes = options.superparentFoodTypes

    if self.superparentFoodTypes == nil or #self.superparentFoodTypes ~= self.superparents then
        assert (#self.superparentFoodTypes == self.superparents, "Mismatch between number of superparents and superparentFoodTypes length")
    end

    self.maxCells = options.maxCells or nil
    if type(self.maxCells) ~= "table" then
        assert (type (self.maxCells) == "number" or self.maxCells == nil, "Invalid max cells value")

        local singularValue = self.maxCells or 10
        self.maxCells = {}
        for superparent = 1, self.superparents do
            self.maxCells[superparent] = singularValue
        end
    else
        assert (self.superparents == #self.maxCells, "Mismatch between superparents (" .. self.superparents .. ") and maxCells length (" .. #self.maxCells .. ")")
    end

    self.maxWalls = options.maxWalls or nil
    if type(self.maxWalls) ~= "table" then
        assert (type (self.maxWalls) == "number" or self.maxWalls == nil, "Invalid max walls value")

        local singularValue = self.maxWalls or 10
        self.maxWalls = {}
        for superparent = 1, self.superparents do
            self.maxWalls[superparent] = singularValue
        end
    else
        assert (self.superparents == #self.maxWalls, "Mismatch between superparents (" .. self.superparents .. ") and maxWalls length (" .. #self.maxWalls .. ")")
    end

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
    self.initialMutRates.age = clamp (options.initialMutRates.age or 10, self.minMutRate, 100)
    self.initialMutRates.reproductionEnergy = clamp (options.initialMutRates.reproductionEnergy or 10, self.minMutRate, 100)
    self.initialMutRates.actionThreshold = clamp (options.initialMutRates.actionThreshold or 25, self.minMutRate, 100)

    options.age = options.age or {}
    self.age.min = options.age.min or 50
    self.age.max = options.age.max or 6000

    options.reproductionEnergy = options.reproductionEnergy or {}
    self.reproductionEnergy.min = options.reproductionEnergy.min or 2
    self.reproductionEnergy.max = options.reproductionEnergy.max or math.ceil ((self.maxEnergy + self.maxHealth) * 0.5)

    self.pheromones = options.pheromones or 2
    self.pheromoneTime = options.pheromoneTime or 250

    mutationHandlers.init (self)

    print ("Cell manager initialized")
end

local validFoodTypes = {
    meat = true,
    plant = true,
    waste = true,
}
--- Generates a default cell with no actions
--- @return table cellObj The new default cell object
function cell:new (health, energy, superparent, type)
    assert (superparent ~= nil, "Superparent must be provided")

    local newCell = {
        type = type or "normal",
        lastUpdate = 0,
        color = {0.5, 0.5, 0.5, 1},
        vars = {},
        displayVars = {},
        health = clamp (health or self.maxHealth, 0, self.maxHealth),
        energy = clamp (energy or self.maxEnergy, 0, self.maxEnergy),
        wasteBuffer = 0,
        -- totalEnergy = 0,
        ticksLeft = self.age.max * 0.5,
        direction = 1,
        mutationRates = {},
        network = NeuralNet:new(self.network.layers),
        superparent = superparent,
        maxAge = self.age.max * 0.5,
        reproductionEnergy = self.reproductionEnergy.max * 0.5,
        consumes = self.superparentFoodTypes[superparent],
        actionThreshold = 0,
    }

    -- Initializes the cell's network
    for inputID, _ in pairs (self.inputs) do
        -- Input layer: identity activation (raw sensor value after normalization)
        newCell.network:addHidden (inputID, Neuron:new (actFuncs.identity), 1)
    end

    -- Output neurons
    local finalLayerIndex = self.network.layers + 2
    for i = 1, self.memVars do
        newCell.network:addHidden ("getMem" .. i, Neuron:new (actFuncs.identity), 1)
        newCell.network:addHidden ("memIncr" .. i, Neuron:new (actFuncs.tanh), finalLayerIndex)
        newCell.network:addHidden ("memDecr" .. i, Neuron:new (actFuncs.tanh), finalLayerIndex)

        if self.canZeroVars == true then
            newCell.network:addHidden ("memZero" .. i, Neuron:new (actFuncs.tanh), finalLayerIndex)
        end
    end
    for i = 1, self.displayVars do
        newCell.network:addHidden ("disIncr" .. i, Neuron:new (actFuncs.tanh), finalLayerIndex)
        newCell.network:addHidden ("disDecr" .. i, Neuron:new (actFuncs.tanh), finalLayerIndex)
        newCell.network:addHidden ("getDis" .. i, Neuron:new (actFuncs.identity), 1)
        newCell.network:addHidden ("avgAdjDis" .. i, Neuron:new (actFuncs.identity), 1)

        if self.canZeroVars == true then
            newCell.network:addHidden ("disZero" .. i, Neuron:new (actFuncs.tanh), finalLayerIndex)
        end
    end
    for i = 1, self.pheromones do
        newCell.network:addHidden ("emitPhero" .. i, Neuron:new (actFuncs.tanh), finalLayerIndex)
        newCell.network:addHidden ("getPhero" .. i, Neuron:new (actFuncs.identity), 1)
    end
    for actionID, _ in pairs (self.actions) do
        -- Output layer: identity activation produces logits for softmax (or raw scores)
        newCell.network:addHidden (actionID, Neuron:new (actFuncs.tanh), finalLayerIndex)
    end
    for i = 1, self.network.layers do
        local newNeuron = Neuron:new(actFuncs.leaky()) -- Call the factory to get the actual function
        local newID = lume.uuid() -- stable unique key
        newCell.network:addHidden (newID, newNeuron, i + 1)
    end

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

local wasteMap = {
    meat = "waste",
    plants = "waste",
    waste = "plants",
}
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
            local success, result = pcall (inputFunc, tileX, tileY, cellObj, self.map)

            if success == true then
                inputs[key] = result
            else
                local errorMsg = "Error in cell input function '" .. tostring (key) .. "': " .. tostring (result)
                error (errorMsg)
            end
        end
        for i = 1, self.memVars do
            inputs["getMem" .. i] = mapToScale (cellObj.vars[i], self.varBounds.min, self.varBounds.max, -1, 1)
        end
        local envTile = map.envGrid[tileX][tileY]
        for i = 1, self.memVars do
            inputs["getPhero" .. i] = (envTile.pheromones[i] > 0) and 1 or -1
        end
        for i = 1, self.displayVars do
            local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)

            if map:isTaken (otherTileX, otherTileY) == true then
                inputs["getDis" .. i] = mapToScale (map.cellGrid[otherTileX][otherTileY].displayVars[i], self.varBounds.min, self.varBounds.max, -1, 1)
            end

            local total = 0
            local count = 0
            for j = 1, #adjacentOffsets do
                local dx = adjacentOffsets[j][1]
                local dy = adjacentOffsets[j][2]
                local adjX, adjY = tileX + dx, tileY + dy

                if map:isTaken (adjX, adjY) == true then
                    local value = map.cellGrid[adjX][adjY].displayVars[i]
                    if value ~= nil then
                        total = total + value
                        count = count + 1
                    end
                end
            end

            if count > 0 then
                inputs["avgAdjDis" .. i] = mapToScale (total / count, self.varBounds.min, self.varBounds.max, -1, 1)
            else
                inputs["avgAdjDis" .. i] = 0
            end
        end

        -- Run the NN and get outputs
        local outputs = cellObj.network:predict(inputs)

        -- Consume energy automatically
        if self.consumeOnTick.amount > 0 then
            local itx, ity = map:getForwardPos (tileX, tileY, 1)
            map:transferInputToCell (itx, ity, tileX, tileY, self.superparentFoodTypes[cellObj.superparent], self.consumeOnTick.amount, self.consumeOnTick.cost)
        end

        -- Decide action from outputs: either softmax-based or raw argmax
        if self.decision.useSoftmax == true then
            error ("Not implemented: softmax-based action selection")

            -- local T = (self.decision.temperature and self.decision.temperature > 0) and self.decision.temperature or 1.0

            -- -- Compute numerically stable softmax probabilities over outputs
            -- local maxLogit = -math.huge
            -- for _, v in pairs(outputs) do
            --     if v > maxLogit then maxLogit = v end
            -- end

            -- local expSum = 0
            -- local probs = {}
            -- for k, v in pairs(outputs) do
            --     local z = (v - maxLogit) / T
            --     local ev = math.exp(z)
            --     probs[k] = ev
            --     expSum = expSum + ev
            -- end
            -- if expSum <= 0 then
            --     -- Degenerate case; fall back to uniform distribution
            --     local n = 0
            --     for _ in pairs(outputs) do n = n + 1 end
            --     for k, _ in pairs(outputs) do probs[k] = 1 / n end
            -- else
            --     for k, v in pairs(probs) do probs[k] = v / expSum end
            -- end

            -- local chosenKey
            -- if self.decision.sample == true then
            --     -- Sample by probability
            --     chosenKey = weightedchoice(probs)
            -- else
            --     -- Argmax over probabilities
            --     local bestK, bestP = nil, -math.huge
            --     for k, p in pairs(probs) do
            --         if p > bestP then bestK, bestP = k, p end
            --     end
            --     chosenKey = bestK
            -- end

            -- if chosenKey ~= nil then
            --     -- Check if chosenKey is for memory vars or display vars
            --     if string.sub (chosenKey, 1, 3) == "mem" then
            --         local actionType = string.sub(chosenKey, 4, 7)
            --         local varIndex = tonumber(string.sub(chosenKey, 8))
            --         cellObj.vars[varIndex] = (actionType == "Incr") and cellObj.vars[varIndex] + 1 or cellObj.vars[varIndex] - 1
            --         cellObj.vars[varIndex] = clamp (cellObj.vars[varIndex], self.varBounds.min, self.varBounds.max)

            --     elseif string.sub (chosenKey, 1, 3) == "dis" then
            --         local actionType = string.sub(chosenKey, 4, 7)
            --         local varIndex = tonumber(string.sub(chosenKey, 8))
            --         cellObj.displayVars[varIndex] = (actionType == "Incr") and cellObj.displayVars[varIndex] + 1 or cellObj.displayVars[varIndex] - 1
            --         cellObj.displayVars[varIndex] = clamp (cellObj.displayVars[varIndex], self.varBounds.min, self.varBounds.max)

            --     elseif string.sub (chosenKey, 1, 9) == "emitPhero" then
            --         envTile.pheromones[tonumber(string.sub(chosenKey, 10))] = self.pheromoneTime

            --     else
            --         self.actions[chosenKey](tileX, tileY, cellObj, self.map)
            --     end
            -- end
        else
            -- Choose argmax over raw outputs and act only if its above the threshold

            -- Sort the outputs array
            table.sort (outputs, function(a, b) return a[2] > b[2] end)

            local cellX, cellY = tileX, tileY
            for i = 1, self.actionsPerTurn do
                if cellObj.health <= 0 then
                    break
                end

                assert (map.cellGrid[cellX][cellY] == cellObj, "Cell object mismatch during action execution")

                local outputValue = outputs[i][2]

                if outputValue > cellObj.actionThreshold then
                    local outputKey = outputs[i][1]

                    -- -- TEMP
                    -- cellObj.actionsTaken = cellObj.actionsTaken or {}
                    -- table.insert (cellObj.actionsTaken, 1, outputKey)
                    -- table.remove (cellObj.actionsTaken, 6)

                    -- Check if outputKey is for memory vars or display vars
                    if string.sub (outputKey, 1, 3) == "mem" then
                        local actionType = string.sub(outputKey, 4, 7)
                        local varIndex = tonumber(string.sub(outputKey, 8))
                        if actionType == "Zero" then
                            cellObj.vars[varIndex] = 0
                        elseif actionType == "Incr" then
                            cellObj.vars[varIndex] = cellObj.vars[varIndex] + 1
                        elseif actionType == "Decr" then
                            cellObj.vars[varIndex] = cellObj.vars[varIndex] - 1
                        else
                            error ("Unknown memory var action type: " .. tostring (actionType))
                        end
                        cellObj.vars[varIndex] = clamp (cellObj.vars[varIndex], self.varBounds.min, self.varBounds.max)

                    elseif string.sub (outputKey, 1, 3) == "dis" then
                        local actionType = string.sub(outputKey, 4, 7)
                        local varIndex = tonumber(string.sub(outputKey, 8))
                        if actionType == "Zero" then
                            cellObj.displayVars[varIndex] = 0
                        elseif actionType == "Incr" then
                            cellObj.displayVars[varIndex] = cellObj.displayVars[varIndex] + 1
                        elseif actionType == "Decr" then
                            cellObj.displayVars[varIndex] = cellObj.displayVars[varIndex] - 1
                        else
                            error ("Unknown display var action type: " .. tostring (actionType))
                        end
                        cellObj.displayVars[varIndex] = clamp (cellObj.displayVars[varIndex], self.varBounds.min, self.varBounds.max)

                    elseif string.sub (outputKey, 1, 9) == "emitPhero" then
                        envTile.pheromones[tonumber(string.sub(outputKey, 10))] = self.pheromoneTime

                    else
                        cellX, cellY = self.actions[outputKey](cellX, cellY, cellObj, self.map)
                    end
                end
            end
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
    if mutationHandlers[mutationType] then
        mutationHandlers[mutationType](cellObj)
    end
end


function cell:newChild (parentCellObj)
    local childCellObj = self:new (nil, nil, parentCellObj.superparent)
    childCellObj.type = parentCellObj.type
    childCellObj.color = copyTable(parentCellObj.color)
    childCellObj.mutationRates = copyTable(parentCellObj.mutationRates)
    childCellObj.network = parentCellObj.network:copy()
    childCellObj.direction = parentCellObj.direction
    childCellObj.maxAge = parentCellObj.maxAge
    childCellObj.reproductionEnergy = parentCellObj.reproductionEnergy
    childCellObj.ticksLeft = childCellObj.maxAge
    -- childCellObj.superparent = parentCellObj.superparent

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