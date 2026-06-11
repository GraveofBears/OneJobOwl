-- OneJobOwl_IamOwl.lua
-- "I Am Owl" praise mode: the moonkin runs this on themselves and gets graded
-- on their OWN Faerie Fire discipline during a fight.
--
--   * Refresh FF before it falls off      -> good. The closer to expiry you
--     cut it (without dropping it), the more efficient -> higher score.
--   * Let FF fall off the boss entirely    -> a "drop" -> instant shame.
--   * End of combat                        -> an after-action report: uptime %,
--     number of refreshes, total seconds FF was off the boss, and a letter grade.
--
-- Output goes to your OWN chat frame by default (channel = WHISPER, since
-- whispering yourself makes no sense). Set the channel to SAY / PARTY / RAID /
-- YELL in the options panel if you want the owl to announce its greatness.
--
-- Driven entirely by the core: core calls NS.IamOwl_StartCombat /
-- NS.IamOwl_Scan / NS.IamOwl_EndCombat. This file only DEFINES functions --
-- it never reaches into core internals at load time.

local ADDON_NAME, NS = ...
NS.praiseMessages = {
    -- Unhinged Moonkin Energy
    "Your Faerie Fire uptime is so perfect it’s giving the boss performance anxiety.",
    "You didn’t just debuff the armor — you debuffed the boss’s will to live.",
    "That refresh was so clean even the Rogues stopped lying about their uptime.",
    "You’re maintaining that debuff like it owes you rent.",
    "The boss is filing an HR complaint against your Faerie Fire.",
    "Your uptime is so tight it should be classified as a raid cooldown.",
    "You’re not a Moonkin — you’re a walking OSHA violation.",
    "That debuff is clinging harder than a Warlock to their DoTs.",
    "You’ve applied Faerie Fire so consistently the boss thinks it’s a lifestyle.",
    "Your uptime is so good the boss asked if you’re running add-ons IRL.",

    -- Raid-Leader Approved Insults
    "If everyone did their job like you, we’d clear content by accident.",
    "Your Faerie Fire is carrying harder than the tank’s chiropractor.",
    "You’re the only reason this boss isn’t still at 98%.",
    "That debuff uptime is the only thing keeping this raid from collapsing.",
    "You’re doing so well the healers are suspicious.",
    "Your FF uptime is the only thing in this raid that isn’t disappointing.",
    "You’re melting the boss faster than our morale on wipe 12.",
    "If the raid had your discipline, we’d be world-first by now.",
    "Your debuffing is so good the boss is considering early retirement.",
    "You’re the only one here who actually read their spellbook.",

    -- Petty, Spite-Powered Praise
    "You’re refreshing FF like you’re trying to prove something. And it’s working.",
    "Your uptime is so good it’s making the Rogues insecure.",
    "You’re maintaining that debuff out of pure spite and I respect it.",
    "You’re bullying the boss harder than the raid bullies the Shadow Priest.",
    "That refresh was so tight it made the boss question its armor choices.",
    "You’re the only one here who presses their utility button on purpose.",
    "Your Faerie Fire is the only stable thing in this raid group.",
    "You’re debuffing like you’re trying to win a custody battle.",
    "Your uptime is so high it’s making the Paladin jealous.",
    "You’re applying FF like it personally wronged you.",

    -- Lore-Friendly But Still Deranged
    "Elune just whispered: ‘who is that owl and why are they so angry.’",
    "You channel the stars like they owe you money.",
    "Nature is proud. The boss is not.",
    "Your Faerie Fire burns brighter than your social skills.",
    "You wield cosmic power like a toddler with scissors.",
    "The stars tremble. The boss cries.",
    "You’ve achieved perfect lunar aggression.",
    "Your FF uptime is now canon in the druid class hall.",
    "You’re the chosen one. The boss wishes you weren’t.",
    "Elune is watching. And she’s wheezing.",

    -- Meme & Meta Tier
    "Wait, you actually pressed a utility spell? Incredible.",
    "The boss just whispered: ‘please stop glowing, it hurts.’",
    "Your Faerie Fire uptime is so high it’s basically a bug.",
    "You’re doing the work of an entire debuff-bot.",
    "The boss’s armor has left the chat.",
    "Your uptime is so good the combat log blushed.",
    "You’ve turned the boss into a squishy. Congratulations.",
    "Your FF uptime is the raid’s true secret sauce.",
    "You’re the MVP of the armor-melting Olympics.",
    "The boss is wondering where their armor went and why you hate them.",
	"Your Faerie Fire uptime is so good the boss asked if you’re using wallhacks.",
	"You’re refreshing FF like you’re trying to impress Elune on a first date.",
	"That debuff is sticking harder than a Hunter to bad loot.",
	"You’re maintaining FF with the energy of someone who REALLY wants a parse.",
	"Your uptime is so high the boss thinks you’re running a script.",
	"You’ve bullied the armor off this boss and you’re not even sorry.",
	"Your Faerie Fire is the only thing holding this raid together emotionally.",
	"You’re refreshing FF like it’s the only joy you have left.",
	"That uptime is tighter than a Rogue’s excuses.",
	"You’ve applied FF so consistently the boss thinks it’s a permanent aura.",
	"Your debuffing is so good the tank is considering sending you flowers.",
	"You’re melting armor faster than the raid melts brain cells.",
	"Your FF uptime is the only thing preventing a healer strike.",
	"You’re refreshing like you’re speedrunning a utility‑button world record.",
	"That debuff is clinging harder than a Mage to their food buff.",
	"You’re the reason the boss is questioning its life choices.",
	"Your uptime is so good the combat log asked for your autograph.",
	"You’re maintaining FF like you’re trying to win a scholarship.",
	"That refresh was so clean it exfoliated the boss.",
	"You’re debuffing with the confidence of someone who knows the mechanics.",
	"Your Faerie Fire is the raid’s emotional support buff.",
	"You’re refreshing FF like you’re being graded… which you are.",
	"Your uptime is so high the boss thinks you’re multiboxing yourself.",
	"You’ve turned the boss’s armor into a suggestion.",
	"Your FF is more reliable than the tank’s cooldowns.",
	"You’re maintaining that debuff like it’s your side hustle.",
	"Your uptime is so good the boss asked for a break.",
	"You’re refreshing FF like you’re trying to get promoted.",
	"That debuff is sticking harder than a Warlock to a soul shard.",
	"You’re the reason the boss is Googling ‘how to cope with Moonkins’.",
	"Your Faerie Fire uptime is the only thing preventing a wipe.",
	"You’re refreshing FF like you’re trying to impress the loot council.",
	"Your uptime is so high the boss thinks you’re time-traveling.",
	"You’ve debuffed the armor so hard it filed a missing‑armor report.",
	"Your FF is the only thing in this raid that’s consistent.",
	"You’re refreshing like you’re trying to win a custody battle with Elune.",
	"Your uptime is so good the boss asked if you’re okay.",
	"You’re maintaining FF like it’s your emotional support spell.",
	"That refresh was so tight it made the boss flinch.",
	"You’re debuffing with the enthusiasm of a Druid who found a new macro.",
	"Your Faerie Fire uptime is the only thing keeping the DPS honest.",
	"You’re refreshing FF like you’re trying to get tenure in Moonglade.",
	"Your uptime is so high the boss thinks you’re cheating on your GCDs.",
	"You’ve turned the boss into a walking armor‑free zone.",
	"Your FF is more dependable than the raid’s attendance.",
	"You’re refreshing like you’re trying to impress the parser gods.",
	"Your uptime is so good the boss asked for a restraining order.",
	"You’re maintaining FF like you’re being paid per refresh.",
	"That debuff is sticking harder than a Paladin to bubble-hearth.",
	"You’re the reason the boss is reconsidering its armor choices.",
	
}

