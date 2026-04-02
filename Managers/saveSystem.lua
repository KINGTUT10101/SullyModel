local bitser = require ("Libraries.bitser")
local NeuralNet = require ("Helpers.NeuralNet")
local Neuron = require ("Helpers.Neuron")
local actFuncs = require ("Helpers.actFuncs")

bitser.register("function", function()
    return nil
end)

local saveSystem = {}

local function sanitizeFilename (value)
    local safe = tostring (value or "save")
    safe = safe:gsub ("[^%w%-%_ ]", "_")
    safe = safe:gsub ("%s+", "_")
    safe = safe:gsub ("_+", "_")

    if safe == "" then
        safe = "save"
    end

    return safe
end

local function copyNoFuncs (value, seen)
    local valueType = type (value)
    if valueType == "function" or valueType == "userdata" or valueType == "thread" then
        return nil
    elseif valueType ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return nil
    end

    seen[value] = true
    local out = {}
    for k, v in pairs (value) do
        local newKey = copyNoFuncs (k, seen)
        if newKey ~= nil then
            local newValue = copyNoFuncs (v, seen)
            if newValue ~= nil then
                out[newKey] = newValue
            end
        end
    end
    seen[value] = nil

    return out
end

local function resolveActMeta (neuron)
    if type (neuron.actMeta) == "table" and type (neuron.actMeta.name) == "string" then
        return copyNoFuncs (neuron.actMeta)
    end

    if neuron.actFunc == actFuncs.identity then
        return {name = "identity"}
    elseif neuron.actFunc == actFuncs.tanh then
        return {name = "tanh"}
    elseif neuron.actFunc == actFuncs.relu then
        return {name = "relu"}
    elseif neuron.actFunc == actFuncs.sigmoid then
        return {name = "sigmoid"}
    elseif neuron.actFunc == actFuncs.softplus then
        return {name = "softplus"}
    end

    return nil
end

local function buildActFunc (meta)
    if type (meta) ~= "table" or type (meta.name) ~= "string" then
        return nil, "Missing activation metadata"
    end

    if meta.name == "leaky" then
        local alpha = (meta.params and meta.params.alpha) or 0.05
        return actFuncs.leaky (alpha), nil
    elseif meta.name == "elu" then
        local alpha = (meta.params and meta.params.alpha) or 1.0
        return actFuncs.elu (alpha), nil
    elseif type (actFuncs[meta.name]) == "function" then
        return actFuncs[meta.name], nil
    end

    return nil, "Undefined activation function: " .. tostring (meta.name)
end

function saveSystem:new (mapRef)
    assert (type (mapRef) == "table", "mapRef must be a table")

    local obj = {
        map = mapRef,
    }

    for k, v in pairs (self) do
        if k ~= "new" and type (v) == "function" then
            obj[k] = v
        end
    end

    return obj
end

function saveSystem:getMapSaveKey ()
    return sanitizeFilename (self.map.title or "Untitled_Map")
end

function saveSystem:getSaveFolder ()
    return "saves"
end

function saveSystem:ensureSaveFolder ()
    local ok = love.filesystem.createDirectory (self:getSaveFolder ())
    if ok == false then
        print ("[SAVE ERROR] Failed to create saves directory")
        return false
    end

    return true
end

function saveSystem:buildSavePath (baseName)
    return self:getSaveFolder () .. "/" .. sanitizeFilename (baseName) .. ".slf"
end

function saveSystem:getQuickSavePath ()
    return self:buildSavePath ("quicksave_" .. self:getMapSaveKey ())
end

function saveSystem:buildAutoSaveName ()
    return "auto_" .. self:getMapSaveKey () .. "_" .. os.date ("%Y-%m-%d_%H-%M-%S")
end

function saveSystem:quickSave ()
    return self:saveToPath (self:getQuickSavePath ())
end

function saveSystem:serializeNetwork (network)
    local layers = {}

    for layerIndex = 1, #network.layers do
        local layer = {}
        for _, neuronID, neuron in network.layers[layerIndex]:pairs () do
            local actMeta = resolveActMeta (neuron)
            if actMeta == nil then
                return nil, "Missing/unknown activation metadata for neuron '" .. tostring (neuronID) .. "'"
            end

            local weights = {}
            for _, weightKey, weightValue in neuron.weights:pairs () do
                table.insert (weights, {
                    key = weightKey,
                    value = weightValue,
                })
            end

            table.insert (layer, {
                id = neuronID,
                actMeta = actMeta,
                weights = weights,
                lastOutput = neuron.lastOutput or 0,
            })
        end

        layers[layerIndex] = layer
    end

    return {
        hiddenLayers = #network.layers - 2,
        layers = layers,
    }, nil
end

