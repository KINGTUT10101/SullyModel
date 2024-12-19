--- Increments a value by the provided amount.
--- If the new value is greater than the max, the value will wrap around to 1.
--- @param value integer
--- @param amount integer
--- @param max integer
--- @return integer newValue
local function cycleValue (value, amount, max)
    return (value + amount - 1) % max + 1
end

return cycleValue