-- Faerie Fire lasts 40s; a "tight" refresh lands in the last few seconds.
local FF_DURATION   = 40
local PRAISE_COOLDOWN = 12  -- min seconds between live clutch-praise lines (anti-spam)

-- Clutch window: refreshing with <= this many seconds left counts as a
-- clutch refresh. Configurable via the options slider (1-10s, default 8).
local function TightWindow()
    return OneJobOwlDB.tightWindow or 8
end

-- ===== per-combat state =====
local tracking       = false
local combatStart    = nil
local firstApplied   = nil   -- when FF first went up this fight
local ffUp           = false -- is FF currently on the boss?
local lastExpiration = nil   -- expiration timestamp of the FF cast we last saw
local downStart      = nil   -- when FF last fell off (nil while up)
local refreshCount   = 0
local dropCount      = 0
local totalDowntime  = 0
local leftoverSum    = 0     -- sum of "seconds left at the moment of refresh"
local lastPraise     = 0

local function ClearState()
    combatStart, firstApplied   = nil, nil
    ffUp, lastExpiration, downStart = false, nil, nil
    refreshCount, dropCount     = 0, 0
    totalDowntime, leftoverSum  = 0, 0
    lastPraise                  = 0
end

function NS.IsIamOwlMode()
    return OneJobOwlDB.mode == "IAMOWL"
