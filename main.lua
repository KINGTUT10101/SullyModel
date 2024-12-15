-- Loads the libraries
local sceneMan = require("Libraries.sceneMan")
local lovelyToasts = require("Libraries.lovelyToasts")
local tux = require("Libraries.tux")

-- Declares / initializes the local variables



-- Declares / initializes the global variables
DevMode = false

-- Defines the functions



function love.load ()
	-- Sets up scenes for SceneMan
    sceneMan:newScene ("sandTest", require ("Scenes.sandTest"))

    sceneMan:push ("sandTest")
end


function love.update (dt)
	tux.callbacks.update(dt)
    sceneMan:event("update", dt)
    lovelyToasts.update(dt)
end


function love.draw ()
    sceneMan:event("draw")
    tux.callbacks.draw()
    sceneMan:event("lateDraw")
    lovelyToasts.draw()
end


function love.keypressed (key, scancode, isrepeat)
    sceneMan:event("keypressed", key, scancode, isrepeat)
end

function love.wheelmoved (x, y)
    sceneMan:event("wheelmoved", x, y)
end

function love.textinput(text)
    tux.callbacks.textinput(text)
end

function love.mousereleased(x, y, button)
    sceneMan:event("mousereleased", x, y, button)
end