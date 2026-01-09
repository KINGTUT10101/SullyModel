local bitser = require ("Libraries.bitser")
local clamp = require ("Libraries.lume").clamp
local round = require ("Libraries.lume").round
local cycleValue = require ("Helpers.cycleValue")
local mapToScale = require ("Helpers.mapToScale")
local copyTable  = require("Helpers.copyTable")

bitser.register("function", function()
    return nil
end)

local map = {
    cellGrid = {},
    envGrid = {},
    width = 0, -- Width of the input grid
    height = 0, --- Height of the input grid
    lastTick = 0, --- Time since the last tick, in seconds
    tickSpeed = 1/32, -- Intended number of ticks per second
    evenTick = true,
    camera = {
        x = 0,
        y = 0,
        zoom = 1,
    }, -- Contains camera position information
    inputBounds = {
        meat = {
            min = 0,
            max = 0,
        },
        plants = {
            min = 0,
            max = 0,
        },
        waste = {
            min = 0,
            max = 0,
        },
    },
    drawBounds = {
        meat = {
            min = 0,
            max = 0,
        },
        plants = {
            min = 0,
            max = 0,
        },
        waste = {
            min = 0,
            max = 0,
        },
    },
    dataBounds = {
        min = 0,
        max = 0,
    },
    title = "Untitled Map", -- The title of the map. Mostly used in menus
    cellManager = nil,
    stats = {
        cells = {},
        walls = {},
    },
    ticksBetweenSaves = 0,
    lastSave = 0,
    resets = 0,
    lastLogMsg = "",
    superparentColors = {},
    pheromoneColors = {},
    totalEnergy = 0,
    stopOnError = true,
    spawnFunc = nil,
}

function map:quickSave ()
    -- local cellGridCopy = {}

    -- for i = 1, self.width do
    --     local cellRow = {}
    --     cellGridCopy[i] = cellRow -- Add row to cell grid

    --     for j = 1, self.height do
    --         if self.cellGrid[i][j] ~= nil then
    --             cellRow[j] = copyTable (self.cellGrid[i][j])
    --             cellRow[j].scriptFunc = nil
    --             if cellRow[j].childCell ~= nil then
    --                 cellRow[j].childCell.scriptFunc = nil
    --             end
    --         end
    --     end
    -- end
    
    -- local fileName = "quickSave_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".slf"
    -- bitser.dumpLoveFile (fileName, {
    --     envGrid = self.envGrid,
    --     cellGrid = cellGridCopy,
    --     stats = self.stats,
    --     lastSave = self.lastSave,
    --     resets = self.resets,
    --     lastTick = self.lastTick,
    -- })
    -- print ("QUICK SAVE: " .. fileName)
end

local foodTypes = {
    "meat",
    "plants",
    "waste",
}
--- Initializes the map manager and prepares it for processing.
function map:init (cellManager, options)
    options = options or {}
    assert (type (options) == "table", "Provided options argument is not a table")

    self.cellManager = cellManager
    self.title = options.title or "Untitled Map"
    self.stats.resets = 0
    self.ticksBetweenSaves = options.ticksBetweenSaves or 100000
    self.maxMutsOnSpawn = options.maxMutsOnSpawn or 5 -- TODO: Add this

    options.inputBounds = options.inputBounds or {}
    if options.inputBounds.min ~= nil then
        assert (options.inputBounds.max ~= nil, "If inputBounds.min is provided, inputBounds.max must also be provided")
        for index, type in ipairs (foodTypes) do
            options.inputBounds[type] = {
                min = options.inputBounds.min,
                max = options.inputBounds.max,
            }
        end
    end
    for index, type in ipairs (foodTypes) do
        self.inputBounds[type].min = options.inputBounds[type].min or 0
        self.inputBounds[type].max = options.inputBounds[type].max or 500
    end

    options.drawBounds = options.drawBounds or {}
    if options.drawBounds.min ~= nil then
        assert (options.drawBounds.max ~= nil, "If drawBounds.min is provided, drawBounds.max must also be provided")
        for index, type in ipairs (foodTypes) do
            options.drawBounds[type] = {
                min = options.drawBounds.min,
                max = options.drawBounds.max,
            }
        end
    end
    for index, type in ipairs (foodTypes) do
        self.drawBounds[type].min = options.drawBounds[type].min or 0
        self.drawBounds[type].max = options.drawBounds[type].max or 500
    end

    options.dataBounds = options.dataBounds or {}
    self.dataBounds.min = options.dataBounds.min or self.inputBounds.min
    self.dataBounds.max = options.dataBounds.max or self.inputBounds.max

    self.tickSpeed = math.huge

    for i = 1, self.cellManager.superparents do
        self.stats.cells[i] = 0
        self.stats.walls[i] = 0
        self.superparentColors[i] = {math.random(), math.random(), math.random(), 1}
    end
    for i = 1, self.cellManager.pheromones do
        self.pheromoneColors[i] = {math.random(), math.random(), math.random(), 1}
    end
    self.pheromoneColors[0] = {0, 0, 0, 1}

    self.spawnFunc = options.spawnFunc
