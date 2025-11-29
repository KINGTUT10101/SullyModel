local thisScene = {}
local sceneMan = require ("Libraries.sceneMan")
local map = require ("Managers.map")
local cell = require ("Managers.cell")
local mapToScale = require ("Helpers.mapToScale")
local round = require ("Libraries.lume").round
local cellActions = require ("Data.cellActions")
local cellInputs = require ("Data.cellInputs")
local cycleValue = require ("Helpers.cycleValue")

local startTime

local mapSize = 50

local camVelocity = 15
local zoomVelocity = 2

local cellStartHealth, cellStartEnergy = 500, 500

local maxCaptures = 50
local maxCaptureCycles = 10000
local captureTimer = maxCaptureCycles
local captures = {}

local superparents = 3

local totalCycles = 0
local cyclesSinceLastFail = {}
for superparent = 1, superparents do
    cyclesSinceLastFail[superparent] = 0
end

local failsafeSpawns = 200
local failsafeActivations = {}
for superparent = 1, superparents do
    failsafeActivations[superparent] = -1
end
local lastCells = {}
local failsafeMutations = {
    min = 0,
    max = 500,
}

local renderMap = true
local renderModeIndex = 1
local validModes = {
    "normal",
    "superparents",
    "energy",
    "health",
    "total",
    "one",
    "none"
}
local renderSubModeIndex = 1
local validSubModes = {
    "normal",
    "pheromones",
    "inputDisabled",
    "barriersDisabled",
    "allDisabled",
}

local baseXInput = 10000 * love.math.random()
local baseYInput = 10000 * love.math.random()
local maxInput = 500
local function mapInput (tileX, tileY)
    return (math.random () < 0.10) and maxInput or 0

    -- return round (mapToScale (love.math.noise(baseXInput+.05*tileX, baseYInput+.02*tileY), 0, 1, 0, maxInput))
end

local baseXBarriers = 10000 * love.math.random()
local baseYBarriers = 10000 * love.math.random()
local multXBarrier = 0.15 -- 0.03
local multYBarrier = 0.25 -- 0.1
local biomeXBarriers = 100000 * love.math.random()
local biomeYBarriers = 100000 * love.math.random()
local bmultXBarrier = 0.03
local bmultYBarrier = 0.03
local function mapBarriers (tileX, tileY)
    -- if true then return "blank" end

    if love.math.noise(biomeXBarriers+bmultXBarrier*tileX, biomeYBarriers+bmultYBarrier*tileY) >= 0.35 then
        return (love.math.noise(baseXBarriers+multXBarrier*tileX, baseYBarriers+multYBarrier*tileY) > 0.50) and "barrier" or "blank"
    else
        return "blank"
    end
end

function thisScene:load (...)
    cell:init (map, cellInputs, cellActions, {
        network = {
            layers = 5,
            neuronsPerLayer = 20
        },
        decision = {
            -- useSoftmax = true,
        },
        maxHealth = 1500,
        maxEnergy = 1500,
        memVars = 2,
        displayVars = 1,
        tickCost = 1,
        -- cellAge = {
            --     min = math.huge,
            --     max = math.huge,
            -- },
        maxCells = 150,
        -- maxCells = {
        --     600,
        --     450,
        --     -- 450,
        --     -- 75,
        -- },
        superparents = superparents,
        consumeOnTick = {
            amount = 0,
            cost = 0,
        },
        pheromoneTime = 250,
        pheromones = 2,
        actionsPerTurn = 3,
        actionThreshold = 0.5,
        canZeroVars = true,
    })
    map:init (cell, {
        inputBounds = {
            min = 0,
            max = math.huge,
        },
        drawBounds = {
            min = 0,
            max = 500,
        },
    })

    map:reset (mapSize, mapSize, mapInput, mapBarriers)
    map:setCamera (-110, -10, 3.8)
    map:setTickSpeed (1/8)
    startTime = os.time()

    -- Adds a few heavily mutated cells to the initial captures lists
    for superparent = 1, superparents do
        captures[superparent] = {}

        for i = 1, maxCaptures do
            local newCellObj = cell:new (cellStartHealth, cellStartEnergy, superparent)

            -- Heavily mutate cell
            for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, failsafeMutations.min, failsafeMutations.max)) do
                cell:mutate (newCellObj)
            end

            captures[superparent][i] = newCellObj
        end
    end
