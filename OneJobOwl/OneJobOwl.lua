-- OneJobOwl.lua
-- Core logic: IFF tracking, shame triggering, channel routing, slash commands.
--
-- HOW DETECTION WORKS:
--   We listen to UNIT_AURA (fires whenever auras change on a unit) for your
--   target, plus PLAYER_TARGET_CHANGED. Each time, we scan the target's
--   debuffs for Faerie Fire (any rank, druid or feral version).
--   We remember whether FF has been SEEN on the current target (iffSeen).
--   The shame only triggers when FF was applied and then expired/fell off.
--   A fresh pull where FF hasn't gone up yet will NOT trigger. If FF is
--   reapplied, the shame button retracts (it also auto-hides on its own).
--
-- PHASE FORGIVENESS:
--   Bosses vanish, fly off, or go immune (Solarian's void phase, Al'ar's
--   rebirth, Kael's early phases). While the boss can't be tracked (doesn't
--   exist / can't be attacked / not visible), scanning halts. If FF expired
--   during such a gap, that is the BOSS's fault, not the owl's: we detect
--   the gap in scan times and forgive the drop, re-arming fresh -- the next
--   FF application starts a clean watch, with a few seconds of grace to
--   get it back up.
--
-- DEATH RACE:
--   When a mob dies, the aura-wipe UNIT_AURA event often arrives BEFORE
--   UnitIsDeadOrGhost() reports true, which looked like "FF fell off a
--   living mob". So no drop is ever acted on instantly: we wait a beat
--   (DROP_VERIFY_DELAY) and re-verify the unit is still alive, attackable,
--   visible, and still missing FF. Dead, despawned, or phased mobs are
--   excused; reapplied FF cancels the pending shame.

local ADDON_NAME, NS = ...

_G["OneJobOwl"] = NS

-- The debuff on the target is plain Faerie Fire (all ranks, plus the feral
-- versions). The Improved Faerie Fire TALENT (33600-33602) just makes this
-- same debuff grant +hit -- it is never itself an aura on the target, which
-- is why matching 33602 never detected anything.
local FF_SPELL_IDS = {
    [770] = true, [778] = true, [9749] = true, [9907] = true, [26993] = true,   -- Faerie Fire r1-r5
    [16857] = true, [17390] = true, [17391] = true, [17392] = true, [27011] = true, -- Faerie Fire (Feral) r1-r5
}

OneJobOwlDB = OneJobOwlDB or {}

NS.defaults = {
    enabled = true,
    channel = "WHISPER",     -- default: whisper your designated moonkin
    moonkinName = "",
    mode = "BUTTON",         -- "BUTTON" = shame button, "AUTO" = auto-send, "IAMOWL" = praise mode
    iamowlReport = true,     -- I Am Owl: post the after-battle report when combat ends
    iamowlOutput = "BUBBLE", -- I Am Owl output: "BUBBLE" = on-screen owl speech bubble, "CHAT" = use channel above
    bubblePos = nil,         -- saved drag position of the owl bubble
    bubbleScale = 1.0,       -- owl bubble scale (0.5 - 2.0)
	balloonScale = 1.0,      -- speech bubble + text
    bubbleDuration = 6,      -- seconds a bubble message stays before fading
    sound = 8959,            -- soundkit ID played when the button appears (8959 = Raid Warning)
    trackScope = "BOSS",     -- "BOSS" (skull only), "ELITE" (bosses+elites), "ALL"
    combatOnly = true,       -- only alert while you are in combat
    buttonPos = nil,         -- saved drag position of the shame button
    buttonScale = 1.0,       -- shame button scale (0.5 - 2.0)
    glowColor = { r = 1, g = 0.2, b = 0.1, a = 0.7 }, -- shame button glow
    tightWindow = 8,         -- I Am Owl: refreshing FF with <= this many seconds left counts as "clutch"
    shames = nil,            -- seeded from NS.defaultShames on first load
    praises = nil,           -- seeded from NS.praiseMessages on first load
}

local lastWarning = 0
local iffSeen = false  -- has FF been observed on the current watched unit?

-- Smarter detection: phase forgiveness + death-race verification.
local PHASE_GAP         = 2.0  -- a scan gap longer than this means the unit was untrackable (boss phase)
local DROP_VERIFY_DELAY = 0.3  -- seconds to wait before confirming a drop is real (not a death race)
local lastGoodScan = nil       -- GetTime() of the last successful aura scan on the watched unit
local pendingDrop  = nil       -- token for an in-flight drop verification (nil = none)

-- The designated FF Enemy: a specific mob watched by GUID, independent of
-- what you're currently targeting. Runtime-only on purpose -- it clears
-- when combat ends (or the mob dies), so it can't go stale between pulls.
local ffEnemy = nil    -- { guid = ..., name = ... }
local enemyTicker = nil

function NS.GetFFEnemyName()
    return ffEnemy and ffEnemy.name or nil
end

-- Find a unit token that currently points at the watched GUID. The boss is
-- usually visible as your target, your focus, or one of its nameplates.
local function ResolveEnemyUnit()
    if not ffEnemy then return nil end
    if UnitExists("target") and UnitGUID("target") == ffEnemy.guid then return "target" end
    if UnitExists("focus") and UnitGUID("focus") == ffEnemy.guid then return "focus" end
    for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists(u) then
            if UnitGUID(u) == ffEnemy.guid then return u end
        else
            break
        end
    end
    return nil
end

local function CopyDefaults(src, dest)
    if type(dest) ~= "table" then dest = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then dest[k] = CopyDefaults(v, dest[k])
        elseif dest[k] == nil then dest[k] = v end
    end
    return dest
end

function NS.SeedShames(force)
    if force or type(OneJobOwlDB.shames) ~= "table" or #OneJobOwlDB.shames == 0 then
        OneJobOwlDB.shames = {}
        for _, v in ipairs(NS.defaultShames) do
            table.insert(OneJobOwlDB.shames, v)
        end
        if not force and type(OneJobOwlDB.customShames) == "table" then
            for _, v in ipairs(OneJobOwlDB.customShames) do
                table.insert(OneJobOwlDB.shames, v)
            end
        end
        OneJobOwlDB.customShames = nil
    end
end

function NS.SeedPraises(force)
    if force or type(OneJobOwlDB.praises) ~= "table" or #OneJobOwlDB.praises == 0 then
        OneJobOwlDB.praises = {}
        for _, v in ipairs(NS.praiseMessages or {}) do
            table.insert(OneJobOwlDB.praises, v)
        end
    end
end

-- "Is this player a druid?" -- the self-tracking gate. This used to check
-- GetShapeshiftForm() == 5, which is a trap twice over: form INDICES are
-- bar positions that shift depending on which forms the druid knows (no
-- Aquatic Form quest = everything moves down one), and a druid applying
-- Faerie Fire (Feral) from bear/cat -- which our spell table supports --
-- isn't in form 5 at all. Class is stable for the whole session.
local function IsDruid()
    local _, class = UnitClass("player")
    return class == "DRUID"
end

function NS.HasMoonkinSet()
    return OneJobOwlDB.moonkinName and OneJobOwlDB.moonkinName ~= ""
end

-- ===== Keep the shame target tied to your group =====
-- A designated moonkin should only stick while they're actually grouped with
-- us. If they leave the raid/party -- or we do -- the name clears so we don't
-- keep whispering someone who's gone. We remember whether the moonkin has been
-- SEEN in the group, so a deliberately-set out-of-group target (e.g. whispering
-- a friend while solo) isn't wiped the instant a roster event fires; we only
-- clear on an actual departure.
local moonkinSeenInGroup = false
function NS.ResetMoonkinSeenFlag() moonkinSeenInGroup = false end

local function IsUnitTheMoonkin(unit)
    if not UnitExists(unit) then return false end
    local name, realm = UnitName(unit)
    if not name then return false end
    local target = (OneJobOwlDB.moonkinName or ""):lower()
    if target == "" then return false end
    if name:lower() == target then return true end -- bare-name match (same realm)
    if realm and realm ~= "" then
        return (name .. "-" .. realm):lower() == target -- cross-realm "Name-Realm"
    end
    return false
end

local function MoonkinInGroup()
    if not NS.HasMoonkinSet() then return false end
    local n = GetNumGroupMembers()
    if not n or n == 0 then return false end -- not in a group at all
    if IsInRaid() then
        for i = 1, n do
            if IsUnitTheMoonkin("raid" .. i) then return true end
        end
    else
        if IsUnitTheMoonkin("player") then return true end -- party1-4 exclude you
        for i = 1, 4 do
            if IsUnitTheMoonkin("party" .. i) then return true end
        end
    end
    return false
end

-- Run on GROUP_ROSTER_UPDATE and right after a moonkin is set.
function NS.CheckMoonkinGroupMembership()
    if not NS.HasMoonkinSet() then
        moonkinSeenInGroup = false
        return
    end
    if MoonkinInGroup() then
        moonkinSeenInGroup = true
    elseif moonkinSeenInGroup then
        -- They were grouped with us and now they aren't: they left, or we did.
        moonkinSeenInGroup = false
        local who = OneJobOwlDB.moonkinName
        OneJobOwlDB.moonkinName = ""
        print("|cffff8800[OneJobOwl]|r " .. who
            .. " left the group -- shame target cleared.")
        if NS.RefreshOptions then NS.RefreshOptions() end
    end
    -- Never seen in the group => a deliberate out-of-group target; leave it be.
end

local function GetIFFRemaining(unit)
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime, _, _, _, spellId = UnitDebuff(unit, i)
        if not name then break end
        -- ID match first; name fallback catches any rank/version we missed
        if FF_SPELL_IDS[spellId] or (name and name:find("^Faerie Fire")) then
            return (expirationTime and expirationTime > 0) and (expirationTime - GetTime()) or 9999
        end
    end
    return nil
end
NS.GetIFFRemaining = GetIFFRemaining

function NS.SendShame()
    local pool = OneJobOwlDB.shames
    if not pool or #pool == 0 then return end
    
    local shameText = pool[math.random(#pool)]
    -- Clean prefix without color codes for chat
    local msg = "[OneJobOwl] " .. shameText

    local ch = OneJobOwlDB.channel or "WHISPER"
    if ch == "WHISPER" then
        if NS.HasMoonkinSet() then
            SendChatMessage(msg, "WHISPER", nil, OneJobOwlDB.moonkinName)
        else
            print("|cffff8800[OneJobOwl]|r No moonkin set! Use /shame <name> (channel is WHISPER).")
        end
    elseif ch == "RAID" and IsInRaid() then
        SendChatMessage(msg, "RAID")
    elseif ch == "PARTY" and IsInGroup() then
        SendChatMessage(msg, "PARTY")
    elseif ch == "YELL" then
        SendChatMessage(msg, "YELL")
    else
        SendChatMessage(msg, "SAY")
    end
end

local function Trigger()
    if (OneJobOwlDB.mode or "BUTTON") == "AUTO" then
        -- Auto-Shame: no button, rate-limited auto-send
        if GetTime() - lastWarning > 10 then
            lastWarning = GetTime()
            NS.SendShame()
        end
    else
        -- Shame Button: pop the owl, message only goes out when clicked
        if NS.ShowShameButton then NS.ShowShameButton() end
    end
end

function NS.ResetTargetState()
    iffSeen = false
    lastGoodScan = nil
    pendingDrop = nil
    if NS.HideShameButton then NS.HideShameButton() end
    if NS.ResetIamOwlTracking then NS.ResetIamOwlTracking() end
end

-- Does the current target matter enough to shame over?
--   BOSS  -> level -1 ("skull"): raid bosses and world bosses report this,
--            normal mobs never do. The most reliable boss check in TBC.
--   ELITE -> bosses plus elite/rare-elite mobs (covers raid & dungeon trash)
--   ALL   -> anything you can attack
local function TargetInScope()
    local scope = OneJobOwlDB.trackScope or "BOSS"
    if scope == "ALL" then return true end
    local isBoss = UnitLevel("target") == -1
        or UnitClassification("target") == "worldboss"
    if scope == "BOSS" then return isBoss end
    -- ELITE
    local class = UnitClassification("target")
    return isBoss or class == "elite" or class == "rareelite"
end

local function CheckIFF(unit)
    unit = unit or "target"
    if not OneJobOwlDB.enabled then
        NS.ResetTargetState()
        return
    end
    -- With a designated moonkin anyone can run the watch (raid lead mode);
    -- without one, original self-shame behavior: only for druids watching
    -- their own Faerie Fire (any form -- balance or feral).
    if not NS.HasMoonkinSet() and not IsDruid() then return end
    if not UnitExists(unit) or not UnitCanAttack("player", unit)
        or not UnitIsVisible(unit) then
        -- Untrackable: vanished, flew off, went friendly/immune (boss phase).
        -- Don't touch the books; the scan gap that builds up here is what
        -- earns the owl its phase forgiveness.
        if not ffEnemy then NS.ResetTargetState() end
        return
    end
    if UnitIsDeadOrGhost(unit) or (UnitHealth(unit) or 0) <= 0 then
        pendingDrop = nil -- it died; whatever FF did at the end is excused
        if ffEnemy then
            NS.ClearFFEnemy("it died") -- boss is dead, job's done
        else
            NS.ResetTargetState()
        end
        return
    end
    -- An explicitly chosen FF enemy bypasses the boss/elite scope filter --
    -- you picked it, so it matters.
    if not ffEnemy and not TargetInScope() then
        NS.ResetTargetState()
        return
    end
    if OneJobOwlDB.combatOnly and not UnitAffectingCombat("player") then
        return -- keep state, just stay quiet out of combat
    end

    local now = GetTime()
    local gap = lastGoodScan and (now - lastGoodScan) or 0
    lastGoodScan = now

    local rem = GetIFFRemaining(unit)
    local iamowl = NS.IsIamOwlMode and NS.IsIamOwlMode()

    if rem ~= nil then
        -- FF is up: the owl is redeemed. Cancel any pending shame.
        pendingDrop = nil
        if iamowl and NS.IamOwl_Scan then NS.IamOwl_Scan(unit, rem) end
        iffSeen = true
        if NS.HideShameButton then NS.HideShameButton() end
        return
    end

    -- FF not on the unit. Only act if we actually saw it up before.
    if not iffSeen then return end
    iffSeen = false

    if gap > PHASE_GAP then
        -- We couldn't track the unit while FF ran out (vanish phase, flight
        -- phase, immunity). Not the owl's fault: forgive and re-arm fresh.
        if iamowl and NS.IamOwl_Excuse then NS.IamOwl_Excuse() end
        return
    end

    -- Looks like a genuine drop -- but mobs often wipe their auras an instant
    -- BEFORE the game reports them dead. Verify after a short delay.
    local guid = UnitGUID(unit)
    local dropAt = now
    local token = {}
    pendingDrop = token
    C_Timer.After(DROP_VERIFY_DELAY, function()
        if pendingDrop ~= token then return end -- superseded or cancelled
        pendingDrop = nil
        -- Re-resolve the unit; tokens can shift in 0.3s.
        local u
        if ffEnemy then
            u = ResolveEnemyUnit()
        elseif UnitExists("target") and UnitGUID("target") == guid then
            u = "target"
        end
        if not u or UnitGUID(u) ~= guid
            or UnitIsDeadOrGhost(u) or (UnitHealth(u) or 0) <= 0
            or not UnitCanAttack("player", u) or not UnitIsVisible(u) then
            -- Dead, despawned, or phased out between detection and now:
            -- FF "fell off" because the mob stopped existing. Excused.
            if iamowl and NS.IamOwl_Excuse then NS.IamOwl_Excuse() end
            return
        end
        if GetIFFRemaining(u) ~= nil then
            iffSeen = true -- reapplied within the window; no harm done
            return
        end
        -- Confirmed: living, attackable mob with no Faerie Fire. Shame.
        if iamowl then
            if NS.IamOwl_Drop then NS.IamOwl_Drop(dropAt) end
        else
            Trigger()
        end
    end)
end

-- ===== FF Enemy set/clear =====
-- /ojo debug -- walk the whole detection chain on the current target and
-- print PASS/FAIL for every guard, plus live state from both modules.
-- When the owl goes quiet, this says exactly which gate is closed.
function NS.DebugStatus()
    local function P(label, ok, extra)
        local mark = ok and "|cff44ff44PASS|r" or "|cffff4444FAIL|r"
        print("  " .. mark .. "  " .. label .. (extra and (" -- " .. extra) or ""))
    end
    print("|cffff8800[OneJobOwl]|r debug status:")
    print("  mode=" .. tostring(OneJobOwlDB.mode)
        .. "  enabled=" .. tostring(OneJobOwlDB.enabled)
        .. "  combatOnly=" .. tostring(OneJobOwlDB.combatOnly)
        .. "  scope=" .. tostring(OneJobOwlDB.trackScope))
    print("  IamOwl module loaded: " .. tostring(NS.IsIamOwlMode ~= nil)
        .. "  |  IsIamOwlMode(): " .. tostring(NS.IsIamOwlMode and NS.IsIamOwlMode()))
    print("  Bubble module loaded: " .. tostring(NS.OwlBubbleSay ~= nil))
    print("  iffSeen=" .. tostring(iffSeen)
        .. "  lastGoodScan=" .. (lastGoodScan and string.format("%.1fs ago", GetTime() - lastGoodScan) or "never")
        .. "  pendingDrop=" .. tostring(pendingDrop ~= nil))
    print("  heartbeat ticker: " .. tostring(NS.IsWatchTickerRunning and NS.IsWatchTickerRunning() or false)
        .. "  ffEnemy=" .. tostring(ffEnemy and ffEnemy.name or "none"))
    if NS.IamOwlDebugLine then print("  " .. NS.IamOwlDebugLine()) end

    print("  guard chain for current target:")
    P("enabled", OneJobOwlDB.enabled)
    P("druid-or-designated", NS.HasMoonkinSet() or IsDruid(),
        "class=" .. tostring(select(2, UnitClass("player")))
        .. " form=" .. tostring(GetShapeshiftForm())
        .. " moonkinName='" .. tostring(OneJobOwlDB.moonkinName) .. "'")
    local unit = "target"
    P("UnitExists", UnitExists(unit))
    if UnitExists(unit) then
        P("UnitCanAttack", UnitCanAttack("player", unit))
        P("UnitIsVisible", UnitIsVisible(unit))
        P("alive", not UnitIsDeadOrGhost(unit) and (UnitHealth(unit) or 0) > 0,
            "health=" .. tostring(UnitHealth(unit)))
        P("TargetInScope", ffEnemy ~= nil or TargetInScope(),
            "level=" .. tostring(UnitLevel(unit)) .. " class=" .. tostring(UnitClassification(unit)))
        P("combat gate", (not OneJobOwlDB.combatOnly) or UnitAffectingCombat("player"),
            "inCombat=" .. tostring(UnitAffectingCombat("player")))
        local rem = GetIFFRemaining(unit)
        print("  FF on target: " .. (rem and string.format("%.1fs remaining", rem) or "|cffff4444none|r"))
    end
end

function NS.SetFFEnemyFromTarget()
    if not UnitExists("target") or not UnitCanAttack("player", "target")
        or UnitIsDeadOrGhost("target") then
        print("|cffff8800[OneJobOwl]|r Target a living enemy first, then try again.")
        return false
    end

    local currentGUID = UnitGUID("target")
    
    -- Only reset the tracking state if we are targeting a DIFFERENT unit
    -- than the one we are currently watching.
    if not ffEnemy or ffEnemy.guid ~= currentGUID then
        ffEnemy = { guid = currentGUID, name = UnitName("target") }
        NS.ResetTargetState()
        
        -- Success: Print confirmation that we are now watching this unit
        print("|cffff8800[OneJobOwl]|r Now watching FF on: |cff00ff00" .. ffEnemy.name .. "|r.")
    else
        -- Already watching this target
        print("|cffff8800[OneJobOwl]|r Already watching: |cff00ff00" .. ffEnemy.name .. "|r.")
    end

    -- poll every half second so expiry is caught even if no aura event
    -- happens to fire on a visible unit token at that moment
    if not enemyTicker then
        enemyTicker = C_Timer.NewTicker(0.5, function()
            local u = ResolveEnemyUnit()
            if u then CheckIFF(u) end
        end)
    end
    
    if NS.RefreshOptions then NS.RefreshOptions() end
    return true
end

function NS.ClearFFEnemy(reason)
    if not ffEnemy then return end
    local name = ffEnemy.name
    ffEnemy = nil
    if enemyTicker then
        enemyTicker:Cancel()
        enemyTicker = nil
    end
    NS.ResetTargetState()
    print("|cffff8800[OneJobOwl]|r FF enemy cleared (" .. (reason or "manual") .. "): " .. name)
    if NS.RefreshOptions then NS.RefreshOptions() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- Combat heartbeat: poll the watched unit every half second while in combat.
-- This is what makes the phase-gap detection trustworthy -- while the boss is
-- trackable, scans land at least this often, so any longer silence really
-- does mean the boss was untrackable. (The /fftarget path has its own ticker.)
local watchTicker
local function StartWatchTicker()
    if watchTicker then return end
    watchTicker = C_Timer.NewTicker(0.5, function()
        if not ffEnemy then CheckIFF("target") end
    end)
end
local function StopWatchTicker()
    if watchTicker then
        watchTicker:Cancel()
        watchTicker = nil
    end
end
function NS.IsWatchTickerRunning() return watchTicker ~= nil end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        OneJobOwlDB = CopyDefaults(NS.defaults, OneJobOwlDB)
        NS.SeedShames(false)
        NS.SeedPraises(false)
        NS.CreateShameButton()
        if NS.CreateOwlBubble then NS.CreateOwlBubble() end
        NS.CreateOptions()
        if NS.ReportSession_Init then NS.ReportSession_Init() end
        -- /reload mid-fight: PLAYER_REGEN_DISABLED already fired before we
        -- existed, so start the scorecard and heartbeat ourselves.
        if UnitAffectingCombat("player") then
            if NS.IamOwl_StartCombat then NS.IamOwl_StartCombat() end
            StartWatchTicker()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if ffEnemy then
            -- enemy identity is fixed; target swaps don't reset tracking
            local u = ResolveEnemyUnit()
            if u then CheckIFF(u) end
        else
            NS.ResetTargetState()
            CheckIFF("target")
        end
    elseif event == "UNIT_AURA" then
        if ffEnemy then
            if arg1 and UnitGUID(arg1) == ffEnemy.guid then CheckIFF(arg1) end
        elseif arg1 == "target" then
            CheckIFF("target")
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- combat started: I Am Owl begins a fresh scorecard
        if NS.IamOwl_StartCombat then NS.IamOwl_StartCombat() end
        StartWatchTicker()
    elseif event == "PLAYER_REGEN_ENABLED" then
        StopWatchTicker()
        pendingDrop = nil -- combat's over; any unconfirmed drop is moot
        -- combat over: the FF enemy's shift is done
        if ffEnemy then NS.ClearFFEnemy("combat ended") end
        -- and I Am Owl posts the after-action report
        if NS.IamOwl_EndCombat then NS.IamOwl_EndCombat() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- someone joined/left (or we did): drop the moonkin if they're gone
        NS.CheckMoonkinGroupMembership()
        -- and let the Report Card track group join/leave for its session
        if NS.ReportSession_OnRosterUpdate then NS.ReportSession_OnRosterUpdate() end
    end
end)

local function OpenOptions()
    if not OneJobOwlOptions then
        print("|cffff8800[OneJobOwl]|r Options panel not loaded yet. Try /reload.")
        return
    end

    if OneJobOwlOptions.category and Settings and Settings.OpenToCategory then
        -- Modern method (best)
        Settings.OpenToCategory(OneJobOwlOptions.category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Classic fallback
        InterfaceOptionsFrame_OpenToCategory("OneJobOwl")
        C_Timer.After(0.05, function()
            InterfaceOptionsFrame_OpenToCategory("OneJobOwl")
        end)
    else
        print("|cffff8800[OneJobOwl]|r Could not open options panel.")
    end
end

function NS.SetMoonkin(name)
    OneJobOwlDB.moonkinName = name
    print("|cffff8800[OneJobOwl]|r Moonkin set to: " .. name .. ". Whispers incoming.")
    -- if they're already in our group, remember that so a later exit clears them
    NS.CheckMoonkinGroupMembership()
    if NS.RefreshOptions then NS.RefreshOptions() end
end
local SetMoonkin = NS.SetMoonkin

function NS.ClearMoonkin()
    OneJobOwlDB.moonkinName = ""
    NS.ResetMoonkinSeenFlag()
    print("|cffff8800[OneJobOwl]|r Moonkin cleared. Back to self-shame mode.")
    if NS.RefreshOptions then NS.RefreshOptions() end
end
local ClearMoonkin = NS.ClearMoonkin

-- Grab the player you're currently targeting, with cross-realm handling.
-- Whispers to players on other realms need "Name-Realm", and UnitName
-- returns the realm separately, so we stitch it together here. This also
-- sidesteps typing names with special characters entirely.
function NS.SetMoonkinFromTarget()
    if not UnitExists("target") or not UnitIsPlayer("target") then
        print("|cffff8800[OneJobOwl]|r Target a player first, then try again.")
        return false
    end
    local name, realm = UnitName("target")
    if realm and realm ~= "" then
        name = name .. "-" .. realm
    end
    SetMoonkin(name)
    return true
end

SLASH_ONEJOBOWL1 = "/ojo"
SlashCmdList["ONEJOBOWL"] = function(msg)
    msg = msg or ""
    local cmd = msg:match("^(%S*)"):lower()
    if cmd == "test" then
        NS.SendShame()
    elseif cmd == "debug" then
        NS.DebugStatus()
    elseif cmd == "card" then
        if NS.ReportCard_Show then NS.ReportCard_Show(true) end
    elseif cmd == "button" then
        if NS.ShowShameButton then NS.ShowShameButton() end -- preview the button
    elseif cmd == "owl" then
        if NS.PreviewOwlBubble then NS.PreviewOwlBubble() end -- preview the owl bubble
    else
        OpenOptions()
    end
end

SLASH_OJOCLEAR1 = "/ojoclear"
SlashCmdList["OJOCLEAR"] = function()
    if NS.ReportCard_ClearSession then
        NS.ReportCard_ClearSession()
        print("|cffff8800[OneJobOwl]|r Session report cleared.")
    else
        print("|cffff8800[OneJobOwl]|r Report card module not active.")
    end
end
-- /shame Playername  -> set your moonkin by name
-- /shame target      -> set your moonkin to your current target (also: /shame %t)
-- /shame             -> show who's on the hook
SLASH_OJOSHAME1 = "/shame"
SlashCmdList["OJOSHAME"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = msg:lower()
    if lower == "target" or lower == "t" or msg == "%t" then
        NS.SetMoonkinFromTarget()
    elseif msg ~= "" then
        SetMoonkin(msg)
    elseif NS.HasMoonkinSet() then
        print("|cffff8800[OneJobOwl]|r Current moonkin on the hook: " .. OneJobOwlDB.moonkinName
            .. ". Use /shame <name>, /shame target, or /shameclear.")
    else
        print("|cffff8800[OneJobOwl]|r No moonkin set. Use /shame <name> or target them and type /shame target.")
    end
end

SLASH_OJOSHAMECLEAR1 = "/shameclear"
SlashCmdList["OJOSHAMECLEAR"] = function() ClearMoonkin() end

-- /fftarget  -> watch your current target's FF (clears after combat)
SLASH_OJOFFTARGET1 = "/fftarget"
SlashCmdList["OJOFFTARGET"] = function()
    NS.SetFFEnemyFromTarget()
end

-- /ffclear   -> stop watching the FF enemy
SLASH_OJOFFCLEAR1 = "/ffclear"
SlashCmdList["OJOFFCLEAR"] = function()
    if NS.GetFFEnemyName() then
        NS.ClearFFEnemy("manual")
    else
        print("|cffff8800[OneJobOwl]|r No FF enemy is set.")
    end
end