-- OneJobOwl_IamOwlMulti.lua
-- Multi-target I Am Owl grading: one scorecard per tracked GUID,
-- aggregated into a single weighted grade at combat end.
--
-- HOW IT DIFFERS FROM THE SINGLE-TARGET GRADER:
--   * IamOwl_Scan / IamOwl_Drop / IamOwl_Excuse all receive the unit token
--     and resolve it to a GUID immediately. Every GUID gets its own scorecard
--     (ffUp, downStart, dropCount, refreshCount, etc.) stored in mobCards[guid].
--   * Mid-combat shames/praise fire per-mob, each with its own cooldown stored
--     in mobCards[guid].lastPraise / .lastShame so a busy AoE fight doesn't
--     spam one target's cooldown onto every other target.
--   * At combat end the scorecards are aggregated: each mob's score is weighted
--     by how long it was tracked (firstApplied -> combatEnd). Short-lived mobs
--     that only took one or two GCDs of FF have very little weight. The final
--     number drives a single combined grade shown in the same owl bubble/chat
--     format as the single-target report.
--   * Mobs that were never given FF (no firstApplied) are silently ignored --
--     they never entered the grader's books.
--
-- PUBLIC API (mirrors IamOwl.lua so core can route to either module):
--   NS.IamOwlMulti_StartCombat()
--   NS.IamOwlMulti_Scan(unit, rem)      -- rem = seconds remaining on FF
--   NS.IamOwlMulti_Drop(unit, dropAt)
--   NS.IamOwlMulti_Excuse(unit)
--   NS.IamOwlMulti_EndCombat()
--   NS.IamOwlMulti_Reset()              -- called by ResetTargetState (between pulls)
--
-- Enabled by OneJobOwlDB.iamowlMultiTarget == true (set via options checkbox).

local ADDON_NAME, NS = ...

local FF_DURATION     = 40
local PRAISE_COOLDOWN = 12   -- per-mob seconds between live praise lines
local SHAME_COOLDOWN  = 10   -- per-mob seconds between live shame lines

-- Cross-mob global cooldown: even if mob A and mob B both drop FF at the
-- same instant, only one shame fires. The next mob's message has to wait
-- this long before the owl speaks again. Keeps a mass-aura-wipe (death,
-- immune phase, AoE dispel) from dumping 5 shames in 0.2 seconds.
local GLOBAL_MSG_COOLDOWN = 5  -- seconds between ANY shame or praise message
local lastGlobalMessage   = 0  -- GetTime() of the last OwlSay call

-- ===== Clutch window (shared with single-target module) =====
local function TightWindow()
    return OneJobOwlDB.tightWindow or 8
end

-- ===== Per-combat state =====
local tracking    = false
local combatStart = nil
local mobCards    = {}   -- [guid] = scorecard (see NewCard below)
local mobOrder    = {}   -- stable insertion order for report display

local function NewCard(name)
    return {
        name         = name or "?",
        firstApplied = nil,   -- when FF first went up on this mob
        ffUp         = false,
        lastExpiry   = nil,   -- predicted expiration of the most recent cast
        downStart    = nil,   -- when FF last fell off (nil = currently up)
        dropCount    = 0,
        refreshCount = 0,
        totalDowntime= 0,
        leftoverSum  = 0,
        tightSum     = 0,
        lastPraise   = 0,
        lastShame    = 0,
    }
end

local function ClearState()
    tracking    = false
    combatStart = nil
    lastGlobalMessage = 0
    wipe(mobCards)
    wipe(mobOrder)
end

-- ===== Helper: get or create a card for a GUID =====
local function CardFor(unit)
    local guid = unit and UnitGUID(unit)
    if not guid then return nil, nil end
    if not mobCards[guid] then
        mobCards[guid] = NewCard(UnitName(unit) or "?")
        table.insert(mobOrder, guid)
    else
        -- keep the name fresh (target can rename on phase transitions)
        local n = UnitName(unit)
        if n then mobCards[guid].name = n end
    end
    return mobCards[guid], guid
end

-- ===== Output routing (same logic as single-target OwlSay) =====
local function OwlSay(text, isShame)
    NS.PlayIamOwlSound()
    if (OneJobOwlDB.iamowlOutput or "BUBBLE") == "BUBBLE" then
        if NS.OwlBubbleSay then
            NS.OwlBubbleSay(text, isShame)
            return
        end
    end
    local ch = OneJobOwlDB.channel or "WHISPER"
    local tagged = "[I Am Owl] " .. text
    if ch == "RAID" or ch == "PARTY" or ch == "YELL" or ch == "SAY" then
        tagged = tagged:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end
    if ch == "RAID" and IsInRaid() then
        SendChatMessage(tagged, "RAID")
    elseif ch == "PARTY" and IsInGroup() then
        SendChatMessage(tagged, "PARTY")
    elseif ch == "YELL" then
        SendChatMessage(tagged, "YELL")
    elseif ch == "SAY" then
        SendChatMessage(tagged, "SAY")
    else
        local color = isShame and "ffff4444" or "ff44ff44"
        print("|c" .. color .. "[I Am Owl]|r " .. text)
    end