end

function thisScene:update (dt)
    local camX, camY, zoom = map:getCamera ()
    local speedMult = (love.keyboard.isDown ("lshift") == true) and 5 or 1

    if love.keyboard.isDown("w") then
        camY = camY - camVelocity * dt * zoom * speedMult
    elseif love.keyboard.isDown("s") then
        camY = camY + camVelocity * dt * zoom * speedMult
    end

    if love.keyboard.isDown("a") then
        camX = camX - camVelocity * dt * zoom * speedMult
    elseif love.keyboard.isDown("d") then
        camX = camX + camVelocity * dt * zoom * speedMult
    end

    if love.keyboard.isDown("q") then
        zoom = zoom - zoomVelocity * dt * zoom
    elseif love.keyboard.isDown("e") then
        zoom = zoom + zoomVelocity * dt * zoom
    end

    -- Update map and camera
    map:setCamera (camX, camY, zoom)
    local currentCaptures, tickOccured = map:update (dt)

    if tickOccured == true then
        for superparent = 1, superparents do
            cyclesSinceLastFail[superparent] = cyclesSinceLastFail[superparent] + 1
        end

        totalCycles = totalCycles + 1
        captureTimer = captureTimer - 1

        if captureTimer <= 0 then
            captureTimer = maxCaptureCycles

            -- Capture cells
            for superparent = 1, superparents do
                if currentCaptures[superparent] ~= nil then
                    table.insert (captures[superparent], 1, currentCaptures[superparent])
                    if #captures[superparent] > maxCaptures then
                        table.remove (captures[superparent], maxCaptures + 1)
                    end
                end
            end
        end
    end

    for superparent = 1, superparents do
        local capture = currentCaptures[superparent]

        if capture ~= nil then
            lastCells[superparent] = capture
        end

        -- Activate failsafe if all cells are dead
        if map.stats.cells[superparent] <= 0 then
            print ("WARNING: Failsafe '" .. superparent .. "' #" .. failsafeActivations[superparent] .. " activated", os.date("%H:%M:%S - %Y-%m-%d"))
            print ("Number of available captures: " .. #captures[superparent])

            -- Add last surviving cell to captures list
            if lastCells[superparent] ~= nil then
                table.insert (captures[superparent], 1, lastCells[superparent])
                if #captures[superparent] > maxCaptures then
                    table.remove (captures[superparent], maxCaptures + 1)
                end
            end

            local cellsSpawned = 0
            local outerTries = 0
            local outerMaxTries = 5

            while cellsSpawned < math.min (failsafeSpawns, cell.maxCells[superparent]) and outerTries < outerMaxTries do
                for i = 1, #captures[superparent] do
                    local newCell = cell:newChild (captures[superparent][i])

                    -- Heavily mutate cell
                    for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, failsafeMutations.min, failsafeMutations.max)) do
                        cell:mutate (newCell)
                    end

                    -- print ("INFO:", i)
                    -- cell:printCellInfo (newCell)
                    -- cell:printCellScriptList (newCell)

                    -- Set the starting health and energy
                    newCell.health = cellStartHealth
                    newCell.energy = cellStartEnergy

                    -- Attempt to spawn the cell
                    local tries = 0
                    local maxTries = 50
                    while map:spawnCell (math.random (1, map.width), math.random (1, map.height), cellStartHealth, cellStartEnergy, newCell.superparent, newCell) == false and tries < maxTries do
                        tries = tries + 1
                    end
                    if tries < maxTries then
                        cellsSpawned = cellsSpawned + 1

                        if cellsSpawned >= math.min (failsafeSpawns, cell.maxCells[superparent]) then
                            break
                        end
                    end
                end

                outerTries = outerTries + 1
            end

            failsafeActivations[superparent] = failsafeActivations[superparent] + 1
            cyclesSinceLastFail[superparent] = 0
            print ("Cells spawned for " .. superparent .. ": " .. cellsSpawned)
        end
    end
