-- Collection of activation functions and lightweight factories.
-- Each function takes a single numeric argument and returns a transformed value.
-- For parametric activations (leaky ReLU, ELU) we provide factories that
-- capture the parameter and return a 1-arg function suitable for neuron use.

local actFuncs = {}

-- Identity (no-op) – useful for input or output (logit) layers
function actFuncs.identity(n)
    return n
end

-- Standard ReLU
function actFuncs.relu(n)
    return math.max (0, n)
end

-- Leaky ReLU factory (default alpha=0.05) – mitigates dying ReLU problem
function actFuncs.leaky(alpha)
    alpha = alpha or 0.05
    return function(n)
        return (n > 0) and n or alpha * n
    end
end

-- ELU factory (Exponential Linear Unit) – smooth for n < 0
function actFuncs.elu(alpha)
    alpha = alpha or 1.0
    return function(n)
        return (n >= 0) and n or (alpha * (math.exp(n) - 1))
    end
end

-- Sigmoid – squashes to (0,1); can saturate for large |n|
function actFuncs.sigmoid(n)
    -- Guard against overflow (not usually needed in Lua, but safe)
    if n < -60 then return 0 end
    if n > 60 then return 1 end
    return 1 / (1 + math.exp(-n))
end

-- Tanh – centered at 0, range (-1,1)
function actFuncs.tanh(n)
    -- math.tanh added in LuaJIT; if unavailable, approximate
    if math.tanh then
        return math.tanh(n)
    else
        local e2x = math.exp(2 * n)
        return (e2x - 1) / (e2x + 1)
    end
end

-- Softplus – smooth ReLU approximation: log(1+e^n)
function actFuncs.softplus(n)
    if n > 60 then return n end -- avoid overflow
    return math.log(1 + math.exp(n))
end

return actFuncs