end

-- One-line state dump for /ojo debug.
function NS.IamOwlDebugLine()
    return string.format(
        "IamOwl: tracking=%s ffUp=%s firstApplied=%s refreshes=%d drops=%d downtime=%.1fs report=%s output=%s",
        tostring(tracking), tostring(ffUp),
        firstApplied and "yes" or "no",
        refreshCount, dropCount, totalDowntime,
        tostring(OneJobOwlDB.iamowlReport ~= false),
        tostring(OneJobOwlDB.iamowlOutput or "BUBBLE"))
end

-- Called from core's ResetTargetState. Two guards: never wipe mid-combat
-- (target swaps onto adds must not throw away the fight's numbers), and
-- never wipe an OPEN scorecard -- on a killing blow the player's combat
-- flag drops a beat before PLAYER_REGEN_ENABLED dispatches, and a death
-- scan landing in that window used to slip past the combat guard and
-- erase the fight right before the report. Closing a live scorecard is
-- IamOwl_EndCombat's job alone; this only sweeps up stale, already-
-- reported state between pulls.
function NS.ResetIamOwlTracking()
    if UnitAffectingCombat("player") then return end
    if tracking then return end -- open scorecard: EndCombat will close it
    ClearState()
end

-- Play the selected sound if one is configured
function NS.PlayIamOwlSound()
    local id = OneJobOwlDB.iamowlSound or 0
    if id and id > 0 then
        PlaySound(id, "Master")
    end
end

-- Route a line to its destination. Default ("BUBBLE") shows it in the
-- on-screen owl speech bubble -- zero chat spam. Set the I Am Owl output to
-- "CHAT" in options to broadcast on the configured channel instead (or print
-- privately when the channel is WHISPER, since whispering yourself is silly).
local function OwlSay(text, isShame)
    -- Trigger the selected sound whenever the Owl speaks or reports
    NS.PlayIamOwlSound()

    if (OneJobOwlDB.iamowlOutput or "BUBBLE") == "BUBBLE" then
        if NS.OwlBubbleSay then
            NS.OwlBubbleSay(text, isShame)
            return
        end
        -- bubble file missing somehow: fall through to chat so nothing is lost
    end
    local ch = OneJobOwlDB.channel or "WHISPER"
    local tagged = "[I Am Owl] " .. text
    if ch == "RAID" or ch == "PARTY" or ch == "YELL" or ch == "SAY" then
        -- Color escape codes don't render in outbound chat (and can get the
        -- message eaten), so strip them before broadcasting.
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

-- Combat start: fresh scorecard.
function NS.IamOwl_StartCombat()
    if not NS.IsIamOwlMode() then return end
    ClearState()
    tracking = true
    combatStart = GetTime()
end

