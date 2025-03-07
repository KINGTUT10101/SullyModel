local bitser = require ("Libraries.bitser")
local clamp = require ("Libraries.lume").clamp
local cycleValue = require ("Helpers.cycleValue")
local mapToScale = require ("Helpers.mapToScale")
local copyTable  = require("Helpers.copyTable")

bitser.register("function", function()
    return nil
end)

local map = {
    inputGrid = {}, -- Tracks all the tiles in the map environment
    barrierGrid = {}, -- Tracks all the barriers in the map environment
    cellGrid = {}, -- Sparse matrix that tracks all the cells in the map environment
    -- inputRender = nil, -- Contains a pre-rendered image of the background data
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
        min = 0,
        max = 1,
    },
    drawBounds = {
        min = 0,
        max = 1,
    },
    title = "Untitled Map", -- The title of the map. Mostly used in menus
    cellManager = nil,
    stats = {
        cells = 0,
    },
    ticksBetweenSaves = 100000,
    lastSave = 0,
    resets = 0,
}

function map:quickSave ()
    local cellGridCopy = {}

    for i = 1, self.width do
        local cellRow = {}
        cellGridCopy[i] = cellRow -- Add row to cell grid

        for j = 1, self.height do
            if self.cellGrid[i][j] ~= nil then
                cellRow[j] = copyTable (self.cellGrid[i][j])
                cellRow[j].scriptFunc = nil
            end
        end
    end
    
    local fileName = "quickSave_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".slf"
    bitser.dumpLoveFile (fileName, {
        inputGrid = self.inputGrid,
        barrierGrid = self.barrierGrid,
        cellGrid = cellGridCopy,
        stats = self.stats,
        lastSave = self.lastSave,
        resets = self.resets,
        lastTick = self.lastTick,
    })
    print ("QUICK SAVE: " .. fileName)
end

--- Initializes the map manager and prepares it for processing.
--- @param title string The name of the map.
function map:init (cellManager, title, inputMin, inputMax, drawMin, drawMax)
    self.cellManager = cellManager
    self.title = title or "Untitled Map"
    self.inputBounds.min = inputMin or 0
    self.inputBounds.max = inputMax or 1
    self.drawBounds.min = drawMin or self.inputBounds.min
    self.drawBounds.max = drawMax or self.inputBounds.max
end

--- Resets the map with a new size and input data.
--- @param width integer The width of the input data.
--- @param height integer The height of the input data.
--- @param mapInput? fun(param:integer, param:integer):number Used to map the value of each input tile
--- @param mapBarriers? fun(param:integer, param:integer):boolean Used to map the impassible barrier tiles
function map:reset (width, height, mapInput, mapBarriers)
    self.width, self.height = width, height

    -- Generates the input grid and input render
    local inputGrid = {}
    local barrierGrid = {}
    local cellGrid = {}
    for i = 1, self.width do
        local inputRow = {}
        inputGrid[i] = inputRow -- Add row to input grid

        local barrierRow = {}
        barrierGrid[i] = barrierRow -- Add row to barrier grid

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

            local barrier = false

            if mapBarriers ~= nil then
                barrier = mapBarriers (i, j)
            else
                barrier = false
            end

            barrierRow[j] = barrier -- Add tile to grid
        end
    end

    self.inputGrid = inputGrid
    self.barrierGrid = barrierGrid
    self.cellGrid = cellGrid
    self.stats.cells = 0
    self.resets = self.resets + 1
    -- self.inputRender = love.graphics.newImage (inputRender)
    -- self.inputRender:setFilter ("nearest", "nearest")
end

function map:update (dt)
    self.lastTick = self.lastTick + dt -- Update last tick

    local capture = nil

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

                -- Check if cell exists at this position
                if cellObj ~= nil then
                    -- Skip cells that have already been updated this tick
                    if cellObj.lastUpdate < updateStartTime then
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

                    capture = cellObj
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

    return capture
end

