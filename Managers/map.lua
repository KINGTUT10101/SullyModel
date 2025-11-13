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
    },
    ticksBetweenSaves = 0,
    lastSave = 0,
    resets = 0,
    lastLogMsg = "",
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
    self.inputBounds.min = options.inputBounds.min or 0
    self.inputBounds.max = options.inputBounds.max or 500

    options.drawBounds = options.drawBounds or {}
    self.drawBounds.min = options.drawBounds.min or self.inputBounds.min
    self.drawBounds.max = options.drawBounds.max or self.inputBounds.max

    self.tickSpeed = math.huge
end

--- Resets the map with a new size and input data.
--- @param width integer The width of the input data.
--- @param height integer The height of the input data.
--- @param mapEnvInputs? fun(param:integer, param:integer):number Used to map the value of each input tile
--- @param mapEnvTypes? fun(param:integer, param:integer):boolean Used to map the impassible barrier tiles
function map:reset (width, height, mapEnvInputs, mapEnvTypes)
    self.width, self.height = width, height

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
                input = 0,
                type = "blank",
            }

            if mapEnvInputs ~= nil then
                envTile.input = mapEnvInputs (i, j)
            end

            if mapEnvTypes ~= nil then
                envTile.type = mapEnvTypes (i, j)
            end

            envRow[j] = envTile
        end
    end

    self.envGrid = envGrid
    self.cellGrid = cellGrid
    self.stats.cells = 0
    self.resets = self.resets + 1
    self.lastLogMsg = ""
    -- self.inputRender = love.graphics.newImage (inputRender)
    -- self.inputRender:setFilter ("nearest", "nearest")
end

--- Updates the cells on the map if enough time has passed since the last tick.
--- @param dt number Delta time. AKA the amount of time since the last frame.
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

                        self.cellManager.update(self.cellManager, i, j, cellObj, self)

                        -- local result, errorStr = pcall (self.cellManager.update, self.cellManager, i, j, cellObj, self) -- Call cell update function
                    
                        -- if result == false then
                        --     self.cellManager:printCellInfo (cellObj)
                        --     print ("Cell located at (" .. i .. ", " .. j .. ")")
                        --     error (errorStr)
                        -- end
                    end

                    if cellObj.type == "normal" then
                        capture = cellObj
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

    return capture
end

