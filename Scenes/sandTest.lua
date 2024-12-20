local thisScene = {}
local sceneMan = require ("Libraries.sceneMan")
local map = require ("Managers.map")
local cell = require ("Managers.cell")

local camVelocity = 15
local zoomVelocity = 25

local testCell = cell:new (100, 100)

function thisScene:load (...)
    cell:init (map)
    map:init (cell, "Test Map", 0, math.huge)
    map:reset (100, 100, {{1, 0.75, 0.25, 0, 0.25, 0.75, 1}})
    map:setCamera (nil, nil, 20)
    map:setTickSpeed (1/8)

    local cellScriptRecursive, cellScriptLinear, variables = loadfile ("testCellScript.lua") ()

    map:spawnCell (20, 20, 100, 100, {
        scriptList = cellScriptLinear,
        vars = variables,
        color = {1, 0, 0, 1},
        mutationRates = {
            major = 0.1,
            moderate = 0.1,
            minor = 0.1,
            meta = 0.1,
        }
    })
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

    map:setCamera (camX, camY, zoom)
    map:update (dt)
end

function thisScene:draw ()
    love.graphics.setBackgroundColor (0, 0, 1, 1)
    map:draw ()

    -- Show FPS
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 10, 35, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf (love.timer.getFPS (), 15, 15, 25, "center")
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
        for i = 1, 100 do
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
    end
end

function thisScene:mousereleased (x, y, button)
    local tileX, tileY = map:screenToMap (x, y)

    map:adjustInputTile (tileX, tileY, (button == 1) and 0.1 or -0.1)
    print (map:getInputTile (tileX, tileY))
end

return thisScene