end

--- Resets the map with a new size and input data.
--- @param width integer The width of the input data.
--- @param height integer The height of the input data.
--- @param mapEnvInputs? fun(param:integer, param:integer):number Used to map the value of each input tile
--- @param mapEnvTypes? fun(param:integer, param:integer):boolean Used to map the impassible barrier tiles
--- @param mapEnvData? fun(param:integer, param:integer):boolean Used to map additional environmental data
function map:reset (width, height, mapEnvInputs, mapEnvTypes, mapEnvData)
    self.width, self.height = width, height

    self.totalEnergy = 0

    -- Generates the input grid and input render
    local envGrid = {}
    local cellGrid = {}
    for i = 1, self.width do
        local envRow = {}
        envGrid[i] = envRow -- Add row to input grid

        local cellRow = {}
        cellGrid[i] = cellRow -- Add row to cell grid

        for j = 1, self.height do
            local envTile = {
                input = {
                    meat = 0,
                    plants = 0,
                    waste = 0,
                },
                type = "blank",
                data = 0,
                pheromones = {},
            }

            for i = 1, self.cellManager.pheromones do
                envTile.pheromones[i] = 0
            end

            if mapEnvInputs ~= nil then
                envTile.input = mapEnvInputs (i, j)
                self.totalEnergy = self.totalEnergy + envTile.input.meat + envTile.input.plants + envTile.input.waste
            end

            if mapEnvTypes ~= nil then
                envTile.type = mapEnvTypes (i, j)
            end

            if mapEnvData ~= nil then
                envTile.data = mapEnvData (i, j)
            end

            envRow[j] = envTile
        end
    end

    self.envGrid = envGrid
    self.cellGrid = cellGrid
    self.resets = self.resets + 1
    self.lastLogMsg = ""

    for i = 1, self.cellManager.superparents do
        self.stats.cells[i] = 0
        self.stats.walls[i] = 0
    end
    -- self.inputRender = love.graphics.newImage (inputRender)
    -- self.inputRender:setFilter ("nearest", "nearest")
end

