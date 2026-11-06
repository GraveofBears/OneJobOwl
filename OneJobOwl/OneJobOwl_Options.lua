-- OneJobOwl_Options.lua
-- Tabbed options panel:
--   General       -> enable, mode, tracking scope, combat gate
--   Shame         -> shame button sound/scale/mover (all modes)
--   I Am Owl      -> grading, output, clutch window, owl bubble,
--                    FF bar, multi-target grading
--                    (I Am Owl-only controls grey out in other modes)
--   Messages      -> shame list + praise list editors
--   Targets       -> channel, moonkin name, FF enemy, silent alerts
--
-- "I Am Owl only" controls: shown at all times but disabled/greyed
-- when the mode is not IAMOWL, with a one-line note explaining why.

local ADDON_NAME, NS = ...

function NS.CreateOptions()

    -- =========================================================
    -- Root frame (registered with the Interface Options system)
    -- =========================================================
    local optionsFrame = CreateFrame("Frame", "OneJobOwlOptions", UIParent)
    optionsFrame.name = "OneJobOwl"

    -- =========================================================
    -- Tab definitions
    -- =========================================================
    local TAB_DEFS = {
        { id = "general",  label = "General"    },
        { id = "shame",    label = "Shame"      },
        { id = "iamowl",   label = "I Am Owl"   },
        { id = "messages", label = "Messages"   },
        { id = "targets",  label = "Targets"    },
    }

    -- =========================================================
    -- Shared layout helpers (operate on whichever 'c' is active)
    -- =========================================================
    local GAP_SECTION = 18
    local GAP_CONTROL = 10
    local c           -- current tab content frame, set per-tab below
    local y           -- vertical cursor, reset per-tab

    local function Header(text)
        y = y + GAP_SECTION
        local fs = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOPLEFT", 5, -y)
        fs:SetText(text)
        y = y + 26
        local line = c:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 0.55, 0, 0.3)
        line:SetSize(510, 1)
        line:SetPoint("TOPLEFT", 5, -y)
        y = y + 12
        return fs
    end

    local function Note(text, indent)
        local fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", indent or 10, -y)
        fs:SetWidth(500 - (indent or 10))
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

    -- =========================================================
    -- Build the tab bar across the top of the panel
    -- =========================================================
    local TAB_H   = 28
    local TAB_PAD = 14
    local CONTENT_TOP = -(TAB_H + 8)

    local tabButtons = {}
    local tabFrames  = {}
    local activeTab  = nil

    local function ShowTab(id)
        activeTab = id
        for _, def in ipairs(TAB_DEFS) do
            local frame = tabFrames[def.id]
            local btn   = tabButtons[def.id]
            if frame then frame:SetShown(def.id == id) end
            if btn then
                if def.id == id then
                    btn.bg:SetColorTexture(1, 0.55, 0, 0.85)
                    btn.lbl:SetTextColor(0.05, 0.05, 0.05)
                else
                    btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
                    btn.lbl:SetTextColor(0.85, 0.85, 0.85)
                end
            end
        end
    end

    local tabRowX = 6
    for _, def in ipairs(TAB_DEFS) do
        local btn = CreateFrame("Button", nil, optionsFrame)
        local tmp = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tmp:SetText(def.label)
        local tw = tmp:GetStringWidth() + TAB_PAD * 2
        tmp:Hide()

        btn:SetSize(tw, TAB_H)
        btn:SetPoint("TOPLEFT", tabRowX, -4)
        tabRowX = tabRowX + tw + 3

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        btn.bg = bg

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("CENTER")
        lbl:SetText(def.label)
        lbl:SetTextColor(0.85, 0.85, 0.85)
        btn.lbl = lbl

        local id = def.id
        btn:SetScript("OnClick", function() ShowTab(id) end)
        btn:SetScript("OnEnter", function() bg:SetColorTexture(1, 0.7, 0.2, 0.85) end)
        btn:SetScript("OnLeave", function()
            if activeTab == id then
                bg:SetColorTexture(1, 0.55, 0, 0.85)
            else
                bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
            end
        end)

        tabButtons[def.id] = btn
    end

    local tabLine = optionsFrame:CreateTexture(nil, "ARTWORK")
    tabLine:SetColorTexture(1, 0.55, 0, 0.4)
    tabLine:SetSize(560, 1)
    tabLine:SetPoint("TOPLEFT", 0, -(TAB_H + 8))

    -- =========================================================
    -- Helper: build a scrollable content frame for one tab
    -- =========================================================
    local function NewTabFrame(id)
        local outer = CreateFrame("Frame", nil, optionsFrame)
        outer:SetPoint("TOPLEFT", 0, CONTENT_TOP - 4)
        outer:SetPoint("BOTTOMRIGHT", 0, 0)
        outer:Hide()

        local scroll = CreateFrame("ScrollFrame", "OneJobOwlScroll_" .. id,
            outer, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 6, -4)
        scroll:SetPoint("BOTTOMRIGHT", -26, 4)

        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(520, 100)
        scroll:SetScrollChild(content)

        tabFrames[id] = outer
        return content, outer
    end

    -- =========================================================
    -- Forward-declare all widget locals
    -- =========================================================
    local enableCheck, scopeDD, combatCheck
    local btnRadio, autoRadio, owlRadio
    local ScopeTextFor, SetMode

    local soundDD, SoundNameForID, scaleSlider, moverCheck

    local reportCheck, multiTargetCheck
    local outputDD, OutputTextFor, bubblePreviewBtn
    local clutchSlider, owlSoundDD, owlPreviewBtn
    local bubbleMoverCheck, bubbleScaleSlider, balloonScaleSlider, bubbleDurSlider
    local ffbarCheck, ffbarMoverCheck, ffbarHeaderCheck
    local ffbarScaleSlider, ffbarWidthSlider, ffbarRowHSlider
    local ffbarPaddingSlider, ffbarMaxRowsSlider
    local owlGateNote

    local RefreshShameList, RefreshPraiseList

    local nameInput, moonkinStatus, UpdateMoonkinStatus
    local dd
    local enemyStatus, UpdateEnemyStatus
    local silentFFCheck

    -- =========================================================
    -- TAB: General
    -- =========================================================
    do
        local content, outer = NewTabFrame("general")
        c = content ; y = 8

        Header("General")

        enableCheck = Check("OneJobOwlEnable", "Enable OneJobOwl", function(s)
            OneJobOwlDB.enabled = s:GetChecked()
            if not OneJobOwlDB.enabled then NS.ResetTargetState() end
        end)
        enableCheck:SetChecked(OneJobOwlDB.enabled)

        local modeLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        modeLabel:SetPoint("TOPLEFT", 10, -y - 4)
        modeLabel:SetText("Mode:")

        btnRadio = CreateFrame("CheckButton", "OneJobOwlModeButton", c, "UIRadioButtonTemplate")
        btnRadio:SetPoint("TOPLEFT", 60, -y)
        _G[btnRadio:GetName() .. "Text"]:SetText("Shame Button")

        autoRadio = CreateFrame("CheckButton", "OneJobOwlModeAuto", c, "UIRadioButtonTemplate")
        autoRadio:SetPoint("TOPLEFT", 200, -y)
        _G[autoRadio:GetName() .. "Text"]:SetText("Auto-Shame")

        owlRadio = CreateFrame("CheckButton", "OneJobOwlModeIamOwl", c, "UIRadioButtonTemplate")
        owlRadio:SetPoint("TOPLEFT", 340, -y)
        _G[owlRadio:GetName() .. "Text"]:SetText("I Am Owl")
        y = y + 26 + GAP_CONTROL

        SetMode = function(mode)
            OneJobOwlDB.mode = mode
            btnRadio:SetChecked(mode == "BUTTON")
            autoRadio:SetChecked(mode == "AUTO")
            owlRadio:SetChecked(mode == "IAMOWL")
            if NS.UpdateFFBarOptionGate then NS.UpdateFFBarOptionGate() end
            if (mode == "AUTO" or mode == "IAMOWL") and not NS.IsButtonMoverOn() then
                NS.HideShameButton()
            end
        end

        btnRadio:SetScript("OnClick",  function() SetMode("BUTTON") end)
        autoRadio:SetScript("OnClick", function() SetMode("AUTO")   end)
        owlRadio:SetScript("OnClick",  function() SetMode("IAMOWL") end)
        SetMode(OneJobOwlDB.mode or "BUTTON")

        Note("Shame Button: owl pops up when IFF expires; click to shame. Auto-Shame: fires automatically. I Am Owl: you are the moonkin — grade yourself.")

        Label("Track on")
        local scopes = {
            { text = "Bosses only (skull)", value = "BOSS"  },
            { text = "Bosses & elites",     value = "ELITE" },
            { text = "Everything",          value = "ALL"   },
        }
        ScopeTextFor = function(value)
            for _, s in ipairs(scopes) do
                if s.value == value then return s.text end
            end
            return scopes[1].text
        end

        scopeDD = CreateFrame("Frame", "OneJobOwlScopeDD", c, "UIDropDownMenuTemplate")
        scopeDD:SetPoint("TOPLEFT", -10, -y)
        UIDropDownMenu_SetWidth(scopeDD, 150)
        UIDropDownMenu_Initialize(scopeDD, function()
            for _, s in ipairs(scopes) do
                local info = UIDropDownMenu_CreateInfo()
                info.text, info.value, info.checked =
                    s.text, s.value, (OneJobOwlDB.trackScope == s.value)
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

        combatCheck = CreateFrame("CheckButton", "OneJobOwlCombatOnly", c, "UICheckButtonTemplate")
        combatCheck:SetPoint("LEFT", scopeDD, "RIGHT", 0, 2)
        _G[combatCheck:GetName() .. "Text"]:SetText("Only while in combat")
        combatCheck:SetScript("OnClick", function(s) OneJobOwlDB.combatOnly = s:GetChecked() end)
        combatCheck:SetChecked(OneJobOwlDB.combatOnly)
        y = y + 34 + GAP_CONTROL

        Note("Scope controls the shame button and auto-shame. With the FF Bar enabled in I Am Owl mode, set this to Bosses & elites or Everything so all tracked mobs feed the grade.")

        content:SetHeight(y + 20)
    end

    -- =========================================================
    -- TAB: Shame
    -- =========================================================
    do
        local content, outer = NewTabFrame("shame")
        c = content ; y = 8

        Header("Shame Button")
        Note("Pops up when Faerie Fire falls off. Retracts if FF is reapplied, or after 10 seconds. Not active in I Am Owl mode (the owl speaks directly there).")

        Label("Alert Sound")
        soundDD = CreateFrame("Frame", "OneJobOwlSoundDD", c, "UIDropDownMenuTemplate")
        soundDD:SetPoint("TOPLEFT", -10, -y)
        UIDropDownMenu_SetWidth(soundDD, 150)

        SoundNameForID = function(id)
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
                    NS.PlayShameSound()
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

        moverCheck = Check("OneJobOwlMover", "Unlock button (drag to reposition)", function(s)
            NS.SetButtonMover(s:GetChecked())
        end)
        moverCheck:SetChecked(false)

        scaleSlider = Slider("OneJobOwlScaleSlider", 0.5, 2.0, 0.05,
            function() return OneJobOwlDB.buttonScale or 1 end,
            function(v) return ("Button Scale: %d%%"):format(v * 100 + 0.5) end,
            function(v) NS.SetButtonScale(v) end)
        _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
        _G[scaleSlider:GetName() .. "High"]:SetText("200%")

        content:SetHeight(y + 20)
    end

    -- =========================================================
    -- TAB: I Am Owl
    -- =========================================================
    do
        local content, outer = NewTabFrame("iamowl")
        c = content ; y = 8

        local owlOnlyWidgets = {}
        -- Each entry: { w = widget, kind = "button"|"slider"|"dropdown" }
        -- button   -> CheckButton/Button: Enable/Disable + text colour
        -- slider   -> Slider: EnableMouse/DisableMouse + alpha
        -- dropdown -> UIDropDownMenu Frame: alpha only (no Enable method)
        local function AddOwlWidget(w, kind)
            owlOnlyWidgets[#owlOnlyWidgets + 1] = { w = w, kind = kind or "button" }
        end

        owlGateNote = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        owlGateNote:SetPoint("TOPLEFT", 10, -y)
        owlGateNote:SetWidth(490)
        owlGateNote:SetJustifyH("LEFT")
        owlGateNote:SetText("|cffff9900Switch to I Am Owl mode (General tab) to enable these settings.|r")
        owlGateNote:Hide()
        y = y + 20 + GAP_CONTROL

        -- ── Grading ───────────────────────────────────────────
        Header("Grading")

        reportCheck = Check("OneJobOwlIamOwlReport", "Show after-battle report (grade & stats)", function(s)
            OneJobOwlDB.iamowlReport = s:GetChecked() and true or false
        end)
        reportCheck:SetChecked(OneJobOwlDB.iamowlReport ~= false)
        AddOwlWidget(reportCheck)

        multiTargetCheck = Check("OneJobOwlMultiTarget",
            "Multi-target grading (grade all FF Bar mobs, not just current target)", function(s)
            OneJobOwlDB.iamowlMultiTarget = s:GetChecked() and true or false
        end)
        multiTargetCheck:SetChecked(OneJobOwlDB.iamowlMultiTarget == true)
        AddOwlWidget(multiTargetCheck)
        Note("One combined grade for all mobs you applied FF to, weighted by fight duration. Per-mob shames and praises still fire mid-fight.", 20)
		
		y = y + 15
		
        clutchSlider = Slider("OneJobOwlClutchSlider", 1, 10, 1,
            function() return OneJobOwlDB.tightWindow or 8 end,
            function(v) return ("Clutch Window: %ds"):format(v) end,
            function(v) OneJobOwlDB.tightWindow = math.floor(v) end)
        _G[clutchSlider:GetName() .. "Low"]:SetText("1s")
        _G[clutchSlider:GetName() .. "High"]:SetText("10s")
        AddOwlWidget(clutchSlider, "slider")
        Note("Refreshing FF with this many seconds left = clutch refresh: live praise + better grade. Letting FF hit 0 = drop.", 20)

        -- ── Output ────────────────────────────────────────────
        Header("Output")

        Label("Deliver messages via")
        local outputs = {
            { text = "Owl Bubble (on screen)",    value = "BUBBLE" },
            { text = "Chat (uses Channel below)", value = "CHAT"   },
        }
        OutputTextFor = function(value)
            for _, o in ipairs(outputs) do
                if o.value == value then return o.text end
            end
            return outputs[1].text
        end

        outputDD = CreateFrame("Frame", "OneJobOwlOutputDD", c, "UIDropDownMenuTemplate")
        outputDD:SetPoint("TOPLEFT", -10, -y)
        UIDropDownMenu_SetWidth(outputDD, 170)
        UIDropDownMenu_Initialize(outputDD, function()
            for _, o in ipairs(outputs) do
                local info = UIDropDownMenu_CreateInfo()
                info.text, info.value, info.checked =
                    o.text, o.value, ((OneJobOwlDB.iamowlOutput or "BUBBLE") == o.value)
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
        AddOwlWidget(outputDD, "dropdown")

        bubblePreviewBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        bubblePreviewBtn:SetSize(70, 22)
        bubblePreviewBtn:SetPoint("LEFT", outputDD, "RIGHT", -8, 2)
        bubblePreviewBtn:SetText("Preview")
        bubblePreviewBtn:SetScript("OnClick", function() NS.PreviewOwlBubble() end)
        AddOwlWidget(bubblePreviewBtn)
        y = y + 34 + GAP_CONTROL

        Label("Praise Sound")
        owlSoundDD = CreateFrame("Frame", "OneJobOwlIamOwlSoundDD", c, "UIDropDownMenuTemplate")
        owlSoundDD:SetPoint("TOPLEFT", -10, -y)
        UIDropDownMenu_SetWidth(owlSoundDD, 150)
        UIDropDownMenu_Initialize(owlSoundDD, function()
            for _, s in ipairs(NS.sounds) do
                local info = UIDropDownMenu_CreateInfo()
                info.text, info.value, info.checked = s.name, s.id, (OneJobOwlDB.iamowlSound == s.id)
                info.func = function(sel)
                    OneJobOwlDB.iamowlSound = sel.value
                    UIDropDownMenu_SetSelectedValue(owlSoundDD, sel.value)
                    UIDropDownMenu_SetText(owlSoundDD, sel.text)
                    NS.PlaySoundByID(sel.value)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedValue(owlSoundDD, OneJobOwlDB.iamowlSound or 0)
        UIDropDownMenu_SetText(owlSoundDD, (function()
            for _, s in ipairs(NS.sounds) do
                if s.id == (OneJobOwlDB.iamowlSound or 0) then return s.name end
            end
            return "None"
        end)())
        AddOwlWidget(owlSoundDD, "dropdown")

        owlPreviewBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        owlPreviewBtn:SetSize(55, 22)
        owlPreviewBtn:SetPoint("LEFT", owlSoundDD, "RIGHT", -8, 2)
        owlPreviewBtn:SetText("Play")
        owlPreviewBtn:SetScript("OnClick", function() NS.PlaySoundByID(OneJobOwlDB.iamowlSound or 0) end)
        AddOwlWidget(owlPreviewBtn)
        y = y + 34 + GAP_CONTROL

        -- ── Owl Bubble ────────────────────────────────────────
        Header("Owl Bubble")

        bubbleMoverCheck = Check("OneJobOwlBubbleMover", "Unlock owl bubble (drag to reposition)", function(s)
            NS.SetBubbleMover(s:GetChecked())
        end)
        bubbleMoverCheck:SetChecked(false)
        AddOwlWidget(bubbleMoverCheck)

        bubbleScaleSlider = Slider("OneJobOwlBubbleScaleSlider", 0.5, 2.0, 0.05,
            function() return OneJobOwlDB.bubbleScale or 1 end,
            function(v) return ("Owl Icon Scale: %d%%"):format(v * 100 + 0.5) end,
            function(v) NS.SetBubbleScale(v) end)
        _G[bubbleScaleSlider:GetName() .. "Low"]:SetText("50%")
        _G[bubbleScaleSlider:GetName() .. "High"]:SetText("200%")
        AddOwlWidget(bubbleScaleSlider, "slider")

        balloonScaleSlider = Slider("OneJobOwlBalloonScaleSlider", 0.5, 2.0, 0.05,
            function() return OneJobOwlDB.balloonScale or 1.0 end,
            function(v) return ("Balloon Scale: %d%%"):format(v * 100 + 0.5) end,
            function(v) NS.SetBalloonScale(v) end)
        _G[balloonScaleSlider:GetName() .. "Low"]:SetText("50%")
        _G[balloonScaleSlider:GetName() .. "High"]:SetText("200%")
        AddOwlWidget(balloonScaleSlider, "slider")

        bubbleDurSlider = Slider("OneJobOwlBubbleDurSlider", 3, 15, 1,
            function() return OneJobOwlDB.bubbleDuration or 6 end,
            function(v) return ("Message Duration: %ds"):format(v) end,
            function(v) OneJobOwlDB.bubbleDuration = math.floor(v) end)
        _G[bubbleDurSlider:GetName() .. "Low"]:SetText("3s")
        _G[bubbleDurSlider:GetName() .. "High"]:SetText("15s")
        AddOwlWidget(bubbleDurSlider, "slider")

        -- ── Faerie Fire Bar ───────────────────────────────────
        Header("Faerie Fire Bar")

        ffbarCheck = Check("OneJobOwlFFBarEnable", "Enable Faerie Fire bar (per-target FF tracker)", function(s)
            NS.FFBar_SetEnabled(s:GetChecked() and true or false)
            s:SetChecked(NS.FFBar_IsEnabled())
        end)
        ffbarCheck:SetChecked(OneJobOwlDB.ffbarEnabled == true)
        AddOwlWidget(ffbarCheck)
        Note("Target and Focus rows are click-to-cast. All other Faerie Fired mobs show with live timers (display only in combat). Clears on combat end.", 20)

        ffbarMoverCheck = Check("OneJobOwlFFBarMover", "Unlock bar (drag to reposition)", function(s)
            NS.FFBar_SetMover(s:GetChecked() and true or false)
            s:SetChecked(NS.FFBar_IsMoverOn())
        end)
        ffbarMoverCheck:SetChecked(false)
        AddOwlWidget(ffbarMoverCheck)

        ffbarHeaderCheck = Check("OneJobOwlFFBarHeader", "Show 'Faerie Fire' title above the bar", function(s)
            NS.FFBar_SetShowHeader(s:GetChecked() and true or false)
        end)
        ffbarHeaderCheck:SetChecked(OneJobOwlDB.ffbarShowHeader ~= false)
        AddOwlWidget(ffbarHeaderCheck)

        ffbarScaleSlider = Slider("OneJobOwlFFBarScaleSlider", 0.5, 2.0, 0.05,
            function() return OneJobOwlDB.ffbarScale or 1 end,
            function(v) return ("Bar Scale: %d%%"):format(v * 100 + 0.5) end,
            function(v) NS.FFBar_SetScale(v) end)
        _G[ffbarScaleSlider:GetName() .. "Low"]:SetText("50%")
        _G[ffbarScaleSlider:GetName() .. "High"]:SetText("200%")
        AddOwlWidget(ffbarScaleSlider, "slider")

        ffbarWidthSlider = Slider("OneJobOwlFFBarWidthSlider", 120, 320, 5,
            function() return OneJobOwlDB.ffbarWidth or 190 end,
            function(v) return ("Bar Width: %dpx"):format(v + 0.5) end,
            function(v) NS.FFBar_SetWidth(v) end)
        _G[ffbarWidthSlider:GetName() .. "Low"]:SetText("120")
        _G[ffbarWidthSlider:GetName() .. "High"]:SetText("320")
        AddOwlWidget(ffbarWidthSlider, "slider")

        ffbarRowHSlider = Slider("OneJobOwlFFBarRowHSlider", 14, 30, 1,
            function() return OneJobOwlDB.ffbarRowHeight or 20 end,
            function(v) return ("Row Height: %dpx"):format(v + 0.5) end,
            function(v) NS.FFBar_SetRowHeight(v) end)
        _G[ffbarRowHSlider:GetName() .. "Low"]:SetText("14")
        _G[ffbarRowHSlider:GetName() .. "High"]:SetText("30")
        AddOwlWidget(ffbarRowHSlider, "slider")

        ffbarPaddingSlider = Slider("OneJobOwlFFBarPaddingSlider", 0, 12, 1,
            function() return OneJobOwlDB.ffbarRowPadding or 2 end,
            function(v) return ("Row Padding: %dpx"):format(v) end,
            function(v)
                OneJobOwlDB.ffbarRowPadding = math.floor(v)
                if NS.FFBar_ApplyLayout then NS.FFBar_ApplyLayout() end
            end)
        _G[ffbarPaddingSlider:GetName() .. "Low"]:SetText("0")
        _G[ffbarPaddingSlider:GetName() .. "High"]:SetText("12")
        AddOwlWidget(ffbarPaddingSlider, "slider")

        ffbarMaxRowsSlider = Slider("OneJobOwlFFBarMaxRowsSlider", 1, 15, 1,
            function() return OneJobOwlDB.ffbarMaxRows or 8 end,
            function(v) return ("Max Mob Rows: %d"):format(v + 0.5) end,
            function(v) NS.FFBar_SetMaxRows(v) end)
        _G[ffbarMaxRowsSlider:GetName() .. "Low"]:SetText("1")
        _G[ffbarMaxRowsSlider:GetName() .. "High"]:SetText("15")
        AddOwlWidget(ffbarMaxRowsSlider, "slider")

        content:SetHeight(y + 20)

        -- ── Gate: called from SetMode + RefreshOptions ────────
        NS.UpdateFFBarOptionGate = function()
            local isOwl = (OneJobOwlDB.mode == "IAMOWL")
            if not isOwl and NS.FFBar_IsEnabled() then
                NS.FFBar_SetEnabled(false)
            end
            owlGateNote:SetShown(not isOwl)
            for _, entry in ipairs(owlOnlyWidgets) do
                local w, kind = entry.w, entry.kind
                if kind == "dropdown" then
                    -- Dropdowns are plain Frames; just dim them visually
                    w:SetAlpha(isOwl and 1.0 or 0.4)
                elseif kind == "slider" then
                    w:SetAlpha(isOwl and 1.0 or 0.4)
                    if isOwl then w:EnableMouse(true) else w:EnableMouse(false) end
                else
                    -- button / checkbutton
                    if isOwl then
                        w:Enable()
                        if w.GetName and w:GetName() then
                            local t = _G[w:GetName() .. "Text"]
                            if t then t:SetTextColor(1, 1, 1) end
                        end
                    else
                        w:Disable()
                        if w.GetName and w:GetName() then
                            local t = _G[w:GetName() .. "Text"]
                            if t then t:SetTextColor(0.45, 0.45, 0.45) end
                        end
                    end
                end
            end
            if ffbarCheck then ffbarCheck:SetChecked(NS.FFBar_IsEnabled()) end
        end
        NS.UpdateFFBarOptionGate()
    end

    -- =========================================================
    -- TAB: Messages
    -- =========================================================
    do
        local content, outer = NewTabFrame("messages")
        c = content ; y = 8

        local function BuildMessageEditor(cfg)
            local editingIndex = nil
            local rows = {}
            local input, addBtn

            local scrollFrame = CreateFrame("ScrollFrame", nil, c, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", 5, -y)
            scrollFrame:SetSize(480, 180)
            local scrollContent = CreateFrame("Frame", nil, scrollFrame)
            scrollContent:SetSize(460, 10)
            scrollFrame:SetScrollChild(scrollContent)
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
                        row = CreateFrame("Frame", nil, scrollContent)
                        row:SetSize(450, 24)
                        row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)

                        row.lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        row.lbl:SetPoint("LEFT")
                        row.lbl:SetWidth(345)
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
                scrollContent:SetHeight(math.max(#list * 26, 10))
            end

            input = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
            input:SetSize(270, 30)
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
                    text         = cfg.popupText,
                    button1      = YES,
                    button2      = NO,
                    OnAccept     = function()
                        cfg.onRestore()
                        ResetEditState()
                        RefreshList()
                    end,
                    timeout      = 0,
                    whileDead    = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show(cfg.popupKey)
            end)
            y = y + 36 + GAP_CONTROL

            return RefreshList
        end

        Header("Shame Messages")
        Note("Sent when Faerie Fire falls off. Enter saves an edit; Escape cancels.")
        RefreshShameList = BuildMessageEditor({
            getList   = function() return OneJobOwlDB.shames end,
            popupKey  = "ONEJOBOWL_RESTORE",
            popupText = "Wipe your shame list and restore the defaults? Custom and edited messages will be lost.",
            onRestore = function() NS.SeedShames(true) end,
        })

        Header("Praise Messages")
        Note("Shown on clutch refreshes in I Am Owl mode. Enter saves; Escape cancels.")
        RefreshPraiseList = BuildMessageEditor({
            getList   = function() return OneJobOwlDB.praises end,
            popupKey  = "ONEJOBOWL_RESTORE_PRAISES",
            popupText = "Wipe your praise list and restore the defaults? Custom and edited messages will be lost.",
            onRestore = function() NS.SeedPraises(true) end,
        })

        content:SetHeight(y + 20)
    end

    -- =========================================================
    -- TAB: Targets
    -- =========================================================
    do
        local content, outer = NewTabFrame("targets")
        c = content ; y = 8

        Header("Output Channel")

        Label("Send shames via")
        dd = CreateFrame("Frame", "OneJobOwlChannelDD", c, "UIDropDownMenuTemplate")
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

        Note("Also used by I Am Owl when Output is set to Chat (I Am Owl tab).", 15)

        Header("Moonkin Target")

        Label("Your Moonkin (whisper target)")
        nameInput = CreateFrame("EditBox", "OneJobOwlMoonkinName", c, "InputBoxTemplate")
        nameInput:SetSize(160, 25)
        nameInput:SetPoint("TOPLEFT", 15, -y)
        nameInput:SetAutoFocus(false)
        nameInput:SetText(OneJobOwlDB.moonkinName or "")
        nameInput:SetScript("OnEnterPressed", function(s)
            local txt = s:GetText():gsub("^%s+", ""):gsub("%s+$", "")
            if txt ~= "" then NS.SetMoonkin(txt) else NS.ClearMoonkin() end
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
            nameInput:ClearFocus()
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

        moonkinStatus = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        moonkinStatus:SetPoint("TOPLEFT", 15, -y)
        moonkinStatus:SetJustifyH("LEFT")
        UpdateMoonkinStatus = function()
            if NS.HasMoonkinSet() then
                moonkinStatus:SetText("|cff44ff44Current moonkin: " .. OneJobOwlDB.moonkinName .. "|r")
            else
                moonkinStatus:SetText("|cffff6666No moonkin set (self-shame mode)|r")
            end
        end
        UpdateMoonkinStatus()
        y = y + 18 + GAP_CONTROL

        Note("Type a name + Enter, or use Target / Clear. Chat: /shame Name, /shame target, /shameclear. /ojo test sends a test shame.", 15)

        Header("FF Enemy")

        Label("Pin a specific mob to watch (independent of your target)")
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

        enemyStatus = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        enemyStatus:SetPoint("TOPLEFT", 15, -y)
        enemyStatus:SetJustifyH("LEFT")
        UpdateEnemyStatus = function()
            local name = NS.GetFFEnemyName()
            if name then
                enemyStatus:SetText("|cff44ff44Watching: " .. name .. "|r")
            else
                enemyStatus:SetText("|cffaaaaaaNo enemy set — tracking follows your current target|r")
            end
        end
        UpdateEnemyStatus()
        y = y + 18 + GAP_CONTROL

        Note("Tracked by GUID via target, focus, or nameplate. Auto-clears when combat ends or mob dies. Chat: /fftarget, /ffclear.", 15)

        silentFFCheck = Check("OneJobOwlSilentFFTarget",
            "Silence chat alerts for /fftarget and /ffclear", function(s)
            OneJobOwlDB.silentFFTarget = s:GetChecked()
        end)
        silentFFCheck:SetChecked(OneJobOwlDB.silentFFTarget or false)

        content:SetHeight(y + 20)
    end

    -- =========================================================
    -- Activate first tab, seed lists
    -- =========================================================
    ShowTab("general")
    RefreshShameList()
    RefreshPraiseList()

    -- =========================================================
    -- OnHide: retract any open movers
    -- =========================================================
    optionsFrame:SetScript("OnHide", function()
        if NS.IsButtonMoverOn() then
            NS.SetButtonMover(false)
            if moverCheck then moverCheck:SetChecked(false) end
        end
        if NS.IsBubbleMoverOn and NS.IsBubbleMoverOn() then
            NS.SetBubbleMover(false)
            if bubbleMoverCheck then bubbleMoverCheck:SetChecked(false) end
        end
        if NS.FFBar_IsMoverOn and NS.FFBar_IsMoverOn() then
            NS.FFBar_SetMover(false)
            if ffbarMoverCheck then ffbarMoverCheck:SetChecked(false) end
        end
    end)

    -- =========================================================
    -- RefreshOptions: re-sync every widget from saved state
    -- =========================================================
    function NS.RefreshOptions()
        if nameInput           then nameInput:SetText(OneJobOwlDB.moonkinName or "") end
        if UpdateMoonkinStatus then UpdateMoonkinStatus() end
        if UpdateEnemyStatus   then UpdateEnemyStatus()   end

        if dd then
            UIDropDownMenu_SetSelectedValue(dd, OneJobOwlDB.channel or "WHISPER")
            UIDropDownMenu_SetText(dd, OneJobOwlDB.channel or "WHISPER")
        end
        if soundDD then
            UIDropDownMenu_SetSelectedValue(soundDD, OneJobOwlDB.sound or 8959)
            UIDropDownMenu_SetText(soundDD, SoundNameForID(OneJobOwlDB.sound or 8959))
        end
        if owlSoundDD then
            UIDropDownMenu_SetSelectedValue(owlSoundDD, OneJobOwlDB.iamowlSound or 0)
            local name = "None"
            for _, s in ipairs(NS.sounds) do
                if s.id == (OneJobOwlDB.iamowlSound or 0) then name = s.name ; break end
            end
            UIDropDownMenu_SetText(owlSoundDD, name)
        end
        if scopeDD then
            UIDropDownMenu_SetSelectedValue(scopeDD, OneJobOwlDB.trackScope or "BOSS")
            UIDropDownMenu_SetText(scopeDD, ScopeTextFor(OneJobOwlDB.trackScope or "BOSS"))
        end
        if outputDD then
            UIDropDownMenu_SetSelectedValue(outputDD, OneJobOwlDB.iamowlOutput or "BUBBLE")
            UIDropDownMenu_SetText(outputDD, OutputTextFor(OneJobOwlDB.iamowlOutput or "BUBBLE"))
        end

        if enableCheck       then enableCheck:SetChecked(OneJobOwlDB.enabled) end
        if combatCheck       then combatCheck:SetChecked(OneJobOwlDB.combatOnly) end
        if silentFFCheck     then silentFFCheck:SetChecked(OneJobOwlDB.silentFFTarget or false) end
        if reportCheck       then reportCheck:SetChecked(OneJobOwlDB.iamowlReport ~= false) end
        if multiTargetCheck  then multiTargetCheck:SetChecked(OneJobOwlDB.iamowlMultiTarget == true) end

        if scaleSlider        then scaleSlider:SetValue(OneJobOwlDB.buttonScale or 1) end
        if bubbleScaleSlider  then bubbleScaleSlider:SetValue(OneJobOwlDB.bubbleScale or 1) end
        if balloonScaleSlider then balloonScaleSlider:SetValue(OneJobOwlDB.balloonScale or 1.0) end
        if bubbleDurSlider    then bubbleDurSlider:SetValue(OneJobOwlDB.bubbleDuration or 6) end
        if clutchSlider       then clutchSlider:SetValue(OneJobOwlDB.tightWindow or 8) end
        if ffbarHeaderCheck   then ffbarHeaderCheck:SetChecked(OneJobOwlDB.ffbarShowHeader ~= false) end
        if ffbarPaddingSlider then ffbarPaddingSlider:SetValue(OneJobOwlDB.ffbarRowPadding or 2) end
        if ffbarScaleSlider   then ffbarScaleSlider:SetValue(OneJobOwlDB.ffbarScale or 1) end
        if ffbarWidthSlider   then ffbarWidthSlider:SetValue(OneJobOwlDB.ffbarWidth or 190) end
        if ffbarRowHSlider    then ffbarRowHSlider:SetValue(OneJobOwlDB.ffbarRowHeight or 20) end
        if ffbarMaxRowsSlider then ffbarMaxRowsSlider:SetValue(OneJobOwlDB.ffbarMaxRows or 8) end

        if SetMode              then SetMode(OneJobOwlDB.mode or "BUTTON") end
        if NS.UpdateFFBarOptionGate then NS.UpdateFFBarOptionGate() end
        if RefreshShameList     then RefreshShameList()  end
        if RefreshPraiseList    then RefreshPraiseList() end
    end

    optionsFrame:HookScript("OnShow", function() NS.RefreshOptions() end)

    -- =========================================================
    -- Register with Interface Options
    -- =========================================================
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(optionsFrame, optionsFrame.name)
        Settings.RegisterAddOnCategory(category)
        optionsFrame.category = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsFrame)
    end
end