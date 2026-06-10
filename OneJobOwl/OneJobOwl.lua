-- OneJobOwl.lua
-- Core logic: IFF tracking, shame triggering, channel routing, slash commands.
--
-- HOW DETECTION WORKS:
--   We listen to UNIT_AURA (fires whenever auras change on a unit) for your
--   target, plus PLAYER_TARGET_CHANGED. Each time, we scan the target's
--   debuffs for Faerie Fire (any rank, druid or feral version).
--   We remember whether FF has been SEEN on the current target (iffSeen).
--   The shame only triggers when FF was applied and then expired/fell off,
--   or when its remaining time drops below your threshold. A fresh pull
--   where FF hasn't gone up yet will NOT trigger (set threshold to 0 if
--   you only want actual fall-offs, not "about to expire" warnings).

local ADDON_NAME, NS = ...

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
    threshold = 5,
    channel = "WHISPER",     -- default: whisper your designated moonkin
    moonkinName = "",
    mode = "BUTTON",         -- "BUTTON" = shame button, "AUTO" = auto-send, "IAMOWL" = praise mode
    iamowlReport = true,     -- I Am Owl: post the after-battle report when combat ends
    sound = 8959,            -- soundkit ID played when the button appears (8959 = Raid Warning)
    trackScope = "BOSS",     -- "BOSS" (skull only), "ELITE" (bosses+elites), "ALL"
    combatOnly = true,       -- only alert while you are in combat
    buttonPos = nil,         -- saved drag position of the shame button
    buttonScale = 1.0,       -- shame button scale (0.5 - 2.0)
    glowColor = { r = 1, g = 0.2, b = 0.1, a = 0.7 }, -- shame button glow
    shames = nil,            -- seeded from NS.defaultShames on first load
}

local lastWarning = 0
local iffSeen = false  -- has FF been observed on the current watched unit?

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

local function IsMoonkin() return GetShapeshiftForm() == 5 end

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
    if NS.HideShameButton then NS.HideShameButton() end
    if NS.ResetIamOwlTracking then NS.ResetIamOwlTracking() end   -- <-- Add this
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
    -- without one, original self-shame behavior: only while YOU are moonkin.
    if not NS.HasMoonkinSet() and not IsMoonkin() then return end
    if not UnitExists(unit) or not UnitCanAttack("player", unit) then
        if not ffEnemy then NS.ResetTargetState() end
        return
    end
    if UnitIsDeadOrGhost(unit) then
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

    local rem = GetIFFRemaining(unit)

    -- I Am Owl praise mode keeps its own books and handles its own feedback;
    -- the button / auto-shame paths stay out of its way.
    if NS.IsIamOwlMode and NS.IsIamOwlMode() then
        if NS.IamOwl_Scan then NS.IamOwl_Scan(unit, rem) end
        iffSeen = (rem ~= nil)
        if NS.HideShameButton then NS.HideShameButton() end
        return
    end

    if rem == nil then
        -- IFF not on target. Only shame if we actually saw it up before.
        if iffSeen then
            iffSeen = false
            Trigger()
        end
    elseif rem <= (OneJobOwlDB.threshold or 5) then
        -- Applied but about to expire
        iffSeen = true
        Trigger()
    else
        -- Healthy uptime: the owl is redeemed, retract the button
        iffSeen = true
        if NS.HideShameButton then NS.HideShameButton() end
    end
end

-- ===== FF Enemy set/clear =====
function NS.SetFFEnemyFromTarget()
    if not UnitExists("target") or not UnitCanAttack("player", "target")
        or UnitIsDeadOrGhost("target") then
        print("|cffff8800[OneJobOwl]|r Target a living enemy first, then try again.")
        return false
    end
    ffEnemy = { guid = UnitGUID("target"), name = UnitName("target") }
    NS.ResetTargetState()
    -- poll every half second so expiry is caught even if no aura event
    -- happens to fire on a visible unit token at that moment
    if not enemyTicker then
        enemyTicker = C_Timer.NewTicker(0.5, function()
            local u = ResolveEnemyUnit()
            if u then CheckIFF(u) end
        end)
    end
    print("|cffff8800[OneJobOwl]|r Now watching FF on: " .. ffEnemy.name
        .. " (clears when combat ends).")
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
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        OneJobOwlDB = CopyDefaults(NS.defaults, OneJobOwlDB)
        NS.SeedShames(false)
        NS.CreateShameButton()
        NS.CreateOptions()
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
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- combat over: the FF enemy's shift is done
        if ffEnemy then NS.ClearFFEnemy("combat ended") end
        -- and I Am Owl posts the after-action report
        if NS.IamOwl_EndCombat then NS.IamOwl_EndCombat() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- someone joined/left (or we did): drop the moonkin if they're gone
        NS.CheckMoonkinGroupMembership()
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
    elseif cmd == "button" then
        if NS.ShowShameButton then NS.ShowShameButton() end -- preview the button
    else
        OpenOptions()
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