--- Updates the cells on the map if enough time has passed since the last tick.
--- @param dt number Delta time. AKA the amount of time since the last frame.
function map:update (dt)
    self.lastTick = self.lastTick + dt -- Update last tick

    local captures = {}
    local tickOccured = false

    -- Check if enough time has passed since the last tick
    local cellGrid = self.cellGrid
    local envGrid = self.envGrid
    if self.lastTick >= self.tickSpeed then
        local updateStartTime = love.timer.getTime()
        tickOccured = true

        -- Iterate over active grid and update cells
        -- TODO: Optimize this system so it doesn't have to iterate over the entire grid
        for i = 1, self.width do
            local cellRow = cellGrid[i]
            local envRow = envGrid[i]

            for j = 1, self.height do
                local cellObj = cellRow[j]
                local envTile = envRow[j]

                -- Check if cell exists at this position
                if cellObj ~= nil then
                    -- Skip cells that have already been updated this tick
                    if cellObj.lastUpdate < updateStartTime then
                        cellObj.lastUpdate = updateStartTime

                        local result, errorStr = xpcall (self.cellManager.update, debug.traceback, self.cellManager, i, j, cellObj, self) -- Call cell update function
                    
                        if result == false then
                            print ("Cell located at (" .. i .. ", " .. j .. ")")
                            self.cellManager:printCellInfo (cellObj)
                            print (errorStr)

                            if self.stopOnError == true then
                                self.tickSpeed = math.huge
                                love.window.requestAttention ()
                            end

                            return captures, tickOccured
                        end
                    end

                    if cellObj.type == "normal" and captures[cellObj.superparent] == nil then
                        captures[cellObj.superparent] = cellObj
                    end
                
                -- Process pheromones
                else
                    for i = 1, self.cellManager.pheromones do
                        local value = envTile.pheromones[i]
                        if value > 0 then
                            envTile.pheromones[i] = value - 1
                        end
                    end
                end
            end
        end

        self.lastTick = 0 -- Reset last tick
        self.lastSave = self.lastSave - 1 -- Decrement ticks since last save

        -- Save the map and cells if enough ticks have passed
        if self.lastSave <= 0 then
            self:quickSave ()

            self.lastSave = self.ticksBetweenSaves
        end
    end

    return captures, tickOccured
end

local validModes = {
    normal = true,
    superparents = true,
    energy = true,
    health = true,
    total = true,
    one = true,
    none = true,
}
local validSubModes = {
    normal = true,
    data = true,
    pheromones = true,
    inputDisabled = true,
    barriersDisabled = true,
    allDisabled = true,
}
function map:draw (mode, subMode)
    mode = mode or "normal"

    assert (validModes[mode] == true, "Invalid rendering mode provided")
    assert (validSubModes[subMode] == true, "Invalid rendering sub-mode provided")

    local maxEnergy = self.cellManager.maxEnergy
    local maxHealth = self.cellManager.maxHealth

    love.graphics.push ()
    love.graphics.translate (-self.camera.x, -self.camera.y)
    love.graphics.scale (self.camera.zoom)

    -- Draw cells
    local envGrid = self.envGrid
    local cellGrid = self.cellGrid
    local totalEnergy = 0
    for i = 1, self.width do
        local cellRow = cellGrid[i]
        local envRow = envGrid[i]

        for j = 1, self.height do
            local cellObj = cellRow[j]
            local envTile = envRow[j]

            totalEnergy = totalEnergy + envTile.input.meat + envTile.input.plants + envTile.input.waste

            -- Check what exists at the current position to determine what to render
            if cellObj ~= nil and mode ~= "none" then
                totalEnergy = totalEnergy + cellObj.wasteBuffer + cellObj.energy + cellObj.health

                -- Render cell
                if mode == "normal" then
                    love.graphics.setColor (cellObj.color)
                    love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
                elseif mode == "superparents" then
                    if cellObj.type == "normal" then
                        love.graphics.setColor (self.superparentColors[cellObj.superparent])
                        love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
                    else
                        love.graphics.setColor (cellObj.color)
                        love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
                    end
                elseif mode == "energy" then
                    local cellEnergyPercent = cellObj.energy / maxEnergy
                    love.graphics.setColor (0, cellEnergyPercent, 0, 1)
                    love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
                elseif mode == "health" then
                    local cellHealthPercent = cellObj.health / maxHealth
                    love.graphics.setColor (0, cellHealthPercent, 0, 1)
                    love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
                elseif mode == "total" then
                    local cellTotalPercent = (cellObj.energy + cellObj.health) / (maxEnergy + maxHealth)
                    love.graphics.setColor (0, cellTotalPercent, 0, 1)
                    love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
                elseif mode == "one" then
                    love.graphics.setColor (1, 1, 1, 1)
                    love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
                end

            elseif subMode == "pheromones" and envTile.type == "blank" then
                -- Render the strongest pheromone
                local strongestPhero, highestValue = 0, 0
                for k = 1, self.cellManager.pheromones do
                    if envTile.pheromones[k] > highestValue then
                        highestValue = envTile.pheromones[k]
                        strongestPhero = k
                    end
                end

                love.graphics.setColor (self.pheromoneColors[strongestPhero])
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)

            elseif envTile.type ~= "blank" and subMode ~= "barriersDisabled" and subMode ~= "allDisabled" then
                -- Render barrier (assume this is the only other tile type right now)
                love.graphics.setColor ({1, 0, 0, 1})
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)

            elseif subMode ~= "inputDisabled" and subMode ~= "allDisabled" then
                -- Render input tile
                local r, g, b
                if subMode == "data" then
                    local scaledColor = mapToScale (envTile.data, self.dataBounds.min, self.dataBounds.max, 0, 1)
                    r, g, b = scaledColor, scaledColor, scaledColor
                else
                    local input = envTile.input
                    r = mapToScale (input.meat, self.drawBounds.meat.min, self.drawBounds.meat.max, 0, 1)
                    g = mapToScale (input.plants, self.drawBounds.plants.min, self.drawBounds.plants.max, 0, 1)
                    b = mapToScale (input.waste, self.drawBounds.waste.min, self.drawBounds.waste.max, 0, 1)
                end

                love.graphics.setColor (r, g, b, 1)
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
            else
                love.graphics.setColor (0, 0, 0, 1)
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
            end
        end
    end

    if math.floor (self.totalEnergy) ~= math.floor (totalEnergy) and mode ~= "none" then
        if self.tickSpeed ~= math.huge then
            print ("Total energy mismatch detected! " .. math.floor (self.totalEnergy) .. " vs " .. math.floor (totalEnergy) .. " (Diff: " .. math.floor (self.totalEnergy) - math.floor (totalEnergy) .. ")") -- Add this back later
        end
        self.tickSpeed = math.huge
    end

    love.graphics.pop ()
