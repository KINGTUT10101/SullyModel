local thisScene = {}
local sceneMan = require ("Libraries.sceneMan")
local map = require ("Managers.map")

local camVelocity = 15
local zoomVelocity = 25

function thisScene:load (...)
    map:init ("Test Map")
    map:reset (100, 100, {{1, 0.75, 0.25, 0, 0.25, 0.75, 1}})
    map:setCamera (nil, nil, 20)
end

function thisScene:update (dt)
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
	
end

function thisScene:mousereleased (x, y, button)
    local tileX, tileY = map:screenToMap (x, y)

    map:incrInputTile (tileX, tileY, (button == 1) and 0.1 or -0.1)
    print (map:getInputTile (tileX, tileY))
end

return thisScene