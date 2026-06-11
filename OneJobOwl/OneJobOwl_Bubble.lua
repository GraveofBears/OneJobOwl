-- OneJobOwl_Bubble.lua
local ADDON_NAME, NS = ...

-- Two faces, one owl: mad for shames, happy for praise. The mood is driven
-- by the same isShame flag every message already carries.
local OWL_TEXTURE_MAD   = "Interface\\AddOns\\OneJobOwl\\IamOwl.tga"
local OWL_TEXTURE_HAPPY = "Interface\\AddOns\\OneJobOwl\\IamOwlWoW.tga"
local OWL_SIZE     = 128

local function OwlFaceFor(isShame)
    if isShame == true then return OWL_TEXTURE_MAD end
    return OWL_TEXTURE_HAPPY -- praise and neutral announcements both smile
end
local HALO_SCALE   = 1.20
local RING_SCALE   = 1.0
local BUBBLE_WIDTH = 280
local TEXT_PAD     = 14

local owl, balloon
local moverMode = false
local hideTimer

function NS.CreateOwlBubble()
    if owl then return end

    owl = CreateFrame("Frame", "OneJobOwlBubbleOwl", UIParent)
    owl:SetSize(OWL_SIZE, OWL_SIZE)
    owl:SetFrameStrata("HIGH")
    owl:SetClampedToScreen(true)
    owl:SetScale(OneJobOwlDB.bubbleScale or 1)
    owl:Hide()

    local pos = OneJobOwlDB.bubblePos
    if pos and pos.point then
        owl:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        owl:SetPoint("CENTER", UIParent, "CENTER", 0, 250)
    end

    local tex = owl:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(OWL_TEXTURE_MAD)
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
    owl.tex = tex

    local halo = owl:CreateTexture(nil, "BACKGROUND")
    halo:SetPoint("CENTER")
    halo:SetSize(OWL_SIZE * HALO_SCALE, OWL_SIZE * HALO_SCALE)
    halo:SetTexture("Interface\\Cooldown\\ping4")
    halo:SetBlendMode("ADD")
    halo:SetVertexColor(1, 0.82, 0.2, 0.55)
    owl.halo = halo

    local ring = owl:CreateTexture(nil, "OVERLAY")
    ring:SetPoint("CENTER")
    ring:SetSize(OWL_SIZE * RING_SCALE, OWL_SIZE * RING_SCALE)
    ring:SetTexture("Interface\\AddOns\\OneJobOwl\\OwlRing.tga")
    if ring.SetSnapToPixelGrid then
        ring:SetSnapToPixelGrid(false)
        ring:SetTexelSnappingBias(0)
    end
    owl.ring = ring

    -- Speech Bubble (child of owl again, but with independent scale)
    balloon = CreateFrame("Frame", "OneJobOwlBubbleBalloon", owl, "BackdropTemplate")
    balloon:SetPoint("BOTTOM", owl, "TOP", 0, -8)  -- fixed offset
    balloon:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\ChatBubble-Background",
        edgeFile = "Interface\\Tooltips\\ChatBubble-Backdrop",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 16, right = 16, top = 16, bottom = 16 },
    })
    balloon:SetScale(OneJobOwlDB.balloonScale or 1.0)

    local tail = balloon:CreateTexture(nil, "BORDER")
    tail:SetTexture("Interface\\Tooltips\\ChatBubble-Tail")
    tail:SetSize(16, 16)
    tail:SetPoint("TOP", balloon, "BOTTOM", 0, 4)
    balloon.tail = tail

    local text = balloon:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetWidth(BUBBLE_WIDTH - TEXT_PAD * 2)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(true)
    balloon.text = text

    -- Animations
    local fade = owl:CreateAnimationGroup()
    local alpha = fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1) alpha:SetToAlpha(0) alpha:SetDuration(0.6)
    fade:SetScript("OnFinished", function() owl:Hide() owl:SetAlpha(1) end)
    owl.fade = fade

    local fadeIn = owl:CreateAnimationGroup()
    local alphaIn = fadeIn:CreateAnimation("Alpha")
    alphaIn:SetFromAlpha(0) alphaIn:SetToAlpha(1) alphaIn:SetDuration(0.3) alphaIn:SetSmoothing("OUT")
    owl.fadeIn = fadeIn

    local bob = owl.tex:CreateAnimationGroup()
    bob:SetLooping("BOUNCE")
    local breathe = bob:CreateAnimation("Alpha")
    breathe:SetFromAlpha(1) breathe:SetToAlpha(0.78) breathe:SetDuration(0.8) breathe:SetSmoothing("IN_OUT")
    owl.bob = bob

    -- Dragging
    owl:SetMovable(true)
    owl:EnableMouse(true)
    owl:RegisterForDrag("LeftButton")
    owl:SetScript("OnDragStart", owl.StartMoving)
    owl:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        OneJobOwlDB.bubblePos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    owl:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("OneJobOwl - I Am Owl")
        if moverMode then
            GameTooltip:AddLine("Mover mode: drag to position.", 1, 1, 1)
            GameTooltip:AddLine("Uncheck 'Unlock owl bubble' in options when done.", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("The owl speaks its mind here.", 1, 1, 1)
            GameTooltip:AddLine("Drag: move the owl", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    owl:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function LayoutBalloon()
    if not balloon then return end
    local text = balloon.text
    local w = text:GetStringWidth() + TEXT_PAD * 2 + 16
    if w > BUBBLE_WIDTH then w = BUBBLE_WIDTH end
    if w < 90 then w = 90 end

    local h = text:GetStringHeight() + TEXT_PAD * 2
    if h < 40 then h = 40 end
    balloon:SetSize(w, h)
end

function NS.OwlBubbleSay(msg, isShame)
    if not owl or not balloon then return end
    if moverMode then return end

    if hideTimer then hideTimer:Cancel() hideTimer = nil end
    local wasShown = owl:IsShown()
    owl.fade:Stop()
    owl.fadeIn:Stop()
    owl:SetAlpha(1)

    if isShame == true then
        balloon.text:SetTextColor(1, 0.35, 0.35)
        owl.halo:SetVertexColor(1, 0.25, 0.15, 0.6)
    elseif isShame == false then
        balloon.text:SetTextColor(0.45, 1, 0.45)
        owl.halo:SetVertexColor(0.3, 1, 0.4, 0.55)
    else
        balloon.text:SetTextColor(1, 1, 1)
        owl.halo:SetVertexColor(1, 0.82, 0.2, 0.55)
    end
    owl.tex:SetTexture(OwlFaceFor(isShame))

    balloon.text:SetText(msg)
    LayoutBalloon()

    owl:Show()
    if not wasShown then owl.fadeIn:Play() end
    owl.bob:Play()

    local dur = OneJobOwlDB.bubbleDuration or 6
    hideTimer = C_Timer.NewTimer(dur, function()
        hideTimer = nil
        owl.bob:Stop()
        owl.fade:Play()
    end)
end

function NS.SetBubbleMover(enabled)
    if not owl then return end
    moverMode = enabled
    if hideTimer then hideTimer:Cancel() hideTimer = nil end
    owl.fade:Stop()
    owl.fadeIn:Stop()
    owl.bob:Stop()
    if enabled then
        owl:SetAlpha(0.8)
        owl.tex:SetTexture(OWL_TEXTURE_HAPPY)
        balloon.text:SetTextColor(0.3, 1, 0.3)
        balloon.text:SetText("DRAG ME -- this is where the owl will speak.")
        LayoutBalloon()
        owl:Show()
    else
        owl:SetAlpha(1)
        owl:Hide()
    end
end

function NS.IsBubbleMoverOn() return moverMode end

function NS.SetBubbleScale(scale)
    OneJobOwlDB.bubbleScale = scale
    if owl then owl:SetScale(scale) end
end

function NS.SetBalloonScale(scale)
    OneJobOwlDB.balloonScale = scale
    if balloon then balloon:SetScale(scale) end
end

function NS.PreviewOwlBubble()
    if moverMode then return end
    local pool = OneJobOwlDB.praises
    if not pool or #pool == 0 then pool = NS.praiseMessages end
    if pool and #pool > 0 then
        NS.OwlBubbleSay(pool[math.random(#pool)], false)
    end
end