end


-- Runs a function for all cells in the map
function map:getCells (cellFunc)
    local totalCells = 0

    for i = 1, #self.stats.cells do
        totalCells = totalCells + self.stats.cells[i]
    end

    if totalCells > 0 then
        local cellGrid = self.cellGrid
        for i = 1, self.width do
            local cellRow = cellGrid[i]

            for j = 1, self.height do
                local cellObj = cellRow[j]

                if cellObj ~= nil then
                    cellFunc (i, j, cellObj)
                end
            end
        end
    end
end


function map:getTiles (tileFunc)
    local envGrid = self.envGrid
    for i = 1, self.width do
        local envRow = envGrid[i]

        for j = 1, self.height do
            local envTile = envRow[j]

            if envTile ~= nil then
                tileFunc (i, j, envTile)
            end
        end
    end
end


function map:checkEnergyBalance ()
    local totalEnergy = 0

    local envGrid = self.envGrid
    local cellGrid = self.cellGrid
    for i = 1, self.width do
        local cellRow = cellGrid[i]
        local envRow = envGrid[i]

        for j = 1, self.height do
            local cellObj = cellRow[j]
            local envTile = envRow[j]

            totalEnergy = totalEnergy + envTile.input.meat + envTile.input.plants + envTile.input.waste

            if cellObj ~= nil then
                totalEnergy = totalEnergy + cellObj.wasteBuffer + cellObj.energy + cellObj.health
            end
        end
    end

    return totalEnergy == self.totalEnergy, totalEnergy
end


function map:setLastLogMsg (msg)
    self.lastLogMsg = msg
end


--- Gets the current tick speed.
--- @return number tickSpeed The amount of time between map updates.
function map:getTickSpeed ()
    return self.tickSpeed
end


--- Sets the tick speed.
--- @param value number The new amount of time between map updates. Expects a value between 0 and infinity.
function map:setTickSpeed (value)
    assert (type (value) == "number", "Provided value is not a number")

    self.tickSpeed = value
end

--- Gets the current camera information
--- @return number camX
--- @return number camY
--- @return number camZoom
function map:getCamera ()
    return self.camera.x, self.camera.y, self.camera.zoom
end

