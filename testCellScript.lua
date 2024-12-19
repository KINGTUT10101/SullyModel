-- Behavior script for the cell
local cellScriptRecursive = {
    {
        id = "readInput",
        args = {
            2,
        },
    },
    {
        id = "ifStruct",
        args = {
            1,
            3,
        },
        hyperargs = {
            2,
        },
        scope = {
            {
                id = "reproduce",
            }
        },
    },
}

local cellScriptLinear = {
    {
        id = "readInput",
        args = {
            "var2",
        },
    },
    {
        id = "ifStruct",
        args = {
            "var1",
            "var3",
        },
        hyperargs = {
            "=="
        },
    },
    {
        id = "reproduce",
    },
    {
        id = "endStruct",
        startScope = 2,
    }
}

-- Starting values for the variables
local variables = {
    42,
    62,
    0,
    77,
}

return cellScriptRecursive, cellScriptLinear, variables