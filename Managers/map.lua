local clamp = require ("Libraries.lume").clamp

local map = {
    inputGrid = {}, -- Tracks all the tiles in the map environment
    cellGrid = {}, -- Sparse matrix that tracks all the cells in the map environment
    -- inputRender = nil, -- Contains a pre-rendered image of the background data
    width = 0, -- Width of the input grid
    height = 0, --- Height of the input grid
    lastTick = 0, --- Time since the last tick, in seconds
    tickSpeed = 32, -- Intended number of ticks per second
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
    title = "Untitled Map", -- The title of the map. Mostly used in menus
}

--- Initializes the map manager and prepares it for processing.
--- @param title string The name of the map.
function map:init (title, inputMin, inputMax)
    self.title = title or "Untitled Map"
    self.inputBounds.min = inputMin or 0
    self.inputBounds.max = inputMax or 1
end

--- Resets the map with a new size and input data.
--- @param width integer The width of the input data.
--- @param height integer The height of the input data.
--- @param sparseInput number[][] A sparse matrix containing the input data. Blank tiles will be set to 0.
function map:reset (width, height, sparseInput)
    self.width, self.height = width, height

    -- Generates the input grid and input render
    local inputGrid = {}
    local cellGrid = {}
    -- local inputRender = love.image.newImageData (self.width, self.height)
    for i = 1, self.width do
        local inputRow = {}
        inputGrid[i] = inputRow -- Add row to input grid

        local cellRow = {}
        cellGrid[i] = cellRow -- Add row to cell grid

        for j = 1, self.height do
            local tile = 0

            if sparseInput[i] ~= nil and sparseInput[i][j] ~= nil then
                tile = sparseInput[i][j]
            end

            inputRow[j] = tile -- Add tile to grid
            -- inputRender:setPixel (i - 1, j - 1, tile, tile, tile, 1) -- Render tile to image
        end
    end

    self.inputGrid = inputGrid
    self.cellGrid = cellGrid
    -- self.inputRender = love.graphics.newImage (inputRender)
    -- self.inputRender:setFilter ("nearest", "nearest")
end

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
                local cell = cellRow[j]

                -- Check if cell exists at this position
                if cell ~= nil then
                    -- Skip cells that have already been updated this tick
                    if cell.lastUpdate < updateStartTime then
                        cell.lastUpdate = updateStartTime

                        -- Call cell update function
                    end
                end
            end
        end

        self.lastTick = 0 -- Reset last tick
    end
end

function map:draw ()
    love.graphics.push ()
    love.graphics.translate (-self.camera.x, -self.camera.y)
    love.graphics.scale (self.camera.zoom)

    -- Draw input image
    -- love.graphics.draw (self.inputRender, 0, 0)

    -- Draw cells
    local inputGrid = self.inputGrid
    local cellGrid = self.cellGrid
    for i = 1, self.width do
        local cellRow = cellGrid[i]
        local inputRow = inputGrid[i]

        for j = 1, self.height do
            local cell = cellRow[j]
            local input = inputRow[j]

            -- Render input tile
            love.graphics.setColor (input, input, input, 1)
            love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)

            -- Check if cell exists at this position
            if cell ~= nil then
                -- Render cell
                love.graphics.setColor (1, 0, 0, 1)
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
            end
        end
    end

    love.graphics.pop ()
end

--- comment
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
function map:incrInputTile (tileX, tileY, value)
    assert (type (value) == "number", "Provided value is not a number")

    if self:inBounds (tileX, tileY) == true then
        self.inputGrid[tileX][tileY] = clamp (self.inputGrid[tileX][tileY] + value, self.inputBounds.min, self.inputBounds.max)
    end
end

return map