--- Sets the position of the camera.
--- The camera position corresponds to the top-left corner of the camera, not the center.
--- Blank arguments will default to the current camera data.
--- @param x number | nil The horizontal position of the camera.
--- @param y number | nil The vertical position of the camera.
--- @param zoom number | nil The scale of the tiles (base size is 1x1 pixels).
function map:setCamera (x, y, zoom)
    self.camera.x = x or self.camera.x
    self.camera.y = y or self.camera.y
    self.camera.zoom = zoom or self.camera.zoom
end

--- Translates a screen position into a map position
--- @param screenX number The horizontal screen position
--- @param screenY number The vertical screen position
--- @return integer mapX The horizontal map position
--- @return integer mapY The vertical map position
function map:screenToMap (screenX, screenY)
    love.graphics.push ()
    love.graphics.translate (-self.camera.x, -self.camera.y)
    love.graphics.scale (self.camera.zoom)

    local mapX, mapY = love.graphics.inverseTransformPoint (screenX, screenY)

    love.graphics.pop ()

    return math.ceil (mapX), math.ceil (mapY)
end

--- Checks if the provided position is within the bounds of the map
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @return boolean inBounds True if the provided position is within bounds
function map:inBounds (tileX, tileY)
    return tileX >= 1 and tileX <= self.width and tileY >= 1 and tileY <= self.height
end

--- Gets the value of the input tile at the provided position
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @param key any The key of the environment value to get
--- @return number | nil inputValue The value of the input tile or nil if the provided position was out of bounds
function map:getEnvValue (tileX, tileY, key)
    if self:inBounds (tileX, tileY) == true then
        return self.envGrid[tileX][tileY][key]

    else
        return nil
    end
end

--- Gets the value of the input tile at the provided position
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @return number | nil inputValue The value of the input tile or nil if the provided position was out of bounds
function map:getInputTile (tileX, tileY, foodType)
    if self:inBounds (tileX, tileY) == true then
        return self.envGrid[tileX][tileY].input[foodType]

    else
        return nil
    end
end

--- Sets the value of the input tile at the provided position
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @param value number The new value of the input tile
function map:setInputTile (tileX, tileY, foodType, value)
    assert (type (value) == "number", "Provided value is not a number")

    if self:inBounds (tileX, tileY) == true then
        self.envGrid[tileX][tileY].input[foodType] = clamp (value, self.inputBounds[foodType].min, self.inputBounds[foodType].max)
    end
end

--- Increments the value of the input tile at the provided position
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @param value number The amount to increment the input value by
function map:adjustInputTile (tileX, tileY, foodType, value)
    assert (type (value) == "number", "Provided value is not a number")

    if self:inBounds (tileX, tileY) == true then
        self.envGrid[tileX][tileY].input[foodType] = clamp (self.envGrid[tileX][tileY].input[foodType] + value, self.inputBounds[foodType].min, self.inputBounds[foodType].max)
        return true
    end

    return false
end

--- Checks if the provided position is clear of any cells or barriers.
--- It also implicitly checks if the provided position is within bounds.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @return boolean isClear True if the provided position does not have a cell object.
function map:isClear (tileX, tileY)
    return self:inBounds (tileX, tileY) == true and self.cellGrid[tileX][tileY] == nil and self.envGrid[tileX][tileY].type == "blank"
end

--- Checks if the provided position is taken by a cell object.
--- It also implicitly checks if the provided position is within bounds.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @return boolean isClear True if the provided position contains a cell object.
function map:isTaken (tileX, tileY)
    return self:inBounds (tileX, tileY) and self.cellGrid[tileX][tileY] ~= nil
end


