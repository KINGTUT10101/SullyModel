local lume = require("Libraries.lume")

local mutationHandlers = {}

local cell = nil

function mutationHandlers.init(cellRef)
    cell = cellRef
end

function mutationHandlers.addNeuron(cellObj)
    
end

function mutationHandlers.removeNeuron(cellObj)
    -- TODO: remove neuron from cellObj and detach related connections
    return true
end

function mutationHandlers.increaseWeight(cellObj)
    -- TODO: increase the weight of the given connection by delta
    return true
end

function mutationHandlers.decreaseWeight(cellObj)
    -- TODO: decrease the weight of the given connection by delta
    return true
end

function mutationHandlers.randomizeWeight(cellObj)
    -- TODO: set the connection weight to a random value between minValue and maxValue
    return true
end

function mutationHandlers.zeroWeight(cellObj)
    -- TODO: set the connection weight to zero
    return true
end

function mutationHandlers.addNeuronConnection(cellObj)
    -- TODO: create a new connection between fromNeuronId and toNeuronId with initialWeight
    return true
end

function mutationHandlers.removeNeuronConnection(cellObj)
    -- TODO: remove the connection with the given id
    return true
end

function mutationHandlers.meta(cellObj)
    local mutationType = lume.randomchoice (lume.keys (cellObj.mutationRates))
    local changeAmount = lume.randomchoice ({-1, 1}) * (math.random (1, 10) / 100)

    cellObj.mutationRates[mutationType] = lume.clamp (cellObj.mutationRates[mutationType] + changeAmount, 0, 100)
end

return mutationHandlers