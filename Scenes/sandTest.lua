local thisScene = {}
local sceneMan = require ("Libraries.sceneMan")
local map = require ("Managers.map")
local cell = require ("Managers.cell")
local mapToScale = require ("Helpers.mapToScale")
local round = require ("Libraries.lume").round
local cellActions = require ("Data.cellActions")
local cellInputs = require ("Data.cellInputs")
local lume = require ("Libraries.lume")
local saveUi = require ("Managers.saveUi")

local startTime

local voting = true
local maxTicksSinceVote = 1000
local ticksSinceVote = 0
local predRounds = 0
local startPredTokens = 1

local minReproChance, maxReproChance = 0.10, 1
local alpha = 1.5
local minAccuracyDenom = 5

local currLabel = 0

local cm = {
    tp = 0,
    tn = 0,
    fp = 0,
    fn = 0,
} -- Confusion matrix
local positiveLabels = 0

local function getTotalPreds ()
    return cm.tp + cm.tn + cm.fp + cm.fn
end
local function getAccuracy ()
    local total = getTotalPreds ()
    if total == 0 then
        return 0
    else
        return (cm.tp + cm.tn) / total
    end
end

local function getPredRatio ()
    local total = getTotalPreds ()
    if total == 0 then
        return 0
    else
        return (cm.tp + cm.fp) / total
    end
end

local function calcReproChance (accuracy)
    return minReproChance + (maxReproChance - minReproChance) * (accuracy ^ alpha)
end