end

function thisScene:draw ()
    love.graphics.setBackgroundColor (0, 0, 1, 1)

    if renderMap == true then
        map:draw (validModes[renderModeIndex], validSubModes[renderSubModeIndex])
    end

    -- Super speed border
    local tickSpeed = map:getTickSpeed ()
    if tickSpeed == 0 then
        love.graphics.setColor (0, 1, 0, 1)
        love.graphics.rectangle ("fill", 0, 0, love.graphics.getWidth (), 5)
        love.graphics.rectangle ("fill", 0, 0, 5, love.graphics.getHeight ())
        love.graphics.rectangle ("fill", love.graphics.getWidth (), 0, -5, love.graphics.getHeight ())
        love.graphics.rectangle ("fill", 0, love.graphics.getHeight (), love.graphics.getWidth (), -5)
    elseif tickSpeed == math.huge then
        love.graphics.setColor (1, 0, 0, 1)
        love.graphics.rectangle ("fill", 0, 0, love.graphics.getWidth (), 5)
        love.graphics.rectangle ("fill", 0, 0, 5, love.graphics.getHeight ())
        love.graphics.rectangle ("fill", love.graphics.getWidth (), 0, -5, love.graphics.getHeight ())
        love.graphics.rectangle ("fill", 0, love.graphics.getHeight (), love.graphics.getWidth (), -5)
    end

    -- Show FPS
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 10, 35, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf (love.timer.getFPS (), 15, 15, 25, "center")

    -- Show cursor tile position
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 45, 125, 25)
    love.graphics.setColor (1, 1, 1, 1)
    local cursorTileX, cursorTileY = map:screenToMap (love.mouse.getPosition ())
    love.graphics.printf ("Cursor: (" .. cursorTileX .. ", " .. cursorTileY .. ")", 15, 50, 125, "left")

    -- Show total number of ticks
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 80, 150, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Cycles: (*): " .. totalCycles, 15, 85, 150, "left")

    -- Ticks since last fail for each superparent
    for superparent = 1, superparents do
        love.graphics.setColor (0, 0, 0, 0.75)
        love.graphics.rectangle ("fill", 10, 115 + (superparent - 1) * 35, 150, 25)
        love.graphics.setColor (1, 1, 1, 1)
        love.graphics.printf ("Cycles (" .. superparent .. "): " .. cyclesSinceLastFail[superparent], 15, 120 + (superparent - 1) * 35, 150, "left")
    end

    -- Show number of cells
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 720, 10, 76, 25)
    love.graphics.setColor (1, 1, 1, 1)
    local totalCellCount = 0
    for superparent = 1, superparents do
        totalCellCount = totalCellCount + map.stats.cells[superparent]
    end
    love.graphics.printf ("Cells: " .. totalCellCount, 725, 15, 100, "left")

    -- Show number of failsafe activations for each superparent
    for superparent = 1, superparents do
        love.graphics.setColor (0, 0, 0, 0.75)
        love.graphics.rectangle ("fill", 720, 45 + (superparent - 1) * 35, 76, 25)
        love.graphics.setColor (1, 1, 1, 1)
        love.graphics.printf ("FSs (" .. superparent .. "): " .. failsafeActivations[superparent], 725, 50 + (superparent - 1) * 35, 100, "left")
    end

    -- Show number of cells for each superparent (rendered below the failsafe boxes)
    local cellsBaseY = 45 + superparents * 35
    for superparent = 1, superparents do
        love.graphics.setColor (0, 0, 0, 0.75)
        love.graphics.rectangle ("fill", 705, cellsBaseY + (superparent - 1) * 35, 90, 25)
        love.graphics.setColor (1, 1, 1, 1)
        love.graphics.printf ("Cells (" .. superparent .. "): " .. map.stats.cells[superparent], 710, cellsBaseY + 5 + (superparent - 1) * 35, 85, "left")
    end

    -- Shows the rendering mode
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 540, 100, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf (validModes[renderModeIndex] .. " mode", 15, 545, 100, "left")

    -- Shows the sub-rendering mode
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 570, 100, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf (validSubModes[renderSubModeIndex] .. " mode", 15, 575, 100, "left")
end