local validModes = {
    normal = true,
    energy = true,
    health = true,
    total = true,
    none = true,
}
function map:draw (mode)
    mode = mode or "normal"

    assert (validModes[mode] == true, "Invalid rendering mode provided")

    local maxEnergy = self.cellManager.maxEnergy
    local maxHealth = self.cellManager.maxHealth

    love.graphics.push ()
    love.graphics.translate (-self.camera.x, -self.camera.y)
    love.graphics.scale (self.camera.zoom)

    -- Draw cells
    local envGrid = self.envGrid
    local cellGrid = self.cellGrid
    for i = 1, self.width do
        local cellRow = cellGrid[i]
        local envRow = envGrid[i]

        for j = 1, self.height do
            local cellObj = cellRow[j]
            local envTile = envRow[j]

            -- Check what exists at the current position to determine what to render
            if cellObj ~= nil then
                -- Render cell
                if mode == "normal" then
                    love.graphics.setColor (cellObj.color)
                    love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
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
                end

            elseif envTile.type ~= "blank" then
                -- Render barrier (assume this is the only other tile type right now)
                love.graphics.setColor ({1, 0, 0, 1})
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)

            else
                -- Render input tile
                local scaledColor = mapToScale (envTile.input, self.drawBounds.min, self.drawBounds.max, 0, 1)
                love.graphics.setColor (scaledColor, scaledColor, scaledColor, 1)
                love.graphics.rectangle ("fill", i - 1, j - 1, 1, 1)
            end
        end
    end

    love.graphics.pop ()
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
--- @return number | nil inputValue The value of the input tile or nil if the provided position was out of bounds
function map:getInputTile (tileX, tileY)
    assert (tileX == tileX and tileY == tileY, "Bad coords found " .. tileX .. " " .. tileY)
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
function map:spawnCell (tileX, tileY, health, energy, parentCellObj)
    if self.stats.cells < self.cellManager.maxCells and self:isClear (tileX, tileY) == true then
        local newCellObj

        -- Mutate cell if a parent is given
        if parentCellObj ~= nil then
            newCellObj = self.cellManager:newChild (parentCellObj)
            newCellObj.energy = energy
            newCellObj.health = health
            
            for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, 0, 25)) do
                self.cellManager:mutate (newCellObj)
            end
        else
            newCellObj = self.cellManager:new (health, energy) -- Create default cell object
        end

        self.cellGrid[tileX][tileY] = newCellObj
        
        -- Only count normal and egg cells
        assert (newCellObj.type ~= "wall", "Error: Attempted to count a wall cell as a normal or egg cell.")
        self.stats.cells = self.stats.cells + 1
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
function map:spawnEgg (tileX, tileY, health, energy, parentCellObj)
    error ("TODO: map:spawnEgg")
    if self.stats.cells < self.cellManager.maxCells and self:isClear (tileX, tileY) == true then
        local newCellObj = self.cellManager:new (math.huge, math.huge) -- Create default cell object

        -- Mutate cell if a parent is given
        if parentCellObj ~= nil then
            -- TODO: Mutate the child cell multiple times
            local mutSuccess, mutErr = pcall (self.cellManager.mutate, self.cellManager, newCellObj, parentCellObj)
            local compSuccess, compErr = pcall (self.cellManager.compileScript, self.cellManager, newCellObj)

            assert (mutSuccess == true, "ERROR: Problem with mutation:" .. tostring (mutErr))
            assert (compSuccess == true, "ERROR: Problem with script compilation:" .. tostring (compErr))
        end

        local eggCellObj = self.cellManager:new (health, energy, "egg") -- Create default cell object
        eggCellObj.childCell = newCellObj
        eggCellObj.tickTimer = self.cellManager.eggTimer
        eggCellObj.ticksLeft = math.huge
        eggCellObj.color = {0, 0, 1, 1}

        self.cellGrid[tileX][tileY] = eggCellObj
        
        -- Only count normal and egg cells
        if eggCellObj.type == "normal" or eggCellObj.type == "egg" then
            self.stats.cells = self.stats.cells + 1
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
function map:spawnWall (tileX, tileY, health)
    if self.stats.cells < self.cellManager.maxCells and self:isClear (tileX, tileY) == true then
        local newCellObj = self.cellManager:new (health, 0, "wall") -- Create default cell object

        newCellObj.color = {1, 1, 0, 1}

        self.cellGrid[tileX][tileY] = newCellObj
        -- self.stats.cells = self.stats.cells + 1
        
        return true
    else
        return false
    end
end

--- Removes a cell object from the map.
--- @param tileX integer The horizontal map position.
--- @param tileY integer The vertical map position.
--- @param dropEnergy boolean If true, the energy from the deleted cell will be added to the environment
function map:deleteCell (tileX, tileY, dropEnergy)
    if self:isTaken (tileX, tileY) == true then
        local cellObj = self.cellGrid[tileX][tileY]

        -- Add cell's remaining energy and health to the ground
        if dropEnergy ~= false then
            map:adjustInputTile (tileX, tileY, cellObj.totalEnergy)
        end

        self.cellGrid[tileX][tileY] = nil

        if cellObj.type == "normal" or cellObj.type == "egg" then
            self.stats.cells = self.stats.cells - 1
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

function map:transferInputToCell (tileX, tileY, cellObj, amount, cost)
    if self:inBounds (tileX, tileY) == true then
        local inputVal = self:getInputTile (tileX, tileY)
        local maxEnergy = self.cellManager.maxEnergy
        
        -- For some reason, this check is needed to make stable ecosystems possible...
        -- My guess is that the cells would waste too much energy abusing this function otherwise cuz energy is so sparse
        if inputVal > cost then
            -- Energy cost of consuming a tile
            self:adjustCellEnergy (tileX, tileY, -cost)

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

function map:getCellDisplayVar (tileX, tileY, index)
    if self:isTaken (tileX, tileY) == true then
        return self.cellGrid[tileX][tileY].displayVars[index]
    else
        return nil
    end
end

return map