local mapDataGenerator
local function processPred ()
    local metrics = {
        posPreds = 0,
        negPreds = 0,
        abstains = 0,
        totalCells = 0,
        tokensAwarded = 0,
    }
    predRounds = predRounds + 1

    map:getCells (function (tileX, tileY, cellObj)
        -- Cells that are correct have a chance to be awarded a prediction token based on their accuracy
        cellObj.vote = cellObj.vote or 0
        cellObj.totalVotes = cellObj.totalVotes or 0
        cellObj.accurateVotes = cellObj.accurateVotes or 0
        cellObj.totalPosVotes = cellObj.totalPosVotes or 0
        cellObj.accuratePosVotes = cellObj.accuratePosVotes or 0
        cellObj.totalNegVotes = cellObj.totalNegVotes or 0
        cellObj.accurateNegVotes = cellObj.accurateNegVotes or 0
        cellObj.predTokens = cellObj.predTokens or 0

        local posAccuracy = (cellObj.totalPosVotes > 0) and (cellObj.accuratePosVotes / math.max (cellObj.totalPosVotes, minAccuracyDenom)) or 0
        local negAccuracy = (cellObj.totalNegVotes > 0) and (cellObj.accurateNegVotes / math.max (cellObj.totalNegVotes, minAccuracyDenom)) or 0
        local accuracy = math.min (posAccuracy, negAccuracy)

        local cellVote = cellObj.vote
        metrics.totalCells = metrics.totalCells + 1

        -- True positive
        if currLabel > 0 and cellVote > 0 then
            cm.tp = cm.tp + 1
            metrics.posPreds = metrics.posPreds + 1

            cellObj.accurateVotes = cellObj.accurateVotes + 1
            cellObj.accuratePosVotes = cellObj.accuratePosVotes + 1
            
            if math.random () < calcReproChance (accuracy) then
                cellObj.predTokens = cellObj.predTokens + 1
                metrics.tokensAwarded = metrics.tokensAwarded + 1
            end

        -- False positive
        elseif currLabel < 0 and cellVote >= 0 then
            cm.fp = cm.fp + 1
            metrics.posPreds = metrics.posPreds + 1
            if cellVote == 0 then
                metrics.abstains = metrics.abstains + 1
            end
        
        -- True negative
        elseif currLabel < 0 and cellVote < 0 then
            cm.tn = cm.tn + 1
            metrics.negPreds = metrics.negPreds + 1

            cellObj.accurateVotes = cellObj.accurateVotes + 1
            cellObj.accurateNegVotes = cellObj.accurateNegVotes + 1

            if math.random () < calcReproChance (accuracy) then
                cellObj.predTokens = cellObj.predTokens + 1
                metrics.tokensAwarded = metrics.tokensAwarded + 1
            end

        -- False negative
        elseif currLabel > 0 and cellVote <= 0 then
            cm.fn = cm.fn + 1
            metrics.negPreds = metrics.negPreds + 1
            if cellVote == 0 then
                metrics.abstains = metrics.abstains + 1
            end

        end

        -- Each cell gets a shot at a prediction token based on its accuracy
        -- Cells that predict right have two chances
        if math.random () < calcReproChance (accuracy) then
            cellObj.predTokens = cellObj.predTokens + 1
            metrics.tokensAwarded = metrics.tokensAwarded + 1
        end

        cellObj.vote = 0 -- Reset vote for next round
        cellObj.totalVotes = cellObj.totalVotes + 1
        if currLabel > 0 then
            cellObj.totalPosVotes = cellObj.totalPosVotes + 1
        elseif currLabel < 0 then
            cellObj.totalNegVotes = cellObj.totalNegVotes + 1
        end
    end)

    -- Print the metrics overall and for this round
    print ("--- Prediction Metrics for Round #" .. predRounds .. "---")
    local roundMatches = (currLabel > 0) and metrics.posPreds or metrics.negPreds
    local roundMatchPct = (metrics.totalCells > 0) and ((roundMatches / metrics.totalCells) * 100) or 0
    local overallMatches = cm.tp + cm.tn
    local overallPreds = getTotalPreds ()
    local overallMatchPct = (overallPreds > 0) and ((overallMatches / overallPreds) * 100) or 0

    if currLabel > 0 then
        print ("Current Label: POSITIVE")
        print ("Round Accuracy : " .. round ((metrics.posPreds / metrics.totalCells) * 100, 0.01) .. "%")
    elseif currLabel < 0 then
        print ("Current Label: NEGATIVE")
        print ("Round Accuracy : " .. round ((metrics.negPreds / metrics.totalCells) * 100, 0.01) .. "%")
    end
    print ("Cells Matched Label (Round): " .. roundMatches .. "/" .. metrics.totalCells .. " (" .. round (roundMatchPct, 0.01) .. "%)")
    print ("Cells Matched Label (Overall): " .. overallMatches .. "/" .. overallPreds .. " (" .. round (overallMatchPct, 0.01) .. "%)")
    print ("Round Total Cells: " .. metrics.totalCells)
    print ("Round Prediction Ratio: " .. round ((metrics.posPreds / metrics.totalCells) * 100, 0.01) .. "%")
    print ("Round Abstains: " .. metrics.abstains)
    print ("Tokens Awarded This Round: " .. metrics.tokensAwarded)
    print ("Overall Accuracy : " .. round (getAccuracy () * 100, 0.01) .. "%")
    print ("Overall Prediction Ratio: " .. round (getPredRatio () * 100, 0.01) .. "%")
    print ("Label Ratio: " .. round ((positiveLabels / predRounds) * 100, 0.01) .. "%")
    print ()

    -- Reset data
    local rectFunc = mapDataGenerator ()
    map:getTiles (function (tileX, tileY, envTile)
        envTile.data = rectFunc (tileX, tileY)
    end)
end

local mapSize = 22

local camVelocity = 15
local zoomVelocity = 2

local cellStartHealth, cellStartEnergy = 500, 500

local maxCaptures = 50
local maxCaptureCycles = 10000
local captureTimer = maxCaptureCycles
local captures = {}

local superparents = 3

local totalCycles = 0
local cyclesSinceLastFail = {}
for superparent = 1, superparents do
    cyclesSinceLastFail[superparent] = 0
end

local failsafeSpawns = 200
local failsafeActivations = {}
for superparent = 1, superparents do
    failsafeActivations[superparent] = -1
end
local lastCells = {}
local failsafeMutations = {
    min = 0,
    max = 50,
}

local renderMap = true
local showWalls = false
local showSuperparentKills = false
local renderModeIndex = 1
local validModes = {
    "normal",
    "superparents",
    "normalEnergyOpacity",
    "superparentsEnergyOpacity",
    "energy",
    "health",
    "total",
    "one",
    "none"
}
local renderSubModeIndex = 1
local validSubModes = {
    "normal",
    "data",
    "energyOnly",
    "pheromones",
    "pheromonesOpacity",
    "inputDisabled",
    "barriersDisabled",
    "allDisabled",
}

