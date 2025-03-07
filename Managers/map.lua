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

                    local result, errorStr = pcall (self.cellManager.update, self.cellManager, i, j, cellObj, self) -- Call cell update function
                    
                        if result == false then
                            self.cellManager:printCellScriptString (cellObj)
                            self.cellManager:printCellInfo (cellObj)
                            love.system.setClipboardText (self.cellManager:compileScript (cellObj, true))
                            print ("Cell located at (" .. i .. ", " .. j .. ")")
                            error (errorStr)
                        end
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
        if parentCellObj ~= nil then
            local mutSuccess, mutErr = pcall (self.cellManager.mutate, self.cellManager, newCellObj, parentCellObj)
            local compSuccess, compErr = pcall (self.cellManager.compileScript, self.cellManager, newCellObj)

            assert (mutSuccess == true, "ERROR: Problem with mutation: " .. tostring (mutErr))
            assert (compSuccess == true, "ERROR: Problem with script compilation: " .. tostring (compErr))
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

        -- Add cell's remaining energy and health to the ground
        map:adjustInputTile (tileX, tileY, cellObj.totalEnergy)

        self.cellGrid[tileX][tileY] = nil
        self.stats.cells = self.stats.cells - 1
    end
end

local directionVects = {
    [1] = {0, -1}, -- Up
    [2] = {1, 0}, -- Right
    [3] = {0, 1}, -- Down
    [4] = {-1, 0}, -- Left
}
function map:getForwardPos (tileX, tileY, direction)
    local vect = directionVects[direction]

    return tileX + vect[1], tileY + vect[2]
end

function map:moveCellForward (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cellDirection = self.cellGrid[tileX][tileY].moveDir
        local vect = directionVects[cellDirection]
        local newTileX, newTileY = tileX + vect[1], tileY + vect[2]

        if self:isClear (newTileX, newTileY) == true then
            self.cellGrid[tileX][tileY], self.cellGrid[newTileX][newTileY] = self.cellGrid[newTileX][newTileY], self.cellGrid[tileX][tileY]

            return newTileX, newTileY
        else
            return tileX, tileY
        end
    else
        return tileX, tileY
    end
end

function map:turnCellLeft (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.moveDir = cycleValue (cell.moveDir, -1, 4)
    end
end

function map:turnCellRight (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.moveDir = cycleValue (cell.moveDir, 1, 4)
    end
end

function map:moveViewForward (tileX, tileY)
    local cellObj = self.cellGrid[tileX][tileY]
    local viewDirection = cellObj.viewDir
    local vect = directionVects[viewDirection]

    if self:inBounds (cellObj.relViewX + vect[1], cellObj.relViewY + vect[2]) == true then
        cellObj.relViewX, cellObj.relViewY = cellObj.relViewX + vect[1], cellObj.relViewY + vect[2]

        return cellObj.relViewX, cellObj.relViewY
    else
        return cellObj.relViewX, cellObj.relViewY
    end
end

function map:turnViewLeft (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.viewDir = cycleValue (cell.viewDir, -1, 4)
    end
end

function map:turnViewRight (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.viewDir = cycleValue (cell.viewDir, 1, 4)
    end
end

function map:dropEnergy ()

end

function map:adjustCellEnergy (tileX, tileY, amount)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.energy = math.min (self.cellManager.maxEnergy, cell.energy + amount)

        if cell.energy < 0 then
            map:adjustCellHealth (tileX, tileY, cell.energy)
            cell.energy = 0
        end
    end
end

function map:adjustCellHealth (tileX, tileY, amount)
    if self:isTaken (tileX, tileY) == true then
        local cell = self.cellGrid[tileX][tileY]
        cell.health = math.min (self.cellManager.maxHealth, cell.health + amount)

        if cell.health <= 0 then
            self:deleteCell (tileX, tileY)
        end
    end
end

function map:getCellEnergy (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        return self.cellGrid[tileX][tileY].energy
    else
        return 0
    end
end

function map:getCellHealth (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        return self.cellGrid[tileX][tileY].health
    else
        return 0
    end
end

function map:getCellAge (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        return self.cellGrid[tileX][tileY].ticksLeft
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