end

-- ===== Scoring helpers (identical logic to IamOwl.lua) =====
local function ScoreCard(card, now)
    -- Returns score (0-100), uptimePct, avgLeftover|nil for one mob.
    -- now = the time at which to close the card (combat end).
    local span = (now - card.firstApplied)
    if span < 1 then span = 1 end

    local downtime = card.totalDowntime
    -- Close any open downtime window
    if card.downStart then
        downtime = downtime + (now - card.downStart)
    end

    local uptime = span - downtime
    if uptime < 0 then uptime = 0 end

    local uptimePct = math.floor((uptime / span) * 100 + 0.5)
    if downtime > 0.05 and uptimePct >= 100 then uptimePct = 99 end

    local score = uptimePct
    local avgLeftover = nil
    if card.refreshCount > 0 then
        avgLeftover = card.leftoverSum / card.refreshCount
        local tight = card.tightSum / card.refreshCount
        score = uptimePct * 0.88 + tight * 12
    end
    if card.dropCount > 0 then
        local cap = 84 - (card.dropCount - 1) * 6
        if score > cap then score = cap end
    end
    score = score - (downtime * 0.5)
    if score < 0 then score = 0 elseif score > 100 then score = 100 end

    return score, uptimePct, avgLeftover, downtime
end

-- ===== Public API =====

function NS.IamOwlMulti_StartCombat()
    if not NS.IsIamOwlMode() then return end
    ClearState()
    tracking    = true
    combatStart = GetTime()
end

