local thisScene = {}
local map = require ("Managers.map")
local cell = require ("Managers.cell")
local mapToScale = require ("Helpers.mapToScale")
local round = require ("Libraries.lume").round
local copyTable = require ("Helpers.copyTable")
local cellActions = require ("Data.cellActions")
local shortenNumber = require ("Helpers.shortenNumber")

local mapSize = 25

local camVelocity = 15
local zoomVelocity = 25

local testCell = cell:new (100, 100)

local maxCaptures = 500
local maxCaptureCycles = 10000
local captureTimer = maxCaptureCycles
local captures = {} -- Holds the last 10 captures

local cyclesSinceLastFail = 0

local failsafeSpawns = 625
local failsafeActivations = -1
local lastCell = nil

local renderMap = true

local newPercent = 0.00
local replacementPercent = 0.15
local datasetRatio = 0.5
local predRatio = 0.5
local shuffles = 4
local batchSize = 1
local predsSinceLastReset = 0
local attemptPreds = {
    pos = 0,
    neg = 0,
    total = 0,
}

local rewardEnergy = 100
local punishHealth = 250
local predRetries = 0
local cyclesPerPred = 750
local predTimer = cyclesPerPred
local confusionMatrix = {
    tp = 0,
    fp = 0,
    fn = 0,
    tn = 0,
}
local currLabel = 1 -- 1 = wide, -1 = tall

local function createInputMapper ()
    local rectX1, rectY1 = math.random (1, math.floor (mapSize / 2)), math.random (1, math.floor (mapSize / 2))
    local rectX2, rectY2 = mapSize - math.random (0, math.floor (mapSize / 2)), mapSize - math.random (0, math.floor (mapSize / 2))

    -- Adjust tall/wide chance based on predRatio
    -- predRatio is the fraction of positive predictions
    -- So, chance of negative label = predRatio, chance of positive label = 1 - predRatio
    if math.random() < predRatio then
        -- Make tall rectangle (negative label)
        if rectX2 - rectX1 > rectY2 - rectY1 then
            -- Swap to make tall
            local mid = math.floor((rectX1 + rectX2) / 2)
            rectX2 = mid
        end
        currLabel = -1
    else
        -- Make wide rectangle (positive label)
        if rectY2 - rectY1 > rectX2 - rectX1 then
            -- Swap to make wide
            local mid = math.floor((rectY1 + rectY2) / 2)
            rectY2 = mid
        end
        currLabel = 1
    end

    local function mapInputRect (tileX, tileY)
        if tileX >= rectX1 and tileX <= rectX2 and tileY >= rectY1 and tileY <= rectY2 then
            return 100
        else
            return -100
        end
    end

    return mapInputRect
end

local function calcTotalPreds ()
    return confusionMatrix.tp + confusionMatrix.fp + confusionMatrix.fn + confusionMatrix.tn
end

local function calcAccuracy ()
    local total = calcTotalPreds ()
    local accuracy = (confusionMatrix.tp + confusionMatrix.tn) / total

    datasetRatio = (confusionMatrix.tp + confusionMatrix.fn) / total
    predRatio = (confusionMatrix.tp + confusionMatrix.fp) / total

    return (accuracy ~= accuracy) and 0 or accuracy
end

-- Rewards/punishes each cell after a prediction
local function rewardCell (tileX, tileY, cellObj)
    -- map:adjustCellEnergy (tileX, tileY, rewardEnergy * mapToScale (calcAccuracy (), 0, 1, 0, 2))
    cellObj.correct = cellObj.correct + 1
    cellObj.lastCorrect = true
end
local function punishCell (tileX, tileY, cellObj)
    if confusionMatrix.fn + confusionMatrix.fp > predRetries then
        -- map:adjustCellEnergy (tileX, tileY, -punishHealth * -mapToScale (1 - calcAccuracy (), 0, 1, 0, 2))
    end

    cellObj.lastCorrect = false
end

