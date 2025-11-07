local KeyedArray = require("Helpers.keyedArray")
local Neuron = require ("Helpers.Neuron")

local NeuralNet = {}

function NeuralNet:new (layers)
    assert (layers >= 1, "Neural network must have at least one hidden layer")

    local newObj = {
        layers = {}, -- Each layer contains a keyed array of neurons
    }

    -- Create arrays for network layers (+2 for input and output layers)
    for i = 1, layers + 2 do
        newObj.layers[i] = KeyedArray:new ()
    end

    -- Copy method references
    for k, v in pairs (self) do
        if k ~= "new" and type (v) == "function" then
            newObj[k] = v
        end
    end

    return newObj
end


function NeuralNet:copy ()
    local copyObj = NeuralNet:new(#self.layers - 2)

    for i = 1, #self.layers do
        for pos, id, neuron in self.layers[i]:pairs() do
            local neuronInputIDs = neuron:getInputIDs()
            local neuronInputRefs = {}

            for index, id in ipairs (neuronInputIDs) do
                neuronInputRefs[index] = self.layers[i - 1]:get(id, "key")
            end

            copyObj:addHidden (id, neuron:copy (neuronInputRefs))
        end
    end

    return copyObj
end


function NeuralNet:addHidden (id, neuron, layerIndex)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")
    assert (type (id) == "string", "Neuron ID must be a string")
    assert (self.layers[layerIndex]:exists(id, "key") == false, "Neuron with this ID already exists in the layer")

    self.layers[layerIndex]:insert(id, neuron)
end


function NeuralNet:removeHidden (id, layerIndex)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")
    assert (self.layers[layerIndex]:exists(id, "key") == true, "Neuron with this ID does not exist in the layer")

    self.layers[layerIndex]:delete(id, "key")
end


function NeuralNet:removeHiddenIndexed (index, layerIndex)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")
    assert (index >= 1 and index <= self.layers[layerIndex]:size(), "Index is out of bounds")

    self.layers[layerIndex]:delete(index, "array")
end


function NeuralNet:addConnection (fromID, toID, layerIndex, weight)
    assert (layerIndex > 1 and layerIndex <= #self.layers, "Layer index must be between 2 and the number of layers")
    assert (self.layers[layerIndex - 1]:exists(fromID, "key") == true, "Source neuron with this ID does not exist in the previous layer")
    assert (self.layers[layerIndex]:exists(toID, "key") == true, "Target neuron with this ID does not exist in the specified layer")

    local fromNeuron = self.layers[layerIndex - 1]:get(fromID, "key")
    local toNeuron = self.layers[layerIndex]:get(toID, "key")

    toNeuron:addInput(fromNeuron, weight)
end


function NeuralNet:addConnectionIndexed (fromIndex, toIndex, layerIndex, weight)
    assert (layerIndex > 1 and layerIndex <= #self.layers, "Layer index must be between 2 and the number of layers")
    assert (self.layers[layerIndex - 1]:exists(fromIndex, "array") == true, "Source neuron with this index does not exist in the previous layer")
    assert (self.layers[layerIndex]:exists(toIndex, "array") == true, "Target neuron with this index does not exist in the specified layer")

    local fromNeuron = self.layers[layerIndex - 1]:get(fromIndex, "array")
    local toNeuron = self.layers[layerIndex]:get(toIndex, "array")

    toNeuron:addInput(fromNeuron, weight)
end


function NeuralNet:removeConnection (fromID, toID, layerIndex)
    assert (layerIndex > 1 and layerIndex <= #self.layers, "Layer index must be between 2 and the number of layers")
    assert (self.layers[layerIndex - 1]:exists(fromID, "key") == true, "Source neuron with this ID does not exist in the previous layer")
    assert (self.layers[layerIndex]:exists(toID, "key") == true, "Target neuron with this ID does not exist in the specified layer")

    local toNeuron = self.layers[layerIndex]:get(toID, "key")
    toNeuron:removeInput(fromID)
end


function NeuralNet:removeConnectionIndexed (fromIndex, toIndex, layerIndex)
    assert (layerIndex > 1 and layerIndex <= #self.layers, "Layer index must be between 2 and the number of layers")
    assert (self.layers[layerIndex - 1]:exists(fromIndex, "array") == true, "Source neuron with this index does not exist in the previous layer")
    assert (self.layers[layerIndex]:exists(toIndex, "array") == true, "Target neuron with this index does not exist in the specified layer")

    local toNeuron = self.layers[layerIndex]:get(toIndex, "array")
    toNeuron:removeInput(fromIndex)
end


function NeuralNet:getWeight (id, layerIndex)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")
    assert (self.layers[layerIndex]:exists(id, "key") == true, "Neuron with this ID does not exist in the layer")

    local neuron = self.layers[layerIndex]:get(id, "key")

    return neuron:getWeight(id)
end


function NeuralNet:setWeight (id, layerIndex, weightIndex, weight)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")
    assert (self.layers[layerIndex]:exists(id, "key") == true, "Neuron with this ID does not exist in the layer")

    local neuron = self.layers[layerIndex]:get(id, "key")
    neuron:setWeightIndexed (weightIndex, weight)
end


function NeuralNet:adjustWeight (id, layerIndex, weightIndex, amount)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")
    assert (self.layers[layerIndex]:exists(id, "key") == true, "Neuron with this ID does not exist in the layer")

    local neuron = self.layers[layerIndex]:get(id, "key")
    neuron:adjustWeightIndexed (weightIndex, amount)
end


function NeuralNet:getWeightCount (id, layerIndex)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")
    assert (self.layers[layerIndex]:exists(id, "key") == true, "Neuron with this ID does not exist in the layer")

    local neuron = self.layers[layerIndex]:get(id, "key")
    return neuron:getWeightCount()
end


function NeuralNet:getWeightCountIndexed (index, layerIndex)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")
    assert (self.layers[layerIndex]:exists(index, "array") == true, "Neuron with this index does not exist in the layer")

    local neuron = self.layers[layerIndex]:get(index, "array")
    return neuron:getWeightCount()
end


function NeuralNet:getLayerSize (layerIndex)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")

    return self.layers[layerIndex]:size()
end


function NeuralNet:getLayerCount ()
    return #self.layers
end


--- Makes a prediction using the provided input values
--- @param networkInputs table<string, number> A table mapping input IDs to their values
--- @return table<string, number> networkOutputs A table mapping output IDs to their predicted values
function NeuralNet:predict (networkInputs)
    local networkOutputs = {}

    -- Set input neuron values
    for id, neuronInput in pairs(networkInputs) do
        local inputNeuron = self.layers[1]:get(id, "key")

        inputNeuron.lastOutput = neuronInput
    end

    -- Calculate values for each layer
    for i = 2, #self.layers do
        for j = 1, self.layers[i]:size() do
            local neuron = self.layers[i]:get(j, "array")

            neuron:predict()
        end
    end

    -- Collect output neuron values
    for pos, key, outputNeuron in self.layers[#self.layers]:pairs() do
        networkOutputs[key] = outputNeuron.lastOutput
    end

    return networkOutputs
end

return NeuralNet