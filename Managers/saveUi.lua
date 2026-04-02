local utf8 = require ("utf8")

local saveUi = {}

local function getSaveSystemOrError (self)
    local saveSystem = self.map:getSaveSystem ()
    if saveSystem == nil then
        self:setStatus ("Save system unavailable")
        print ("[SAVE ERROR] Save system is not initialized")
        return nil
    end

    return saveSystem
end

function saveUi:new (mapRef)
    assert (type (mapRef) == "table", "mapRef must be a table")

    local obj = {
        map = mapRef,
        dialog = {
            active = false,
            mode = "load",
            selectedIndex = 1,
            entries = {},
            nameInput = "",
            status = "",
            statusTimer = 0,
        },
    }

    for k, v in pairs (self) do
        if k ~= "new" and type (v) == "function" then
            obj[k] = v
        end
    end

    return obj
end

function saveUi:setStatus (msg)
    self.dialog.status = msg or ""
    self.dialog.statusTimer = 5
end

function saveUi:getHintText ()
    return "M/N render selector | G quicksave | H quickload | F5 load | F6 save-as"
end

function saveUi:refreshEntries ()
    local saveSystem = getSaveSystemOrError (self)
    if saveSystem == nil then
        self.dialog.entries = {}
        return
    end

    self.dialog.entries = saveSystem:listSaveFiles (true)

    if self.dialog.selectedIndex < 1 then
        self.dialog.selectedIndex = 1
    elseif self.dialog.selectedIndex > #self.dialog.entries then
        self.dialog.selectedIndex = #self.dialog.entries
    end

    if self.dialog.selectedIndex <= 0 then
        self.dialog.selectedIndex = 1
    end
end

function saveUi:openLoadDialog ()
    self.dialog.active = true
    self.dialog.mode = "load"
    self:refreshEntries ()
end

function saveUi:openSaveAsDialog ()
    self.dialog.active = true
    self.dialog.mode = "saveAs"
    self.dialog.nameInput = self.map.title .. "_" .. os.date ("%Y-%m-%d_%H-%M-%S")
end

function saveUi:doQuickSave ()
    local saveSystem = getSaveSystemOrError (self)
    if saveSystem == nil then
        return false
    end

    local ok, err = saveSystem:quickSave ()
    if ok == false then
        self:setStatus ("Quicksave failed")
        print ("[SAVE ERROR] Quicksave failed: " .. tostring (err))
        return false
    end

    self:setStatus ("Quicksave complete")
    return true
end

function saveUi:doQuickLoad ()
    local saveSystem = getSaveSystemOrError (self)
    if saveSystem == nil then
        return false
    end

    local ok, err = saveSystem:loadFromPath (saveSystem:getQuickSavePath ())
    if ok == false then
        self:setStatus ("Quickload failed")
        print ("[LOAD ERROR] Quickload failed: " .. tostring (err))
        return false
    end

    self:setStatus ("Quickload complete")
    return true
end

function saveUi:loadSelectedSave ()
    local selected = self.dialog.entries[self.dialog.selectedIndex]
    if selected == nil then
        self:setStatus ("No save file selected")
        return false
    end

    local saveSystem = getSaveSystemOrError (self)
    if saveSystem == nil then
        return false
    end

    local ok, err = saveSystem:loadFromPath (selected.path)
    if ok == false then
        self:setStatus ("Load failed")
        print ("[LOAD ERROR] Save load failed: " .. tostring (err))
        return false
    end

    self.dialog.active = false
    self:setStatus ("Loaded " .. selected.name)
    return true
end

function saveUi:submitSaveAs ()
    local trimmed = string.gsub (self.dialog.nameInput or "", "^%s*(.-)%s*$", "%1")
    if trimmed == "" then
        self:setStatus ("Save name is empty")
        return false
    end

    local saveSystem = getSaveSystemOrError (self)
    if saveSystem == nil then
        return false
    end

    local ok, err = saveSystem:saveAs (trimmed)
    if ok == false then
        self:setStatus ("Save failed")
        print ("[SAVE ERROR] Save As failed: " .. tostring (err))
        return false
    end

    self.dialog.active = false
    self:setStatus ("Saved as " .. trimmed .. ".slf")
    return true
end

function saveUi:deleteSelectedSave ()
    local selected = self.dialog.entries[self.dialog.selectedIndex]
    if selected == nil then
        self:setStatus ("No save selected")
        return false
    end

    local ok, err = love.filesystem.remove (selected.path)
    if ok == false then
        self:setStatus ("Delete failed")
        print ("[SAVE ERROR] Failed to delete save: " .. tostring (selected.path) .. " - " .. tostring (err))
        return false
    end

    self:setStatus ("Deleted " .. selected.name)
    self:refreshEntries ()
    return true
end

