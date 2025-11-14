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
    healSelf = {
        healing = 50,
        energyCost = 50,
    },
    energizeSelf = {
        energyTransferred = 50,
        healthCost = 50,
    },
    reproduce = {
        energyCost = 500,
    },
    reproduceExtra = {
        energyCost = 750,
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
}

-- function cellActions.nothing (tileX, tileY, cellObj, map)
--     return
-- end

function cellActions.moveForward (tileX, tileY, cellObj, map)
    map:moveForward (tileX, tileY)
end

function cellActions.turnLeft (tileX, tileY, cellObj, map)
    map:turnLeft (tileX, tileY)
end

function cellActions.turnRight (tileX, tileY, cellObj, map)
    map:turnRight (tileX, tileY)
end

function cellActions.consume (tileX, tileY, cellObj, map)
    local itx, ity = map:getForwardPos (tileX, tileY, 1)
    -- local origEnergy = cellObj.energy
    map:transferInputToCell (itx, ity, cellObj, hyperArgs.consume.energyFromTile, hyperArgs.consume.energyCost)
    -- if cellObj.energy - origEnergy > 0 then
    --     print ("===Energy change: " .. (cellObj.energy - origEnergy) .. "===")
    --     print (origEnergy .. "->" .. cellObj.energy)
    -- end
end

function cellActions.applyDamage (tileX, tileY, cellObj, map)
    local enemyTileX, enemyTileY = map:getForwardPos (tileX, tileY, 1)
    map:adjustCellEnergy (tileX, tileY, -hyperArgs.applyDamage.energyCost)
    map:adjustCellHealth (enemyTileX, enemyTileY, -hyperArgs.applyDamage.damage)
end

function cellActions.healSelf (tileX, tileY, cellObj, map)
    if map:getCellTotalResources (tileX, tileY) - hyperArgs.healSelf.energyCost > 0 then
        map:adjustCellEnergy (tileX, tileY, -hyperArgs.healSelf.energyCost)
        map:adjustCellHealth (tileX, tileY, hyperArgs.healSelf.healing)
    end
end

function cellActions.energizeSelf (tileX, tileY, cellObj, map)
    map:adjustCellHealth (tileX, tileY, -hyperArgs.energizeSelf.healthCost)
    if map:isTaken (tileX, tileY) == true then
        map:adjustCellEnergy (tileX, tileY, hyperArgs.energizeSelf.energyTransferred)
    end
end

function cellActions.reproduce (tileX, tileY, cellObj, map)
    local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
    if map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
        if cellObj.energy + cellObj.health > hyperArgs.reproduce.energyCost then
            -- local origResources = map:getCellTotalResources (tileX, tileY)

            map:adjustCellEnergy (tileX, tileY, -hyperArgs.reproduce.energyCost)
            map:spawnCell (babyTileX, babyTileY, hyperArgs.reproduce.energyCost / 2, hyperArgs.reproduce.energyCost / 2, cellObj.superparent, cellObj)

            -- print ("NORMAL:", origResources .. "->" .. map:getCellTotalResources (tileX, tileY))
            -- print ("Reproduce success!!")
            -- print (tileX, tileY, babyTileX, babyTileY)
        else
            -- print ("Reproduce failed energy:", cellObj.energy + cellObj.health > hyperArgs.reproduce.energyCost)
            -- print (cellObj.energy + cellObj.health, hyperArgs.reproduce.energyCost)
            -- print (tileX, tileY, babyTileX, babyTileY)
        end
    else
        -- print ("Reproduce failed init:", map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent], map:isClear (babyTileX, babyTileY) == true)
        -- print (tileX, tileY, babyTileX, babyTileY)
    end
end

function cellActions.reproduceExtra (tileX, tileY, cellObj, map)
    local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
    if map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
        if cellObj.energy + cellObj.health > hyperArgs.reproduceExtra.energyCost then
            -- local origResources = map:getCellTotalResources (tileX, tileY)

            map:adjustCellEnergy (tileX, tileY, -hyperArgs.reproduceExtra.energyCost)
            map:spawnCell (babyTileX, babyTileY, hyperArgs.reproduceExtra.energyCost / 2, hyperArgs.reproduceExtra.energyCost / 2, cellObj.superparent, cellObj)

            -- print ("EXTRA:", origResources .. "->" .. map:getCellTotalResources (tileX, tileY))
            -- print ("Reproduce extra success!!")
            -- print (tileX, tileY, babyTileX, babyTileY)
        else
            -- print ("Reproduce extra failed energy:", cellObj.energy + cellObj.health > hyperArgs.reproduceExtra.energyCost)
            -- print (cellObj.energy + cellObj.health, hyperArgs.reproduceExtra.energyCost)
            -- print (tileX, tileY, babyTileX, babyTileY)
        end
    else
        -- print ("Reproduce extra failed init:", map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent], map:isClear (babyTileX, babyTileY) == true)
        -- print (tileX, tileY, babyTileX, babyTileY)
    end
end

function cellActions.createWall (tileX, tileY, cellObj, map)
    local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
    if map.stats.cells[cellObj.superparent] < map.cellManager.maxCells[cellObj.superparent] and map:isClear (babyTileX, babyTileY) == true then
        if cellObj.energy + cellObj.health > hyperArgs.createWall.energyCost then
            map:adjustCellEnergy (tileX, tileY, -hyperArgs.createWall.energyCost)
            map:spawnWall (babyTileX, babyTileY, hyperArgs.createWall.energyCost / 2, cellObj.superparent)
        end
    end
end

function cellActions.shareEnergy (tileX, tileY, cellObj, map)
    local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
    map:shareInputToCell (tileX, tileY, otherTileX, otherTileY, hyperArgs.shareEnergy.sharedEnergy, hyperArgs.shareEnergy.energyCost)
end

function cellActions.placeEnergy (tileX, tileY, cellObj, map)
    local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
    
    if hyperArgs.placeEnergy.energyCost < map:getCellTotalResources (tileX, tileY) then
        map:adjustCellEnergy (tileX, tileY, -(hyperArgs.placeEnergy.energyCost + hyperArgs.placeEnergy.sharedEnergy))
        map:adjustInputTile (otherTileX, otherTileY, hyperArgs.placeEnergy.sharedEnergy)
    end
end

return cellActions