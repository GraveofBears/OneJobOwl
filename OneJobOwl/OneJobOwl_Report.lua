-- OneJobOwl_Report.lua
-- The Report Card: a parchment school-report of every encounter I Am Owl
-- graded this session, shown automatically when you leave the group/raid.
--
--   * Each I Am Owl fight report is also logged here (name, zone, grade,
--     stats). The session starts fresh when you JOIN a group and the card
--     pops when you LEAVE one, so it naturally covers "that raid".
--   * The card survives /reload (entries live in SavedVariables) and can
--     be reopened any time with /ojo card.
--   * The "post after-battle report" checkbox gates the card's auto-show
--     (and the per-fight bubble), so unchecking it silences both.
--
-- Layout: owl face top-left (happy for a B-or-better final grade, mad for
-- C/D/F), moonkin's name and the session's zones up top, close X (and ESC),
-- a scrolling list of encounter rows, and a fixed footer with combined
-- statistics plus a big colored final grade.

local ADDON_NAME, NS = ...

local MAX_ENTRIES = 50
local OWL_MAD     = "Interface\\AddOns\\OneJobOwl\\IamOwl.tga"
local OWL_HAPPY   = "Interface\\AddOns\\OneJobOwl\\IamOwlWoW.tga"
local PARCHMENT   = "Interface\\QuestFrame\\QuestBG"
-- QuestBG is a 512x512 sheet; the parchment art lives in this region.
local PARCH_COORDS = { 0, 0.585, 0.02, 0.62 }

local CARD_W, CARD_H = 380, 470
local ROW_H = 36
local INK = { r = 0.12, g = 0.08, b = 0.02 } -- Much darker, bolder ink

local card -- frame, built lazily on first show
local wasInGroup = nil

-- ===== session data =====

local function EnsureLog()
    if type(OneJobOwlDB.sessionLog) ~= "table"
        or type(OneJobOwlDB.sessionLog.entries) ~= "table" then
        OneJobOwlDB.sessionLog = { entries = {} }
    end
    return OneJobOwlDB.sessionLog
end

-- Called by IamOwl_EndCombat with one finished encounter's stats.
function NS.ReportCard_LogEncounter(e)
    local log = EnsureLog()
    table.insert(log.entries, e)
    while #log.entries > MAX_ENTRIES do table.remove(log.entries, 1) end
end

function NS.ReportCard_ClearSession()
    OneJobOwlDB.sessionLog = { entries = {} }
end

function NS.ReportCard_GetEntries()
    return EnsureLog().entries
end

