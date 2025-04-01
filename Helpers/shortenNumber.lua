local function shortenNumber(number, maxDigits)
    maxDigits = maxDigits or 3  -- Default to 3 digits if not specified
    
    if type(number) ~= "number" then
        return tostring(number)  -- Return as-is if not a number
    end
    
    local isNegative = number < 0
    number = math.abs(number)
    
    local suffixes = {"", "K", "M", "B", "T"}
    local suffixIndex = 1
    
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    
    local formatted = string.format("%." .. (maxDigits - 1) .. "f", number)
    formatted = string.gsub(formatted, "%.?0+$", "")  -- Remove trailing zeros and decimal point
    
    if isNegative then
        return "-" .. formatted .. suffixes[suffixIndex]
    else
        return formatted .. suffixes[suffixIndex]
    end
end


return shortenNumber