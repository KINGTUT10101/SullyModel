local clamp = require ("Libraries.lume").clamp
local round = require ("Libraries.lume").round
local mapToScale = require ("Helpers.mapToScale")

local mean = 8
local range = 10
local iterations = 1000

local sum = 0
for i = 1, iterations do
    local val = clamp (love.math.randomNormal (range / 2) + (range / 2), 0, range)
    sum = sum + val
    print (val)
end
print ()
print ("=====AVERAGE=====")
print (sum / iterations)
print ()