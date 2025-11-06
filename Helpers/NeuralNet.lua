local KeyedArray = require("Helpers.keyedArray")
local Neuron = require ("Helpers.Neuron")

local NeuralNet = {}

function NeuralNet:new (layers)
    assert (layers >= 1, "Neural network must have at least one hidden layer")

    local newObj = {
        layers = {}, -- Each layer contains an array of neurons
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


function NeuralNet:addHidden (id, neuron, layerIndex)
    assert (layerIndex >= 1 and layerIndex <= #self.layers, "Layer index must be between 1 and the number of layers")
    assert (type (id) == "string", "Neuron ID must be a string")
    assert (self.layers[layerIndex]:get(id, "key") == nil, "Neuron with this ID already exists in the layer")

    self.layers[layerIndex]:insert(id, neuron)
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
    for pos, key, outputNeuron in self.layers[#self.layers]:iterate() do
        networkOutputs[key] = outputNeuron.lastOutput
    end

    return networkOutputs
end

return NeuralNet