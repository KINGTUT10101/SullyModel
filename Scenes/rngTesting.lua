local thisScene = {}
local sceneMan = require ("Libraries.sceneMan")
local mapToScale = require ("Helpers.mapToScale")

local function randomNumber ()
    return mapToScale (love.math.randomNormal () / 20, -3, 3, -1, 1)
end

function thisScene:load (...)
    
end

function thisScene:update (dt)
    
end

function thisScene:draw ()
    
end

function thisScene:keypressed (key, scancode, isrepeat)
	if key == "r" then
        print (randomNumber ())
    elseif key == "s" then
        for i = 1, 25 do
            print (randomNumber ())
        end
    end
end

function thisScene:mousereleased (x, y, button)

end

return thisScene