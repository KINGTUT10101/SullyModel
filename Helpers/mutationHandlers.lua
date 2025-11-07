local lume = require("Libraries.lume")
local actFuncs = require("Helpers.actFuncs")
local Neuron = require("Helpers.Neuron")
local mapToScale = require("Helpers.mapToScale")

local mutationHandlers = {}

local cell = nil

function mutationHandlers.init(cellRef)
    cell = cellRef
end

function mutationHandlers.addNeuron(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 2 do
        weightedChoices[i] = cellObj.network:getLayerSize(i)
    end

    if #weightedChoices == 0 then
        return
    end
    local chosenLayer = lume.weightedchoice(weightedChoices)
    if cellObj.network:getLayerSize(chosenLayer) < cell.network.maxNeurons then
        local newNeuron = Neuron:new(actFuncs.relu)
        cellObj.network:addHidden (newNeuron, newNeuron, chosenLayer)
    end
end

function mutationHandlers.removeNeuron(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 2 do
        weightedChoices[i] = cellObj.network:getLayerSize(i)
    end

    if #weightedChoices == 0 then
        return
    end
    local chosenLayer = lume.weightedchoice(weightedChoices)
    if cellObj.network:getLayerSize(chosenLayer) > 0 then
        cellObj.network:removeHiddenIndexed (math.random (1, cellObj.network:getLayerSize(chosenLayer)), chosenLayer)
    end
end

function mutationHandlers.increaseWeight(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 2 do
        weightedChoices[i] = cellObj.network:getLayerSize(i)
    end

    if #weightedChoices == 0 then
        return
    end
    local chosenLayer = lume.weightedchoice(weightedChoices)
    local chosenNeuronIndex = math.random (1, cellObj.network:getLayerSize(chosenLayer))
    local weightCount = cellObj.network:getWeightCountIndexed (chosenNeuronIndex, chosenLayer)
    
    if weightCount > 0 then
        local chosenWeightIndex = math.random(1, weightCount)
        cellObj.network:adjustWeight(chosenNeuronIndex, chosenLayer, chosenWeightIndex, cell.network.weightAdjust)
    end
end

function mutationHandlers.decreaseWeight(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 2 do
        weightedChoices[i] = cellObj.network:getLayerSize(i)
    end

    if #weightedChoices == 0 then
        return
    end
    local chosenLayer = lume.weightedchoice(weightedChoices)
    local chosenNeuronIndex = math.random (1, cellObj.network:getLayerSize(chosenLayer))
    local weightCount = cellObj.network:getWeightCountIndexed (chosenNeuronIndex, chosenLayer)
    
    if weightCount > 0 then
        local chosenWeightIndex = math.random(1, weightCount)
        cellObj.network:adjustWeight(chosenNeuronIndex, chosenLayer, chosenWeightIndex, -cell.network.weightAdjust)
    end
end

function mutationHandlers.randomizeWeight(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 2 do
        weightedChoices[i] = cellObj.network:getLayerSize(i)
    end

    if #weightedChoices == 0 then
        return
    end
    local chosenLayer = lume.weightedchoice(weightedChoices)
    local chosenNeuronIndex = math.random (1, cellObj.network:getLayerSize(chosenLayer))
    local weightCount = cellObj.network:getWeightCountIndexed (chosenNeuronIndex, chosenLayer)
    
    if weightCount > 0 then
        local chosenWeightIndex = math.random(1, weightCount)
        local newWeight = mapToScale (math.random (), 0, 1, -1, 1)
        cellObj.network:setWeight(chosenNeuronIndex, chosenLayer, chosenWeightIndex, newWeight)
    end
end

function mutationHandlers.zeroWeight(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 2 do
        weightedChoices[i] = cellObj.network:getLayerSize(i)
    end

    if #weightedChoices == 0 then
        return
    end
    local chosenLayer = lume.weightedchoice(weightedChoices)
    local chosenNeuronIndex = math.random (1, cellObj.network:getLayerSize(chosenLayer))
    local weightCount = cellObj.network:getWeightCountIndexed (chosenNeuronIndex, chosenLayer)
    
    if weightCount > 0 then
        local chosenWeightIndex = math.random(1, weightCount)
        cellObj.network:setWeight(chosenNeuronIndex, chosenLayer, chosenWeightIndex, 0)
    end
end

function mutationHandlers.addNeuronConnection(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 2 do
        weightedChoices[i] = cellObj.network:getLayerSize(i)
    end

    if #weightedChoices == 0 then
        return
    end
    local chosenLayer = lume.weightedchoice(weightedChoices)
    local chosenNeuronIndex = math.random (1, cellObj.network:getLayerSize(chosenLayer))

    if cellObj.network:getLayerSize(chosenLayer - 1) > 0 then
        local inputIndex = math.random(1, cellObj.network:getLayerSize(chosenLayer - 1))
        local initialWeight = mapToScale(math.random(), 0, 1, -1, 1)
        cellObj.network:addConnectionIndexed(inputIndex, chosenNeuronIndex, chosenLayer, initialWeight)
    end
end

function mutationHandlers.removeNeuronConnection(cellObj)
    local weightedChoices = {}
    for i = 2, cellObj.network:getLayerCount() - 2 do
        weightedChoices[i] = cellObj.network:getLayerSize(i)
    end

    if #weightedChoices == 0 then
        return
    end
    local chosenLayer = lume.weightedchoice(weightedChoices)
    local chosenNeuronIndex = math.random (1, cellObj.network:getLayerSize(chosenLayer))
    local inputIndex = math.random(1, cellObj.network:getWeightCountIndexed(chosenNeuronIndex, chosenLayer))

    if inputIndex then
        cellObj.network:removeConnectionIndexed(inputIndex, chosenNeuronIndex, chosenLayer)
    end
end

function mutationHandlers.meta(cellObj)
    local mutationType = lume.randomchoice (lume.keys (cellObj.mutationRates))
    local changeAmount = lume.randomchoice ({-1, 1}) * (math.random (1, 10) / 100)

    cellObj.mutationRates[mutationType] = lume.clamp (cellObj.mutationRates[mutationType] + changeAmount, 0, 100)
end

return mutationHandlers