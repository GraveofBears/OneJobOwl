-- OneJobOwl_Options.lua
-- Options panel, laid out as one scrollable column:
--   General          -> enable, mode, tracking scope
--   Shame Button     -> sound, unlock/mover, scale
--   I Am Owl         -> report, output (bubble/chat), clutch window, bubble mover/scale/duration
--   Output & Targets -> channel, moonkin name, FF enemy
--   Shame Messages   -> editable shame list
--   Praise Messages  -> editable praise list (I Am Owl)

local ADDON_NAME, NS = ...

function NS.CreateOptions()
    local optionsFrame = CreateFrame("Frame", "OneJobOwlOptions", UIParent)
    optionsFrame.name = "OneJobOwl"

    -- ===== Whole-panel scroll =====
    local panelScroll = CreateFrame("ScrollFrame", "OneJobOwlPanelScroll", optionsFrame, "UIPanelScrollFrameTemplate")
    panelScroll:SetPoint("TOPLEFT", 10, -10)
    panelScroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local c = CreateFrame("Frame", nil, panelScroll) -- everything anchors to this
    c:SetSize(540, 100) -- height set after layout
    panelScroll:SetScrollChild(c)

    local y = 8 -- vertical layout cursor

    -- ===== layout helpers: consistent spacing everywhere =====
    local GAP_SECTION = 18 -- breathing room before each new section header
    local GAP_CONTROL = 10 -- breathing room after a control row

    local function Header(text)
        y = y + GAP_SECTION
        local fs = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOPLEFT", 5, -y)
        fs:SetText(text)
        y = y + 26
        local line = c:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 0.55, 0, 0.3)
        line:SetSize(530, 1)
        line:SetPoint("TOPLEFT", 5, -y)
        y = y + 12
        return fs
    end

    local function Note(text, indent)
        local fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", indent or 10, -y)
        fs:SetWidth(520 - (indent or 10))
        fs:SetJustifyH("LEFT")
        fs:SetText("|cffaaaaaa" .. text .. "|r")
        y = y + fs:GetStringHeight() + GAP_CONTROL
        return fs
    end

    local function Check(name, label, onClick)
        local cb = CreateFrame("CheckButton", name, c, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 5, -y)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb:SetScript("OnClick", onClick)
        y = y + 30 + GAP_CONTROL
        return cb
    end

    local function Label(text)
        local fs = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 10, -y)
        fs:SetText(text)
        y = y + 16
        return fs
    end

    local function Slider(name, minV, maxV, step, getValue, fmt, onChanged)
        local s = CreateFrame("Slider", name, c, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", 15, -y)
        s:SetWidth(220)
        s:SetMinMaxValues(minV, maxV)
        s:SetValue(getValue())
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        _G[s:GetName() .. "Text"]:SetText(fmt(getValue()))
        _G[s:GetName() .. "Low"]:SetText(tostring(minV))
        _G[s:GetName() .. "High"]:SetText(tostring(maxV))
        s:SetScript("OnValueChanged", function(slf, val)
            onChanged(val)
            _G[slf:GetName() .. "Text"]:SetText(fmt(val))
        end)
        y = y + 46 + GAP_CONTROL
        return s
    end

    -- =====================================================================
    Header("General")

    local enableCheck = Check("OneJobOwlEnable", "Enable OneJobOwl Tracking", function(s)
        OneJobOwlDB.enabled = s:GetChecked()
        if not OneJobOwlDB.enabled then NS.ResetTargetState() end
    end)
    enableCheck:SetChecked(OneJobOwlDB.enabled)

    local modeLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLabel:SetPoint("TOPLEFT", 10, -y - 4)
    modeLabel:SetText("Mode:")

    local btnRadio = CreateFrame("CheckButton", "OneJobOwlModeButton", c, "UIRadioButtonTemplate")
    btnRadio:SetPoint("TOPLEFT", 60, -y)
    _G[btnRadio:GetName() .. "Text"]:SetText("Shame Button")

    local autoRadio = CreateFrame("CheckButton", "OneJobOwlModeAuto", c, "UIRadioButtonTemplate")
    autoRadio:SetPoint("TOPLEFT", 200, -y)
    _G[autoRadio:GetName() .. "Text"]:SetText("Auto-Shame")

    local owlRadio = CreateFrame("CheckButton", "OneJobOwlModeIamOwl", c, "UIRadioButtonTemplate")
    owlRadio:SetPoint("TOPLEFT", 340, -y)
    _G[owlRadio:GetName() .. "Text"]:SetText("I Am Owl")
    y = y + 26 + GAP_CONTROL

    local function SetMode(mode)
        OneJobOwlDB.mode = mode
        btnRadio:SetChecked(mode == "BUTTON")
        autoRadio:SetChecked(mode == "AUTO")
        owlRadio:SetChecked(mode == "IAMOWL")

        if (mode == "AUTO" or mode == "IAMOWL") and not NS.IsButtonMoverOn() then
            NS.HideShameButton()
        end
    end

    btnRadio:SetScript("OnClick", function() SetMode("BUTTON") end)
    autoRadio:SetScript("OnClick", function() SetMode("AUTO") end)
    owlRadio:SetScript("OnClick", function() SetMode("IAMOWL") end)
    SetMode(OneJobOwlDB.mode or "BUTTON")

    Note("Shame Button: the owl appears when IFF expires; click to shame. Auto-Shame: sends the message automatically. I Am Owl: praises your own uptime live and grades you after each fight.")

    Label("Track on")
    local scopes = {
        { text = "Bosses only (skull)", value = "BOSS" },
        { text = "Bosses & elites",     value = "ELITE" },
        { text = "Everything",          value = "ALL" },
    }
    local function ScopeTextFor(value)
        for _, s in ipairs(scopes) do
            if s.value == value then return s.text end
        end
        return scopes[1].text
    end

    local scopeDD = CreateFrame("Frame", "OneJobOwlScopeDD", c, "UIDropDownMenuTemplate")
    scopeDD:SetPoint("TOPLEFT", -10, -y)
    UIDropDownMenu_SetWidth(scopeDD, 150)
    UIDropDownMenu_Initialize(scopeDD, function()
        for _, s in ipairs(scopes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.checked = s.text, s.value, (OneJobOwlDB.trackScope == s.value)
            info.func = function(sel)
                OneJobOwlDB.trackScope = sel.value
                UIDropDownMenu_SetSelectedValue(scopeDD, sel.value)
                UIDropDownMenu_SetText(scopeDD, ScopeTextFor(sel.value))
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(scopeDD, OneJobOwlDB.trackScope or "BOSS")
    UIDropDownMenu_SetText(scopeDD, ScopeTextFor(OneJobOwlDB.trackScope or "BOSS"))

    local combatCheck = CreateFrame("CheckButton", "OneJobOwlCombatOnly", c, "UICheckButtonTemplate")
    combatCheck:SetPoint("LEFT", scopeDD, "RIGHT", 0, 2)
    _G[combatCheck:GetName() .. "Text"]:SetText("Only while in combat")
    combatCheck:SetScript("OnClick", function(s) OneJobOwlDB.combatOnly = s:GetChecked() end)
    combatCheck:SetChecked(OneJobOwlDB.combatOnly)
    y = y + 34 + GAP_CONTROL

    -- =====================================================================
    Header("Shame Button")

    Note("Pops up when Faerie Fire falls off. It retracts if FF is reapplied, or on its own after 10 seconds.")

    Label("Alert Sound")
    local soundDD = CreateFrame("Frame", "OneJobOwlSoundDD", c, "UIDropDownMenuTemplate")
    soundDD:SetPoint("TOPLEFT", -10, -y)
    UIDropDownMenu_SetWidth(soundDD, 150)
    local function SoundNameForID(id)
        for _, s in ipairs(NS.sounds) do
            if s.id == id then return s.name end
        end
        return "None"
    end
    UIDropDownMenu_Initialize(soundDD, function()
        for _, s in ipairs(NS.sounds) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.checked = s.name, s.id, (OneJobOwlDB.sound == s.id)
            info.func = function(sel)
                OneJobOwlDB.sound = sel.value
                UIDropDownMenu_SetSelectedValue(soundDD, sel.value)
                UIDropDownMenu_SetText(soundDD, SoundNameForID(sel.value))
                NS.PlayShameSound() -- instant preview on select
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(soundDD, OneJobOwlDB.sound or 8959)
    UIDropDownMenu_SetText(soundDD, SoundNameForID(OneJobOwlDB.sound or 8959))

    local previewBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    previewBtn:SetSize(55, 22)
    previewBtn:SetPoint("LEFT", soundDD, "RIGHT", -8, 2)
    previewBtn:SetText("Play")
    previewBtn:SetScript("OnClick", NS.PlayShameSound)
    y = y + 34 + GAP_CONTROL

    local moverCheck = Check("OneJobOwlMover", "Unlock button (drag the owl to move it)", function(s)
        NS.SetButtonMover(s:GetChecked())
    end)
    moverCheck:SetChecked(false)

    local scaleSlider = Slider("OneJobOwlScaleSlider", 0.5, 2.0, 0.05,
        function() return OneJobOwlDB.buttonScale or 1 end,
        function(v) return ("Button Scale: %d%%"):format(v * 100 + 0.5) end,
        function(v) NS.SetButtonScale(v) end)
    _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[scaleSlider:GetName() .. "High"]:SetText("200%")

    -- =====================================================================
    Header("I Am Owl")

    local reportCheck = Check("OneJobOwlIamOwlReport", "Show after-battle report (grade & stats)", function(s)
        OneJobOwlDB.iamowlReport = s:GetChecked() and true or false
    end)
    reportCheck:SetChecked(OneJobOwlDB.iamowlReport ~= false)

    Label("Output")
    local outputs = {
        { text = "Owl Bubble (on screen)",    value = "BUBBLE" },
        { text = "Chat (uses Channel below)", value = "CHAT" },
    }
    local function OutputTextFor(value)
        for _, o in ipairs(outputs) do
            if o.value == value then return o.text end
        end
        return outputs[1].text
    end

    local outputDD = CreateFrame("Frame", "OneJobOwlOutputDD", c, "UIDropDownMenuTemplate")
    outputDD:SetPoint("TOPLEFT", -10, -y)
    UIDropDownMenu_SetWidth(outputDD, 170)
    UIDropDownMenu_Initialize(outputDD, function()
        for _, o in ipairs(outputs) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.checked = o.text, o.value, ((OneJobOwlDB.iamowlOutput or "BUBBLE") == o.value)
            info.func = function(sel)
                OneJobOwlDB.iamowlOutput = sel.value
                UIDropDownMenu_SetSelectedValue(outputDD, sel.value)
                UIDropDownMenu_SetText(outputDD, OutputTextFor(sel.value))
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(outputDD, OneJobOwlDB.iamowlOutput or "BUBBLE")
    UIDropDownMenu_SetText(outputDD, OutputTextFor(OneJobOwlDB.iamowlOutput or "BUBBLE"))

    local bubblePreviewBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    bubblePreviewBtn:SetSize(70, 22)
    bubblePreviewBtn:SetPoint("LEFT", outputDD, "RIGHT", -8, 2)
    bubblePreviewBtn:SetText("Preview")
    bubblePreviewBtn:SetScript("OnClick", function() NS.PreviewOwlBubble() end)
    y = y + 34 + GAP_CONTROL

    local clutchSlider = Slider("OneJobOwlClutchSlider", 1, 10, 1,
        function() return OneJobOwlDB.tightWindow or 8 end,
        function(v) return ("Clutch Window: %ds"):format(v) end,
        function(v) OneJobOwlDB.tightWindow = math.floor(v) end)
    _G[clutchSlider:GetName() .. "Low"]:SetText("1s")
    _G[clutchSlider:GetName() .. "High"]:SetText("10s")

    Note("Refreshing Faerie Fire with this many seconds (or fewer) remaining counts as a clutch refresh: live praise plus a better efficiency grade. Refreshing earlier is never penalized -- it just earns no clutch credit. Letting FF hit 0 is a drop and gets shamed.", 15)

    local bubbleMoverCheck = Check("OneJobOwlBubbleMover", "Unlock owl bubble (drag the owl to move it)", function(s)
        NS.SetBubbleMover(s:GetChecked())
    end)
    bubbleMoverCheck:SetChecked(false)

    local bubbleScaleSlider = Slider("OneJobOwlBubbleScaleSlider", 0.5, 2.0, 0.05,
        function() return OneJobOwlDB.bubbleScale or 1 end,
        function(v) return ("Owl Icon Scale: %d%%"):format(v * 100 + 0.5) end,
        function(v) NS.SetBubbleScale(v) end)
    _G[bubbleScaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[bubbleScaleSlider:GetName() .. "High"]:SetText("200%")

    local balloonScaleSlider = Slider("OneJobOwlBalloonScaleSlider", 0.5, 2.0, 0.05,
        function() return OneJobOwlDB.balloonScale or 1.0 end,
        function(v) return ("Balloon Scale: %d%%"):format(v * 100 + 0.5) end,
        function(v) NS.SetBalloonScale(v) end)
    _G[balloonScaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[balloonScaleSlider:GetName() .. "High"]:SetText("200%")

-- ... inside the "I Am Owl" section ...

    local bubbleDurSlider = Slider("OneJobOwlBubbleDurSlider", 3, 15, 1,
        function() return OneJobOwlDB.bubbleDuration or 6 end,
        function(v) return ("Message Duration: %ds"):format(v) end,
        function(v) OneJobOwlDB.bubbleDuration = math.floor(v) end)
    _G[bubbleDurSlider:GetName() .. "Low"]:SetText("3s")
    _G[bubbleDurSlider:GetName() .. "High"]:SetText("15s")

    -- ADD THIS BLOCK:
    Label("Praise Sound (I Am Owl)")
    local owlSoundDD = CreateFrame("Frame", "OneJobOwlIamOwlSoundDD", c, "UIDropDownMenuTemplate")
    owlSoundDD:SetPoint("TOPLEFT", -10, -y)
    UIDropDownMenu_SetWidth(owlSoundDD, 150)
    
    UIDropDownMenu_Initialize(owlSoundDD, function()
        for _, s in ipairs(NS.sounds) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.checked = s.name, s.id, (OneJobOwlDB.iamowlSound == s.id)
            info.func = function(sel)
                OneJobOwlDB.iamowlSound = sel.value
                UIDropDownMenu_SetSelectedValue(owlSoundDD, sel.value)
                UIDropDownMenu_SetText(owlSoundDD, s.name)
                NS.PlaySoundByID(sel.value) -- Preview
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(owlSoundDD, OneJobOwlDB.iamowlSound or 0)
    UIDropDownMenu_SetText(owlSoundDD, (function() 
        for _, s in ipairs(NS.sounds) do if s.id == (OneJobOwlDB.iamowlSound or 0) then return s.name end end
        return "None"
    end)())

    local owlPreviewBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    owlPreviewBtn:SetSize(55, 22)
    owlPreviewBtn:SetPoint("LEFT", owlSoundDD, "RIGHT", -8, 2)
    owlPreviewBtn:SetText("Play")
    owlPreviewBtn:SetScript("OnClick", function() NS.PlaySoundByID(OneJobOwlDB.iamowlSound or 0) end)
    y = y + 34 + GAP_CONTROL

    -- =====================================================================
    Header("Output & Targets")

    Label("Channel")
    local dd = CreateFrame("Frame", "OneJobOwlChannelDD", c, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", -10, -y)
    UIDropDownMenu_SetWidth(dd, 110)
    UIDropDownMenu_Initialize(dd, function()
        for _, val in ipairs({"WHISPER", "RAID", "PARTY", "SAY", "YELL"}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.checked = val, val, (OneJobOwlDB.channel == val)
            info.func = function(s)
                OneJobOwlDB.channel = s.value
                UIDropDownMenu_SetSelectedValue(dd, s.value)
                UIDropDownMenu_SetText(dd, s.value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(dd, OneJobOwlDB.channel or "WHISPER")
    UIDropDownMenu_SetText(dd, OneJobOwlDB.channel or "WHISPER")
    y = y + 34 + GAP_CONTROL

    Label("Your Moonkin (whisper target)")
    local nameInput = CreateFrame("EditBox", "OneJobOwlMoonkinName", c, "InputBoxTemplate")
    nameInput:SetSize(160, 25)
    nameInput:SetPoint("TOPLEFT", 15, -y)
    nameInput:SetAutoFocus(false)
    nameInput:SetText(OneJobOwlDB.moonkinName or "")
    -- Save ONLY on Enter. Losing focus reverts the display to the saved
    -- value, so nothing can silently overwrite or blank the name.
    nameInput:SetScript("OnEnterPressed", function(s)
        local txt = s:GetText():gsub("^%s+", ""):gsub("%s+$", "")
        if txt ~= "" then
            NS.SetMoonkin(txt)
        else
            NS.ClearMoonkin()
        end
        s:ClearFocus()
    end)
    nameInput:SetScript("OnEditFocusLost", function(s)
        s:SetText(OneJobOwlDB.moonkinName or "")
    end)
    nameInput:SetScript("OnEscapePressed", function(s)
        s:SetText(OneJobOwlDB.moonkinName or "")
        s:ClearFocus()
    end)

    local targetBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    targetBtn:SetSize(70, 22)
    targetBtn:SetPoint("LEFT", nameInput, "RIGHT", 8, 0)
    targetBtn:SetText("Target")
    targetBtn:SetScript("OnClick", function()
        nameInput:ClearFocus() -- commit/revert any half-typed text first
        NS.SetMoonkinFromTarget()
    end)

    local clearBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    clearBtn:SetSize(70, 22)
    clearBtn:SetPoint("LEFT", targetBtn, "RIGHT", 6, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        nameInput:ClearFocus()
        NS.ClearMoonkin()
    end)
    y = y + 30 + GAP_CONTROL

    -- always-true readout of what's actually saved, independent of the editbox
    local moonkinStatus = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    moonkinStatus:SetPoint("TOPLEFT", 15, -y)
    moonkinStatus:SetJustifyH("LEFT")
    local function UpdateMoonkinStatus()
        if NS.HasMoonkinSet() then
            moonkinStatus:SetText("|cff44ff44Current moonkin: " .. OneJobOwlDB.moonkinName .. "|r")
        else
            moonkinStatus:SetText("|cffff6666No moonkin set (self-shame mode)|r")
        end
    end
    UpdateMoonkinStatus()
    y = y + 18 + GAP_CONTROL

    Note("Type a name and press Enter to save it, or use Target / Clear. From chat: /shame Name, /shame target, /shameclear. /ojo test sends a test message.", 15)

    Label("FF Enemy (the mob being watched)")
    local enemySetBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    enemySetBtn:SetSize(110, 22)
    enemySetBtn:SetPoint("TOPLEFT", 15, -y)
    enemySetBtn:SetText("Set from Target")
    enemySetBtn:SetScript("OnClick", function() NS.SetFFEnemyFromTarget() end)

    local enemyClearBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    enemyClearBtn:SetSize(70, 22)
    enemyClearBtn:SetPoint("LEFT", enemySetBtn, "RIGHT", 6, 0)
    enemyClearBtn:SetText("Clear")
    enemyClearBtn:SetScript("OnClick", function()
        if NS.GetFFEnemyName() then NS.ClearFFEnemy("manual") end
    end)
    y = y + 30 + GAP_CONTROL

    local enemyStatus = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    enemyStatus:SetPoint("TOPLEFT", 15, -y)
    enemyStatus:SetJustifyH("LEFT")
    local function UpdateEnemyStatus()
        local name = NS.GetFFEnemyName()
        if name then
            enemyStatus:SetText("|cff44ff44Watching: " .. name .. "|r")
        else
            enemyStatus:SetText("|cffaaaaaaNone set -- tracking follows your current target instead|r")
        end
    end
    UpdateEnemyStatus()
    y = y + 18 + GAP_CONTROL

    Note("Watched by GUID via your target, focus, or its nameplate, so you can target adds freely. Auto-clears when combat ends or it dies. Chat: /fftarget sets from target, /ffclear clears.", 15)

    -- =====================================================================
    -- Shared builder for the two message-list editors (shames & praises).
    -- Each gets its own scroll list, Edit/Del rows, add box, and a
    -- confirmation-gated Restore Defaults button.
    local function BuildMessageEditor(cfg)
        local editingIndex = nil
        local rows = {}
        local input, addBtn

        local scrollFrame = CreateFrame("ScrollFrame", nil, c, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 5, -y)
        scrollFrame:SetSize(490, 180)
        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetSize(470, 10)
        scrollFrame:SetScrollChild(content)
        y = y + 190 + GAP_CONTROL

        local function ResetEditState()
            editingIndex = nil
            input:SetText("")
            addBtn:SetText("Add")
        end

        local function RefreshList()
            local list = cfg.getList() or {}
            for i, text in ipairs(list) do
                local row = rows[i]
                if not row then
                    row = CreateFrame("Frame", nil, content)
                    row:SetSize(470, 24)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)

                    row.lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.lbl:SetPoint("LEFT")
                    row.lbl:SetWidth(360)
                    row.lbl:SetJustifyH("LEFT")
                    row.lbl:SetWordWrap(false)

                    row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.del:SetSize(36, 20)
                    row.del:SetPoint("RIGHT")
                    row.del:SetText("Del")

                    row.edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.edit:SetSize(40, 20)
                    row.edit:SetPoint("RIGHT", row.del, "LEFT", -2, 0)
                    row.edit:SetText("Edit")

                    rows[i] = row
                end
                row.lbl:SetText(text)
                row.del:SetScript("OnClick", function()
                    table.remove(cfg.getList(), i)
                    if editingIndex == i then ResetEditState() end
                    RefreshList()
                end)
                row.edit:SetScript("OnClick", function()
                    editingIndex = i
                    input:SetText(cfg.getList()[i])
                    input:SetFocus()
                    addBtn:SetText("Save")
                end)
                row:Show()
            end
            for i = #list + 1, #rows do rows[i]:Hide() end
            content:SetHeight(math.max(#list * 26, 10))
        end

        input = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
        input:SetSize(280, 30)
        input:SetPoint("TOPLEFT", 12, -y)
        input:SetAutoFocus(false)
        input:SetScript("OnEscapePressed", function(s)
            ResetEditState()
            s:ClearFocus()
        end)

        addBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)
        addBtn:SetSize(55, 25)
        addBtn:SetText("Add")
        local function Commit()
            local text = input:GetText()
            if text == "" then return end
            local list = cfg.getList()
            if editingIndex and list[editingIndex] then
                list[editingIndex] = text
                editingIndex = nil
                addBtn:SetText("Add")
            else
                table.insert(list, text)
            end
            input:SetText("")
            input:ClearFocus()
            RefreshList()
        end
        addBtn:SetScript("OnClick", Commit)
        input:SetScript("OnEnterPressed", Commit)

        local restoreBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        restoreBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        restoreBtn:SetSize(110, 25)
        restoreBtn:SetText("Restore Defaults")
        restoreBtn:SetScript("OnClick", function()
            StaticPopupDialogs[cfg.popupKey] = StaticPopupDialogs[cfg.popupKey] or {
                text = cfg.popupText,
                button1 = YES,
                button2 = NO,
                OnAccept = function()
                    cfg.onRestore()
                    ResetEditState()
                    RefreshList()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show(cfg.popupKey)
        end)
        y = y + 36 + GAP_CONTROL

        return RefreshList
    end

    -- =====================================================================
    Header("Shame Messages")
    Note("Sent when Faerie Fire falls off. Edit or delete any of them. Enter saves; Escape cancels an edit.")
    local RefreshShameList = BuildMessageEditor({
        getList = function() return OneJobOwlDB.shames end,
        popupKey = "ONEJOBOWL_RESTORE",
        popupText = "Wipe your shame list and restore the defaults? Custom and edited messages will be lost.",
        onRestore = function() NS.SeedShames(true) end,
    })

    -- =====================================================================
    Header("Praise Messages (I Am Owl)")
    Note("Shown on clutch refreshes in I Am Owl mode. Edit or delete any of them. Enter saves; Escape cancels an edit.")
    local RefreshPraiseList = BuildMessageEditor({
        getList = function() return OneJobOwlDB.praises end,
        popupKey = "ONEJOBOWL_RESTORE_PRAISES",
        popupText = "Wipe your praise list and restore the defaults? Custom and edited messages will be lost.",
        onRestore = function() NS.SeedPraises(true) end,
    })

    c:SetHeight(y + 30) -- final scrollable height

    RefreshShameList()
    RefreshPraiseList()

    -- Don't leave the movers stuck on if the panel closes
    optionsFrame:SetScript("OnHide", function()
        if NS.IsButtonMoverOn() then
            NS.SetButtonMover(false)
            moverCheck:SetChecked(false)
        end
        if NS.IsBubbleMoverOn and NS.IsBubbleMoverOn() then
            NS.SetBubbleMover(false)
            bubbleMoverCheck:SetChecked(false)
        end
    end)

    function NS.RefreshOptions()
        nameInput:SetText(OneJobOwlDB.moonkinName or "")
        UpdateMoonkinStatus()
        UpdateEnemyStatus()
        UIDropDownMenu_SetSelectedValue(dd, OneJobOwlDB.channel or "WHISPER")
        UIDropDownMenu_SetText(dd, OneJobOwlDB.channel or "WHISPER")
		UIDropDownMenu_SetSelectedValue(soundDD, OneJobOwlDB.sound or 8959)
        UIDropDownMenu_SetText(soundDD, SoundNameForID(OneJobOwlDB.sound or 8959))
        
        UIDropDownMenu_SetSelectedValue(owlSoundDD, OneJobOwlDB.iamowlSound or 0)
        local owlSoundName = "None"
        for _, s in ipairs(NS.sounds) do 
            if s.id == (OneJobOwlDB.iamowlSound or 0) then 
                owlSoundName = s.name 
                break 
            end 
        end
        UIDropDownMenu_SetText(owlSoundDD, owlSoundName)
        UIDropDownMenu_SetSelectedValue(scopeDD, OneJobOwlDB.trackScope or "BOSS")
        UIDropDownMenu_SetText(scopeDD, ScopeTextFor(OneJobOwlDB.trackScope or "BOSS"))
        UIDropDownMenu_SetSelectedValue(outputDD, OneJobOwlDB.iamowlOutput or "BUBBLE")
        UIDropDownMenu_SetText(outputDD, OutputTextFor(OneJobOwlDB.iamowlOutput or "BUBBLE"))
        enableCheck:SetChecked(OneJobOwlDB.enabled)
        combatCheck:SetChecked(OneJobOwlDB.combatOnly)
        reportCheck:SetChecked(OneJobOwlDB.iamowlReport ~= false)
        scaleSlider:SetValue(OneJobOwlDB.buttonScale or 1)
        bubbleScaleSlider:SetValue(OneJobOwlDB.bubbleScale or 1)
        balloonScaleSlider:SetValue(OneJobOwlDB.balloonScale or 1.0)         
        bubbleDurSlider:SetValue(OneJobOwlDB.bubbleDuration or 6)
        clutchSlider:SetValue(OneJobOwlDB.tightWindow or 8)
        SetMode(OneJobOwlDB.mode or "BUTTON")
        RefreshShameList()
        RefreshPraiseList()
    end

    -- Re-sync every widget from saved settings whenever the panel opens
    optionsFrame:HookScript("OnShow", function() NS.RefreshOptions() end)

    -- Modern registration (matches your Tank Buff Reminder addon)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(optionsFrame, optionsFrame.name)
        Settings.RegisterAddOnCategory(category)
        optionsFrame.category = category   -- Store for slash command
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsFrame)
    end
end