-- Combined statistics + final grade (average of per-fight scores).
function NS.ReportCard_GetSummary()
    local entries = EnsureLog().entries
    if #entries == 0 then return nil end
    local s = { fights = #entries, refreshes = 0, drops = 0, downtime = 0 }
    local scoreSum, uptimeSum = 0, 0
    local zones, zoneSeen = {}, {}
    for _, e in ipairs(entries) do
        scoreSum    = scoreSum + (e.score or 0)
        uptimeSum   = uptimeSum + (e.uptimePct or 0)
        s.refreshes = s.refreshes + (e.refreshCount or 0)
        s.drops     = s.drops + (e.dropCount or 0)
        s.downtime  = s.downtime + (e.downtime or 0)
        local z = e.zone
        if z and z ~= "" and not zoneSeen[z] then
            zoneSeen[z] = true
            table.insert(zones, z)
        end
    end
    s.avgScore   = scoreSum / s.fights
    s.avgUptime  = uptimeSum / s.fights
    s.finalGrade = NS.GradeFor and NS.GradeFor(s.avgScore) or "?"
    s.zones      = zones
    return s
end

-- ===== UI =====

local function GradeHex(grade)
    return NS.GradeColorHex and NS.GradeColorHex(grade) or "ffffffff"
end

local function InkText(fs)
    fs:SetTextColor(INK.r, INK.g, INK.b)
    return fs
end

local function BuildCard()
    if card then return end

    card = CreateFrame("Frame", "OneJobOwlReportCard", UIParent, "BackdropTemplate")
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("CENTER")
    card:SetFrameStrata("DIALOG")
    card:SetClampedToScreen(true)
    card:EnableMouse(true)
    card:SetMovable(true)
    card:RegisterForDrag("LeftButton")
    card:SetScript("OnDragStart", card.StartMoving)
    card:SetScript("OnDragStop", card.StopMovingOrSizing)
    card:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    card:Hide()

    -- ESC closes it like any panel
    tinsert(UISpecialFrames, "OneJobOwlReportCard")

    local parchment = card:CreateTexture(nil, "BACKGROUND")
    parchment:SetPoint("TOPLEFT", 7, -7)
    parchment:SetPoint("BOTTOMRIGHT", -7, 7)
    parchment:SetTexture(PARCHMENT)
    parchment:SetTexCoord(unpack(PARCH_COORDS))

    -- Owl face, top-left: graded mood, set on populate
    local face = card:CreateTexture(nil, "ARTWORK")
    face:SetSize(56, 56)
    face:SetPoint("TOPLEFT", 10, -10)
    card.face = face

    -- Close X, top-right
    local close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    -- Title: the moonkin's name
    local title = card:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    title:SetPoint("TOP", 0, -20)
    title:SetWidth(CARD_W - 130)
    card.title = InkText(title)

    -- Subtitle: where the deeds were done
    local zone = card:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    zone:SetPoint("TOP", title, "BOTTOM", 0, -3)
    zone:SetWidth(CARD_W - 130)
    card.zone = InkText(zone)

    local headerLine = card:CreateTexture(nil, "ARTWORK")
    headerLine:SetColorTexture(0.35, 0.22, 0.08, 0.55)
    headerLine:SetPoint("TOPLEFT", 18, -68)
    headerLine:SetPoint("TOPRIGHT", -18, -68)
    headerLine:SetHeight(1)

    -- Scrolling body of encounter rows
    local scroll = CreateFrame("ScrollFrame", "OneJobOwlReportScroll", card, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -74)
    scroll:SetPoint("BOTTOMRIGHT", -36, 118)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CARD_W - 60, 10)
    scroll:SetScrollChild(content)
    card.content = content
    card.rows = {}

    local footerLine = card:CreateTexture(nil, "ARTWORK")
    footerLine:SetColorTexture(0.35, 0.22, 0.08, 0.55)
    footerLine:SetPoint("BOTTOMLEFT", 18, 112)
    footerLine:SetPoint("BOTTOMRIGHT", -18, 112)
    footerLine:SetHeight(1)

    -- Fixed footer: combined statistics + the big final grade
    local sumHead = card:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    sumHead:SetPoint("BOTTOMLEFT", 20, 92)
    sumHead:SetText("COMBINED STATISTICS")
    InkText(sumHead)

    local sum1 = card:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    sum1:SetPoint("BOTTOMLEFT", 20, 70)
    sum1:SetJustifyH("LEFT")
    card.sum1 = InkText(sum1)

    local sum2 = card:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    sum2:SetPoint("BOTTOMLEFT", 20, 52)
    sum2:SetJustifyH("LEFT")
    card.sum2 = InkText(sum2)

    local sum3 = card:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    sum3:SetPoint("BOTTOMLEFT", 20, 34)
    sum3:SetJustifyH("LEFT")
    card.sum3 = InkText(sum3)

    local gradeLabel = card:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    gradeLabel:SetPoint("BOTTOMRIGHT", -28, 84)
    gradeLabel:SetText("FINAL GRADE")
    InkText(gradeLabel)

	local finalGrade = card:CreateFontString(nil, "OVERLAY")
	finalGrade:SetFont("Fonts\\FRIZQT__.TTF", 34, "OUTLINE")
	finalGrade:SetPoint("TOP", gradeLabel, "BOTTOM", 0, -6)
	finalGrade:SetShadowOffset(0, 0)
	card.finalGrade = finalGrade
end

