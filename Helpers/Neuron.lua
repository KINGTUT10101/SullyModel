local copyTable = require ("Helpers.copyTable")
local KeyedArray = require("Helpers.keyedArray")

local Neuron = {}

function Neuron:new (actFunc)
    assert (type (actFunc) == "function", "actFunc must be a function")

    local newObj = {
        weights = KeyedArray:new (), -- Array of weights for inputs. Must contain at least one value for the bias
        inputs = KeyedArray:new (), -- References to the neurons this neuron gets input from. Should equal the number of weights minus one (bias)
        actFunc = actFunc, -- Activation function that is run after the weighted sum is calculated
        lastOutput = 0, -- The last output value of the neuron
    }

    -- Insert the bias into the weights array
    newObj.weights:insert("bias", 0, 1)

    -- Copy method references
    for k, v in pairs (self) do
        if k ~= "new" and type (v) == "function" then
            newObj[k] = v
        end
    end

    return newObj
end


function Neuron:copy (inputNeurons)
    local copyObj = Neuron:new(self.actFunc)

    -- Copy weights and inputs
    copyObj:setWeight ("bias", self.weights:get("bias", "key"))
    for id, neuron in pairs (inputNeurons) do
        copyObj:addInput (id, neuron, self.weights:get(id, "key"))
    end

    copyObj.lastOutput = self.lastOutput

    return copyObj
end

function Neuron:addInput (id, neuron, weight)
    weight = weight or 0

    self.inputs:insert(id, neuron)
    self.weights:insert(id, weight)
end


function Neuron:removeInput (id)
    assert (self.weights:exists (id, "key"), "Weight ID does not exist")

    self.inputs:delete(id, "key")
    self.weights:delete(id, "key")
end


function Neuron:getWeight (id)
    assert (self.weights:exists (id, "key"), "Weight ID does not exist")

    return self.weights:get(id, "key")
end


function Neuron:setWeight (id, weight)
    assert (self.weights:exists (id, "key"), "Weight ID does not exist")

    self.weights:replace (id, weight, "key")
end


function Neuron:adjustWeight (id, amount)
    assert (self.weights:exists (id, "key"), "Weight ID does not exist")

    local currentWeight = self.weights:get(id, "key")
    self.weights:replace(id, currentWeight + amount, "key")
end


function Neuron:getInputIDs ()
    local keys = {}

    for _, id, _ in self.inputs:pairs() do
        table.insert(keys, id)
    end

    return keys
end


function Neuron:predict ()
    -- Calculate the weighted sum of the inputs
    -- Assume that the first input is 1 (bias)
    local sum = self.weights:get("bias", "key") -- bias
    for i = 2, self.weights:size() do
        sum = sum + self.weights:get(i, "array") * self.inputs:get(i - 1, "array").lastOutput
    end

    self.lastOutput = self.actFunc(sum)
end

return Neuron