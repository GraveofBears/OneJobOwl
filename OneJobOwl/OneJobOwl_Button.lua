-- OneJobOwl_Button.lua
-- The Shame Button: pops up (with sound) when Improved Faerie Fire expires.
-- Left-click = send the shame. Right-click = forgive (dismiss silently).
-- Drag with left mouse to move it; position is saved.
-- "Unlock button" in options enables mover mode: the button shows
-- semi-transparent so you can drag/position it without shaming anyone.

local ADDON_NAME, NS = ...

local TEXTURE_PATH = "Interface\\AddOns\\OneJobOwl\\Moonkin.tga"

-- Sound choices shown in options. PlaySound() soundkit IDs from the game.
NS.sounds = {
    { name = "None",                 id = 0 },
    { name = "Moonkin Crit",         id = 5358 },
    { name = "Dead Moonkin",         id = 5359 },
    { name = "Moonkin Mad", 		 id = 5360 },
    { name = "I miss my dog",   	 id = 11798 },
    { name = "Where is that dog",    id = 11796 },
    { name = "Druid Of The Claw",    id = 6209 },
    { name = "Whisper Alert",        id = 3081 },
}

function NS.PlayShameSound()
    local id = OneJobOwlDB.sound or 0
    if id and id > 0 then
        PlaySound(id, "Master")
    end
end

local AUTOHIDE_SECONDS = 10  -- shame button retracts on its own after this long

local button
local moverMode = false
local autoHideTimer

function NS.CreateShameButton()
    if button then return end

    button = CreateFrame("Button", "OneJobOwlShameButton", UIParent, "BackdropTemplate")
    button:SetSize(48, 48)
    button:SetFrameStrata("HIGH")
    button:SetClampedToScreen(true)
    button:SetScale(OneJobOwlDB.buttonScale or 1)
    button:Hide()

    local pos = OneJobOwlDB.buttonPos
    if pos and pos.point then
        button:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end

    -- gold border around the owl
    button:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    button:SetBackdropBorderColor(1, 0.82, 0, 1)

    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetTexture(TEXTURE_PATH)
    tex:SetAlpha(1)
    button.tex = tex

    local glow = button:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("CENTER")
    glow:SetSize(72, 72)
    glow:SetTexture("Interface\\Cooldown\\star4")
    glow:SetBlendMode("ADD")
    button.glow = glow
    NS.ApplyGlowColor()

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", button, "BOTTOM", 0, -2)
    label:SetText("|cffff4444SHAME!|r")
    button.label = label

    local ag = button:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local pulse = ag:CreateAnimation("Scale")
    pulse:SetScale(1.12, 1.12)
    pulse:SetDuration(0.5)
    pulse:SetSmoothing("IN_OUT")
    button.pulse = ag

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        if moverMode then return end -- positioning, not shaming
        if mouseButton == "LeftButton" then
            NS.SendShame()
        end
        NS.HideShameButton()
    end)

    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", button.StartMoving)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        OneJobOwlDB.buttonPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("OneJobOwl")
        if moverMode then
            GameTooltip:AddLine("Mover mode: drag to position.", 1, 1, 1)
            GameTooltip:AddLine("Uncheck 'Unlock button' in options when done.", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("Improved Faerie Fire fell off!", 1, 1, 1)
            GameTooltip:AddLine("Left-click: shame the owl", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Right-click: forgive (this time)", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Drag: move this button", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function NS.ShowShameButton()
    if not button or moverMode or button:IsShown() then return end
    button:Show()
    button.pulse:Play()
    NS.PlayShameSound()
    -- the owl gets AUTOHIDE_SECONDS of judgment, then retracts on its own
    if autoHideTimer then autoHideTimer:Cancel() end
    autoHideTimer = C_Timer.NewTimer(AUTOHIDE_SECONDS, function()
        autoHideTimer = nil
        NS.HideShameButton()
    end)
end

function NS.HideShameButton()
    if not button or moverMode or not button:IsShown() then return end
    if autoHideTimer then
        autoHideTimer:Cancel()
        autoHideTimer = nil
    end
    button.pulse:Stop()
    button:Hide()
end

-- Mover mode: show the button faded so it can be dragged into place.
function NS.SetButtonMover(enabled)
    if not button then return end
    moverMode = enabled
    if enabled then
        button.pulse:Stop()
        button:SetAlpha(0.6)
        button.label:SetText("|cff44ff44DRAG ME|r")
        button:Show()
    else
        button:SetAlpha(1)
        button.label:SetText("|cffff4444SHAME!|r")
        button:Hide()
    end
end

function NS.IsButtonMoverOn() return moverMode end

-- Scale: 0.5x to 2x, applied live and saved.
function NS.SetButtonScale(scale)
    OneJobOwlDB.buttonScale = scale
    if button then button:SetScale(scale) end
end

-- Glow color: stored in OneJobOwlDB.glowColor, applied live.
function NS.ApplyGlowColor()
    if not button then return end
    local gc = OneJobOwlDB.glowColor or { r = 1, g = 0.2, b = 0.1, a = 0.7 }
    button.glow:SetVertexColor(gc.r, gc.g, gc.b, gc.a)
end

function NS.SetGlowColor(r, g, b, a)
    OneJobOwlDB.glowColor = { r = r, g = g, b = b, a = a }
    NS.ApplyGlowColor()
end