local function GetRow(i)
    if card.rows[i] then return card.rows[i] end
    local row = CreateFrame("Frame", nil, card.content)
    row:SetSize(CARD_W - 64, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)

    local name = row:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    name:SetPoint("TOPLEFT", 2, -2)
    name:SetWidth(CARD_W - 130)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = InkText(name)

    local stats = row:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    stats:SetPoint("TOPLEFT", 10, -18)
    stats:SetWidth(CARD_W - 120)
    stats:SetJustifyH("LEFT")
    stats:SetWordWrap(false)
    stats:SetTextColor(0.35, 0.24, 0.10)
    row.stats = stats

    local grade = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    grade:SetPoint("RIGHT", -6, 0)
    row.grade = grade

    card.rows[i] = row
    return row
end

local function Populate()
    local entries = NS.ReportCard_GetEntries()
    local summary = NS.ReportCard_GetSummary()
    if not summary then return false end

    local who = OneJobOwlDB.moonkinName
    if not who or who == "" then who = UnitName("player") or "The Owl" end
    card.title:SetText(who .. "'s Report Card")

    local zones = summary.zones
    local zoneText = ""
    if #zones > 0 then
        zoneText = zones[1]
        if zones[2] then zoneText = zoneText .. ", " .. zones[2] end
        if #zones > 2 then zoneText = zoneText .. (" +%d more"):format(#zones - 2) end
    end
    card.zone:SetText(zoneText)

    for i, e in ipairs(entries) do
        local row = GetRow(i)
        row.name:SetText(("%d. %s"):format(i, e.name or "Unknown foe"))
        local line = ("%d%% up · %d refresh%s · %d drop%s · %.1fs down"):format(
            e.uptimePct or 0,
            e.refreshCount or 0, (e.refreshCount == 1) and "" or "es",
            e.dropCount or 0, (e.dropCount == 1) and "" or "s",
            e.downtime or 0)
        row.stats:SetText(line)
        row.grade:SetText(("|c%s%s|r"):format(GradeHex(e.grade), e.grade or "?"))
        row:Show()
    end
    for i = #entries + 1, #card.rows do card.rows[i]:Hide() end
    card.content:SetHeight(math.max(#entries * ROW_H, 10))

    card.sum1:SetText(("%d encounter%s graded"):format(
        summary.fights, summary.fights == 1 and "" or "s"))
    card.sum2:SetText(("avg uptime %d%% · %d refreshes"):format(
        math.floor(summary.avgUptime + 0.5), summary.refreshes))
    card.sum3:SetText(("%d drop%s · %.1fs total downtime"):format(
        summary.drops, summary.drops == 1 and "" or "s", summary.downtime))

	local fg = summary.finalGrade
    card.finalGrade:SetText(("|c%s%s|r"):format(GradeHex(fg), fg))
    
    -- UPDATED: C+ is now considered a 'bad' grade to match your threshold
    local badGrade = (fg == "C+" or fg == "C" or fg == "D" or fg == "F")
    card.face:SetTexture(badGrade and OWL_MAD or OWL_HAPPY)
    
    return true
end

-- Show the card. With `manual` (the /ojo card path) an empty session gets
-- a chat nudge instead of a blank parchment.
function NS.ReportCard_Show(manual)
    if not NS.ReportCard_GetSummary() then
        if manual then
            print("|cffff8800[OneJobOwl]|r No graded encounters this session yet.")
        end
        return
    end
    BuildCard()
    if Populate() then card:Show() end
end

function NS.ReportCard_Hide()
    if card then card:Hide() end
end

-- ===== session lifecycle =====

function NS.ReportSession_Init()
    EnsureLog()
    wasInGroup = IsInRaid() or IsInGroup()
end

-- Wired to GROUP_ROSTER_UPDATE in core. Joining a group starts a fresh
-- session; leaving one presents the report card (if the report checkbox
-- is on and anything was graded).
function NS.ReportSession_OnRosterUpdate()
    local nowInGroup = IsInRaid() or IsInGroup()
    if wasInGroup == nil then
        wasInGroup = nowInGroup
        return
    end
    if nowInGroup and not wasInGroup then
        -- fresh group, fresh report card
        NS.ReportCard_ClearSession()
        NS.ReportCard_Hide()
    elseif wasInGroup and not nowInGroup then
        -- school's out: hand over the report card
        if OneJobOwlDB.iamowlReport ~= false then
            NS.ReportCard_Show(false)
        end
    end
    wasInGroup = nowInGroup
end
