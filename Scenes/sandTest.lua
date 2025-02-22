local thisScene = {}
local sceneMan = require ("Libraries.sceneMan")
local tux = require ("Libraries.tux")
local map = require ("Managers.map")
local cell = require ("Managers.cell")
local mapToScale = require ("Helpers.mapToScale")
local round = require ("Libraries.lume").round
local copyTable = require ("Helpers.copyTable")

local mapSize = 100

local camVelocity = 15
local zoomVelocity = 25

local testCell = cell:new (100, 100)

local maxCaptures = 25
local maxCaptureCycles = 500
local captureTimer = maxCaptureCycles
local captures = {} -- Holds the last 10 captures

local cyclesSinceLastFail = 0

local failsafeSpawns = 50
local failsafeActivations = -1
local lastCell = nil

local renderMap = true

local baseX = 1000000 * love.math.random()
local baseY = 1000000 * love.math.random()
local function mapInput (tileX, tileY)
    return mapToScale (love.math.noise(baseX+.05*tileX, baseY+.07*tileY), 0, 1, 0, 500)
end

function thisScene:load (...)
    cell:init (map)
    map:init (cell)
    map:reset (mapSize, mapSize, mapInput)
    map:setCamera (-110, -10, 5.8)
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

    -- Save cell to captures table
    -- if capture ~= nil then
    --     captureTimer = captureTimer - 1

    --     if captureTimer <= 0 then
    --         if capture ~= nil then
    --             table.insert (captures, 1, capture)
    --             table.remove (captures, maxCaptures)

    --             print ("INFO: Cell captured successfully")
    --             cell:printCellInfo (capture)
    --         else
    --             print ("WARNING: Capture failed", os.date("%H:%M:%S - %Y-%m-%d"))
    --             print ("Cells left: " .. map.stats.cells)
    --         end

    --         captureTimer = maxCaptureCycles
    --     end
    -- end

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

        baseX = 1000000 * love.math.random()
        baseY = 1000000 * love.math.random()
        map:reset (mapSize, mapSize, mapInput)

        local cellsSpawned = 0

        while cellsSpawned < failsafeSpawns do
            for i = 1, #captures do
                local newCell = copyTable (captures[i])

                -- Heavily mutate cell
                for i = 1, round (mapToScale (love.math.randomNormal (), 0, 1, 0, 50)) do
                    local mutCell = cell:new (100, 100)
                    cell:mutate (mutCell, newCell)
                    newCell = mutCell
                end

                cell:compileScript (newCell)

                -- print ("INFO:", i)
                -- cell:printCellInfo (newCell)
                -- cell:printCellScriptList (newCell)

                -- Attempt to spawn the cell
                if map:spawnCell (math.random (1, map.width), math.random (1, map.height), 500, 500, newCell) == true then
                    cellsSpawned = cellsSpawned + 1
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
        map:draw ()
    else
        -- Print message in the middle of the screen
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
    love.graphics.rectangle ("fill", 10, 45, 95, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Cycles: " .. cyclesSinceLastFail, 15, 50, 85, "left")

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
    -- Toggles map rendering
    if key == "p" then
        renderMap = not renderMap

    -- Prints an input tile's value
    elseif key == "i" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())

        if love.keyboard.isDown ("lshift") then
            print ("Input @ (" .. tileX .. ", " .. tileY .. "): " .. map:getInputTile (map:screenToMap (love.mouse.getPosition ())))
        else
            local cellToPrint = map:getCell (tileX, tileY)

            if cellToPrint ~= nil then
                if love.keyboard.isDown ("lctrl") == true then
                    cell:printCellScriptList (map:getCell (tileX, tileY))
                else
                    cell:printCellInfo (map:getCell (tileX, tileY))
                end
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
    end
end

function thisScene:mousereleased (x, y, button)
    local tileX, tileY = map:screenToMap (x, y)

    map:adjustInputTile (tileX, tileY, (button == 1) and 100 or -100)
    print (map:getInputTile (tileX, tileY))
end

return thisScene