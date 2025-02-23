local clamp = require ("Libraries.lume").clamp
local cycleValue = require ("Helpers.cycleValue")
local mapToScale = require ("Helpers.mapToScale")
local copyTable  = require("Helpers.copyTable")

local map = {
    envGrid = {},
    cellGrid = {},
    version = "mk-2",
    width = 0, -- Width of the input grid
    height = 0, --- Height of the input grid
    lastTick = 0, --- Time since the last tick, in seconds
    tickSpeed = 0, -- Time between ticks
    camera = {
        x = 0,
        y = 0,
        zoom = 1,
    }, -- Contains camera position information
    inputBounds = {
        min = 0,
        max = 0,
    },
    drawBounds = {
        min = 0,
        max = 0,
    },
    title = "Untitled Map", -- The title of the map. Mostly used in menus
    cellManager = nil,
    stats = {
        cells = 0,
        resets = 0,
    },
    ticksBetweenSaves = 0,
    lastSave = 0,
}

--- Initializes the map manager and prepares it for processing.
function map:init (cellManager, options)
    options = options or {}
    assert (type (options) == "table", "Provided options argument is not a table")

    self.cellManager = cellManager
    self.title = options.title or "Untitled Map"
    self.inputBounds.min = options.inputMin or 0
    self.inputBounds.max = options.inputMax or 500
    self.drawBounds.min = options.drawMin or self.inputBounds.min
    self.drawBounds.max = options.drawMax or self.inputBounds.max
    self.stats.resets = 0
    self.ticksBetweenSaves = options.ticksBetweenSaves or 100000

    self.tickSpeed = math.huge
end

--- Resets the map with a new size and input data.
--- @param width integer The width of the input data.
--- @param height integer The height of the input data.
--- @param mapInput fun(param:integer, param:integer):number Used to map the value of each input tile
function map:reset (width, height, mapInput)
    self.width, self.height = width, height

    -- Generates the grids
    local envGrid = {}
    local cellGrid = {}
    for i = 1, self.width do
        local envRow = {}
        envGrid[i] = envRow -- Add row to input grid

        local cellRow = {}
        cellGrid[i] = cellRow

        for j = 1, self.height do
            local envTile = {
                input = 0,
                type = "blank",
            }

            if mapInput ~= nil then
                envTile.input = mapInput (i, j)
            end

            envRow[j] = envTile -- Add tile to grid
        end
    end

    self.envGrid = envGrid
    self.cellGrid = cellGrid
    self.stats.cells = 0
    self.stats.resets = self.stats.resets + 1
    self.lastTick = 0
    self.startCell = nil
end

--- Updates the cells on the map if enough time has passed since the last tick.
--- @param dt number Delta time. AKA the amount of time since the last frame.
function map:update (dt)
    self.lastTick = self.lastTick + dt -- Update last tick

    -- Check if enough time has passed since the last tick
    local cellGrid = self.cellGrid
    if self.lastTick >= self.tickSpeed then
        local updateStartTime = love.timer.getTime()

        -- Iterate over active grid and update cells
        -- TODO: Optimize this system so it doesn't have to iterate over the entire grid
        for i = 1, self.width do
            local cellRow = cellGrid[i]

            for j = 1, self.height do
                local cellObj = cellRow[j]

                -- Skip tiles without cells and cells that have already been updated this tick
                if cellObj ~= nil and cellObj.lastUpdate < updateStartTime then
                    cellObj.lastUpdate = updateStartTime

                    self.cellManager:update (i, j, cellObj, self) -- Call cell update function
                end
            end
        end

        self.lastTick = 0 -- Reset last tick
        self.lastSave = self.lastSave - 1 -- Decrement ticks since last save

        -- Save the map and cells if enough ticks have passed
        if self.lastSave <= 0 then
            -- self:quickSave ()

            self.lastSave = self.ticksBetweenSaves
        end
    end
end

--- Renders the cell objects and input tiles based on the current camera position.
function map:draw ()
    love.graphics.push ()
    love.graphics.translate (-self.camera.x, -self.camera.y)
    love.graphics.scale (self.camera.zoom)

    -- Draw tiles
    local envGrid = self.envGrid
    local cellGrid = self.cellGrid
    for i = 1, self.width do
        local cellRow = cellGrid[i]
        local envRow = envGrid[i]

        for j = 1, self.height do
            local cellObj = cellRow[j]

            -- Check if cell exists at this position
            if cellObj ~= nil then
                -- Render cell object
                love.graphics.setColor (cellObj.color)
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)

            else
                -- Render input tile
                local scaledColor = mapToScale (envRow[j].input, self.drawBounds.min, self.drawBounds.max, 0, 1)
                love.graphics.setColor (scaledColor, scaledColor, scaledColor, 1)
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
            end
        end
    end

    love.graphics.pop ()
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

--- Gets the value of the input tile at the provided position
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @return number | nil inputValue The value of the input tile or nil if the provided position was out of bounds
function map:getInputTile (tileX, tileY)
    if self:inBounds (tileX, tileY) == true then
        return self.envGrid[tileX][tileY].input

    else
        return nil
    end
