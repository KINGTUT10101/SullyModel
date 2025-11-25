local mapToScale = require ("Helpers.mapToScale")

local cellInputs = {}

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
    
    return mapToScale (map:getInputTile (itx, ity) or 0, map.inputBounds.min, map.inputBounds.max, -1, 1)
end

function cellInputs.getTileValue (tileX, tileY, cellObj, map)
    local itx, ity = map:getForwardPos (tileX, tileY, 1)
    
    return map:getEnvValue (itx, ity, "data") or -1
end

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

return cellInputs