--- Gets a copy of the cell object at the specified map position.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @return table|nil cellObj The cell object at the given position or nil if a cell object doesn't exist there.
function map:getCell (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        return self.cellGrid[tileX][tileY]
    end
end

--- Spawns a new cell object into the map.
--- The new cell object will have n rounds of mutations applied to it if a parent is provided, depending on the value of map.cellManager.meanMut.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @param health number The health value of the new cell object.
--- @param energy number The energy value of the new cell object.
--- @param parentCellObj? table The parent cell object object.
--- @return boolean success True if a cell object was spawned successfully.
function map:spawnCell (tileX, tileY, health, energy, superparent, parentCellObj)
    if self.stats.cells[superparent] < self.cellManager.maxCells[superparent] and self:isClear (tileX, tileY) == true then
        local newCellObj

        -- Mutate cell if a parent is given
        if parentCellObj ~= nil then
            newCellObj = self.cellManager:newChild (parentCellObj)
            if health ~= nil then
                newCellObj.health = health
            end
            if energy ~= nil then
                newCellObj.energy = energy
            end
            
            for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, 0, 25)) do
                self.cellManager:mutate (newCellObj)
            end
        else
            newCellObj = self.cellManager:new (health, energy, superparent) -- Create default cell object
        end

        newCellObj.lastUpdate = love.timer.getTime()
        self.cellGrid[tileX][tileY] = newCellObj

        if self.spawnFunc ~= nil then
            self.spawnFunc (tileX, tileY, newCellObj)
        end
        
        -- Only count normal and egg cells
        assert (newCellObj.type ~= "wall", "Error: Attempted to count a wall cell as a normal or egg cell.")
        self.stats.cells[superparent] = self.stats.cells[superparent] + 1
        
        return true
    else
        return false
    end
end

--- Spawns a new cell egg into the map.
--- The new cell object will have n rounds of mutations applied to it if a parent is provided, depending on the value of map.cellManager.meanMut.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @param health number The health value of the new cell object.
--- @param energy number The energy value of the new cell object.
--- @param parentCellObj? table The parent cell object object.
--- @return boolean success True if a cell object was spawned successfully.
function map:spawnEgg (tileX, tileY, health, energy, superparent, parentCellObj)
    error ("TODO: map:spawnEgg")
    if self.stats.cells[superparent] < self.cellManager.maxCells[superparent] and self:isClear (tileX, tileY) == true then
        local newCellObj = self.cellManager:new (math.huge, math.huge, superparent) -- Create default cell object

        -- Mutate cell if a parent is given
        if parentCellObj ~= nil then
            -- TODO: Mutate the child cell multiple times
            local mutSuccess, mutErr = pcall (self.cellManager.mutate, self.cellManager, newCellObj, parentCellObj)
            local compSuccess, compErr = pcall (self.cellManager.compileScript, self.cellManager, newCellObj)

            assert (mutSuccess == true, "ERROR: Problem with mutation:" .. tostring (mutErr))
            assert (compSuccess == true, "ERROR: Problem with script compilation:" .. tostring (compErr))
        end

        local eggCellObj = self.cellManager:new (health, energy, superparent, "egg") -- Create default cell object
        eggCellObj.childCell = newCellObj
        eggCellObj.tickTimer = self.cellManager.eggTimer
        eggCellObj.ticksLeft = math.huge
        eggCellObj.color = {0, 0, 1, 1}

        self.cellGrid[tileX][tileY] = eggCellObj
        
        -- Only count normal and egg cells
        if eggCellObj.type == "normal" or eggCellObj.type == "egg" then
            self.stats.cells[superparent] = self.stats.cells[superparent] + 1
        end
        
        return true
    else
        return false
    end
end

--- Spawns a new cell wall into the map.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @param health number The health value of the new cell object.
--- @return boolean success True if a cell object was spawned successfully.
function map:spawnWall (tileX, tileY, health, superparent)
    if self.stats.walls[superparent] < self.cellManager.maxWalls[superparent] and self:isClear (tileX, tileY) == true then
        local newCellObj = self.cellManager:new (health, 0, superparent, "wall") -- Create default cell object

        newCellObj.color = {1, 1, 0, 1}

        self.cellGrid[tileX][tileY] = newCellObj
        self.stats.walls[superparent] = self.stats.walls[superparent] + 1
        
        return true
    else
        return false
    end
end

local wasteMap = {
    meat = "waste",
    plants = "waste",
    waste = "plants",
}