local renderSelector = {
    active = false,
    target = "mode",
    selectedIndex = 1,
}
local saveUiManager = saveUi:new (map)

local function openRenderSelector (target)
    renderSelector.active = true
    renderSelector.target = target

    if target == "mode" then
        renderSelector.selectedIndex = renderModeIndex
    else
        renderSelector.selectedIndex = renderSubModeIndex
    end
end

local function getSelectorList ()
    if renderSelector.target == "mode" then
        return validModes
    else
        return validSubModes
    end
end

local function getCurrentRenderIndex ()
    if renderSelector.target == "mode" then
        return renderModeIndex
    else
        return renderSubModeIndex
    end
end

local function applyRenderSelector ()
    if renderSelector.target == "mode" then
        renderModeIndex = renderSelector.selectedIndex
    else
        renderSubModeIndex = renderSelector.selectedIndex
    end
end

local function moveRenderSelector (direction)
    local list = getSelectorList ()
    local newIndex = renderSelector.selectedIndex + direction

    if newIndex < 1 then
        newIndex = #list
    elseif newIndex > #list then
        newIndex = 1
    end

    renderSelector.selectedIndex = newIndex
end

local function switchRenderSelectorTarget ()
    if renderSelector.target == "mode" then
        renderSelector.target = "submode"
        renderSelector.selectedIndex = renderSubModeIndex
    else
        renderSelector.target = "mode"
        renderSelector.selectedIndex = renderModeIndex
    end
end

local baseXInput1 = 10 * love.math.random()
local baseYInput1 = 10 * love.math.random()
local baseXInput2 = 10000 * love.math.random()
local baseYInput2 = 10000 * love.math.random()
local baseXInput3 = 10000 * love.math.random()
local baseYInput3 = 10000 * love.math.random()
local maxInput = 1000
local function mapInput (tileX, tileY)
    -- return (math.random () < 0.10) and maxInput or 0

    return{
        meat = 0, -- round (mapToScale (love.math.noise(baseXInput1+.05*tileX, baseYInput1+.02*tileY), 0, 1, 0, maxInput)),
        plants = 0, -- round (mapToScale (love.math.noise(baseXInput2+.05*tileX, baseYInput2+.02*tileY), 0, 1, 0, maxInput)),
        waste = 0, -- round (mapToScale (love.math.noise(baseXInput3+.05*tileX, baseYInput3+.02*tileY), 0, 1, 0, maxInput)),
        any = 0, -- round (mapToScale (love.math.noise(baseXInput1+.05*tileX, baseYInput1+.02*tileY), 0, 1, 0, maxInput))
    }
end

local baseXBarriers = 10000 * love.math.random()
local baseYBarriers = 10000 * love.math.random()
local multXBarrier = 0.15 -- 0.03
local multYBarrier = 0.25 -- 0.1
local biomeXBarriers = 100000 * love.math.random()
local biomeYBarriers = 100000 * love.math.random()
local bmultXBarrier = 0.03
local bmultYBarrier = 0.03
local function mapBarriers (tileX, tileY)
    if true then return "blank" end

    if love.math.noise(biomeXBarriers+bmultXBarrier*tileX, biomeYBarriers+bmultYBarrier*tileY) >= 0.35 then
        return (love.math.noise(baseXBarriers+multXBarrier*tileX, baseYBarriers+multYBarrier*tileY) > 0.50) and "barrier" or "blank"
    else
        return "blank"
    end
end

function mapDataGenerator ()
    local rectX1, rectY1, rectX2, rectY2

    local rectWidth = math.random (1, mapSize)
    local rectHeight = math.random (1, mapSize)

    -- Center the rectangle within the map bounds (1-indexed)
    rectX1 = math.floor ((mapSize - rectWidth) / 2) + 1
    rectY1 = math.floor ((mapSize - rectHeight) / 2) + 1
    rectX2 = rectX1 + rectWidth - 1
    rectY2 = rectY1 + rectHeight - 1

    if rectWidth > rectHeight then
        currLabel = 1 -- Positive, rectangle is wide
        positiveLabels = positiveLabels + 1
    else
        currLabel = -1 -- Negative, rectangle is tall
    end

    local function mapInputRect (tileX, tileY)
        if tileX >= rectX1 and tileX <= rectX2 and tileY >= rectY1 and tileY <= rectY2 then
            return 1
        else
            return -1
        end
    end

    return mapInputRect
