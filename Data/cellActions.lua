local cellActions = {}

function cellActions.moveForward (tileX, tileY, cellObj, map)
    map:moveForward (tileX, tileY)
end

return cellActions