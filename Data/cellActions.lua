local mapToScale = require ("Helpers.mapToScale")

local cellActions = {}

local hyperArgs = {
    consume = {
        energyFromTile = 250,
        energyCost = 30,
        wasteThreshold = 200,
    },
    applyDamage = {
        damage = 1000,
        energyCost = 25,
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
        energyCost = 50,
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

-- WORKS
function cellActions.consume (tileX, tileY, cellObj, map)
    local itx, ity = map:getForwardPos (tileX, tileY, 1)
    
    local anyAtTile = (map:getInputTile (itx, ity, "any") or 0)
    local wasteAtTile = (map:getInputTile (itx, ity, "waste") or 0)
    local meatAtTile = (map:getInputTile (itx, ity, "meat") or 0)
    
    local canEat = false
    if anyAtTile > 0 or cellObj.consumes == "any" then
        canEat = true
    elseif cellObj.consumes == "waste" then
        canEat = true
    elseif cellObj.consumes == "plants" then
        -- Plant eaters cannot eat if there is too much meat
        canEat = meatAtTile < hyperArgs.consume.wasteThreshold
    elseif cellObj.consumes == "meat" then
        -- Meat eaters cannot eat if there is too much waste
        canEat = wasteAtTile < hyperArgs.consume.wasteThreshold
    end
    
    if canEat then
        local origResources = map:getCellTotalResources (tileX, tileY)
        map:transferInputToCell (itx, ity, tileX, tileY, cellObj.consumes, hyperArgs.consume.energyFromTile, hyperArgs.consume.energyCost)
    end

    return tileX, tileY
end

-- -- Voting based consumption method
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

-- WORKS
function cellActions.applyDamage (tileX, tileY, cellObj, map)
    local enemyTileX, enemyTileY = map:getForwardPos (tileX, tileY, 1)

    local damage = (cellObj.consumes == "meat") and hyperArgs.applyDamage.damage or math.ceil (hyperArgs.applyDamage.damage / 8)

    if map:getCellTotalResources (tileX, tileY) > hyperArgs.applyDamage.energyCost then
        -- print ("BEFORE:", map:getCellTotalResources (tileX, tileY), map:getCellTotalResources (enemyTileX, enemyTileY))
        -- print ("WASTE BUFFERS:", map.cellGrid[tileX][tileY].wasteBuffer, map.cellGrid[enemyTileX][enemyTileY].wasteBuffer)
        -- print ("TILES:", map:getInputTile (tileX, tileY, "meat"), map:getInputTile (enemyTileX, enemyTileY, "meat"))

        map:adjustCellEnergy (tileX, tileY, -hyperArgs.applyDamage.energyCost)

        if map:isTaken (enemyTileX, enemyTileY) == true then
            local enemyCell = map.cellGrid[enemyTileX][enemyTileY]
            local origEnemyHealth = enemyCell.health
            map:adjustCellHealth (enemyTileX, enemyTileY, -damage, false)

            -- Credit the environment with the exact health lost, even on kill
            local newHealth = math.max (enemyCell.health or 0, 0)
            local healthLost = origEnemyHealth - newHealth
            if healthLost > 0 then
                map:adjustInputTile (enemyTileX, enemyTileY, "meat", healthLost)
            end
        end
        -- print ("AFTER:", map:getCellTotalResources (tileX, tileY), map:getCellTotalResources (enemyTileX, enemyTileY))
        -- print ("WASTE BUFFERS:", map.cellGrid[tileX][tileY].wasteBuffer, map.cellGrid[enemyTileX][enemyTileY].wasteBuffer)
        -- print ("TILES:", map:getInputTile (tileX, tileY, "meat"), map:getInputTile (enemyTileX, enemyTileY, "meat"))
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

-- WORKS
function cellActions.healSelf (tileX, tileY, cellObj, map)
    if map:getCellEnergy (tileX, tileY) - hyperArgs.healSelf.energyCost > 0 then
        local energyUsed = math.min (hyperArgs.healSelf.energyCost, map.cellManager.maxHealth - cellObj.health) -- Calculate the exact energy needed to heal to full

        map:adjustCellEnergy (tileX, tileY, -energyUsed, false)
        map:adjustCellHealth (tileX, tileY, energyUsed, false)
    end

    return tileX, tileY
end

-- -- Not currently working with the new food system in term of energy stability, but it was kinda useless anyway
-- function cellActions.energizeSelf (tileX, tileY, cellObj, map)
--     map:adjustCellHealth (tileX, tileY, -hyperArgs.energizeSelf.healthCost)
--     if map:isTaken (tileX, tileY) == true then
--         map:adjustCellEnergy (tileX, tileY, hyperArgs.energizeSelf.energyTransferred)
--     end

--     return tileX, tileY
-- end

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

-- WORKS
-- New reproduction method
function cellActions.reproduce (tileX, tileY, cellObj, map)
    local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
    if map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
        local energyCost = cellObj.reproductionEnergy

        if cellObj.energy + cellObj.health > energyCost then
            if map:spawnCell (babyTileX, babyTileY, math.ceil (energyCost / 2), math.floor (energyCost / 2), cellObj.superparent, cellObj) then
                map:adjustCellEnergy (tileX, tileY, -energyCost, false)
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

-- WORKS
function cellActions.createWall (tileX, tileY, cellObj, map)
    local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
    if map.stats.walls[cellObj.superparent] < map.cellManager.maxWalls[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
        if cellObj.energy + cellObj.health > hyperArgs.createWall.energyCost then
            if map:spawnWall (babyTileX, babyTileY, hyperArgs.createWall.energyCost, cellObj.superparent) then
                map:adjustCellEnergy (tileX, tileY, -hyperArgs.createWall.energyCost, false)
            end
        end
    end

    return tileX, tileY
end

-- function cellActions.shareEnergy (tileX, tileY, cellObj, map)
--     local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
--     map:shareInputToCell (tileX, tileY, otherTileX, otherTileY, hyperArgs.shareEnergy.sharedEnergy, hyperArgs.shareEnergy.energyCost)

--     print (cellObj.energy, cellObj.health)

--     return tileX, tileY
-- end

-- WORKS
function cellActions.placeEnergy (tileX, tileY, cellObj, map)
    local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
    
    if hyperArgs.placeEnergy.energyCost + hyperArgs.placeEnergy.sharedEnergy < map:getCellTotalResources (tileX, tileY) then
        if map:adjustInputTile (otherTileX, otherTileY, cellObj.consumes, hyperArgs.placeEnergy.sharedEnergy) then
            map:adjustCellEnergy (tileX, tileY, -hyperArgs.placeEnergy.sharedEnergy, false)
            map:adjustCellEnergy (tileX, tileY, -hyperArgs.placeEnergy.energyCost)
        end
    end

    return tileX, tileY
end

return cellActions