end

function thisScene:load (...)
    saveUiManager = saveUi:new (map)

    cell:init (map, cellInputs, cellActions, {
        network = {
            layers = 3,
            neuronsPerLayer = 10,
        },
        maxHealth = 500,
        maxEnergy = 500,
        memVars = 4,
        displayVars = 2,
        tickCost = -0.5,
        -- cellAge = {
            --     min = math.huge,
            --     max = math.huge,
            -- },
        maxCells = math.huge,
        maxWalls = math.huge,
        -- maxCells = {
        --     100,
        --     250,
        --     400,
        -- },
        superparents = superparents,
        consumeOnTick = {
            amount = 15,
            cost = 0,
        },
        pheromoneTime = 500,
        pheromones = 3,
        usePheroBuffers = true,
        pheromoneBufferSize = 35, -- How long the cell remembers that it encountered a certain pheromone, in ticks
        canClearPheroBuffers = true,
        actionsPerTurn = lume.count (cellActions),
        -- actionThreshold = 0.5,
        canZeroVars = true,
        age = {
            min = 500,
            max = 7000,
        },
        superparentFoodTypes = {
            "any",
            "any",
            "any",
        },
        reproductionEnergy = {
            -- min = 3000,
        }
    })
    map:init (cell, {
        inputBounds = {
            min = 0,
            max = math.huge,
        },
        drawBounds = {
            meat = {
                min = 0,
                max = 2500,
            },
            plants = {
                min = 0,
                max = 2500,
            },
            waste = {
                min = 0,
                max = 2500,
            },
            energy = {
                min = 0,
                max = 5000,
            },
            pheromones = {
                min = 0,
                max = 500,
            },
        },
        dataBounds = {
            min = -1,
            max = 1,
        },
        spawnFunc = function (tileX, tileY, cellObj)
            cellObj.predTokens = startPredTokens
            cellObj.vote = 0
            cellObj.totalVotes = 0
            cellObj.accurateVotes = 0
            cellObj.totalPosVotes = 0
            cellObj.accuratePosVotes = 0
            cellObj.totalNegVotes = 0
            cellObj.accurateNegVotes = 0
        end
    })

    map:reset (mapSize, mapSize, mapInput, mapBarriers, mapDataGenerator())
    map:setCamera (-110, -10, 3.8)
    map:setTickSpeed (math.huge)
    startTime = os.time()

    -- Adds a few heavily mutated cells to the initial captures lists
    for superparent = 1, superparents do
        captures[superparent] = {}

        for i = 1, maxCaptures do
            local newCellObj = cell:new (cellStartHealth, cellStartEnergy, superparent)

            -- Heavily mutate cell
            for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, failsafeMutations.min, failsafeMutations.max)) do
                cell:mutate (newCellObj)
            end

            captures[superparent][i] = newCellObj
        end
    end
end