end

--- Sets the value of the input tile at the provided position
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @param value number The new value of the input tile
function map:setInputTile (tileX, tileY, value)
    assert (type (value) == "number", "Provided value is not a number")

    if self:inBounds (tileX, tileY) == true then
        self.envGrid[tileX][tileY].input = clamp (value, self.inputBounds.min, self.inputBounds.max)
    end
end

--- Increments the value of the input tile at the provided position
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @param value number The amount to increment the input value by
function map:adjustInputTile (tileX, tileY, value)
    assert (type (value) == "number", "Provided value is not a number")

    if self:inBounds (tileX, tileY) == true then
        self.envGrid[tileX][tileY].input = clamp (self.envGrid[tileX][tileY].input + value, self.inputBounds.min, self.inputBounds.max)
    end
end

--- Checks if the provided position is within the bounds of the map
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @return boolean inBounds True if the provided position is within bounds
function map:inBounds (tileX, tileY)
    return tileX >= 1 and tileX <= self.width and tileY >= 1 and tileY <= self.height
end

--- Checks if the provided position is clear of any cells.
--- It also implicitly checks if the provided position is within bounds.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @return boolean isClear True if the provided position does not have a cell object.
function map:isClear (tileX, tileY)
    return self:inBounds (tileX, tileY) and self.cellGrid[tileX][tileY] == nil
end

--- Checks if the provided position is taken by a cells.
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
        return copyTable (self.cellGrid[tileX][tileY])
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
function map:spawnCell (tileX, tileY, health, energy, parentCellObj)
    if self.stats.cells < self.cellManager.maxCells and self:isClear (tileX, tileY) == true then
        local newCellObj = self.cellManager:new (health, energy) -- Create default cell object

        -- Mutate cell object if a parent is given
        -- if parentCellObj ~= nil then
        --     local mutSuccess, mutErr = pcall (self.cellManager.mutate, self.cellManager.mutate, newCellObj, parentCellObj)
        --     local compSuccess, compErr = pcall (self.cellManager.compileScript, self.cellManager.compileScript, newCellObj)

        --     assert (mutSuccess == true, "ERROR: Problem with mutation: " .. tostring (mutErr))
        --     assert (compSuccess == true, "ERROR: Problem with script compilation: " .. tostring (compErr))
        -- end

        self.cellGrid[tileX][tileY] = newCellObj
        self.stats.cells = self.stats.cells + 1
        
        return true
    else
        return false
    end
end

--- Removes a cell object from the map.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
function map:deleteCell (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cellObj = self.cellGrid[tileX][tileY]

        -- Add cell's remaining energy and health to the ground
        map:adjustInputTile (tileX, tileY, cellObj.totalEnergy)

        self.cellGrid[tileX][tileY] = nil
        self.stats.cells = self.stats.cells - 1
    end
end

--- Swaps the positions of two cells in the map.
--- @param tileX1 integer The horizontal map position of the first cell object.
--- @param tileY1 integer The vertical map position of the first cell object.
--- @param tileX2 integer The horizontal map position of the second cell object.
--- @param tileY2 integer The vertical map position of the second cell object.
--- @return integer newTileX1 The new horizontal position of the first cell object.
--- @return integer newTileY1 The new vertical position of the first cell object.
function map:swapCells (tileX1, tileY1, tileX2, tileY2)
    if self:isTaken (tileX1, tileY1) == true and self:isClear (tileX2, tileY2) == true then
        self.cellGrid[tileX1][tileY1], self.cellGrid[tileX2][tileY2] = self.cellGrid[tileX2][tileY2], self.cellGrid[tileX1][tileY1]

        return tileX2, tileY2
    else
        return tileX1, tileY1
    end
end

function map:shareInputToCell (tileX1, tileY1, tileX2, tileY2, amount)
    if self:isTaken (tileX1, tileY1) == true and self:isTaken (tileX2, tileY2) == true then
        local currCellObj = self.cellGrid[tileX1][tileY1]
        local otherCellObj = self.cellGrid[tileX2][tileY2]

        -- Energy cost of sharing energy
        currCellObj.energy = currCellObj.energy - 3

        if currCellObj.energy <= amount then
            otherCellObj.energy = otherCellObj.energy + currCellObj.energy
            currCellObj.energy = 0
        else
            otherCellObj.energy = otherCellObj.energy + amount
            currCellObj.energy = currCellObj.energy - amount
        end
        
        if otherCellObj.energy > 500 then -- Cell energy max
            currCellObj.energy = currCellObj.energy + otherCellObj.energy - 500
            otherCellObj.energy = 500
        end

        if currCellObj.energy <= 0 then
            self:deleteCell (tileX1, tileY1)
        end
    end
end

function map:dropEnergy ()

end

function map:adjustCellEnergy (tileX, tileY, amount)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.energy = math.min (500, cell.energy + amount)

        if cell.energy < 0 then
            map:adjustCellHealth (tileX, tileY, cell.energy)
            cell.energy = 0
        end
    end
end

function map:adjustCellHealth (tileX, tileY, amount)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.health = math.min (500, cell.health + amount)

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

return map