local cellList = {}
local posCellList = {}
local negCellList = {}
local function replaceCells(list)
    local endIndex = math.ceil(#list * (replacementPercent + newPercent))
    local listLength = #list

    for i = 1, endIndex do
        if i < math.ceil (#list * newPercent) then
            local newCellObj = cell:new(cell.maxEnergy, cell.maxHealth)

            -- Heavily mutate cell
            for i = 1, round(mapToScale(love.math.randomNormal(), -0.5, 3, 0, 500)) do
                local mutCell = cell:new(cell.maxEnergy, cell.maxHealth)
                cell:mutate(mutCell, newCellObj)
                newCellObj = mutCell
            end

            while map:spawnCell(math.random(1, map.width), math.random(1, map.height), cell.maxHealth, cell.maxEnergy, newCellObj) do end
        else
            local cellDataGood = list[listLength - (i - 1)]
            local cellDataBad = list[i]

            map:deleteCell(cellDataBad.tileX, cellDataBad.tileY)
            while map:spawnCell(math.random(1, map.width), math.random(1, map.height), cell.maxHealth, cell.maxEnergy, cellDataGood.cellObj) do end
        end
    end
end

local function replaceCellInList (list)
    for i = 1, shuffles do
        local partialCellList = {}

        local iters = math.ceil (#list / shuffles)
        for i = 1, iters do
            table.insert (partialCellList, table.remove (list, math.random (1, #list)))
        end
        table.sort(partialCellList, function(cellData1, cellData2)
            local cellObj1 = cellData1.cellObj
            local cellObj2 = cellData2.cellObj

            local accuracy1 = cellObj1.correct / cellObj1.total
            local accuracy2 = cellObj2.correct / cellObj2.total

            local predRatioDiff1 = math.abs (datasetRatio - (cellObj1.positivePreds / cellObj1.total))
            local predRatioDiff2 = math.abs (datasetRatio - (cellObj2.positivePreds / cellObj2.total))

            local total1 = cellObj1.total
            local total2 = cellObj2.total

            if cellObj2.lastCorrect ~= cellObj1.lastCorrect then
                return cellObj2 == true
            elseif accuracy2 ~= accuracy1 then
                return accuracy2 > accuracy1
            elseif predRatioDiff2 ~= predRatioDiff1 then
                return predRatioDiff2 < predRatioDiff1
            else
                return total2 > total1
            end
        end)
        replaceCells (partialCellList)
    end
end

local function treatCell (tileX, tileY, cellObj)
    if math.random () >= 0.20 then
        local multi = math.random (0, 5)
        map.currPred = map.currPred - cellObj.contributions + cellObj.contributions * multi
        cellObj.contributions = cellObj.contributions * multi
    end

    attemptPreds.total = attemptPreds.total + 1

    if cellObj.contributions > 0 then
        cellObj.positivePreds = cellObj.positivePreds + 1
        attemptPreds.pos = attemptPreds.pos + 1

        if currLabel > 0 then
            rewardCell (tileX, tileY, cellObj) -- True positive
        else
            punishCell (tileX, tileY, cellObj) -- False positive
        end

        table.insert (posCellList, {
            cellObj = cellObj,
            tileX = tileX,
            tileY = tileY,
        })
    else
        attemptPreds.neg = attemptPreds.neg + 1

        if currLabel < 0 then
            rewardCell (tileX, tileY, cellObj) -- True negative
        else
            punishCell (tileX, tileY, cellObj) -- False negative
        end

        table.insert (negCellList, {
            cellObj = cellObj,
            tileX = tileX,
            tileY = tileY,
        })
    end

    cellObj.lastContribution = cellObj.contributions
    cellObj.contributions = 0
    cellObj.total = cellObj.total + 1

    for i = cell.scriptVars + 1, cell.scriptVars + cell.memVars do
        cellObj.vars[i] = 0
    end

    table.insert (cellList, {
        cellObj = cellObj,
        tileX = tileX,
        tileY = tileY,
    })
end

local baseXInput = 1000000 * love.math.random()
local baseYInput = 1000000 * love.math.random()
local function mapInput (tileX, tileY)
    -- if math.random () < 0.002 then
    --     return math.huge
    -- else
        return mapToScale (love.math.noise(baseXInput+.05*tileX, baseYInput+.02*tileY), 0, 1, 0, 500)
    -- end
end

local baseXBarriers = 1000 * love.math.random()
local baseYBarriers = 1000 * love.math.random()
local function mapBarriers (tileX, tileY)
    return (love.math.noise(baseXBarriers+.03*tileX, baseYBarriers+.1*tileY) > 0.85) and "barrier" or "blank"
end

function thisScene:load (...)
    cell:init (map, cellActions.actionDefs, cellActions.scriptPrefixes, {
        maxCells = 500,
        maxActions = 15,
        dropEnergy = false,
        scriptVars = 3,
        memVars = 2,
        displayVars = 1,
        globalVars = 2,
        cellAge = {
            min = math.huge,
            max = math.huge,
        },
        tickCost = 0,
        maxEnergy = 10000,
        hyperargs = {
            moveForward = {
                energyCost = 0,
            },
            -- reproduce = {
            --     energyCost = 1000,
            --     babyEnergy = 500,
            --     babyHealth = 500,
            -- },
            -- applyDamage = {
            --     energyCost = 0,
            -- },
        },
    })
    map:init (cell, {
        inputBounds = {
            min = -100,
            max = 100,
        },
        drawBounds = {
            min = -100,
            max = 100,
        }
    })
    map:reset (mapSize, mapSize, true, createInputMapper ())
    map:setCamera (-110, -10, 5.8)
    map:setTickSpeed (math.huge)

    -- Adds a few heavily mutated cells to the initial captures list
    for i = 1, maxCaptures do
        local newCellObj = cell:new (cell.maxEnergy, cell.maxHealth)

        newCellObj.mutationRates.major = 0.35
        newCellObj.mutationRates.moderate = 0.30
        newCellObj.mutationRates.minor = 0.20
        newCellObj.mutationRates.meta = 0.15

        -- Heavily mutate cell
        for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, 0, 500)) do
            local mutCell = cell:new (cell.maxEnergy, cell.maxHealth)
            cell:mutate (mutCell, newCellObj)
            newCellObj = mutCell
        end

        cell:compileScript (newCellObj)

        captures[i] = newCellObj
    end
end

function thisScene:update (dt)
    if love.keyboard.isDown ("lshift") and love.keyboard.isDown ("b") then
        local newCell = cell:new (cell.maxEnergy, cell.maxHealth)
        cell:mutate (newCell, testCell)
        cell:compileScript (newCell)
        testCell = newCell

        for k, v in pairs (testCell) do
            print (k, v)
            if type (v) == "table" then
                for k, v in pairs (v) do
                    print ("    ", k, v)
                end
            end
        end
        print ()
    end

    local camX, camY, zoom = map:getCamera ()
    local speedMult = (love.keyboard.isDown ("lshift") == true) and 5 or 1

    if love.keyboard.isDown("w") then
        camY = camY - camVelocity * dt * zoom * speedMult
    elseif love.keyboard.isDown("s") then
        camY = camY + camVelocity * dt * zoom * speedMult
    end

    if love.keyboard.isDown("a") then
        camX = camX - camVelocity * dt * zoom * speedMult
    elseif love.keyboard.isDown("d") then
        camX = camX + camVelocity * dt * zoom * speedMult
    end

    if love.keyboard.isDown("q") then
        zoom = zoom - zoomVelocity * dt
    elseif love.keyboard.isDown("e") then
        zoom = zoom + zoomVelocity * dt
    end

    -- Update map and camera
    map:setCamera (camX, camY, zoom)
    local capture = map:update (dt)

    if capture ~= nil then
        cyclesSinceLastFail = cyclesSinceLastFail + 1
        predTimer = predTimer - 1

        -- End the current prediction
        if predTimer <= 0 then
            -- currLabel = currLabel * -1

            local origAccuracy = calcAccuracy ()
            local correctPred = false
            attemptPreds.pos = 0
            attemptPreds.neg = 0
            attemptPreds.total = 0

            predTimer = cyclesPerPred

            local totalPreds = confusionMatrix.fn + confusionMatrix.fp + confusionMatrix.tn + confusionMatrix.tp

            print("============= Prediction #" .. totalPreds .. " =============")

            -- Positive predition
            if map.currPred > 0 then
                if currLabel > 0 then
                    correctPred = true
                    confusionMatrix.tp = confusionMatrix.tp + 1
                    print ("(TP) True positive prediction (O)")
                else
                    confusionMatrix.fp = confusionMatrix.fp + 1
                    print ("(FP) False positive prediction (X)")
                end

            -- Negative prediction
            else
                if currLabel < 0 then
                    correctPred = true
                    confusionMatrix.tn = confusionMatrix.tn + 1
                    print ("(TN) True negative prediction (O)")
                else
                    confusionMatrix.fn = confusionMatrix.fn + 1
                    print ("(FN) False negative prediction (X)")
                end
            end

            local origPred = map.currPred
            map:getCells (treatCell)

            predsSinceLastReset = predsSinceLastReset + 1

            if predsSinceLastReset >= batchSize then
                predsSinceLastReset = 0
                if currLabel > 0 then
                    replaceCellInList (negCellList)
                else
                    replaceCellInList (posCellList)
                end
            end
            cellList = {}

            print("Prediction: " .. map.currPred .. "(" .. origPred .. ")")
            print ("Accuracy: " .. origAccuracy .. " -> " .. calcAccuracy ())
            print ("Change: " .. calcAccuracy () - origAccuracy)
            print ("Dataset Ratio: " .. datasetRatio)
            print("Prediction Ratio: " .. predRatio)
            print("Cell Prediction Ratio: " .. (attemptPreds.pos / attemptPreds.total))
            print ("-------------------")
            print ("TP: " .. confusionMatrix.tp .. " | FP: " .. confusionMatrix.fp)
            print ("-------------------")
            print ("FN: " .. confusionMatrix.fn .. " | TN: " .. confusionMatrix.tn)
            print ("-------------------")

            map.currPred = 0

            -- Reset the shape in the background
            if confusionMatrix.fn + confusionMatrix.fp > predRetries or correctPred == true then
                map:reset (mapSize, mapSize, false, createInputMapper ())
            end
        end
    end

    if map.stats.cells == 1 and map:getTickSpeed () < math.huge and capture ~= nil then
        lastCell = capture
    end

    -- Activate failsafe if all cells are dead
    if map.stats.cells <= 0 then
        print ("WARNING: Failsafe #" .. failsafeActivations .. " activated", os.date("%H:%M:%S - %Y-%m-%d"), "Ticks survived: " .. cyclesSinceLastFail)
        print ("Number of available captures: " .. #captures)

        -- Add last surviving cell to captures list
        if lastCell ~= nil then
            table.insert (captures, 1, lastCell)
            table.remove (captures, maxCaptures + 1)
        end

        baseXInput = 1000000 * love.math.random()
        baseYInput = 1000000 * love.math.random()
        baseXBarriers = 1000000 * love.math.random()
        baseYBarriers = 1000000 * love.math.random()
        map:reset (mapSize, mapSize, true, createInputMapper ())

        local cellsSpawned = 0

        for i = 1, math.min (failsafeSpawns, cell.maxCells) do
            local newCell = copyTable (captures[i])

            -- Heavily mutate cell
            for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, 0, 80)) do
                local mutCell = cell:new (cell.maxEnergy, cell.maxHealth)
                cell:mutate (mutCell, newCell)
                newCell = mutCell
            end

            cell:compileScript (newCell)

            -- print ("INFO:", i)
            -- cell:printCellInfo (newCell)
            -- cell:printCellScriptList (newCell)

            -- Attempt to spawn the cell
            while map:spawnCell (math.random (1, map.width), math.random (1, map.height), cell.maxHealth, cell.maxEnergy, newCell) == false do
                
            end
            cellsSpawned = cellsSpawned + 1
        end

        failsafeActivations = failsafeActivations + 1
        cyclesSinceLastFail = 0
    end
end

function thisScene:draw ()
    love.graphics.setBackgroundColor (0, 0, 1, 1)

    if renderMap == true then
        map:draw ()
    end

    -- Super speed border
    local tickSpeed = map:getTickSpeed ()
    if tickSpeed == 0 then
        love.graphics.setColor (0, 1, 0, 1)
        love.graphics.rectangle ("fill", 0, 0, love.graphics.getWidth (), 5)
        love.graphics.rectangle ("fill", 0, 0, 5, love.graphics.getHeight ())
        love.graphics.rectangle ("fill", love.graphics.getWidth (), 0, -5, love.graphics.getHeight ())
        love.graphics.rectangle ("fill", 0, love.graphics.getHeight (), love.graphics.getWidth (), -5)
    elseif tickSpeed == math.huge then
        love.graphics.setColor (1, 0, 0, 1)
        love.graphics.rectangle ("fill", 0, 0, love.graphics.getWidth (), 5)
        love.graphics.rectangle ("fill", 0, 0, 5, love.graphics.getHeight ())
        love.graphics.rectangle ("fill", love.graphics.getWidth (), 0, -5, love.graphics.getHeight ())
        love.graphics.rectangle ("fill", 0, love.graphics.getHeight (), love.graphics.getWidth (), -5)
    end

    -- Show FPS
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 10, 35, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf (love.timer.getFPS (), 15, 15, 25, "center")

    -- Show the number of cycles the current generation has survived
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 45, 95, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Cycles: " .. cyclesSinceLastFail, 15, 50, 120, "left")

    -- Shows the current label
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 80, 95, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Label: " .. currLabel, 15, 85, 85, "left")

    -- Show the current accuracy
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 115, 95, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Acc: " .. round (calcAccuracy () * 100) / 100, 15, 120, 85, "left")

    -- Show the number of predictions made
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 10, 150, 95, 25)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Pred #" .. calcTotalPreds () + 1, 15, 155, 85, "left")

    -- Show the current prediction
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 10, 185, 95, 25)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("C. Pred: " .. map.currPred, 15, 190, 85, "left")

    -- Show number of cells
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 720, 10, 76, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Cells: " .. map.stats.cells, 725, 15, 100, "left")

    -- Show number of failsafe activations
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 720, 45, 76, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("FSs: " .. failsafeActivations, 725, 50, 100, "left")

    -- Show the values of global variables
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 720, 80, 76, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Globals:", 725, 85, 100, "left")

    -- Show value of cell global variables
    for i = 1, cell.globalVars do
        love.graphics.setColor (0, 0, 0, 0.75)
        love.graphics.rectangle ("fill", 720, 80 + i * 25, 76, 25)
        love.graphics.setColor (1, 1, 1, 1)
        love.graphics.printf(shortenNumber(map.globalVars[i], 5), 725, 85 + i * 25, 100, "left")
    end

    -- Show map position under cursor
    local mapX, mapY = map:screenToMap (love.mouse.getPosition ())
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 560, 95, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("(" .. mapX .. ", " .. mapY .. ")", 15, 565, 85, "left")
end

function thisScene:keypressed (key, scancode, isrepeat)
    -- Kills  a cell in the map
    if key == "k" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())
        map:deleteCell (tileX, tileY)

    -- Prints an input tile's value
    elseif key == "i" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())

        if love.keyboard.isDown ("lshift") then
            print ("Input @ (" .. tileX .. ", " .. tileY .. "): " .. map:getInputTile (map:screenToMap (love.mouse.getPosition ())))
        else
            local cellToPrint = map:getCell (tileX, tileY)

            if cellToPrint ~= nil then
                if love.keyboard.isDown ("lctrl") == true then
                    cell:printCellScriptList (map:getCell (tileX, tileY))
                else
                    cell:printCellInfo (map:getCell (tileX, tileY))
                end
            end
        end

    -- Copies a cell's script to your keyboard
    elseif key == "o" then
        local cellObj = map:getCell (map:screenToMap (love.mouse.getPosition ()))
        
        if cellObj ~= nil then
            if love.keyboard.isDown ("lshift") then
                print ("=====Cell Script=====")
                cell:printCellScriptString (cellObj)
            else
                love.system.setClipboardText (cell:compileScript (cellObj, true))
                print ("Script copied to clipboard!")
            end
        end

    -- Prints the values of the cell global variables
    elseif key == "u" then
        if love.keyboard.isDown ("lshift") then
            local totalContributions = 0
            print ("==========Cell Contributions==========")
            map:getCells (function (tileX, tileY, cellObj)
                totalContributions = totalContributions + cellObj.contributions
            end)
            print ("Total:", totalContributions)
            print("Current:", map.currPred)
        elseif love.keypressed.isDown ("rshift") then
            local cellObj = map:getCell(map:screenToMap(love.mouse.getPosition()))

            print("==========Cell Stats==========")
            print("Vote: " .. cellObj.contributions)
            print("Total votes: " .. cellObj.total)
            print("Accuracy: " .. cellObj.correct / cellObj.total)
            print("Pred. ratio: " .. cellObj.positivePreds / cellObj.total)
            print("Last pred correct: " .. cellObj.lastCorrect)
        else
            print ("==========Cell Global Variables==========")
            for i = 1, cell.globalVars do
                print (map.globalVars[i])
            end
        end

    -- Quick saves
    elseif key == "g" then
        map:quickSave ()

    -- Toggle rendering
    elseif key == "z" then
        renderMap = not renderMap
    
    -- Toggles superspeed
    elseif key == "tab" then
        if map:getTickSpeed () == 0 then
            map:setTickSpeed (1/8)
        else
            map:setTickSpeed (0)
        end

    -- Toggles pause mode
    elseif key == "space" then
        if map:getTickSpeed () == math.huge then
            map:setTickSpeed (1/8)
        else
            map:setTickSpeed (math.huge)
        end
    end
end

function thisScene:mousereleased (x, y, button)
    local tileX, tileY = map:screenToMap (x, y)

    map:adjustInputTile (tileX, tileY, (button == 1) and 100 or -100)
    print (map:getInputTile (tileX, tileY))
end

return thisScene