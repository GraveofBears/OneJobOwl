-- OneJobOwl_FFBar.lua
-- The Faerie Fire Bar: a compact per-target FF tracker.

local ADDON_NAME, NS = ...

local FF_DURATION = 40
local HEADER_H = 20
local ICON_FF = "Interface\\Icons\\Spell_Nature_FaerieFire"

-- live-tunable dimensions
local function BarW()   return OneJobOwlDB.ffbarWidth or 190 end
local function RowH()   return OneJobOwlDB.ffbarRowHeight or 20 end
local function RowGap() return OneJobOwlDB.ffbarRowPadding or 2 end
local function MaxDyn() return OneJobOwlDB.ffbarMaxRows or 8 end

local ENABLE_PRAISES = {
    "Now THAT'S a prepared student! Keep Faerie Fire glowing on every target and there will be gold stars on your report card.",
    "Using the study guide, are we? Excellent. Faerie Fire on everything, and I'll have nothing left to shame.",
    "A+ attitude! Watch the bar, click the rows, and the boss's armor doesn't stand a chance.",
}

local bar                -- movable anchor
local secureRows = {}    -- Target / Focus
local dynRows    = {}    -- dynamic rows
local moverRows  = {}    -- mover placeholders
local tracked    = {}    -- [guid] = data
local trackedOrder = {}  -- stable order
local moverMode  = false
local ticker
local playerGUID
local pendingLayout, pendingVisibility = false, false

local events = CreateFrame("Frame")

local function FFSpellName()
    return GetSpellInfo(770) or "Faerie Fire"
end

local function RegisterRowClicks(btn)
    local useDown = false
    if GetCVarBool then
        local ok, v = pcall(GetCVarBool, "ActionButtonUseKeyDown")
        useDown = (ok and v) and true or false
    end
    btn:RegisterForClicks(useDown and "AnyDown" or "AnyUp")
end

local function UnitFFRemaining(unit)
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime, source, _, _, spellId = UnitDebuff(unit, i)
        if not name then break end
        if source == "player" and NS.FF_SPELL_IDS and NS.FF_SPELL_IDS[spellId] then
            return (expirationTime and expirationTime > 0) and (expirationTime - GetTime()) or FF_DURATION
        end
    end
    return nil
end

-- ===== row visuals with border =====
local function BuildRowVisuals(row)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    row.bgTex = bg

    -- Create 4 border textures
    row.border = {}
    local borderCfg = {
        {"TOP", 0, 1}, {"BOTTOM", 0, -1}, {"LEFT", -1, 0}, {"RIGHT", 1, 0}
    }
    for i, v in ipairs(borderCfg) do
        local t = row:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 0, 0, 0.9) -- Initial color
        t:SetAlpha(0) -- Hidden by default
        t:SetPoint(v[1], v[2], v[3])
        if i <= 2 then t:SetSize(0, 1); t:SetPoint("LEFT"); t:SetPoint("RIGHT")
        else t:SetPoint("TOP"); t:SetPoint("BOTTOM"); t:SetWidth(1) end
        row.border[i] = t
    end
    
    -- Helper to toggle border visibility
    row.ShowBorder = function(self, show)
        for _, t in ipairs(self.border) do t:SetAlpha(show and 1 or 0) end
    end

    local fill = row:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetWidth(1)
    fill:SetColorTexture(0.13, 0.7, 0.2, 0.85)
    row.fill = fill

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", 0, 0)
    icon:SetTexture(ICON_FF)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("RIGHT", -38, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    local time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    time:SetPoint("RIGHT", -4, 0)
    time:SetJustifyH("RIGHT")
    row.time = time
end

local function SizeRowVisuals(row)
    row.icon:SetSize(RowH() - 0, RowH() - 0)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", RowH() + 6, 0)
    row.name:SetPoint("RIGHT", -38, 0)
end

local function FormatRemain(remain)
    if remain >= 10 then return ("%ds"):format(remain) end
    if remain > 0 then return ("%.1fs"):format(remain) end
    return "0s"
end

local function PaintRow(row, label, remain, missing)
    local w = row:GetWidth()
    row.name:SetText(label)

    if missing then
        row.fill:SetWidth(w)
        row.fill:SetColorTexture(0.8, 0.12, 0.08, 0.9)
        row.time:SetText("FELL OFF")
        row.time:SetTextColor(1, 0.35, 0.35)
        row.name:SetTextColor(1, 0.85, 0.85)
        return
    end
    if not remain then
        row.fill:SetWidth(1)
        row.time:SetText("--")
        row.time:SetTextColor(0.6, 0.6, 0.6)
        row.name:SetTextColor(0.7, 0.7, 0.7)
        return
    end
    if remain < 0 then remain = 0 end
    local fillW = (remain / FF_DURATION) * w
    if fillW < 1 then fillW = 1 end
    row.fill:SetWidth(fillW)

    if remain <= 5 then row.fill:SetColorTexture(0.8, 0.15, 0.1, 0.9)
    elseif remain <= 10 then row.fill:SetColorTexture(0.85, 0.65, 0.1, 0.85)
    else row.fill:SetColorTexture(0.13, 0.7, 0.2, 0.85) end

    row.time:SetText(FormatRemain(remain))
    row.time:SetTextColor(1, 1, 1)
    row.name:SetTextColor(1, 1, 1)
end

local function RowY(slot)
    -- The 16 constant determines the distance from the top header
    return -(16 + (slot - 1) * (RowH() + RowGap()))
end

local function LayoutSecureRows()
    if not bar then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    local scale = OneJobOwlDB.ffbarScale or 1
    local left, top = bar:GetLeft(), bar:GetTop()
    if not left or not top then return end
    for slot, btn in ipairs(secureRows) do
        btn:SetScale(scale)
        btn:SetSize(BarW(), RowH())
        SizeRowVisuals(btn)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + 4, top + RowY(slot))
    end
