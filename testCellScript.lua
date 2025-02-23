-- An example of a scriptList attribute of a cell object
local exScriptList = {
    {
        id = "startScript",
        vars = 2,
        scope = {
            {
                id = "readInput",
                args = {
                    saveTo = "var1_1",
                },
            },
            {
                id = "addVariables",
                args = {
                    saveTo = "var1_1",
                    term1 = "var1_1",
                    term2 = "var1_2",
                },
            },
            {
                id = "ifStruct",
                args = {
                    term1 = "var1_1",
                    term2 = "var1_1",
                    op = "~=",
                },
                vars = 2,
                scope = {
                    {
                        id = "applyDamage",
                        args = {},
                    },
                    {
                        id = "isTaken",
                        args = {
                            assignTo = "var2_1"
                        },
                    },
                    {
                        id = "addVariables",
                        args = {
                            assignTo = "var1_2",
                            term1 = "var2_2",
                            term2 = "var2_1",
                        },
                    },
                },
            }
        }
    }
}

return exScriptList