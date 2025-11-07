local actFuncs = {}

function actFuncs.relu (n)
    return math.max(0, n)
end

return actFuncs