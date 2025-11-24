
local seed = os.time ()
math.randomseed (seed)

print ("Seed: " .. type (seed) .. " " .. seed)

-- Append the numeric seed to a file in the save directory
local filename = "seeds.txt"
local prev, readErr = love.filesystem.read(filename)
local timestamp = os.date("%Y-%m-%d %H:%M:%S")
local entry = string.format("%s - %s\n", timestamp, tostring(seed))
local contents = (prev or "") .. entry
local ok, writeErr = love.filesystem.write(filename, contents)
if not ok then
    print("Failed to append seed to " .. filename .. ": " .. tostring(writeErr))
else
    print("Seed appended to " .. filename .. " (" .. timestamp .. ")")
end
print ()

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
    -- sceneMan:newScene ("rngTesting", require ("Scenes.rngTesting"))

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