local thisScene = {}
local sceneMan = require ("Libraries.sceneMan")
local map = require ("Managers.map")
local cell = require ("Managers.cell")
local mapToScale = require ("Helpers.mapToScale")
local round = require ("Libraries.lume").round
local cellActions = require ("Data.cellActions")
local cellInputs = require ("Data.cellInputs")
local cycleValue = require ("Helpers.cycleValue")

local mapSize = 150

local camVelocity = 15
local zoomVelocity = 25

local cellStartEnergy, cellStartHealth = 100, 100

local maxCaptures = 50
local maxCaptureCycles = 10000
local captureTimer = maxCaptureCycles
local captures = {}

local cyclesSinceLastFail = 0

local failsafeSpawns = 350
local failsafeActivations = -1
local lastCell = nil
local failsafeMutations = {
    min = 10,
    max = 5000,
}

local renderMap = true
local renderModeIndex = 1
local validModes = {
    "normal",
    "energy",
    "health",
    "total",
    "none"
}

local baseXInput = 1000000 * love.math.random()
local baseYInput = 1000000 * love.math.random()
local maxInput = 5
local function mapInput (tileX, tileY)
    return mapToScale (love.math.noise(baseXInput+.05*tileX, baseYInput+.02*tileY), 0, 1, 0, maxInput)
end

local baseXBarriers = 1000 * love.math.random()
local baseYBarriers = 1000 * love.math.random()
local function mapBarriers (tileX, tileY)
    return (love.math.noise(baseXBarriers+.03*tileX, baseYBarriers+.1*tileY) > 0.70) and "barrier" or "blank"
end

function thisScene:load (...)
    cell:init (map, cellInputs, cellActions, {
        maxCells = math.huge,
        network = {
            layers = 5,
            -- neuronsPerLayer = 26,
            neuronsPerLayer = {
                5, 10, 20, 40, 80
            }
        },
        decision = {
            -- useSoftmax = true,
        },
        maxHealth = 1500,
        maxEnergy = 1500,
        cellAge = {
            min = math.huge,
            max = math.huge,
        }
    })
    map:init (cell, {
        inputBounds = {
            min = 0,
            max = math.huge,
        },
        drawBounds = {
            min = 0,
            max = 500,
        }
    })

    map:reset (mapSize, mapSize, mapInput, mapBarriers)
    map:setCamera (-110, -10, 5.8)
    map:setTickSpeed (1/8)

    -- Adds a few heavily mutated cells to the initial captures list
    for i = 1, maxCaptures do
        local newCellObj = cell:new (cellStartHealth, cellStartEnergy)

        -- Heavily mutate cell
        for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, failsafeMutations.min, failsafeMutations.max)) do
            cell:mutate (newCellObj)
        end

        captures[i] = newCellObj
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
        zoom = zoom - zoomVelocity * dt
    elseif love.keyboard.isDown("e") then
        zoom = zoom + zoomVelocity * dt
    end

    -- Update map and camera
    map:setCamera (camX, camY, zoom)
    local capture = map:update (dt)

    if capture ~= nil then
        cyclesSinceLastFail = cyclesSinceLastFail + 1
    end

    if map.stats.cells == 1 and map:getTickSpeed () < math.huge and capture ~= nil then
        lastCell = capture
    end

    -- Activate failsafe if all cells are dead
    if map.stats.cells <= 0 then
        print ("WARNING: Failsafe #" .. failsafeActivations .. " activated", os.date("%H:%M:%S - %Y-%m-%d"))
        print ("Number of available captures: " .. #captures)

        -- Add last surviving cell to captures list
        if lastCell ~= nil then
            table.insert (captures, 1, lastCell)
            table.remove (captures, maxCaptures + 1)
        end

        baseXInput = 1000000 * love.math.random()
        baseYInput = 1000000 * love.math.random()
        baseXBarriers = 1000000 * love.math.random()
        baseYBarriers = 1000000 * love.math.random()
        map:reset (mapSize, mapSize, mapInput, mapBarriers)

        local cellsSpawned = 0

        while cellsSpawned < math.min (failsafeSpawns, cell.maxCells) do
            for i = 1, #captures do
                local newCell = cell:newChild (captures[i])

                -- Heavily mutate cell
                for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, failsafeMutations.min, failsafeMutations.max)) do
                    cell:mutate (newCell)
                end

                -- print ("INFO:", i)
                -- cell:printCellInfo (newCell)
                -- cell:printCellScriptList (newCell)

                -- Attempt to spawn the cell
                if map:spawnCell (math.random (1, map.width), math.random (1, map.height), cellStartHealth, cellStartEnergy, newCell) == true then
                    cellsSpawned = cellsSpawned + 1

                    if cellsSpawned >= math.min (failsafeSpawns, cell.maxCells) then
                        break
                    end
                end
            end
        end

        failsafeActivations = failsafeActivations + 1
        cyclesSinceLastFail = 0
    end
end

function thisScene:draw ()
    love.graphics.setBackgroundColor (0, 0, 1, 1)

    if renderMap == true then
        map:draw (validModes[renderModeIndex])
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

    -- Show the number of cycles the current generation has survived
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 45, 95, 40)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Cycles:\n" .. cyclesSinceLastFail, 15, 50, 85, "left")

    -- Show number of cells
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 720, 10, 76, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Cells: " .. map.stats.cells, 725, 15, 100, "left")

    -- Show number of failsafe activations
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 720, 45, 76, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("FSs: " .. failsafeActivations, 725, 50, 100, "left")

    -- Shows the rendering mode
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 565, 100, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf (validModes[renderModeIndex] .. " mode", 15, 570, 100, "left")
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

    -- Toggle rendering
    elseif key == "z" then
        renderMap = not renderMap

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

    -- Changes the rendering mode
    elseif key == "m" then
        renderModeIndex = cycleValue (renderModeIndex, 1, #validModes)
    end
end

function thisScene:mousereleased (x, y, button)
    local tileX, tileY = map:screenToMap (x, y)
end

return thisScene