--- Removes a cell object from the map.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @param dropEnergy boolean If true, the energy from the deleted cell will be added to the environment
function map:deleteCell (tileX, tileY, dropEnergy)
    if self:isTaken (tileX, tileY) == true then
        local cellObj = self.cellGrid[tileX][tileY]

        -- Add cell's remaining energy and health to the ground
        if dropEnergy ~= false then
            self:adjustInputTile (tileX, tileY, "meat", cellObj.energy + cellObj.health)
            self:emptyCellWasteBuffer (tileX, tileY)
        end

        self.cellGrid[tileX][tileY] = nil

        if cellObj.type == "normal" or cellObj.type == "egg" then
            self.stats.cells[cellObj.superparent] = self.stats.cells[cellObj.superparent] - 1
        elseif cellObj.type == "wall" then
            self.stats.walls[cellObj.superparent] = self.stats.walls[cellObj.superparent] - 1
        end
    end
end

function map:moveTo (tileX1, tileY1, tileX2, tileY2)
    if self:isTaken (tileX1, tileY1) == true and self:isClear (tileX2, tileY2) == true then
        self.cellGrid[tileX1][tileY1], self.cellGrid[tileX2][tileY2] = nil, self.cellGrid[tileX1][tileY1]

        return tileX2, tileY2
    else
        return tileX1, tileY1
    end
end

local directionVects = {
    [1] = {0, -1}, -- Up
    [2] = {1, 0}, -- Right
    [3] = {0, 1}, -- Down
    [4] = {-1, 0}, -- Left
}
function map:getForwardPos (tileX, tileY, amount)
    local cellDirection = self.cellGrid[tileX][tileY].direction
    local vect = directionVects[cellDirection]

    return tileX + vect[1] * amount, tileY + vect[2] * amount
end

