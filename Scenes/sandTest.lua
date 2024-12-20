local thisScene = {}
local sceneMan = require ("Libraries.sceneMan")
local map = require ("Managers.map")
local cell = require ("Managers.cell")
local mapToScale = require ("Helpers.mapToScale")
local round = require ("Libraries.lume").round

local mapSize = 100

local camVelocity = 15
local zoomVelocity = 25

local testCell = cell:new (100, 100)

local maxCaptureTimer = 120
local captureTimer = maxCaptureTimer
local captures = {} -- Holds the last 10 captures
local failsafeActivations = -1

local superSpeed = false

function thisScene:load (...)
    cell:init (map)
    map:init (cell, "Test Map", 0, 1000)
    map:reset (mapSize, mapSize, {{100, 750, 250, 0, 250, 750, 1000}})
    map:setCamera (nil, nil, 20)
    map:setTickSpeed (1/8)

    captures[1] = cell:new (100, 100)
end

function thisScene:update (dt)
    if love.keyboard.isDown ("lshift") and love.keyboard.isDown ("b") then
        local newCell = cell:new (100, 100)
        cell:mutate (newCell, testCell)
        cell:compileScript (newCell)
        testCell = newCell

        for k, v in pairs (testCell) do
            print (k, v)
            if type (v) == "table" then
                for k, v in pairs (v) do
                    print ("    ", k, v)
                end
            end
        end
        print ()
    end

    local camX, camY, zoom = map:getCamera ()

    if love.keyboard.isDown("w") then
        camY = camY - camVelocity * dt * zoom
    elseif love.keyboard.isDown("s") then
        camY = camY + camVelocity * dt * zoom
    end

    if love.keyboard.isDown("a") then
        camX = camX - camVelocity * dt * zoom
    elseif love.keyboard.isDown("d") then
        camX = camX + camVelocity * dt * zoom
    end

    if love.keyboard.isDown("q") then
        zoom = zoom - zoomVelocity * dt
    elseif love.keyboard.isDown("e") then
        zoom = zoom + zoomVelocity * dt
    end

    -- Update map and camera
    map:setCamera (camX, camY, zoom)
    local capture = map:update (dt)

    -- Save cell to captures table
    captureTimer = captureTimer - dt
    if captureTimer <= 0 then
        if capture ~= nil then
            table.insert (captures, 1, capture)
            table.remove (captures, 11)

            cell:printCellInfo (capture)
        else
            print ("WARNING: Capture failed", os.date("%H:%M:%S - %Y-%m-%d"))
            print ("Cells left: " .. map.stats.cells)
        end

        captureTimer = maxCaptureTimer
    end

    -- Activate failsafe if all cells are dead
    if map.stats.cells <= 0 then
        local cellsSpawned = 0

        while cellsSpawned < 10 do
            for i = 1, #captures do
                local selectedCell = captures[i]

                -- Heavily mutate cell
                for i = 1, round (mapToScale (love.math.randomNormal (), 0, 1, 0, 50)) do
                    local newCell = cell:new (100, 100)
                    cell:mutate (newCell, testCell)
                    cell:compileScript (newCell)
                    testCell = newCell
                end

                -- Attempt to spawn the cell
                if map:spawnCell (math.random (1, map.width), math.random (1, map.height)) == true then
                    cellsSpawned = cellsSpawned + 1
                end
            end
        end

        failsafeActivations = failsafeActivations + 1
        print ("WARNING: Failsafe activated", os.date("%H:%M:%S - %Y-%m-%d"))
    end
end

function thisScene:draw ()
    love.graphics.setBackgroundColor (0, 0, 1, 1)
    map:draw ()

    -- Super speed border
    if superSpeed == true then
        love.graphics.setColor (0, 1, 0, 1)
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
end

function thisScene:keypressed (key, scancode, isrepeat)
    -- Mutate test cell
    if key == "m" then
        local newCell = cell:new (100, 100)
        cell:mutate (newCell, testCell)
        cell:compileScript (newCell)
        testCell = newCell

        for k, v in pairs (testCell) do
            print (k, v)
            if type (v) == "table" then
                for k, v in pairs (v) do
                    print ("    ", k, v)
                end
            end
        end
        print ()

    -- Rapidly mutate the cell
    elseif key == "n" then
        for i = 1, 25 do
            local newCell = cell:new (100, 100)
            cell:mutate (newCell, testCell)
            cell:compileScript (newCell)
            testCell = newCell
        end

        for k, v in pairs (testCell) do
            print (k, v)
            if type (v) == "table" then
                for k, v in pairs (v) do
                    print ("    ", k, v)
                end
            end
        end
        print ()

    -- Reset test cell
    elseif key == "l" then
        testCell = cell:new (100, 100)

    -- Spawn test cell in the map
    elseif key == "p" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())

        map:spawnCell (tileX, tileY, 100, 100, testCell)
        print ("Cell spawned at :", tileX, tileY)
    
    -- Kills  a cell in the map
    elseif key == "k" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())
        map:deleteCell (tileX, tileY)

    -- Prints an input tile's value
    elseif key == "i" then
        print (map:getInputTile (map:screenToMap (love.mouse.getPosition ())))
    
    -- Toggles superspeed
    elseif key == "tab" then
        superSpeed = not superSpeed

        if superSpeed == true then
            map:setTickSpeed (0)
        else
            map:setTickSpeed (1/8)
        end
    end
end

function thisScene:mousereleased (x, y, button)
    local tileX, tileY = map:screenToMap (x, y)

    map:adjustInputTile (tileX, tileY, (button == 1) and 100 or -100)
    print (map:getInputTile (tileX, tileY))
end

return thisScene