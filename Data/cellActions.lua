local mapToScale = require ("Helpers.mapToScale")

local cellActions = {}

local hyperArgs = {
    consume = {
        energyFromTile = 100,
        energyCost = 5,
    },
    applyDamage = {
        damage = 250,
        energyCost = 10,
    },
    stealEnergy = {
        energyGained = 50,
        energyCost = 7,
    },
    healSelf = {
        healing = 50,
        energyCost = 50,
    },
    energizeSelf = {
        energyTransferred = 50,
        healthCost = 50,
    },
    reproduce = {
        -- energyCost = 250,
        -- requiredTokens = 1,
    },
    reproduceExtra = {
        energyCost = 500,
    },
    createWall = {
        energyCost = 5,
    },
    shareEnergy = {
        sharedEnergy = 100,
        energyCost = 0,
    },
    placeEnergy = {
        sharedEnergy = 100,
        energyCost = 0,
    },
    solar = {
        maxThreshold = 0.25,
        minEnergy = -5,
        maxEnergy = 6
    },
}

local maxVote = 10
local minEnergyMulti, maxEnergyMulti = 0.75, 1.50
local alpha = 2.5

-- function cellActions.nothing (tileX, tileY, cellObj, map)
--     return
-- end

-- function cellActions.solar (tileX, tileY, cellObj, map)

-- end

-- function cellActions.votePos (tileX, tileY, cellObj, map)
--     cellObj.vote = math.min ((cellObj.vote or 0) + 1, maxVote)

--     return tileX, tileY
-- end

-- function cellActions.voteNeg (tileX, tileY, cellObj, map)
--     cellObj.vote = math.max ((cellObj.vote or 0) - 1, -maxVote)

--     return tileX, tileY
-- end

function cellActions.moveForward (tileX, tileY, cellObj, map)
    return map:moveForward (tileX, tileY)
end

function cellActions.turnLeft (tileX, tileY, cellObj, map)
    map:turnLeft (tileX, tileY)

    return tileX, tileY
end

function cellActions.turnRight (tileX, tileY, cellObj, map)
    map:turnRight (tileX, tileY)

    return tileX, tileY
end

local wasteMap = {
    meat = "waste",
    plants = "waste",
    waste = "plants",
}
function cellActions.consume (tileX, tileY, cellObj, map)
    local itx, ity = map:getForwardPos (tileX, tileY, 1)
    local origResources = map:getCellTotalResources (tileX, tileY)
    -- local origEnergy = cellObj.energy
    map:transferInputToCell (itx, ity, tileX, tileY, cellObj.consumes, hyperArgs.consume.energyFromTile, hyperArgs.consume.energyCost)
    -- if cellObj.energy - origEnergy > 0 then
    --     print ("===Energy change: " .. (cellObj.energy - origEnergy) .. "===")
    --     print (origEnergy .. "->" .. cellObj.energy)
    -- end

    cellObj.wasteBuffer = cellObj.wasteBuffer + (map:getCellTotalResources (tileX, tileY) - origResources)
    
    if cellObj.wasteBuffer >= map.cellManager.maxWasteBuffer then
        map:adjustInputTile (tileX, tileY, wasteMap[cellObj.consumes], cellObj.wasteBuffer)
        cellObj.wasteBuffer = 0
    end

    return tileX, tileY
end

-- function cellActions.consume (tileX, tileY, cellObj, map)
--     local itx, ity = map:getForwardPos (tileX, tileY, 1)
--     -- local origEnergy = cellObj.energy
--     local accuracy = cellObj.accuracy or 0
--     map:transferInputToCell (itx, ity, tileX, tileY, (minEnergyMulti + (maxEnergyMulti - minEnergyMulti) * (accuracy ^ alpha)) * hyperArgs.consume.energyFromTile, hyperArgs.consume.energyCost)
--     -- if cellObj.energy - origEnergy > 0 then
--     --     print ("===Energy change: " .. (cellObj.energy - origEnergy) .. "===")
--     --     print (origEnergy .. "->" .. cellObj.energy)
--     -- end

--     return tileX, tileY
-- end

function cellActions.applyDamage (tileX, tileY, cellObj, map)
    local enemyTileX, enemyTileY = map:getForwardPos (tileX, tileY, 1)

    if map:getCellTotalResources (tileX, tileY) > hyperArgs.applyDamage.energyCost then
        map:adjustCellEnergy (tileX, tileY, -hyperArgs.applyDamage.energyCost)
        map:adjustCellHealth (enemyTileX, enemyTileY, -hyperArgs.applyDamage.damage)
    end

    return tileX, tileY
end

-- function cellActions.stealEnergy (tileX, tileY, cellObj, map)
--     local enemyTileX, enemyTileY = map:getForwardPos (tileX, tileY, 1)

--     if map:getCellTotalResources (enemyTileX, enemyTileY) > hyperArgs.stealEnergy.energyGained and map:getCellTotalResources (tileX, tileY) > hyperArgs.stealEnergy.energyCost then
--         map:adjustCellEnergy (tileX, tileY, hyperArgs.stealEnergy.energyGained)
--         map:adjustCellEnergy (enemyTileX, enemyTileY, -hyperArgs.stealEnergy.energyGained)
--     end

--     return tileX, tileY
-- end

function cellActions.healSelf (tileX, tileY, cellObj, map)
    if map:getCellTotalResources (tileX, tileY) - hyperArgs.healSelf.energyCost > 0 then
        map:adjustCellEnergy (tileX, tileY, -hyperArgs.healSelf.energyCost)
        map:adjustCellHealth (tileX, tileY, hyperArgs.healSelf.healing)
    end

    return tileX, tileY
