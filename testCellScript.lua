-- An example of a scriptList attribute of a cell object
local exScriptList = {
    {
        id = "readInput",
        interDict = {
            saveTo = "var1"
        },
    },
    {
        id = "addVariables",
        interDict = {
            saveTo = "var0_1",
            term1 = "var0_1",
            term2 = "var1_4"
        },
    },
    {
        id = "ifStruct",
        interDict = {
            compTo = "var1"
        },
    },
}

return exScriptList