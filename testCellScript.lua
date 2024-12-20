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
        hyperargs = {},
    },
    {
        id = "ifStruct",
        args = {
            "var1",
            "var3",
        },
        hyperargs = {
            ">"
        },
    },
    {
        id = "moveForward",
        args = {},
        hyperargs = {},
    },
    {
        id = "addVariables",
        args = {
            "var3",
            "var3",
            "var4",
        },
        hyperargs = {},
    },
    {
        id = "endStruct",
        args = {},
        hyperargs = {},
    }
}

-- Starting values for the variables
local variables = {
    4,
    62,
    0,
    1,
}

return cellScriptRecursive, cellScriptLinear, variables