function thisScene:update (dt)
    saveUiManager:update (dt)

    -- Update global mutation rate based on current accuracy
    cell.globalMutChance = mapToScale (1 - getAccuracy (), 0, 1, 0, 0.45)

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
        zoom = zoom - zoomVelocity * dt * zoom
    elseif love.keyboard.isDown("e") then
        zoom = zoom + zoomVelocity * dt * zoom
    end

    -- Update map and camera
    map:setCamera (camX, camY, zoom)
    local currentCaptures, tickOccured = map:update (dt)

    if tickOccured == true then
        for superparent = 1, superparents do
            cyclesSinceLastFail[superparent] = cyclesSinceLastFail[superparent] + 1
        end

        totalCycles = totalCycles + 1
        captureTimer = captureTimer - 1
        ticksSinceVote = ticksSinceVote + 1

        if voting == true and ticksSinceVote >= maxTicksSinceVote then
            ticksSinceVote = 0
            processPred ()
        end

        if captureTimer <= 0 then
            captureTimer = maxCaptureCycles

            -- Capture cells
            for superparent = 1, superparents do
                if currentCaptures[superparent] ~= nil then
                    table.insert (captures[superparent], 1, currentCaptures[superparent])
                    if #captures[superparent] > maxCaptures then
                        table.remove (captures[superparent], maxCaptures + 1)
                    end
                end
            end
        end
    end

    for superparent = 1, superparents do
        local capture = currentCaptures[superparent]

        if capture ~= nil then
            lastCells[superparent] = capture
        end

        -- Activate failsafe if all cells are dead
        if map.stats.cells[superparent] <= 0 then
            print ("WARNING: Failsafe '" .. superparent .. "' #" .. failsafeActivations[superparent] .. " activated", os.date("%H:%M:%S - %Y-%m-%d"))
            print ("Number of available captures: " .. #captures[superparent])

            -- Add last surviving cell to captures list
            if lastCells[superparent] ~= nil then
                table.insert (captures[superparent], 1, lastCells[superparent])
                if #captures[superparent] > maxCaptures then
                    table.remove (captures[superparent], maxCaptures + 1)
                end
            end

            local cellsSpawned = 0
            local outerTries = 0
            local outerMaxTries = 5

            while cellsSpawned < math.min (failsafeSpawns, cell.maxCells[superparent]) and outerTries < outerMaxTries do
                for i = 1, #captures[superparent] do
                    local newCell = cell:newChild (captures[superparent][i])

                    -- Heavily mutate cell
                    for i = 1, round (mapToScale (love.math.randomNormal (), -0.5, 3, failsafeMutations.min, failsafeMutations.max)) do
                        cell:mutate (newCell)
                    end

                    -- print ("INFO:", i)
                    -- cell:printCellInfo (newCell)
                    -- cell:printCellScriptList (newCell)

                    -- Set the starting health and energy
                    newCell.health = cellStartHealth
                    newCell.energy = cellStartEnergy

                    -- Attempt to spawn the cell
                    local tries = 0
                    local maxTries = 50
                    local tx, ty = math.random (1, map.width), math.random (1, map.height)
                    while map:spawnCell (tx, ty, cellStartHealth, cellStartEnergy, newCell.superparent, newCell) == false and tries < maxTries do
                        tries = tries + 1
                        tx, ty = math.random (1, map.width), math.random (1, map.height)
                    end
                    if tries < maxTries then
                        map.totalEnergy = map.totalEnergy + newCell.energy + newCell.health
                        cellsSpawned = cellsSpawned + 1

                        if cellsSpawned >= math.min (failsafeSpawns, cell.maxCells[superparent]) then
                            break
                        end
                    end
                end

                outerTries = outerTries + 1
            end

            failsafeActivations[superparent] = failsafeActivations[superparent] + 1
            cyclesSinceLastFail[superparent] = 0
            print ("Cells spawned for " .. superparent .. ": " .. cellsSpawned)
            print ()
        end
    end
end

function thisScene:draw ()
    love.graphics.setBackgroundColor (0, 0, 1, 1)

    if renderMap == true then
        map:draw (validModes[renderModeIndex], validSubModes[renderSubModeIndex])
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

    -- Show cursor tile position
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 45, 125, 25)
    love.graphics.setColor (1, 1, 1, 1)
    local cursorTileX, cursorTileY = map:screenToMap (love.mouse.getPosition ())
    love.graphics.printf ("Cursor: (" .. cursorTileX .. ", " .. cursorTileY .. ")", 15, 50, 125, "left")

    -- Show total number of ticks
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 80, 150, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Cycles: (*): " .. totalCycles, 15, 85, 150, "left")

    -- Show death counters
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 115, 180, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Deaths: " .. map.stats.totalCellDeaths, 15, 120, 180, "left")

    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 150, 180, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Cell Kills: " .. map.stats.cellVsCellDeaths, 15, 155, 180, "left")

    -- Ticks since last fail for each superparent
    local foodMap = {
        meat = "M",
        plants = "P",
        waste = "W",
        any = "A",
    }
    for superparent = 1, superparents do
        love.graphics.setColor (0, 0, 0, 0.75)
        love.graphics.rectangle ("fill", 10, 185 + (superparent - 1) * 35, 150, 25)
        love.graphics.setColor (1, 1, 1, 1)
        love.graphics.printf ("Cycles (" .. superparent .. ", " .. foodMap[cell.superparentFoodTypes[superparent]] .. "): " .. cyclesSinceLastFail[superparent], 15, 190 + (superparent - 1) * 35, 150, "left")
    end

    -- Show number of cells or walls
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 720, 10, 76, 25)
    love.graphics.setColor (1, 1, 1, 1)
    if showWalls then
        local totalWallCount = 0
        for superparent = 1, superparents do
            totalWallCount = totalWallCount + map.stats.walls[superparent]
        end
        love.graphics.printf ("Walls: " .. totalWallCount, 725, 15, 100, "left")
    else
        local totalCellCount = 0
        for superparent = 1, superparents do
            totalCellCount = totalCellCount + map.stats.cells[superparent]
        end
        love.graphics.printf ("Cells: " .. totalCellCount, 725, 15, 100, "left")
    end

    -- Show number of failsafe activations for each superparent
    for superparent = 1, superparents do
        love.graphics.setColor (0, 0, 0, 0.75)
        love.graphics.rectangle ("fill", 720, 45 + (superparent - 1) * 35, 76, 25)
        love.graphics.setColor (1, 1, 1, 1)
        love.graphics.printf ("FSs (" .. superparent .. "): " .. failsafeActivations[superparent], 725, 50 + (superparent - 1) * 35, 100, "left")
    end

    -- Show number of cells or walls for each superparent (rendered below the failsafe boxes)
    local cellsBaseY = 45 + superparents * 35
    for superparent = 1, superparents do
        love.graphics.setColor (0, 0, 0, 0.75)
        love.graphics.rectangle ("fill", 705, cellsBaseY + (superparent - 1) * 35, 90, 25)
        love.graphics.setColor (1, 1, 1, 1)
        if showWalls then
            love.graphics.printf ("Walls (" .. superparent .. "): " .. map.stats.walls[superparent], 710, cellsBaseY + 5 + (superparent - 1) * 35, 85, "left")
        else
            love.graphics.printf ("Cells (" .. superparent .. "): " .. map.stats.cells[superparent], 710, cellsBaseY + 5 + (superparent - 1) * 35, 85, "left")
        end
    end

    if showSuperparentKills == true then
        local killsBaseY = cellsBaseY + superparents * 35
        for superparent = 1, superparents do
            love.graphics.setColor (0, 0, 0, 0.75)
            love.graphics.rectangle ("fill", 705, killsBaseY + (superparent - 1) * 35, 90, 25)
            love.graphics.setColor (1, 1, 1, 1)
            love.graphics.printf ("Kills (" .. superparent .. "): " .. map.stats.kills[superparent], 710, killsBaseY + 5 + (superparent - 1) * 35, 85, "left")
        end
    end

    -- Shows the rendering mode
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 510, 210, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Mode: " .. validModes[renderModeIndex], 15, 515, 210, "left")

    -- Shows the sub-rendering mode
    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 540, 210, 25)
    love.graphics.setColor (1, 1, 1, 1)
    love.graphics.printf ("Submode: " .. validSubModes[renderSubModeIndex], 15, 545, 210, "left")

    love.graphics.setColor (0, 0, 0, 0.75)
    love.graphics.rectangle ("fill", 10, 570, 330, 25)
    love.graphics.setColor (1, 1, 1, 1)
    if renderSelector.active then
        love.graphics.printf ("Selector: up/down move, tab switch, enter apply, esc cancel", 15, 575, 325, "left")
    else
        love.graphics.printf (saveUiManager:getHintText (), 15, 575, 325, "left")
    end

    saveUiManager:draw ()

    if renderSelector.active then
        local selectorList = getSelectorList ()
        local currentIndex = getCurrentRenderIndex ()
        local panelX = 10
        local panelWidth = 280
        local panelHeight = 30 + (#selectorList * 20)
        local panelY = math.max (10, 510 - panelHeight - 10)

        love.graphics.setColor (0, 0, 0, 0.85)
        love.graphics.rectangle ("fill", panelX, panelY, panelWidth, panelHeight)

        love.graphics.setColor (1, 1, 1, 1)
        love.graphics.printf (
            "Selecting " .. ((renderSelector.target == "mode") and "mode" or "submode"),
            panelX + 5,
            panelY + 5,
            panelWidth - 10,
            "left"
        )

        for i = 1, #selectorList do
            local prefix = "   "
            if i == renderSelector.selectedIndex then
                prefix = ">  "
            elseif i == currentIndex then
                prefix = "*  "
            end

            if i == renderSelector.selectedIndex then
                love.graphics.setColor (0.1, 0.35, 0.65, 0.9)
                love.graphics.rectangle ("fill", panelX + 3, panelY + 24 + (i - 1) * 20, panelWidth - 6, 18)
            end

            love.graphics.setColor (1, 1, 1, 1)
            love.graphics.printf (prefix .. selectorList[i], panelX + 8, panelY + 25 + (i - 1) * 20, panelWidth - 16, "left")
        end
    end

    -- Shows the current label
    if voting == true then
        love.graphics.setColor (0, 0, 0, 0.75)
        love.graphics.rectangle ("fill", 700, 570, 100, 25)
        love.graphics.setColor (1, 1, 1, 1)
        love.graphics.printf ("Label: " .. (currLabel > 0 and "Positive" or "Negative"), 705, 575, 100, "left")
    end

    -- Show superparent colors
    local colorBoxSize = 20
    local colorBoxSpacing = 5
    local foodMap = {
        meat = "M",
        plants = "P",
        waste = "W",
        any = "A",
    }
    local totalWidth = superparents * colorBoxSize + (superparents - 1) * colorBoxSpacing
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    
    if validModes[renderModeIndex] == "superparents" then
        for superparent = 1, superparents do
            local color = map.superparentColors[superparent]
            local xPos = startX + (superparent - 1) * (colorBoxSize + colorBoxSpacing)
            
            -- Draw color box
            love.graphics.setColor (color[1], color[2], color[3], 1)
            love.graphics.rectangle ("fill", xPos, 10, colorBoxSize, colorBoxSize)
            
            -- Draw border
            love.graphics.setColor (1, 1, 1, 1)
            love.graphics.rectangle ("line", xPos, 10, colorBoxSize, colorBoxSize)
            
            -- Draw label
            love.graphics.setColor (1, 1, 1, 1)
            love.graphics.printf (superparent .. "/" .. foodMap[cell.superparentFoodTypes[superparent]], xPos - 5, 32, colorBoxSize + 10, "center")
        end
    end
end

function thisScene:keypressed (key, scancode, isrepeat)
    if saveUiManager:keypressed (key) == true then
        return
    end

    if renderSelector.active then
        if key == "up" or key == "w" then
            moveRenderSelector (-1)
        elseif key == "down" or key == "s" then
            moveRenderSelector (1)
        elseif key == "tab" or key == "left" or key == "right" then
            switchRenderSelectorTarget ()
        elseif key == "return" or key == "kpenter" then
            applyRenderSelector ()
            renderSelector.active = false
        elseif key == "escape" then
            renderSelector.active = false
        elseif key == "m" then
            openRenderSelector ("mode")
        elseif key == "n" then
            openRenderSelector ("submode")
        end

        return
    end

    if saveUiManager:handleGlobalHotkeys (key) == true then
        return
    end

    -- Kills  a cell in the map
    if key == "k" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())
        map:deleteCell (tileX, tileY, true)

    -- Prints an input tile's value
    elseif key == "i" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())

        if love.keyboard.isDown ("lshift") then
            print ("Any input @ (" .. tileX .. ", " .. tileY .. "): " .. tostring(map:getInputTile (tileX, tileY, "any")))
            print ("Meat input @ (" .. tileX .. ", " .. tileY .. "): " .. tostring(map:getInputTile (tileX, tileY, "meat")))
            print ("Plants input @ (" .. tileX .. ", " .. tileY .. "): " .. tostring(map:getInputTile (tileX, tileY, "plants")))
            print ("Waste input @ (" .. tileX .. ", " .. tileY .. "): " .. tostring(map:getInputTile (tileX, tileY, "waste")))
            print ()
        else
            local cellToPrint = map:getCell (tileX, tileY)

            if cellToPrint ~= nil then
                if love.keyboard.isDown ("lctrl") == true then
                    cell:printNetwork (map:getCell (tileX, tileY))
                else
                    cell:printCellInfo (map:getCell (tileX, tileY))
                end
            end
        end

    -- Prints pheromone levels at the cursor tile
    elseif key == "p" then
        local tileX, tileY = map:screenToMap (love.mouse.getPosition ())
        local pheromones = map:getEnvValue (tileX, tileY, "pheromones")

        if pheromones ~= nil then
            print ("Pheromones @ (" .. tileX .. ", " .. tileY .. "):")

            local strongestIndex = 0
            local strongestValue = 0
            for i = 1, cell.pheromones do
                local value = pheromones[i] or 0
                if value > strongestValue then
                    strongestValue = value
                    strongestIndex = i
                end

                print ("  P" .. i .. ": " .. value)
            end

            print ("  Strongest: " .. strongestIndex .. " (" .. strongestValue .. ")")
            print ()
        else
            print ("No tile at (" .. tileX .. ", " .. tileY .. ")")
        end

    -- Get time since start of the simulation
    elseif key == "t" then
        print ("Time elapsed since the start of the sim: " .. round (((os.time () - startTime) / 60), 0.01) .. " minutes")

    -- Toggle rendering
    elseif key == "z" then
        renderMap = not renderMap

    -- Show total energy
    elseif key == "v" then
        print ("Total energy: " .. map.totalEnergy)

    -- Toggle energy imbalance warnings
    elseif key == "u" then
        map.energyImbalanceMessagesEnabled = not map.energyImbalanceMessagesEnabled

        if map.energyImbalanceMessagesEnabled == true then
            print ("Energy imbalance warnings enabled")
        else
            map.lastEnergyImbalanceLogTime = love.timer.getTime ()
            print ("Energy imbalance warnings disabled; periodic reminders every " .. (map.energyImbalanceLogInterval / 60) .. " minutes")
        end

    -- Mutate cell
    elseif key == "o" then
        if love.keyboard.isDown ("lctrl") then
            local tileX, tileY = map:screenToMap (love.mouse.getPosition ())
            local cellObj = map:getCell (tileX, tileY)

            if cellObj then
                for i = 1, 5000 do
                    cell:mutate (cellObj)
                end
                print ("(" .. tostring (cellObj) .. ") Cell mutated!")
            end
        end
    
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

    -- Print cell colors
    elseif key == "b" then
        print ("======== Cell Colors ========")
        for superparent = 1, superparents do
            local color = map.superparentColors[superparent]
            print (superparent .. ": " .. color[1] .. ", " .. color[2] .. ", " .. color[3])
        end

    -- Open sub rendering mode selector
    elseif key == "n" then
        openRenderSelector ("submode")

    -- Open rendering mode selector
    elseif key == "m" then
        openRenderSelector ("mode")

    elseif key == "'" then
        love.system.openURL ("file://"..love.filesystem.getSaveDirectory()) -- TEMP, this will fail on android

    elseif key == "l" then
        map.stopOnError = not map.stopOnError
        print ("Stop on error: " .. tostring (map.stopOnError))

    -- Toggle between cells and walls display
    elseif key == "c" then
        showWalls = not showWalls
        if showWalls then
            print ("Display switched to walls count")
        else
            print ("Display switched to cells count")
        end

    -- Toggle superparent kill count display
    elseif key == "j" then
        showSuperparentKills = not showSuperparentKills
        print ("Superparent kill display: " .. tostring (showSuperparentKills))

    -- Reduce tile energy by 25%
    elseif key == "x" then
        local totalReduction = 0
        map:getTiles (function (tileX, tileY, envTile)
            local oldMeat = map:getInputTile (tileX, tileY, "meat")
            local oldPlants = map:getInputTile (tileX, tileY, "plants")
            local oldWaste = map:getInputTile (tileX, tileY, "waste")
            
            local newMeat = math.floor (oldMeat * 0.75)
            local newPlants = math.floor (oldPlants * 0.75)
            local newWaste = math.floor (oldWaste * 0.75)
            
            map:setInputTile (tileX, tileY, "meat", newMeat)
            map:setInputTile (tileX, tileY, "plants", newPlants)
            map:setInputTile (tileX, tileY, "waste", newWaste)
            
            totalReduction = totalReduction + (oldMeat - newMeat) + (oldPlants - newPlants) + (oldWaste - newWaste)
        end)
        map.totalEnergy = map.totalEnergy - totalReduction
        print ("Tile energy reduced by 25% (total reduction: " .. totalReduction .. ")")
    end
end

function thisScene:textinput (text)
    saveUiManager:textinput (text)
end

function thisScene:mousereleased (x, y, button)
    local tileX, tileY = map:screenToMap (x, y)
end

return thisScene