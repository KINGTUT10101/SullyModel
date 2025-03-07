local function addLineNumbers (text)
    local numbered_text = {}
    local line_number = 1
    
    for line in text:gmatch("(.-)\n") do
        table.insert(numbered_text, string.format("%d: %s", line_number, line))
        line_number = line_number + 1
    end
    
    return table.concat(numbered_text, "\n")
end

return addLineNumbers