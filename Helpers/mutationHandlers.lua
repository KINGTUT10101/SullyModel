local lume = require("Libraries.lume")
local actFuncs = require("Helpers.actFuncs")
local Neuron = require("Helpers.Neuron")
local mapToScale = require("Helpers.mapToScale")

local mutationHandlers = {}

local cell = nil

function mutationHandlers.init(cellRef)
    cell = cellRef
    assert (type (cell) == "table", "Invalid cell reference")
end

function mutationHandlers.addNeuron(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 1 do
        weightedChoices[i] = cellObj.network:getLayerSize(i) + 1
    end

    local chosenLayer = lume.weightedchoice(weightedChoices)
    if not chosenLayer then
        return
    end

    if cellObj.network:getLayerSize(chosenLayer) < cell.network.neuronsPerLayer[chosenLayer - 1] then
        -- Use a stable unique string key instead of the neuron table itself.
        -- Using the neuron table as the key caused stale position/index mapping issues
        -- inside KeyedArray after insert/delete operations, eventually breaking copies.
        local hiddenAlpha = 0.05
        local newNeuron = Neuron:new(actFuncs.leaky(hiddenAlpha), {name = "leaky", params = {alpha = hiddenAlpha}}) -- Call the factory to get the actual function
        local newID = lume.uuid() -- stable unique key
        cellObj.network:addHidden (newID, newNeuron, chosenLayer)
    end
end

function mutationHandlers.removeNeuron(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 1 do
        weightedChoices[i] = cellObj.network:getLayerSize(i) + 1
    end

    local chosenLayer = lume.weightedchoice(weightedChoices)
    if not chosenLayer then
        return
    end
    if cellObj.network:getLayerSize(chosenLayer) > 0 then
        cellObj.network:removeHiddenIndexed (math.random (1, cellObj.network:getLayerSize(chosenLayer)), chosenLayer)
    end
end

function mutationHandlers.increaseWeight(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() do
        weightedChoices[i] = cellObj.network:getLayerSize(i) + 1
    end

    local chosenLayer = lume.weightedchoice(weightedChoices)
    if chosenLayer then
        local layerSize = cellObj.network:getLayerSize(chosenLayer)
        if layerSize > 0 then
            local chosenNeuronIndex = math.random (1, layerSize)
            local weightCount = cellObj.network:getWeightCountIndexed (chosenNeuronIndex, chosenLayer)
            
            if weightCount > 0 then
                local chosenWeightIndex = math.random(1, weightCount)
                cellObj.network:adjustWeightIndexed(chosenNeuronIndex, chosenLayer, chosenWeightIndex, cell.network.weightAdjust)
            end
        end
    end
end

function mutationHandlers.decreaseWeight(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() do
        weightedChoices[i] = cellObj.network:getLayerSize(i) + 1
    end

    local chosenLayer = lume.weightedchoice(weightedChoices)
    if chosenLayer then
        local layerSize = cellObj.network:getLayerSize(chosenLayer)
        if layerSize > 0 then
            local chosenNeuronIndex = math.random (1, layerSize)
            local weightCount = cellObj.network:getWeightCountIndexed (chosenNeuronIndex, chosenLayer)
            
            if weightCount > 0 then
                local chosenWeightIndex = math.random(1, weightCount)
                cellObj.network:adjustWeightIndexed(chosenNeuronIndex, chosenLayer, chosenWeightIndex, -cell.network.weightAdjust)
            end
        end
    end
end

function mutationHandlers.randomizeWeight(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() do
        weightedChoices[i] = cellObj.network:getLayerSize(i) + 1
    end

    local chosenLayer = lume.weightedchoice(weightedChoices)
    if chosenLayer then
        local layerSize = cellObj.network:getLayerSize(chosenLayer)

        if layerSize > 0 then
            local chosenNeuronIndex = math.random (1, layerSize)
            local weightCount = cellObj.network:getWeightCountIndexed (chosenNeuronIndex, chosenLayer)
            
            if weightCount > 0 then
                local chosenWeightIndex = math.random(1, weightCount)
                local newWeight = mapToScale (math.random (), 0, 1, -1, 1)
                cellObj.network:setWeightIndexed(chosenNeuronIndex, chosenLayer, chosenWeightIndex, newWeight)
            end
        end
    end
end

function mutationHandlers.zeroWeight(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() do
        weightedChoices[i] = cellObj.network:getLayerSize(i) + 1
    end

    local chosenLayer = lume.weightedchoice(weightedChoices)
    if chosenLayer then
        local layerSize = cellObj.network:getLayerSize(chosenLayer)
        if layerSize > 0 then
            local chosenNeuronIndex = math.random (1, layerSize)
            local weightCount = cellObj.network:getWeightCountIndexed (chosenNeuronIndex, chosenLayer)
            
            if weightCount > 0 then
                local chosenWeightIndex = math.random(1, weightCount)
                cellObj.network:setWeightIndexed(chosenNeuronIndex, chosenLayer, chosenWeightIndex, 0)
            end
        end
    end
end

function mutationHandlers.addConnection(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() do
        weightedChoices[i] = cellObj.network:getLayerSize(i) + 1
    end

    local chosenLayer = lume.weightedchoice(weightedChoices)
    if chosenLayer then
        local layerSize = cellObj.network:getLayerSize(chosenLayer)

        if layerSize > 0 then
            local chosenNeuronIndex = math.random (1, layerSize)

            if cellObj.network:getLayerSize(chosenLayer - 1) > 0 then
                local fromIndex = math.random(1, cellObj.network:getLayerSize(chosenLayer - 1))
                local initialWeight = mapToScale(math.random(), 0, 1, -1, 1)
                cellObj.network:addConnectionIndexed(fromIndex, chosenNeuronIndex, chosenLayer, initialWeight)
            end
        end
    end
end

function mutationHandlers.removeConnection(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() do
        weightedChoices[i] = cellObj.network:getLayerSize(i) + 1
    end

    local chosenLayer = lume.weightedchoice(weightedChoices)
    if chosenLayer then
        local toLayerSize = cellObj.network:getLayerSize(chosenLayer)
        local fromLayerSize = cellObj.network:getLayerSize(chosenLayer - 1)
        
        if toLayerSize > 0 and fromLayerSize > 0 then
            local chosenNeuronIndex = math.random(1, toLayerSize)
            local fromNeuronIndex = math.random(1, fromLayerSize)
            
            -- Remove the connection from the randomly chosen neurons
            cellObj.network:removeConnectionIndexed(fromNeuronIndex, chosenNeuronIndex, chosenLayer)
        end
    end
end

function mutationHandlers.meta(cellObj)
    local mutationType = lume.randomchoice (lume.keys (cellObj.mutationRates))
    local changeAmount = lume.randomchoice ({-1, 1}) * (math.random (1, 10) / 100)

    cellObj.mutationRates[mutationType] = lume.clamp (cellObj.mutationRates[mutationType] + changeAmount, 0, 100)
end

function mutationHandlers.age(cellObj)
    local changeAmount = lume.randomchoice ({-1, 1}) * (math.random (5, 25))

    cellObj.maxAge = lume.clamp (cellObj.maxAge + changeAmount, cell.age.min, cell.age.max)
end

function mutationHandlers.reproductionEnergy(cellObj)
    local changeAmount = lume.randomchoice ({-1, 1}) * (math.random (50, 250))
    
    cellObj.reproductionEnergy = lume.clamp (cellObj.reproductionEnergy + changeAmount, cell.reproductionEnergy.min, cell.reproductionEnergy.max)
end

function mutationHandlers.actionThreshold (cellObj)
    local changeAmount = lume.randomchoice ({-1, 1}) * (math.random (1, 25) / 100)

    cellObj.actionThreshold = lume.clamp (cellObj.actionThreshold + changeAmount, -1, 1)
end

return mutationHandlers