function saveUi:update (dt)
    if self.dialog.statusTimer > 0 then
        self.dialog.statusTimer = self.dialog.statusTimer - dt
        if self.dialog.statusTimer <= 0 then
            self.dialog.status = ""
        end
    end
end

function saveUi:draw ()
    if self.dialog.status ~= "" then
        love.graphics.setColor (0, 0, 0, 0.80)
        love.graphics.rectangle ("fill", 350, 10, 240, 25)
        love.graphics.setColor (1, 1, 1, 1)
        love.graphics.printf (self.dialog.status, 355, 15, 230, "left")
    end

    if self.dialog.active == true then
        local panelX, panelY, panelW, panelH = 180, 95, 440, 380
        love.graphics.setColor (0, 0, 0, 0.9)
        love.graphics.rectangle ("fill", panelX, panelY, panelW, panelH)
        love.graphics.setColor (1, 1, 1, 1)

        if self.dialog.mode == "load" then
            love.graphics.printf ("Load Save (.slf)", panelX + 10, panelY + 10, panelW - 20, "left")
            love.graphics.printf ("Up/Down select | Enter load | Del delete | Esc close", panelX + 10, panelY + 30, panelW - 20, "left")

            if #self.dialog.entries <= 0 then
                love.graphics.printf ("No save files found", panelX + 10, panelY + 60, panelW - 20, "left")
            else
                local maxRows = 14
                local startIndex = math.max (1, self.dialog.selectedIndex - 6)
                local endIndex = math.min (#self.dialog.entries, startIndex + maxRows - 1)

                for i = startIndex, endIndex do
                    local rowY = panelY + 60 + (i - startIndex) * 22
                    local entry = self.dialog.entries[i]
                    if i == self.dialog.selectedIndex then
                        love.graphics.setColor (0.1, 0.35, 0.65, 0.85)
                        love.graphics.rectangle ("fill", panelX + 8, rowY - 1, panelW - 16, 20)
                    end

                    love.graphics.setColor (1, 1, 1, 1)
                    local label = entry.name .. " (" .. math.floor ((entry.size or 0) / 1024) .. " KB)"
                    love.graphics.printf (label, panelX + 12, rowY, panelW - 24, "left")
                end
            end
        else
            love.graphics.printf ("Save As (.slf)", panelX + 10, panelY + 10, panelW - 20, "left")
            love.graphics.printf ("Type name, Enter save, Esc cancel", panelX + 10, panelY + 30, panelW - 20, "left")

            love.graphics.setColor (0.08, 0.08, 0.08, 1)
            love.graphics.rectangle ("fill", panelX + 10, panelY + 62, panelW - 20, 28)
            love.graphics.setColor (1, 1, 1, 1)
            love.graphics.rectangle ("line", panelX + 10, panelY + 62, panelW - 20, 28)
            love.graphics.printf (self.dialog.nameInput, panelX + 14, panelY + 70, panelW - 28, "left")
        end
    end
end

function saveUi:keypressed (key)
    if self.dialog.active == false then
        return false
    end

    if key == "escape" then
        self.dialog.active = false
        return true
    end

    if self.dialog.mode == "load" then
        if key == "up" then
            self.dialog.selectedIndex = math.max (1, self.dialog.selectedIndex - 1)
        elseif key == "down" then
            self.dialog.selectedIndex = math.min (#self.dialog.entries, self.dialog.selectedIndex + 1)
        elseif key == "return" or key == "kpenter" then
            self:loadSelectedSave ()
        elseif key == "delete" then
            self:deleteSelectedSave ()
        elseif key == "r" then
            self:refreshEntries ()
        end
    else
        if key == "backspace" then
            local byteoffset = utf8.offset (self.dialog.nameInput, -1)
            if byteoffset then
                self.dialog.nameInput = string.sub (self.dialog.nameInput, 1, byteoffset - 1)
            end
        elseif key == "return" or key == "kpenter" then
            self:submitSaveAs ()
        end
    end

    return true
end

function saveUi:handleGlobalHotkeys (key)
    if key == "g" then
        self:doQuickSave ()
        return true
    elseif key == "h" then
        self:doQuickLoad ()
        return true
    elseif key == "f5" then
        self:openLoadDialog ()
        return true
    elseif key == "f6" then
        self:openSaveAsDialog ()
        return true
    elseif key == "s" and (love.keyboard.isDown ("lctrl") or love.keyboard.isDown ("rctrl")) then
        self:openSaveAsDialog ()
        return true
    end

    return false
end

function saveUi:textinput (text)
    if self.dialog.active == true and self.dialog.mode == "saveAs" then
        if string.match (text, "[%w%-%_ ]") then
            self.dialog.nameInput = self.dialog.nameInput .. text
        end
        return true
    end

    return false
end

return saveUi