function map:moveForward (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cellDirection = self.cellGrid[tileX][tileY].direction
        local vect = directionVects[cellDirection]

        return self:moveTo (tileX, tileY, tileX + vect[1], tileY + vect[2])
    else
        return tileX, tileY
    end
end

function map:turnLeft (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.direction = cycleValue (cell.direction, -1, 4)
    end
end

function map:turnRight (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.direction = cycleValue (cell.direction, 1, 4)
    end
end

function map:transferInputToCell (tileX, tileY, cellTileX, cellTileY, foodType, amount, cost)
    if self:inBounds (cellTileX, cellTileY) == true then
        local inputVal = self:getInputTile (tileX, tileY, foodType) or 0
        local maxEnergy = self.cellManager.maxEnergy

        local origInput = inputVal
        local cellObj = self.cellGrid[cellTileX][cellTileY]
        -- local origTotalEnergy = cellObj.totalEnergy
        
        -- For some reason, this check is needed to make stable ecosystems possible...
        -- My guess is that the cells would waste too much energy abusing this function otherwise cuz energy is so sparse
        if inputVal > cost and maxEnergy - cellObj.energy > cost then
            -- Energy cost of consuming a tile
            if inputVal <= amount then
                cellObj.energy = cellObj.energy + inputVal
                -- cellObj.totalEnergy = cellObj.totalEnergy + inputVal
                inputVal = 0
            else
                cellObj.energy = cellObj.energy + amount
                -- cellObj.totalEnergy = cellObj.totalEnergy + amount
                inputVal = inputVal - amount
            end
            
            if cellObj.energy > maxEnergy then -- Cell energy max
                -- cellObj.totalEnergy = cellObj.totalEnergy - (cellObj.energy - maxEnergy)
                inputVal = inputVal + cellObj.energy - maxEnergy
                cellObj.energy = maxEnergy
            end

            self:adjustCellEnergy (cellTileX, cellTileY, -cost)
            self:setInputTile (tileX, tileY, foodType, inputVal)
        end

        -- assert (origInput + origTotalEnergy == (self:getInputTile (tileX, tileY, foodType) or 0) + cellObj.totalEnergy, "Energy conservation violated in transferInputToCell. " .. tostring(origInput) .. " + " .. tostring(origTotalEnergy) .. " != " .. tostring(self:getInputTile (tileX, tileY, foodType)) .. " + " .. tostring(cellObj.totalEnergy) .. ")")
    end
end

function map:shareInputToCell (tileX1, tileY1, tileX2, tileY2, amount, cost)
    if self:isTaken (tileX1, tileY1) == true and self:isTaken (tileX2, tileY2) == true then
        local currCellObj = self.cellGrid[tileX1][tileY1]
        local otherCellObj = self.cellGrid[tileX2][tileY2]
        local maxEnergy = self.cellManager.maxEnergy

        -- Energy cost of sharing energy
        currCellObj.energy = currCellObj.energy - cost

        if currCellObj.energy <= amount then
            otherCellObj.energy = otherCellObj.energy + currCellObj.energy
            currCellObj.energy = 0
        else
            otherCellObj.energy = otherCellObj.energy + amount
            currCellObj.energy = currCellObj.energy - amount
        end
        
        if otherCellObj.energy > maxEnergy then -- Cell energy max
            currCellObj.energy = currCellObj.energy + otherCellObj.energy - maxEnergy
            otherCellObj.energy = maxEnergy
        end

        if currCellObj.energy <= 0 then
            self:deleteCell (tileX1, tileY1)
        end
    end
end

function map:adjustCellEnergy (tileX, tileY, amount, updateWasteBuffer)
    if updateWasteBuffer == nil then
        updateWasteBuffer = true
    end

    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.energy = math.min (self.cellManager.maxEnergy, cell.energy + amount)

        if cell.energy < 0 then
            local deficit = cell.energy
            cell.energy = 0

            if updateWasteBuffer == true and amount < 0 then
                self:adjustCellWasteBuffer (tileX, tileY, -amount+deficit)
            end
            map:adjustCellHealth (tileX, tileY, deficit, updateWasteBuffer)
        else
            if updateWasteBuffer == true and amount < 0 then
                self:adjustCellWasteBuffer (tileX, tileY, -amount)
            end
        end
    end
end

function map:adjustCellHealth (tileX, tileY, amount, updateWasteBuffer)
    if updateWasteBuffer == nil then
        updateWasteBuffer = true
    end

    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        local origHealth = cell.health
        cell.health = clamp (cell.health + amount, 0, self.cellManager.maxHealth)

        if updateWasteBuffer == true and amount < 0 then
            self:adjustCellWasteBuffer (tileX, tileY, -amount)
        end

        if cell.health <= 0 then
            self:deleteCell (tileX, tileY)
        end
    end
end

function map:getCellHealth (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        return self.cellGrid[tileX][tileY].health
    else
        return 0
    end
end

function map:getCellEnergy (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        return self.cellGrid[tileX][tileY].energy
    else
        return 0
    end
end

function map:getCellTotalResources (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cellObj = self.cellGrid[tileX][tileY]
        return cellObj.energy + cellObj.health
    else
        return 0
    end
end

function map:getCellDisplayVar (tileX, tileY, index)
    if self:isTaken (tileX, tileY) == true then
        return self.cellGrid[tileX][tileY].displayVars[index]
    else
        return nil
    end
end

function map:adjustCellWasteBuffer (tileX, tileY, amount)
    if self:isTaken (tileX, tileY) == true then
        local cellObj = self.cellGrid[tileX][tileY]
        cellObj.wasteBuffer = math.max (0, cellObj.wasteBuffer + amount)

        if cellObj.wasteBuffer >= self.cellManager.maxWasteBuffer then
            local deficit = cellObj.wasteBuffer - self.cellManager.maxWasteBuffer
            cellObj.wasteBuffer = self.cellManager.maxWasteBuffer

            self:emptyCellWasteBuffer (tileX, tileY)

            cellObj.wasteBuffer = cellObj.wasteBuffer + deficit
        end
    end
end

function map:emptyCellWasteBuffer (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cellObj = self.cellGrid[tileX][tileY]
        
        self:adjustInputTile (tileX, tileY, wasteMap[cellObj.consumes], cellObj.wasteBuffer)
        cellObj.wasteBuffer = 0
    end
end

return map