-- Fed by core on every aura scan where FF IS on the unit (rem = seconds
-- remaining). Drops are no longer detected here: core verifies a drop is
-- real (not a death race or a boss phase) and then calls IamOwl_Drop or
-- IamOwl_Excuse instead.
function NS.IamOwl_Scan(unit, rem)
    if not NS.IsIamOwlMode() or not tracking then return end
    if rem == nil then return end
    local now = GetTime()

    -- Block all live praise once combat is ending
    if not UnitAffectingCombat("player") then return end

    -- FF is on the boss right now.
    local exp = now + rem

    if not ffUp then
        if downStart then
            totalDowntime = totalDowntime + (now - downStart)
            downStart = nil
        end
        if not firstApplied then firstApplied = now end
        ffUp = true
        lastExpiration = exp
    else
        -- Refresh detected
        if lastExpiration and exp > lastExpiration + 0.5 then
            local leftover = lastExpiration - now
            if leftover < 0 then leftover = 0 end

            refreshCount = refreshCount + 1
            leftoverSum = leftoverSum + leftover

            -- Clutch refresh praise - only while actively in combat
            local pool = OneJobOwlDB.praises
            if (not pool or #pool == 0) then pool = NS.praiseMessages end
            if UnitAffectingCombat("player")
               and leftover <= TightWindow()
               and (now - lastPraise) >= PRAISE_COOLDOWN
               and pool and #pool > 0 then
                lastPraise = now
                OwlSay(pool[math.random(#pool)], false)
            end
        end
        lastExpiration = exp
    end
end

-- A verified, honest drop: FF hit zero on a living, attackable boss.
-- Called by core after the death-race check passes. dropAt is when the
-- drop was first detected, so downtime isn't shortened by the verify delay.
function NS.IamOwl_Drop(dropAt)
    if not NS.IsIamOwlMode() or not tracking then return end
    if not ffUp then return end
    ffUp = false
    lastExpiration = nil
    downStart = dropAt or GetTime()
    dropCount = dropCount + 1

    -- Only shame while still in combat
    if UnitAffectingCombat("player") then
        local pool = OneJobOwlDB.shames
        if pool and #pool > 0 then
            OwlSay(pool[math.random(#pool)], true)
        end
    end
end

-- FF disappeared through no fault of the owl: the mob died with FF on it,
-- or a boss phase made it untrackable while FF ran out. No drop counted,
-- no shame, and no downtime clock -- the books simply reset to "FF not up
-- yet", so the next application resumes scoring cleanly.
function NS.IamOwl_Excuse()
    if not tracking then return end
    if ffUp then
        ffUp = false
        lastExpiration = nil
    end
    downStart = nil
end

local function GradeFor(score)
    if score >= 97 then return "S+"
    elseif score >= 93 then return "S"
    elseif score >= 88 then return "A+"
    elseif score >= 83 then return "A"
    elseif score >= 75 then return "B"
    elseif score >= 65 then return "C"
    elseif score >= 50 then return "D"
    else return "F" end
end

-- Grade tier colors for the report. S tiers go gold because they're beyond
-- mortal letter grades; A green, B light green, C yellow, D orange, F red.
local GRADE_COLORS = {
    ["S+"] = "ffffd700", -- gold
    ["S"]  = "ffffd700", -- gold
    ["A+"] = "ff00ff00", -- green
    ["A"]  = "ff00ff00", -- green
    ["B"]  = "ffaaff66", -- light green
    ["C"]  = "ffffff00", -- yellow
    ["D"]  = "ffff8800", -- orange
    ["F"]  = "ffff4040", -- red
}

local function ColorGrade(text, grade)
    return "|c" .. (GRADE_COLORS[grade] or "ffffffff") .. text .. "|r"
end

-- Combat end: tally everything and post the report. This is the ONLY place
-- an open scorecard gets closed, so it must always close it -- even if the
-- mode was switched away from I Am Owl mid-fight.
function NS.IamOwl_EndCombat()
    if not tracking then return end
    tracking = false
    if not NS.IsIamOwlMode() then
        ClearState() -- mode changed mid-fight; discard quietly
        return
    end

    local now = GetTime()

    -- CRITICAL FIX: If we are currently in a drop state, close it out now
    if downStart then
        totalDowntime = totalDowntime + (now - downStart)
        downStart = nil
    end

    if OneJobOwlDB.iamowlReport == false then
        ClearState()
        return
    end

    if not firstApplied then
        ClearState()
        return
    end

    local span = now - firstApplied
    if span < 1 then span = 1 end
    
    -- Ensure uptime doesn't exceed span if totalDowntime is somehow slightly off
    local uptime = span - totalDowntime
    if uptime < 0 then uptime = 0 end
    
    local uptimePct = math.floor((uptime / span) * 100 + 0.5)
    if totalDowntime > 0.05 and uptimePct >= 100 then uptimePct = 99 end

    local score = uptimePct
    local avgLeftover = nil
    if refreshCount > 0 then
        avgLeftover = leftoverSum / refreshCount
        local tw = TightWindow()
        local tight = (tw - avgLeftover) / tw
        if tight < 0 then tight = 0 elseif tight > 1 then tight = 1 end
        score = uptimePct * 0.85 + tight * 15
    end
    score = score - dropCount * 2
    if score < 0 then score = 0 elseif score > 100 then score = 100 end

    local grade = GradeFor(score)
    local rounded = math.floor(score + 0.5)
    local gradeText = ColorGrade(("Grade %s (%d)"):format(grade, rounded), grade)

    local report
    if avgLeftover then
        report = string.format(
            "%s | %d%% uptime | %d refresh%s | %.1fs total downtime | avg %.1fs left at refresh",
            gradeText, uptimePct, refreshCount,
            refreshCount == 1 and "" or "es", totalDowntime, avgLeftover)
    else
        report = string.format(
            "%s | %d%% uptime | %d refreshes | %.1fs total downtime",
            gradeText, uptimePct, refreshCount, totalDowntime)
    end

    -- Report mood follows the GRADE, not a raw score line: B and above gets
    -- the happy owl and green text, C/D/F gets the mad owl and red. (The old
    -- score<80 cutoff sat inside the B band, so a 77 B showed up angry.)
    local badGrade = (grade == "C" or grade == "D" or grade == "F")
    OwlSay(report, badGrade)
    ClearState()
end