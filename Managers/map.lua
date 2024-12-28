local clamp = require ("Libraries.lume").clamp
local cycleValue = require ("Helpers.cycleValue")
local mapToScale = require ("Helpers.mapToScale")
local copyTable  = require("Helpers.copyTable")

local map = {
    inputGrid = {}, -- Tracks all the tiles in the map environment
    cellGrid = {}, -- Sparse matrix that tracks all the cells in the map environment
    startCell = nil, -- The first cell object in the linked list used for updating the cells
    width = 0, -- Width of the input grid
    height = 0, --- Height of the input grid
    lastTick = 0, --- Time since the last tick, in seconds
    tickSpeed = 1/32, -- Time between ticks
    camera = {
        x = 0,
        y = 0,
        zoom = 1,
    }, -- Contains camera position information
    inputBounds = {
        min = 0,
        max = 1,
    },
    title = "Untitled Map", -- The title of the map. Mostly used in menus
    cellManager = nil,
    stats = {
        cells = 0,
    },
}

--- Initializes the map manager and prepares it for processing.
--- @param title string The name of the map.
function map:init (cellManager, title, inputMin, inputMax)
    self.cellManager = cellManager
    self.title = title or "Untitled Map"
    self.inputBounds.min = inputMin or 0
    self.inputBounds.max = inputMax or 1
end

--- Resets the map with a new size and input data.
--- @param width integer The width of the input data.
--- @param height integer The height of the input data.
--- @param mapInput fun(param:integer, param:integer):number Used to map the value of each input tile
function map:reset (width, height, mapInput)
    self.width, self.height = width, height

    -- Generates the input grid and input render
    local inputGrid = {}
    local cellGrid = {}
    for i = 1, self.width do
        local inputRow = {}
        inputGrid[i] = inputRow -- Add row to input grid

        local cellRow = {}
        cellGrid[i] = cellRow -- Add row to cell grid

        for j = 1, self.height do
            local tile = 0

            if mapInput ~= nil then
                tile = mapInput (i, j)
            else
                tile = 0
            end

            inputRow[j] = tile -- Add tile to grid
        end
    end

    self.inputGrid = inputGrid
    self.cellGrid = cellGrid
    self.stats.cells = 0
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
        local currCell = self.startCell

        -- Iterate over the cell object's linked list until no more cells are found
        while currCell ~= nil do
            -- Call cell object's update script

            currCell = currCell.nextCell
        end

        self.lastTick = 0 -- Reset last tick
    end
end

--- Renders the cell objects and input tiles based on the current camera position.
function map:draw ()
    love.graphics.push ()
    love.graphics.translate (-self.camera.x, -self.camera.y)
    love.graphics.scale (self.camera.zoom)

    -- Draw tiles
    local inputGrid = self.inputGrid
    local cellGrid = self.cellGrid
    for i = 1, self.width do
        local cellRow = cellGrid[i]
        local inputRow = inputGrid[i]

        for j = 1, self.height do
            local cellObj = cellRow[j]

            -- Check if cell exists at this position
            if cellObj ~= nil then
                -- Render cell object
                love.graphics.setColor (cellObj.color)
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)

            else
                -- Render input tile
                local input = inputRow[j]
                local scaledColor = mapToScale (input, self.inputBounds.min, self.inputBounds.max, 0, 1)
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
--- @return number | nil inputValue The value of the input tile or nil if the provided position was out of bounds
function map:getInputTile (tileX, tileY)
    if self:inBounds (tileX, tileY) == true then
        return self.inputGrid[tileX][tileY]

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
        self.inputGrid[tileX][tileY] = clamp (value, self.inputBounds.min, self.inputBounds.max)
    end
end

--- Increments the value of the input tile at the provided position
--- @param tileX integer The horizontal map position
--- @param tileY integer The vertical map position
--- @param value number The amount to increment the input value by
function map:adjustInputTile (tileX, tileY, value)
    assert (type (value) == "number", "Provided value is not a number")

    if self:inBounds (tileX, tileY) == true then
        self.inputGrid[tileX][tileY] = clamp (self.inputGrid[tileX][tileY] + value, self.inputBounds.min, self.inputBounds.max)
    end
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

--- Spawns a new cell object into the map.
--- The new cell object will have n rounds of mutations applied to it if a parent is provided, depending on the value of map.cellManager.meanMut.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @param health number The health value of the new cell object.
--- @param energy number The energy value of the new cell object.
--- @param parentCellObj? table The parent cell object object.
--- @return boolean success True if a cell object was spawned successfully.
function map:spawnCell (tileX, tileY, health, energy, parentCellObj)
    if self:isClear (tileX, tileY) == true then
        local newCellObj = self.cellManager:new (health, energy) -- Create default cell object

        -- Mutate cell object if a parent is given
        if parentCellObj ~= nil then
            local mutSuccess, mutErr = pcall (self.cellManager.mutate, self.cellManager.mutate, newCellObj, parentCellObj)
            local compSuccess, compErr = pcall (self.cellManager.compileScript, self.cellManager.compileScript, newCellObj)

            assert (mutSuccess == true, "ERROR: Problem with mutation:" .. tostring (mutErr))
            assert (compSuccess == true, "ERROR: Problem with script compilation:" .. tostring (compErr))
            -- self.cellManager:printCellInfo (parentCellObj)
        end

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

        -- Add cell object's remaining energy and health to the ground
        map:adjustInputTile (tileX, tileY, 1 * (cellObj.health + math.max (500 * 0.1, cellObj.energy)))

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

--- Gets a copy of the cell object at the specified map position.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @return table|nil cellObj The cell object at the given position or nil if a cell object doesn't exist there.
function map:getCell (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        return copyTable (self.cellGrid[tileX][tileY])
    end
end

return map