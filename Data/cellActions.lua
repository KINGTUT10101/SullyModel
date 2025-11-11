local cellActions = {}

local hyperArgs = {
    consume = {
        energyFromTile = 25,
        energyCost = 2,
    },
    applyDamage = {
        damage = 5,
        energyCost = 2,
    },
    healSelf = {
        healing = 10,
        energyCost = 12,
    },
    energizeSelf = {
        energyTransferred = 12,
        healthCost = 12,
    },
    reproduce = {
        energyCost = 500,
    },
    createWall = {
        energyCost = 100,
    },
    shareEnergy = {
        sharedEnergy = 25,
        energyCost = 3,
    }
}

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
    local origEnergy = cellObj.energy
    map:transferInputToCell (itx, ity, cellObj, hyperArgs.consume.energyFromTile, hyperArgs.consume.energyCost)
    -- if cellObj.energy - origEnergy > 0 then
    --     print ("Energy change: " .. (cellObj.energy - origEnergy))
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
    if map.stats.cells < map.cellManager.maxCells and map:isClear (babyTileX, babyTileY) == true then
        if cellObj.energy + cellObj.health > hyperArgs.reproduce.energyCost then
            map:adjustCellEnergy (tileX, tileY, -hyperArgs.reproduce.energyCost)
            map:spawnCell (babyTileX, babyTileY, hyperArgs.reproduce.energyCost / 2, hyperArgs.reproduce.energyCost / 2, cellObj)
        end
    end
end

function cellActions.createWall (tileX, tileY, cellObj, map)
    local babyTileX, babyTileY = map:getForwardPos (tileX, tileY, 1)
    if map.stats.cells < map.cellManager.maxCells and map:isClear (babyTileX, babyTileY) == true then
        if cellObj.energy + cellObj.health > hyperArgs.createWall.energyCost then
            map:adjustCellEnergy (tileX, tileY, -hyperArgs.createWall.energyCost)
            map:spawnWall (babyTileX, babyTileY, hyperArgs.createWall.energyCost / 2)
        end
    end
end

function cellActions.shareEnergy (tileX, tileY, cellObj, map)
    local otherTileX, otherTileY = map:getForwardPos (tileX, tileY, 1)
    map:shareInputToCell (tileX, tileY, otherTileX, otherTileY, hyperArgs.shareEnergy.sharedEnergy, hyperArgs.shareEnergy.energyCost)
end

-- TODO Set display var

return cellActions