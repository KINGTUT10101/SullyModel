local cellInputs = {}

function cellInputs.energy (tileX, tileY, cellObj, map)
    return cellObj.energy
end

function cellInputs.health (tileX, tileY, cellObj, map)
    return cellObj.health
end

return cellInputs