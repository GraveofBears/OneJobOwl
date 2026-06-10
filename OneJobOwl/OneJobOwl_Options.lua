-- OneJobOwl_Options.lua
-- Options panel, laid out as one scrollable column so nothing overlaps:
--   General  -> enable, mode
--   Output   -> channel, moonkin name
--   Alerts   -> sound, threshold
--   Button   -> unlock/mover, scale
--   Messages -> editable shame list

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

    local editingIndex = nil
    local y = 5 -- vertical layout cursor

    local function Header(text)
        local fs = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOPLEFT", 5, -y)
        fs:SetText(text)
        y = y + 24
        local line = c:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 0.55, 0, 0.3)
        line:SetSize(530, 1)
        line:SetPoint("TOPLEFT", 5, -y)
        y = y + 8
        return fs
    end

    -- =====================================================================
    Header("General")

    local enableCheck = CreateFrame("CheckButton", "OneJobOwlEnable", c, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 5, -y)
    _G[enableCheck:GetName() .. "Text"]:SetText("Enable OneJobOwl Tracking")
    enableCheck:SetScript("OnClick", function(s)
        OneJobOwlDB.enabled = s:GetChecked()
        if not OneJobOwlDB.enabled then NS.ResetTargetState() end
    end)
    enableCheck:SetChecked(OneJobOwlDB.enabled)
    y = y + 32

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
    y = y + 26

    local modeHelp = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modeHelp:SetPoint("TOPLEFT", 10, -y)
    modeHelp:SetWidth(520)
    modeHelp:SetJustifyH("LEFT")
    modeHelp:SetText("|cffaaaaaaShame Button: the owl appears when IFF expires. Auto-Shame: sends message automatically. I Am Owl: praises your uptime with stats and grade at end of combat.|r")
    y = y + 36

    local reportCheck = CreateFrame("CheckButton", "OneJobOwlIamOwlReport", c, "UICheckButtonTemplate")
    reportCheck:SetPoint("TOPLEFT", 5, -y)
    _G[reportCheck:GetName() .. "Text"]:SetText("Show after-battle report (I Am Owl mode)")
    reportCheck:SetScript("OnClick", function(s)
        OneJobOwlDB.iamowlReport = s:GetChecked() and true or false
    end)
    reportCheck:SetChecked(OneJobOwlDB.iamowlReport ~= false)
    y = y + 32

    local scopeLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scopeLabel:SetPoint("TOPLEFT", 10, -y)
    scopeLabel:SetText("Track on")
    y = y + 14

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
    y = y + 40

    -- =====================================================================
    Header("Output")

    local ddLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ddLabel:SetPoint("TOPLEFT", 10, -y)
    ddLabel:SetText("Channel")
    y = y + 14

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
    y = y + 38

    local nameLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", 10, -y)
    nameLabel:SetText("Your Moonkin (whisper target)")
    y = y + 16

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
    y = y + 28

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
    y = y + 22

    -- ===== FF Enemy (the watched mob) =====
    local enemyLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enemyLabel:SetPoint("TOPLEFT", 10, -y)
    enemyLabel:SetText("FF Enemy (the mob being watched)")
    y = y + 18

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
    y = y + 26

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
    y = y + 16

    local enemyNote = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    enemyNote:SetPoint("TOPLEFT", 15, -y)
    enemyNote:SetWidth(510)
    enemyNote:SetJustifyH("LEFT")
    enemyNote:SetText("|cffaaaaaaWatched by GUID via your target, focus, or its nameplate, so you can target adds freely. Auto-clears when combat ends or it dies. Chat: /fftarget sets from target, /ffclear clears.|r")
    y = y + 42

    local chatNote = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chatNote:SetPoint("TOPLEFT", 10, -y)
    chatNote:SetWidth(520)
    chatNote:SetJustifyH("LEFT")
    chatNote:SetText("|cffaaaaaaType a name and press Enter to save it, or use the Target / Clear buttons. From chat: /shame Name, /shame target (handles weird-character names), /shameclear. /ojo test sends a test message.|r")
    y = y + 32

    -- =====================================================================
    Header("Alerts")

    local soundLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soundLabel:SetPoint("TOPLEFT", 10, -y)
    soundLabel:SetText("Button Alert Sound")
    y = y + 14

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
    y = y + 44

    local slider = CreateFrame("Slider", "OneJobOwlSlider", c, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 15, -y)
    slider:SetWidth(220)
    slider:SetMinMaxValues(0, 10)
    slider:SetValue(OneJobOwlDB.threshold or 5)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    _G[slider:GetName() .. "Text"]:SetText("Warning Threshold: " .. (OneJobOwlDB.threshold or 5) .. "s")
    _G[slider:GetName() .. "Low"]:SetText("0s")
    _G[slider:GetName() .. "High"]:SetText("10s")
    slider:SetScript("OnValueChanged", function(s, val)
        val = math.floor(val)
        OneJobOwlDB.threshold = val
        _G[s:GetName() .. "Text"]:SetText("Warning Threshold: " .. val .. "s")
    end)
    y = y + 44

    -- =====================================================================
    Header("Shame Button")

    local moverCheck = CreateFrame("CheckButton", "OneJobOwlMover", c, "UICheckButtonTemplate")
    moverCheck:SetPoint("TOPLEFT", 5, -y)
    _G[moverCheck:GetName() .. "Text"]:SetText("Unlock button (drag the owl to move it)")
    moverCheck:SetScript("OnClick", function(s) NS.SetButtonMover(s:GetChecked()) end)
    moverCheck:SetChecked(false)
    y = y + 36

    local scaleSlider = CreateFrame("Slider", "OneJobOwlScaleSlider", c, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 15, -y)
    scaleSlider:SetWidth(220)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValue(OneJobOwlDB.buttonScale or 1)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    local function ScaleText(v) return ("Button Scale: %d%%"):format(v * 100 + 0.5) end
    _G[scaleSlider:GetName() .. "Text"]:SetText(ScaleText(OneJobOwlDB.buttonScale or 1))
    _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[scaleSlider:GetName() .. "High"]:SetText("200%")
    scaleSlider:SetScript("OnValueChanged", function(s, val)
        NS.SetButtonScale(val)
        _G[s:GetName() .. "Text"]:SetText(ScaleText(val))
    end)
    y = y + 48

    -- =====================================================================
    Header("Shame Messages")

    local listHint = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    listHint:SetPoint("TOPLEFT", 10, -y)
    listHint:SetText("|cffaaaaaaEdit or delete any of them. Enter saves; Escape cancels an edit.|r")
    y = y + 18

    local scrollFrame = CreateFrame("ScrollFrame", nil, c, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -y)
    scrollFrame:SetSize(490, 200)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(470, 10)
    scrollFrame:SetScrollChild(content)
    y = y + 210

    local rows = {}
    local input, addBtn

    local function RefreshList()
        local shames = OneJobOwlDB.shames or {}
        for i, text in ipairs(shames) do
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
                table.remove(OneJobOwlDB.shames, i)
                if editingIndex == i then
                    editingIndex = nil
                    input:SetText("")
                    addBtn:SetText("Add")
                end
                RefreshList()
            end)
            row.edit:SetScript("OnClick", function()
                editingIndex = i
                input:SetText(OneJobOwlDB.shames[i])
                input:SetFocus()
                addBtn:SetText("Save")
            end)
            row:Show()
        end
        for i = #shames + 1, #rows do rows[i]:Hide() end
        content:SetHeight(math.max(#shames * 26, 10))
    end

    input = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
    input:SetSize(280, 30)
    input:SetPoint("TOPLEFT", 12, -y)
    input:SetAutoFocus(false)
    input:SetScript("OnEscapePressed", function(s)
        s:SetText("")
        s:ClearFocus()
        editingIndex = nil
        addBtn:SetText("Add")
    end)

    addBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)
    addBtn:SetSize(55, 25)
    addBtn:SetText("Add")
    local function Commit()
        local text = input:GetText()
        if text == "" then return end
        if editingIndex and OneJobOwlDB.shames[editingIndex] then
            OneJobOwlDB.shames[editingIndex] = text
            editingIndex = nil
            addBtn:SetText("Add")
        else
            table.insert(OneJobOwlDB.shames, text)
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
        StaticPopupDialogs["ONEJOBOWL_RESTORE"] = StaticPopupDialogs["ONEJOBOWL_RESTORE"] or {
            text = "Wipe your shame list and restore the defaults? Custom and edited messages will be lost.",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                NS.SeedShames(true)
                editingIndex = nil
                input:SetText("")
                addBtn:SetText("Add")
                RefreshList()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("ONEJOBOWL_RESTORE")
    end)
    y = y + 45

    c:SetHeight(y + 20) -- final scrollable height

    RefreshList()

    -- Don't leave the mover stuck on if the panel closes
    optionsFrame:SetScript("OnHide", function()
        if NS.IsButtonMoverOn() then
            NS.SetButtonMover(false)
            moverCheck:SetChecked(false)
        end
    end)

    function NS.RefreshOptions()
        nameInput:SetText(OneJobOwlDB.moonkinName or "")
        UpdateMoonkinStatus()
        UpdateEnemyStatus()
        -- SetSelectedValue alone doesn't repaint a hidden dropdown's label,
        -- so set the visible text explicitly too
        UIDropDownMenu_SetSelectedValue(dd, OneJobOwlDB.channel or "WHISPER")
        UIDropDownMenu_SetText(dd, OneJobOwlDB.channel or "WHISPER")
        UIDropDownMenu_SetSelectedValue(soundDD, OneJobOwlDB.sound or 8959)
        UIDropDownMenu_SetText(soundDD, SoundNameForID(OneJobOwlDB.sound or 8959))
        enableCheck:SetChecked(OneJobOwlDB.enabled)
        UIDropDownMenu_SetSelectedValue(scopeDD, OneJobOwlDB.trackScope or "BOSS")
        UIDropDownMenu_SetText(scopeDD, ScopeTextFor(OneJobOwlDB.trackScope or "BOSS"))
        combatCheck:SetChecked(OneJobOwlDB.combatOnly)
        reportCheck:SetChecked(OneJobOwlDB.iamowlReport ~= false)
        slider:SetValue(OneJobOwlDB.threshold or 5)
        scaleSlider:SetValue(OneJobOwlDB.buttonScale or 1)
        SetMode(OneJobOwlDB.mode or "BUTTON")
        RefreshList()
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