function saveSystem:deserializeNetwork (savedNetwork)
    if type (savedNetwork) ~= "table" or type (savedNetwork.layers) ~= "table" then
        return nil, "Invalid network payload"
    end

    local hiddenLayers = tonumber (savedNetwork.hiddenLayers) or (#savedNetwork.layers - 2)
    local network = NeuralNet:new (math.max (1, hiddenLayers))

    if #savedNetwork.layers ~= #network.layers then
        return nil, "Network layer count mismatch"
    end

    for layerIndex = 1, #savedNetwork.layers do
        local layer = savedNetwork.layers[layerIndex]
        for i = 1, #layer do
            local neuronData = layer[i]
            local actFunc, actError = buildActFunc (neuronData.actMeta)
            if actFunc == nil then
                return nil, actError
            end

            local neuron = Neuron:new (actFunc, neuronData.actMeta)
            neuron.lastOutput = neuronData.lastOutput or 0
            network:addHidden (neuronData.id, neuron, layerIndex)
        end
    end

    for layerIndex = 2, #savedNetwork.layers do
        local layer = savedNetwork.layers[layerIndex]
        for i = 1, #layer do
            local neuronData = layer[i]
            if type (neuronData.weights) == "table" then
                for j = 1, #neuronData.weights do
                    local weightData = neuronData.weights[j]
                    local weightKey = weightData.key
                    local weightValue = weightData.value

                    if weightKey == "bias" then
                        local neuron = network.layers[layerIndex]:get (neuronData.id, "key")
                        neuron:setWeight ("bias", weightValue)
                    elseif network.layers[layerIndex - 1]:exists (weightKey, "key") then
                        network:addConnection (weightKey, neuronData.id, layerIndex, weightValue)
                    end
                end
            end
        end
    end

    return network, nil
end

function saveSystem:buildSavePayload ()
    local map = self.map
    local payload = {
        version = 1,
        createdAt = os.date ("%Y-%m-%d %H:%M:%S"),
        map = {
            title = map.title,
            width = map.width,
            height = map.height,
            lastTick = map.lastTick,
            tickSpeed = map.tickSpeed,
            evenTick = map.evenTick,
            camera = copyNoFuncs (map.camera),
            inputBounds = copyNoFuncs (map.inputBounds),
            drawBounds = copyNoFuncs (map.drawBounds),
            dataBounds = copyNoFuncs (map.dataBounds),
            stats = copyNoFuncs (map.stats),
            resets = map.resets,
            lastLogMsg = map.lastLogMsg,
            superparentColors = copyNoFuncs (map.superparentColors),
            pheromoneColors = copyNoFuncs (map.pheromoneColors),
            totalEnergy = map.totalEnergy,
            stopOnError = map.stopOnError,
            energyImbalanceMessagesEnabled = map.energyImbalanceMessagesEnabled,
            energyImbalanceLogInterval = map.energyImbalanceLogInterval,
            lastEnergyImbalanceLogTime = map.lastEnergyImbalanceLogTime,
            envGrid = copyNoFuncs (map.envGrid),
            cells = {},
        }
    }

    for tileX = 1, map.width do
        local cellRow = map.cellGrid[tileX]
        if cellRow ~= nil then
            for tileY = 1, map.height do
                local cellObj = cellRow[tileY]
                if cellObj ~= nil then
                    local netData, netErr = self:serializeNetwork (cellObj.network)
                    if netData == nil then
                        return nil, netErr
                    end

                    local savedCell = copyNoFuncs (cellObj)
                    savedCell.network = netData

                    table.insert (payload.map.cells, {
                        x = tileX,
                        y = tileY,
                        cell = savedCell,
                    })
                end
            end
        end
    end

    return payload, nil
end

function saveSystem:applySavePayload (payload)
    if type (payload) ~= "table" or type (payload.map) ~= "table" then
        return false, "Invalid save payload"
    end

    local savedMap = payload.map
    if type (savedMap.width) ~= "number" or type (savedMap.height) ~= "number" then
        return false, "Save payload missing map dimensions"
    end

    local map = self.map

    map.title = savedMap.title or map.title
    map.width = savedMap.width
    map.height = savedMap.height
    map.lastTick = savedMap.lastTick or 0
    map.tickSpeed = savedMap.tickSpeed or map.tickSpeed
    map.evenTick = savedMap.evenTick == true
    map.camera = copyNoFuncs (savedMap.camera) or map.camera
    map.inputBounds = copyNoFuncs (savedMap.inputBounds) or map.inputBounds
    map.drawBounds = copyNoFuncs (savedMap.drawBounds) or map.drawBounds
    map.dataBounds = copyNoFuncs (savedMap.dataBounds) or map.dataBounds
    map.stats = copyNoFuncs (savedMap.stats) or map.stats
    map.resets = savedMap.resets or map.resets
    map.lastLogMsg = savedMap.lastLogMsg or ""
    map.superparentColors = copyNoFuncs (savedMap.superparentColors) or map.superparentColors
    map.pheromoneColors = copyNoFuncs (savedMap.pheromoneColors) or map.pheromoneColors
    map.totalEnergy = savedMap.totalEnergy or map.totalEnergy
    map.stopOnError = (savedMap.stopOnError ~= false)
    map.energyImbalanceMessagesEnabled = (savedMap.energyImbalanceMessagesEnabled ~= false)
    map.energyImbalanceLogInterval = savedMap.energyImbalanceLogInterval or map.energyImbalanceLogInterval
    map.lastEnergyImbalanceLogTime = savedMap.lastEnergyImbalanceLogTime or -math.huge

    map.envGrid = copyNoFuncs (savedMap.envGrid) or {}
    map.cellGrid = {}
    for tileX = 1, map.width do
        map.cellGrid[tileX] = {}
    end

    local cells = savedMap.cells or {}
    for i = 1, #cells do
        local cellEntry = cells[i]
        local tileX = cellEntry.x
        local tileY = cellEntry.y
        local savedCell = cellEntry.cell

        if map:inBounds (tileX, tileY) and type (savedCell) == "table" then
            local rebuiltNetwork, netErr = self:deserializeNetwork (savedCell.network)
            if rebuiltNetwork == nil then
                return false, "Failed to rebuild network at (" .. tileX .. ", " .. tileY .. "): " .. tostring (netErr)
            end

            savedCell.network = rebuiltNetwork
            map.cellGrid[tileX][tileY] = savedCell
        end
    end

    -- Always pause immediately after loading a save so the player can inspect state first.
    map.tickSpeed = math.huge
    map.lastSave = map.ticksBetweenSaves
    return true, nil
end

function saveSystem:saveToPath (filePath)
    if self:ensureSaveFolder () == false then
        return false, "Could not create save folder"
    end

    local payload, payloadErr = self:buildSavePayload ()
    if payload == nil then
        local errorMsg = "[SAVE ERROR] Failed to build save payload: " .. tostring (payloadErr)
        print (errorMsg)
        return false, errorMsg
    end

    local ok, err = pcall (bitser.dumpLoveFile, filePath, payload)
    if ok == false then
        local errorMsg = "[SAVE ERROR] Failed to save file '" .. tostring (filePath) .. "': " .. tostring (err)
        print (errorMsg)
        return false, errorMsg
    end

    print ("Saved: " .. tostring (filePath))
    return true, nil
end

function saveSystem:saveAs (name)
    local filePath = self:buildSavePath (name)
    return self:saveToPath (filePath)
end

function saveSystem:autoSave ()
    local ok, err = self:saveAs (self:buildAutoSaveName ())
    if ok == false then
        return false, err
    end

    self:trimAutoSaves (20)
    return true, nil
end

function saveSystem:trimAutoSaves (maxCount)
    maxCount = maxCount or 20

    local prefix = "auto_" .. self:getMapSaveKey () .. "_"
    local files = self:listSaveFiles (true)
    local autos = {}

    for i = 1, #files do
        local fileInfo = files[i]
        if string.sub (fileInfo.name, 1, #prefix) == prefix then
            table.insert (autos, fileInfo)
        end
    end

    table.sort (autos, function (a, b)
        return a.modtime > b.modtime
    end)

    for i = maxCount + 1, #autos do
        love.filesystem.remove (autos[i].path)
    end
end

function saveSystem:listSaveFiles (includeQuickSave)
    includeQuickSave = includeQuickSave == true

    if self:ensureSaveFolder () == false then
        return {}
    end

    local files = {}
    local entries = love.filesystem.getDirectoryItems (self:getSaveFolder ())
    for i = 1, #entries do
        local name = entries[i]
        local isSlf = string.sub (name, -4) == ".slf"
        if isSlf then
            local isQuick = string.sub (name, 1, 10) == "quicksave_"
            if includeQuickSave == true or isQuick == false then
                local path = self:getSaveFolder () .. "/" .. name
                local info = love.filesystem.getInfo (path)
                table.insert (files, {
                    name = name,
                    path = path,
                    isQuick = isQuick,
                    modtime = (info and info.modtime) or 0,
                    size = (info and info.size) or 0,
                })
            end
        end
    end

    table.sort (files, function (a, b)
        return a.modtime > b.modtime
    end)

    return files
end

function saveSystem:loadFromPath (filePath)
    local ok, loadedOrErr = pcall (bitser.loadLoveFile, filePath)
    if ok == false then
        local errorMsg = "[LOAD ERROR] Failed to read save file '" .. tostring (filePath) .. "': " .. tostring (loadedOrErr)
        print (errorMsg)
        return false, errorMsg
    end

    local applyOk, applyErr = self:applySavePayload (loadedOrErr)
    if applyOk == false then
        local errorMsg = "[LOAD ERROR] Failed to load '" .. tostring (filePath) .. "': " .. tostring (applyErr)
        print (errorMsg)
        return false, errorMsg
    end

    print ("Loaded: " .. tostring (filePath))
    return true, nil
end

return saveSystem