end

function cellActions.energizeSelf (tileX, tileY, cellObj, map)
    map:adjustCellHealth (tileX, tileY, -hyperArgs.energizeSelf.healthCost)
    if map:isTaken (tileX, tileY) == true then
        map:adjustCellEnergy (tileX, tileY, hyperArgs.energizeSelf.energyTransferred)
    end

    return tileX, tileY
end

-- -- Voting based reproduction method
-- function cellActions.reproduce (tileX, tileY, cellObj, map)
--     local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
--     local predTokens = cellObj.predTokens or 0
--     if predTokens >= hyperArgs.reproduce.requiredTokens and map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
--         local energyCost = cellObj.reproductionEnergy

--         if cellObj.energy + cellObj.health > energyCost then
--             if map:spawnCell (babyTileX, babyTileY, energyCost / 2, energyCost / 2, cellObj.superparent, cellObj) then
--                 map:adjustCellEnergy (tileX, tileY, -energyCost)
--                 cellObj.predTokens = predTokens - hyperArgs.reproduce.requiredTokens
--             end
--         end
--     end

--     return tileX, tileY
-- end

-- New reproduction method
function cellActions.reproduce (tileX, tileY, cellObj, map)
    local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
    if map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
        local energyCost = cellObj.reproductionEnergy

        if cellObj.energy + cellObj.health > energyCost + map.cellManager.baselineEnergy then
            if map:spawnCell (babyTileX, babyTileY, energyCost / 2, energyCost / 2, cellObj.superparent, cellObj) then
                map:adjustCellEnergy (tileX, tileY, -energyCost)

                -- TODO: Adjust total energy for parent and child
                -- cellObj.totalEnergy = cellObj.totalEnergy - hyperArgs.reproduce.energyCost
                -- map.cellGrid[babyTileX][babyTileY].totalEnergy = hyperArgs.reproduce.energyCost
            end
        end
    end

    return tileX, tileY
end

-- -- Old reproduction method
-- function cellActions.reproduce (tileX, tileY, cellObj, map)
--     local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
--     if map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
--         if cellObj.energy + cellObj.health > hyperArgs.reproduce.energyCost then
--             if map:spawnCell (babyTileX, babyTileY, hyperArgs.reproduce.energyCost / 2, hyperArgs.reproduce.energyCost / 2, cellObj.superparent, cellObj) then
--                 map:adjustCellEnergy (tileX, tileY, -hyperArgs.reproduce.energyCost)

--                 -- TODO: Adjust total energy for parent and child
--                 -- cellObj.totalEnergy = cellObj.totalEnergy - hyperArgs.reproduce.energyCost
--                 -- map.cellGrid[babyTileX][babyTileY].totalEnergy = hyperArgs.reproduce.energyCost
--             end
--         end
--     end

--     return tileX, tileY
-- end

-- function cellActions.reproduceExtra (tileX, tileY, cellObj, map)
--     local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
--     if map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
--         if cellObj.energy + cellObj.health > hyperArgs.reproduceExtra.energyCost then
--             map:adjustCellEnergy (tileX, tileY, -hyperArgs.reproduceExtra.energyCost)
--             map:spawnCell (babyTileX, babyTileY, hyperArgs.reproduceExtra.energyCost / 2, hyperArgs.reproduceExtra.energyCost / 2, cellObj.superparent, cellObj)

--             -- TODO: Adjust total energy for parent and child
--             -- cellObj.totalEnergy = cellObj.totalEnergy - hyperArgs.reproduceExtra.energyCost
--             -- map.cellGrid[babyTileX][babyTileY].totalEnergy = hyperArgs.reproduceExtra.energyCost
--         end
--     end

--     return tileX, tileY
-- end

-- function cellActions.createWall (tileX, tileY, cellObj, map)
--     local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
--     if map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
--         if cellObj.energy + cellObj.health > hyperArgs.createWall.energyCost then
--             map:adjustCellEnergy (tileX, tileY, -hyperArgs.createWall.energyCost)
--             map:spawnWall (babyTileX, babyTileY, hyperArgs.createWall.energyCost / 2, cellObj.superparent)
--         end
--     end

--     return tileX, tileY
-- end

-- function cellActions.shareEnergy (tileX, tileY, cellObj, map)
--     local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
--     map:shareInputToCell (tileX, tileY, otherTileX, otherTileY, hyperArgs.shareEnergy.sharedEnergy, hyperArgs.shareEnergy.energyCost)
-- end

function cellActions.placeEnergy (tileX, tileY, cellObj, map)
    local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
    
    if hyperArgs.placeEnergy.energyCost + hyperArgs.placeEnergy.sharedEnergy < map:getCellTotalResources (tileX, tileY) and hyperArgs.placeEnergy.energyCost + hyperArgs.placeEnergy.sharedEnergy < cellObj.totalEnergy then
        if map:adjustInputTile (otherTileX, otherTileY, cellObj.consumes, hyperArgs.placeEnergy.sharedEnergy) then
            map:adjustCellEnergy (tileX, tileY, -(hyperArgs.placeEnergy.energyCost + hyperArgs.placeEnergy.sharedEnergy))
            cellObj.totalEnergy = cellObj.totalEnergy - hyperArgs.placeEnergy.sharedEnergy
        end
    end

    return tileX, tileY
end

return cellActions