-- Fed by core whenever FF IS present on a unit.
function NS.IamOwlMulti_Scan(unit, rem)
    if not NS.IsIamOwlMode() or not tracking then return end
    if rem == nil then return end
    if not UnitAffectingCombat("player") then return end

    local card, guid = CardFor(unit)
    if not card then return end

    local now = GetTime()
    local exp = now + rem

    if not card.ffUp then
        -- FF just went up (first application or reapplication after a drop)
        if card.downStart then
            card.totalDowntime = card.totalDowntime + (now - card.downStart)
            card.downStart = nil
        end
        if not card.firstApplied then card.firstApplied = now end
        card.ffUp      = true
        card.lastExpiry = exp
    else
        -- FF is already up: check for a refresh
        if card.lastExpiry and exp > card.lastExpiry + 0.5 then
            local leftover = card.lastExpiry - now

            -- Safety net: if the old expiry passed clearly before this cast,
            -- a drop slipped through detection (target swap / event race).
            -- Bill the gap and count it as a drop without shaming again.
            if leftover < -0.75 then
                card.totalDowntime = card.totalDowntime + (now - card.lastExpiry)
                card.dropCount     = card.dropCount + 1
                card.downStart     = nil
                card.lastExpiry    = exp
                -- No shame here: IamOwl_Drop already fired (or the gap was
                -- caused by a target swap and no drop event came). Either way,
                -- double-shaming the same mob is worse than silence.
                return
            end

            if leftover < 0 then leftover = 0 end

            card.refreshCount = card.refreshCount + 1
            card.leftoverSum  = card.leftoverSum  + leftover

            -- Tightness credit: 1.0 inside the clutch window, decays to 0
            -- at 1.5x the window (same formula as single-target module).
            local tw = TightWindow()
            local credit
            if leftover <= tw then
                credit = 1
            else
                credit = 1 - (leftover - tw) / (tw * 0.5)
                if credit < 0 then credit = 0 end
            end
            card.tightSum = card.tightSum + credit

            -- Per-mob clutch praise + cross-mob global cooldown
            local pool = OneJobOwlDB.praises
            if not pool or #pool == 0 then pool = NS.praiseMessages end
            if leftover <= tw
                and (now - card.lastPraise)   >= PRAISE_COOLDOWN
                and (now - lastGlobalMessage) >= GLOBAL_MSG_COOLDOWN
                and pool and #pool > 0 then
                card.lastPraise   = now
                lastGlobalMessage = now
                OwlSay(pool[math.random(#pool)], false)
            end
        end
        card.lastExpiry = exp
    end
end

-- Verified drop on a specific unit (called by core after death-race check).
function NS.IamOwlMulti_Drop(unit, dropAt)
    if not NS.IsIamOwlMode() or not tracking then return end

    local card, guid = CardFor(unit)
    if not card or not card.ffUp then return end

    card.ffUp      = false
    card.lastExpiry = nil
    card.downStart  = dropAt or GetTime()
    card.dropCount  = card.dropCount + 1

    -- Per-mob shame cooldown + cross-mob global cooldown
    local now = GetTime()
    if UnitAffectingCombat("player")
        and (now - card.lastShame)         >= SHAME_COOLDOWN
        and (now - lastGlobalMessage)      >= GLOBAL_MSG_COOLDOWN then
        card.lastShame    = now
        lastGlobalMessage = now
        local pool = OneJobOwlDB.shames
        if pool and #pool > 0 then
            OwlSay(pool[math.random(#pool)], true)
        end
    end
end

-- FF disappeared without fault (mob died, boss phase, etc.).
function NS.IamOwlMulti_Excuse(unit)
    if not tracking then return end
    local card = unit and mobCards[UnitGUID(unit) or ""]
    if not card then return end
    if card.ffUp then
        card.ffUp      = false
        card.lastExpiry = nil
    end
    card.downStart = nil
end

-- Clean up a mob's card when it dies mid-fight (removes it from grading so
-- a mob that died with FF up doesn't count as a drop).
function NS.IamOwlMulti_MobDied(guid)
    if not tracking then return end
    local card = guid and mobCards[guid]
    if not card then return end
    -- Close the card cleanly: if FF was up when it died that is not a drop.
    card.ffUp      = false
    card.lastExpiry = nil
    card.downStart  = nil  -- no ongoing downtime; it's dead
end

-- Called by ResetTargetState between pulls (out of combat only).
function NS.IamOwlMulti_Reset()
    if UnitAffectingCombat("player") then return end
    if tracking then return end   -- open scorecard; EndCombat closes it
    ClearState()
end

-- Combat end: aggregate all scorecards and post one combined grade.
function NS.IamOwlMulti_EndCombat()
    if not tracking then return end
    tracking = false
    if not NS.IsIamOwlMode() then
        ClearState()
        return
    end

    local now = GetTime()

    -- Collect only mobs that actually had FF applied during this fight.
    local scored = {}
    for _, guid in ipairs(mobOrder) do
        local card = mobCards[guid]
        if card and card.firstApplied then
            local span = now - card.firstApplied
            if span < 1 then span = 1 end
            local score, uptimePct, avgLeftover, downtime = ScoreCard(card, now)
            table.insert(scored, {
                name       = card.name,
                span       = span,
                score      = score,
                uptimePct  = uptimePct,
                avgLeftover= avgLeftover,
                dropCount  = card.dropCount,
                refreshCount=card.refreshCount,
                downtime   = downtime,
            })
        end
    end

    if #scored == 0 then
        ClearState()
        return
    end

    -- Weighted average: each mob's score is weighted by how long it was
    -- tracked. A mob you only hit once for 3 seconds barely moves the needle;
    -- the main boss you fought for 90 seconds dominates.
    local totalWeight = 0
    local weightedScore = 0
    local totalRefreshes = 0
    local totalDrops = 0
    local totalDowntime = 0
    local totalUptimeNum = 0   -- for blended uptime %
    for _, s in ipairs(scored) do
        totalWeight     = totalWeight     + s.span
        weightedScore   = weightedScore   + s.score * s.span
        totalRefreshes  = totalRefreshes  + s.refreshCount
        totalDrops      = totalDrops      + s.dropCount
        totalDowntime   = totalDowntime   + s.downtime
        totalUptimeNum  = totalUptimeNum  + s.uptimePct * s.span
    end

    local finalScore  = weightedScore  / totalWeight
    local finalUptime = totalUptimeNum / totalWeight
    if finalScore  > 100 then finalScore  = 100 end
    if finalScore  < 0   then finalScore  = 0   end

    local grade      = NS.GradeFor(finalScore)
    local rounded    = math.floor(finalScore + 0.5)
    local uptimePct  = math.floor(finalUptime + 0.5)

    -- Color grade using shared helper
    local function ColorGrade(text, g)
        return "|c" .. (NS.GradeColorHex(g) or "ffffffff") .. text .. "|r"
    end
    local gradeText = ColorGrade(("Grade %s (%d)"):format(grade, rounded), grade)

    -- Mob count label
    local mobLabel = #scored == 1
        and scored[1].name
        or (tostring(#scored) .. " targets")

    local report = string.format(
        "%s | %s | %d%% uptime | %d refresh%s | %d drop%s | %.1fs downtime",
        gradeText,
        mobLabel,
        uptimePct,
        totalRefreshes, totalRefreshes == 1 and "" or "es",
        totalDrops,     totalDrops     == 1 and "" or "s",
        totalDowntime)

    -- Log to the Report Card module (same format as single-target)
    if NS.ReportCard_LogEncounter then
        -- Use the highest-weight mob as the encounter name for the card
        local heaviest = scored[1]
        for _, s in ipairs(scored) do
            if s.span > heaviest.span then heaviest = s end
        end
        NS.ReportCard_LogEncounter({
            name        = heaviest.name .. (#scored > 1 and (" (+"..(#scored-1)..")") or ""),
            zone        = (GetRealZoneText and GetRealZoneText()) or "",
            grade       = grade,
            score       = rounded,
            uptimePct   = uptimePct,
            refreshCount= totalRefreshes,
            dropCount   = totalDrops,
            downtime    = totalDowntime,
            avgLeftover = nil,   -- n/a for multi-target aggregate
            when        = time(),
        })
    end

    local badGrade = (grade == "C+" or grade == "C" or grade == "D" or grade == "F")
    if OneJobOwlDB.iamowlReport ~= false then
        OwlSay(report, badGrade)
    end

    ClearState()
end