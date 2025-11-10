--- Recursively prints a table, including its data types, keys, and values.
--- Handles nested tables and avoids printing keys listed in a blacklist.
--- @param key any The key associated with the provided value. Defaults to the value itself if not provided.
--- @param value any The value associated with the provided key. Can be of any Lua type, including tables.
--- @param blacklist table<any, boolean|table>? A table containing keys to exclude from printing. Keys can map to:
--- - `boolean`: Exclude the key entirely when set to true.
--- - `table`: Sub-blacklist for recursive filtering.
--- @param prefix string? A string prefix used for indentation in recursive calls.
local function printTableRecur(key, value, blacklist, prefix)
    key = key or value
    blacklist = blacklist or {}
    prefix = prefix or ""

    -- Ensure the passed argument is always a valid table
    if blacklist[key] ~= true then
        if type(value) == "table" then
            print(prefix .. type(value), key, value)
            for childKey, childValue in pairs(value) do
                printTableRecur(childKey, childValue, (type(blacklist[key]) == "table") and blacklist[key] or {}, prefix .. "  ")
            end
        else
            print(prefix .. type(value), key, value)
        end
    end
end

--- Recursively prints a table, including its data types, keys, and values.
--- Handles nested tables and avoids printing keys listed in a blacklist.
--- @param tblToPrint table The table to print.
--- @param blacklist table<any, boolean|table>? A table containing keys to exclude from printing. Keys can map to:
--- - `boolean`: Exclude the key entirely when set to true.
--- - `table`: Sub-blacklist for recursive filtering.
local function printTable (tblToPrint, blacklist)
    printTableRecur ("PRINTED TABLE", tblToPrint, {blacklist}, "")
end

return printTable