function map:draw ()
    love.graphics.push ()
    love.graphics.translate (-self.camera.x, -self.camera.y)
    love.graphics.scale (self.camera.zoom)

    -- Draw input image
    -- love.graphics.draw (self.inputRender, 0, 0)

    -- Draw cells
    local inputGrid = self.inputGrid
    local barrierGrid = self.barrierGrid
    local cellGrid = self.cellGrid
    for i = 1, self.width do
        local cellRow = cellGrid[i]
        local inputRow = inputGrid[i]
        local barrierRow = barrierGrid[i]

        for j = 1, self.height do
            local cell = cellRow[j]
            local input = inputRow[j]
            local barrier = barrierRow[j]

            -- Check what exists at the current position to determine what to render
            if cell ~= nil then
                -- Render cell
                love.graphics.setColor (cell.color)
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)

            elseif barrier == true then
                -- Render barrier
                love.graphics.setColor ({1, 0, 0, 1})
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)

            else
                -- Render input tile
                local scaledColor = mapToScale (input, self.drawBounds.min, self.drawBounds.max, 0, 1)
                love.graphics.setColor (scaledColor, scaledColor, scaledColor, 1)
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
            end
        end
    end

    love.graphics.pop ()
end

function map:getTickSpeed ()
    return self.tickSpeed
end

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
    assert (tileX == tileX and tileY == tileY, "Bad coords found " .. tileX .. " " .. tileY)
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

--- Checks if the provided position is clear of any cells or barriers.
--- It also implicitly checks if the provided position is within bounds.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @return boolean isClear True if the provided position does not have a cell.
function map:isClear (tileX, tileY)
    return self:inBounds (tileX, tileY) == true and self.barrierGrid[tileX][tileY] == false and self.cellGrid[tileX][tileY] == nil
end

--- Checks if the provided position is taken by a cell.
--- It also implicitly checks if the provided position is within bounds.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @return boolean isClear True if the provided position contains a cell.
function map:isTaken (tileX, tileY)
    return self:inBounds (tileX, tileY) and self.cellGrid[tileX][tileY] ~= nil
end

function map:spawnCell (tileX, tileY, health, energy, parentCellObj)
    if self:isClear (tileX, tileY) == true then
        local newCellObj = self.cellManager:new (health, energy) -- Create default cell

        -- Mutate cell if a parent is given
        if parentCellObj ~= nil then
            local mutSuccess, mutErr = pcall (self.cellManager.mutate, self.cellManager, newCellObj, parentCellObj)
            local compSuccess, compErr = pcall (self.cellManager.compileScript, self.cellManager, newCellObj)

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

function map:deleteCell (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        local cellObj = self.cellGrid[tileX][tileY]

        -- Add cell's remaining energy and health to the ground
        map:adjustInputTile (tileX, tileY, cellObj.totalEnergy)

        self.cellGrid[tileX][tileY] = nil
        self.stats.cells = self.stats.cells - 1
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

function map:getCell (tileX, tileY)
    if self:isTaken (tileX, tileY) == true then
        return copyTable (self.cellGrid[tileX][tileY])
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

function map:transferInputToCell (tileX, tileY, amount)
    if self:isTaken (tileX, tileY) == true then
        local cellObj = self.cellGrid[tileX][tileY]
        local inputVal = self:getInputTile (tileX, tileY)
        local maxEnergy = self.cellManager.maxEnergy

        -- Energy cost of consuming a tile
        cellObj.energy = cellObj.energy - 2

        if inputVal <= amount then
            cellObj.energy = cellObj.energy + inputVal
            cellObj.totalEnergy = cellObj.totalEnergy + inputVal
            inputVal = 0
        else
            cellObj.energy = cellObj.energy + amount
            cellObj.totalEnergy = cellObj.totalEnergy + amount
            inputVal = inputVal - amount
        end
        
        if cellObj.energy > maxEnergy then -- Cell energy max
            cellObj.totalEnergy = cellObj.totalEnergy - (cellObj.energy - maxEnergy)
            inputVal = inputVal + cellObj.energy - maxEnergy
            cellObj.energy = maxEnergy
        end

        self:setInputTile (tileX, tileY, inputVal)
    end
end

function map:shareInputToCell (tileX1, tileY1, tileX2, tileY2, amount)
    if self:isTaken (tileX1, tileY1) == true and self:isTaken (tileX2, tileY2) == true then
        local currCellObj = self.cellGrid[tileX1][tileY1]
        local otherCellObj = self.cellGrid[tileX2][tileY2]
        local maxEnergy = self.cellManager.maxEnergy

        -- Energy cost of sharing energy
        currCellObj.energy = currCellObj.energy - 3

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