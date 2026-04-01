local mapToScale = require ("Helpers.mapToScale")

local cellInputs = {}
local consumableFoodTypes = {
    "meat",
    "plants",
    "waste",
    "any",
}

function cellInputs.energy (tileX, tileY, cellObj, map)
    return mapToScale (cellObj.energy, 0, map.cellManager.maxEnergy, -1, 1)
end

function cellInputs.health (tileX, tileY, cellObj, map)
    return mapToScale (cellObj.health, 0, map.cellManager.maxHealth, -1, 1)
end

function cellInputs.age (tileX, tileY, cellObj, map)
    return mapToScale (cellObj.ticksLeft, 0, cellObj.maxAge, -1, 1)
end

function cellInputs.verticalDir (tileX, tileY, cellObj, map)
    if cellObj.direction == 1 then
        return 1
    elseif cellObj.direction == 3 then
        return -1
    else
        return 0
    end
end

function cellInputs.horizontalDir (tileX, tileY, cellObj, map)
    if cellObj.direction == 2 then
        return 1
    elseif cellObj.direction == 4 then
        return -1
    else
        return 0
    end
end

function cellInputs.otherCellResources (tileX, tileY, cellObj, map)
    local maxResources = map.cellManager.maxEnergy + map.cellManager.maxHealth
    local otherCellResources = map:getCellTotalResources (map:getForwardPos (tileX, tileY, 1)) or 0

    return mapToScale (otherCellResources, 0, maxResources, -1, 1)
end

function cellInputs.getTileEnergy (tileX, tileY, cellObj, map)
    local itx, ity = map:getForwardPos (tileX, tileY, 1)
    local foodType = cellObj.consumes

    if foodType == "any" then
        local totalInput = 0
        local minInput = 0
        local maxInput = 0

        for i = 1, #consumableFoodTypes do
            local currFoodType = consumableFoodTypes[i]
            local bounds = map.inputBounds[currFoodType]
            if bounds ~= nil then
                totalInput = totalInput + (map:getInputTile (itx, ity, currFoodType) or 0)
                minInput = minInput + bounds.min
                maxInput = maxInput + bounds.max
            end
        end

        return mapToScale (totalInput, minInput, maxInput, -1, 1)
    end
    
    return mapToScale (map:getInputTile (itx, ity, foodType) or 0, map.inputBounds[foodType].min, map.inputBounds[foodType].max, -1, 1)
end

-- function cellInputs.getTileValue (tileX, tileY, cellObj, map)
--     local itx, ity = map:getForwardPos (tileX, tileY, 1)
    
--     return map:getEnvValue (itx, ity, "data") or -1
-- end

function cellInputs.isTaken (tileX, tileY, cellObj, map)
    return (map:isTaken (map:getForwardPos (tileX, tileY, 1))) and 1 or -1
end

-- local similarRating = 0.05
-- function cellInputs.isSimilar (tileX, tileY, cellObj, map)
--     local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
--     local allSimilar = false
--     if map:isTaken (otherTileX, otherTileY) == true then
--         local currCellColor = cellObj.color
--         local otherCellColor = map.cellGrid[otherTileX][otherTileY].color

--         allSimilar = true
--         for i = 1, 3 do
--             if math.abs (currCellColor[i] - otherCellColor[i]) > similarRating then
--                 allSimilar = false
--             end
--         end
--     end
--     return (allSimilar == true) and 1 or -1
-- end

function cellInputs.isSameSpecies (tileX, tileY, cellObj, map)
    local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)

    if map:isTaken (otherTileX, otherTileY) == true then
        local otherCellObj = map.cellGrid[otherTileX][otherTileY]

        return (cellObj.superparent == otherCellObj.superparent) and 1 or -1
    end

    return 0
end

function cellInputs.randomNumber (tileX, tileY, cellObj, map)
    return mapToScale (math.random (), 0, 1, -1, 1)
end

function cellInputs.getPosX (tileX, tileY, cellObj, map)
    return mapToScale (tileX, 1, map.width, -1, 1)
end

function cellInputs.getPosY (tileX, tileY, cellObj, map)
    return mapToScale (tileY, 1, map.height, -1, 1)
end

return cellInputs