end

local function ApplySecureVisibility()
    if not bar then return end
    if InCombatLockdown() then pendingVisibility = true return end
    pendingVisibility = false
    local live = (OneJobOwlDB.ffbarEnabled == true) and not moverMode
    for _, btn in ipairs(secureRows) do
        UnregisterAttributeDriver(btn, "state-visibility")
        if live then
            RegisterAttributeDriver(btn, "state-visibility",
                ("[@%s,harm,nodead] show; hide"):format(btn.unit))
        else
            btn:Hide()
        end
    end
end

local function EnsureDynRow(i)
    if dynRows[i] then return dynRows[i] end
    local row = CreateFrame("Frame", nil, bar)
    BuildRowVisuals(row)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("OneJobOwl - Faerie Fire Bar")
        GameTooltip:AddLine("Timer only: Blizzard blocks casting on arbitrary mobs in combat. Tab or focus it.", 1, 1, 1)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:Hide()
    dynRows[i] = row
    return row
end

local function ApplyLayout()
    if not bar then return end
    -- Use RowGap() here so the bar height accounts for your chosen padding
    local totalRows = MaxDyn()
    bar:SetSize(BarW() + 8, HEADER_H + (1 + totalRows) * (RowH() + RowGap()) + 6)

    for i = 1, math.max(totalRows, #dynRows) do
        if i <= totalRows then
            local row = EnsureDynRow(i)
            row:SetSize(BarW(), RowH())
            SizeRowVisuals(row)
            row:ClearAllPoints()
            -- Aligning with RowY(i) pulls the rows up under the header
            row:SetPoint("TOPLEFT", bar, "TOPLEFT", 4, RowY(i))
        elseif dynRows[i] then
            dynRows[i]:Hide()
        end
    end

    for slot, row in ipairs(moverRows) do
        row:SetSize(BarW(), RowH())
        SizeRowVisuals(row)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", bar, "TOPLEFT", 4, RowY(slot))
    end
end

local function UpdateDynRows()
    local tGUID = UnitGUID("target")
    local now = GetTime()

    -- Cleanup expired
    for i = #trackedOrder, 1, -1 do
        local guid = trackedOrder[i]
        local e = tracked[guid]
        if not e or (e.missing and (e.expires + 2 < now)) then
            table.remove(trackedOrder, i)
            tracked[guid] = nil
        end
    end

    -- Paint rows
    for i = 1, MaxDyn() do
        local guid = trackedOrder[i]
        local e = guid and tracked[guid]
        local row = EnsureDynRow(i)

        if e then
            local remain = e.missing and -1 or (e.expires - now)
            PaintRow(row, e.name or "?", e.missing and nil or remain, e.missing)
            
            -- Highlight only if this row matches your target
            if guid == tGUID then
                row:ShowBorder(true)
            else
                row:ShowBorder(false)
            end
            row:Show()
        else
            row:ShowBorder(false)
            row:Hide()
        end
    end
end

local function UpdateSecureRow(btn)
    if not btn:IsShown() then return end
    local label = ("[%s] %s"):format(btn.tag, UnitName(btn.unit) or "?")
    local remain = UnitFFRemaining(btn.unit)
    local guid = UnitGUID(btn.unit)
    local missing = false
    if not remain and guid and tracked[guid] and tracked[guid].missing then
        missing = true
    end
    PaintRow(btn, label, remain, missing)
end

local function OnTick()
    if not bar or moverMode or OneJobOwlDB.ffbarEnabled ~= true then return end
    if bar:IsShown() then UpdateDynRows() end
end

local function HandleCLEU()
    local _, sub, _, sourceGUID, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()

    if sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" then
        if tracked[destGUID] then
            for i, guid in ipairs(trackedOrder) do
                if guid == destGUID then
                    table.remove(trackedOrder, i)
                    break
                end
            end
            tracked[destGUID] = nil
        end
        return
    end

    if sourceGUID ~= playerGUID then return end

    local spellId = select(12, CombatLogGetCurrentEventInfo())
    if not (NS.FF_SPELL_IDS and NS.FF_SPELL_IDS[spellId]) then return end

    if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
        if not tracked[destGUID] then
            table.insert(trackedOrder, destGUID)
            tracked[destGUID] = { name = destName }
        else
            tracked[destGUID].name = destName
        end
        tracked[destGUID].expires = GetTime() + FF_DURATION
        tracked[destGUID].missing = nil
    elseif sub == "SPELL_AURA_REMOVED" then
        if tracked[destGUID] then tracked[destGUID].missing = true end
    end
end

events:SetScript("OnEvent", function(self, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCLEU()
    elseif event == "PLAYER_REGEN_ENABLED" then
        wipe(tracked)
        wipe(trackedOrder)
        if pendingVisibility then ApplySecureVisibility() end
        if pendingLayout then LayoutSecureRows() end
    end
end)

-- ===== public API =====
function NS.FFBar_SetMover(enabled)
    if not bar then return end
    if InCombatLockdown() then return end
    moverMode = enabled and true or false
    if moverMode then
        bar:Show()
        bar.backdropTex:Show()
        bar.title:SetText("|cff44ff44DRAG ME|r")
        moverRows[1]:Show()
        moverRows[2]:Show()
        local d1, d2 = EnsureDynRow(1), EnsureDynRow(2)
        PaintRow(d1, "Sample Mob 1", 8, false) d1:Show()
        PaintRow(d2, "Sample Mob 2", 3, false) d2:Show()
    else
        bar.backdropTex:Hide()
        bar.title:SetText("Faerie Fire")
        moverRows[1]:Hide()
        moverRows[2]:Hide()
        for _, row in ipairs(dynRows) do
            row:ShowBorder(false) -- Hide the new border
            row:Hide()
        end
        bar:SetShown(OneJobOwlDB.ffbarEnabled == true)
        LayoutSecureRows()
    end
    ApplySecureVisibility()
end

function NS.FFBar_IsMoverOn() return moverMode end

function NS.FFBar_SetScale(scale)
    OneJobOwlDB.ffbarScale = scale
    if bar then
        bar:SetScale(scale)
        LayoutSecureRows()
    end
end

function NS.FFBar_SetWidth(w)
    OneJobOwlDB.ffbarWidth = math.floor(w + 0.5)
    ApplyLayout()
end

function NS.FFBar_SetRowHeight(h)
    OneJobOwlDB.ffbarRowHeight = math.floor(h + 0.5)
    ApplyLayout()
end

function NS.FFBar_SetMaxRows(n)
    OneJobOwlDB.ffbarMaxRows = math.floor(n + 0.5)
    ApplyLayout()
end

function NS.FFBar_IsEnabled()
    return OneJobOwlDB.ffbarEnabled == true
end

NS.FFBar_ApplyLayout = ApplyLayout

function NS.FFBar_SetEnabled(on)
    if on and OneJobOwlDB.mode ~= "IAMOWL" then
        print("|cffff8800[OneJobOwl]|r The Faerie Fire bar is an I Am Owl tool. Switch Mode to 'I Am Owl' first (/ojo).")
        return false
    end
    on = on and true or false
    local was = OneJobOwlDB.ffbarEnabled == true
    OneJobOwlDB.ffbarEnabled = on
    if bar and not moverMode then
        bar:SetShown(on)
    end
    ApplySecureVisibility()
    if on and not was then
        if NS.OwlBubbleSay then
            NS.OwlBubbleSay(ENABLE_PRAISES[math.random(#ENABLE_PRAISES)], false)
        end
        if NS.PlaySoundByID then NS.PlaySoundByID(OneJobOwlDB.iamowlSound or 0) end
    end
    return was ~= on
end

-- ===== init =====
function NS.FFBar_Init()
    if bar then return end
    playerGUID = UnitGUID("player")

    bar = CreateFrame("Frame", "OneJobOwlFFBar", UIParent, "BackdropTemplate")
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetScale(OneJobOwlDB.ffbarScale or 1)

    local pos = OneJobOwlDB.ffbarPos
    if pos and pos.point then
        bar:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        bar:SetPoint("LEFT", UIParent, "LEFT", 80, 0)
    end

    local backdropTex = bar:CreateTexture(nil, "BACKGROUND")
    backdropTex:SetAllPoints()
    backdropTex:SetColorTexture(0, 0, 0, 0.35)
    backdropTex:Hide()
    bar.backdropTex = backdropTex

    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 6, -2)
    title:SetText("Faerie Fire")
    bar.title = title

    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) if moverMode then self:StartMoving() end end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        OneJobOwlDB.ffbarPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    -- Mover placeholders (keeping these for mover mode preview)
    for slot = 1, MaxDyn() do
        local row = CreateFrame("Frame", nil, bar)
        BuildRowVisuals(row)
        row:Hide()
        moverRows[slot] = row
    end

    ApplyLayout()

    events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    ticker = C_Timer.NewTicker(0.2, OnTick)

    if OneJobOwlDB.ffbarEnabled and OneJobOwlDB.mode ~= "IAMOWL" then
        OneJobOwlDB.ffbarEnabled = false
    end
    bar:SetShown(OneJobOwlDB.ffbarEnabled == true)
end