function thisScene:keypressed (key, scancode, isrepeat)
    -- Kills  a cell in the map
    if key == "k" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())
        map:deleteCell (tileX, tileY)

    -- Prints an input tile's value
    elseif key == "i" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())

        if love.keyboard.isDown ("lshift") then
            print ("Input @ (" .. tileX .. ", " .. tileY .. "): " .. map:getInputTile (map:screenToMap (love.mouse.getPosition ())))
        else
            local cellToPrint = map:getCell (tileX, tileY)

            if cellToPrint ~= nil then
                if love.keyboard.isDown ("lctrl") == true then
                    cell:printNetwork (map:getCell (tileX, tileY))
                else
                    cell:printCellInfo (map:getCell (tileX, tileY))
                end
            end
        end

    -- Quick saves
    elseif key == "g" then
        map:quickSave ()

    -- Get time since start of the simulation
    elseif key == "t" then
        print ("Time elapsed since the start of the sim: " .. round (((os.time () - startTime) / 60), 0.01) .. " minutes")

    -- Toggle rendering
    elseif key == "z" then
        renderMap = not renderMap

    -- Show total energy
    elseif key == "v" then
        print ("Total energy: " .. map.totalEnergy)

    -- Mutate cell
    elseif key == "o" then
        if love.keyboard.isDown ("lctrl") then
            local tileX, tileY = map:screenToMap (love.mouse.getPosition ())
            local cellObj = map:getCell (tileX, tileY)

            if cellObj then
                for i = 1, 5000 do
                    cell:mutate (cellObj)
                end
                print ("(" .. tostring (cellObj) .. ") Cell mutated!")
            end
        end
    
    -- Toggles superspeed
    elseif key == "tab" then
        if map:getTickSpeed () == 0 then
            map:setTickSpeed (1/8)
        else
            map:setTickSpeed (0)
        end

    -- Toggles pause mode
    elseif key == "space" then
        if map:getTickSpeed () == math.huge then
            map:setTickSpeed (1/8)
        else
            map:setTickSpeed (math.huge)
        end

    -- Print cell colors
    elseif key == "b" then
        print ("======== Cell Colors ========")
        for superparent = 1, superparents do
            local color = map.superparentColors[superparent]
            print (superparent .. ": " .. color[1] .. ", " .. color[2] .. ", " .. color[3])
        end

    -- Changes the sub rendering mode
    elseif key == "n" then
        renderSubModeIndex = cycleValue (renderSubModeIndex, 1, #validSubModes)

    -- Changes the rendering mode
    elseif key == "m" then
        renderModeIndex = cycleValue (renderModeIndex, 1, #validModes)

    elseif key == "'" then
        love.system.openURL ("file://"..love.filesystem.getSaveDirectory()) -- TEMP, this will fail on android

    elseif key == "l" then
        map.stopOnError = not map.stopOnError
        print ("Stop on error: " .. tostring (map.stopOnError))
    end
end

function thisScene:mousereleased (x, y, button)
    local tileX, tileY = map:screenToMap (x, y)
end

return thisScene