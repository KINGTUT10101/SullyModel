local mapToScale = require ("Helpers.mapToScale")

local cellInputs = {}

function cellInputs.energy (tileX, tileY, cellObj, map)
    return cellObj.energy
end

function cellInputs.health (tileX, tileY, cellObj, map)
    return cellObj.health
end

function cellInputs.age (tileX, tileY, cellObj, map)
    return cellObj.age
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
    return map:getCellTotalResources (map:getForwardPos (tileX, tileY, 1)) or 0
end

function cellInputs.getTileValue (tileX, tileY, cellObj, map)
    local itx, ity = map:getForwardPos (tileX, tileY, 1)
    
    return map:getInputTile (itx, ity) or 0
end

function cellInputs.isTaken (tileX, tileY, cellObj, map)
    return (map:isTaken (map:getForwardPos (tileX, tileY, 1))) and 1 or -1
end

local similarRating = 0.05
function cellInputs.isSimilar (tileX, tileY, cellObj, map)
    local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
    local allSimilar = false
    if map:isTaken (otherTileX, otherTileY) == true then
        local currCellColor = cellObj.color
        local otherCellColor = map.cellGrid[otherTileX][otherTileY].color

        allSimilar = true
        for i = 1, 3 do
            if math.abs (currCellColor[i] - otherCellColor[i]) > similarRating then
                allSimilar = false
            end
        end
    end
    return (allSimilar == true) and 1 or -1
end

function cellInputs.randomNumber (tileX, tileY, cellObj, map)
    return mapToScale (math.random (), 0, 1, -1, 1)
end

-- TODO
-- function cellInputs:getOtherDisplayVar (tileX, tileY, cellObj, map)
--     local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)

--     if map:isTaken (otherTileX, otherTileY) == true then
--         return map.cellGrid[otherTileX][otherTileY].displayVars[1]
--     end
-- end

-- TODO: variables

return cellInputs