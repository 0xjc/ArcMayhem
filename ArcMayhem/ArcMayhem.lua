-- ArcMayhem: Target curse indicator for Destruction Warlock
--
-- Shows a solid purple square when the current target has a curse-type
-- debuff (HARMFUL|PLAYER filter). Uses color curves + stacked StatusBar
-- overlays to work with WoW 12.0 secret value restrictions.

---------------------------------------------------------------------------
-- Class gate — only load for Warlocks
---------------------------------------------------------------------------
local _, playerClass = UnitClass("player")
if playerClass ~= "WARLOCK" then return end

---------------------------------------------------------------------------
-- Spec + talent gate — only activate for Destruction (267) with Mayhem
---------------------------------------------------------------------------
local DESTRO_SPEC_ID   = 267
local MAYHEM_SPELL_ID  = 387506
local specGatePassed   = false

---------------------------------------------------------------------------
-- API references
---------------------------------------------------------------------------
local GetAuraDataByIndex     = C_UnitAuras.GetAuraDataByIndex
local GetAuraDispelTypeColor = C_UnitAuras.GetAuraDispelTypeColor

---------------------------------------------------------------------------
-- Defaults & saved vars
---------------------------------------------------------------------------
local DEFAULTS = {
    size = 80,
    borderWidth = 2,
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = 0,
}

local db  -- assigned on ADDON_LOADED

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local SCAN_CAP = 16

---------------------------------------------------------------------------
-- Color curves
---------------------------------------------------------------------------
-- Fill: curse → solid purple, everything else → transparent
local fillCurve = C_CurveUtil.CreateColorCurve()
fillCurve:SetType(Enum.LuaCurveType.Step)
fillCurve:AddPoint(0,  CreateColor(0, 0, 0, 0))
fillCurve:AddPoint(1,  CreateColor(0, 0, 0, 0))
fillCurve:AddPoint(2,  CreateColor(0.80, 0, 1.00, 1))   -- Curse — solid purple
fillCurve:AddPoint(3,  CreateColor(0, 0, 0, 0))
fillCurve:AddPoint(4,  CreateColor(0, 0, 0, 0))
fillCurve:AddPoint(9,  CreateColor(0, 0, 0, 0))
fillCurve:AddPoint(11, CreateColor(0, 0, 0, 0))

-- Border: curse → white, everything else → transparent
local borderCurve = C_CurveUtil.CreateColorCurve()
borderCurve:SetType(Enum.LuaCurveType.Step)
borderCurve:AddPoint(0,  CreateColor(0, 0, 0, 0))
borderCurve:AddPoint(1,  CreateColor(0, 0, 0, 0))
borderCurve:AddPoint(2,  CreateColor(1, 1, 1, 1))        -- Curse — white
borderCurve:AddPoint(3,  CreateColor(0, 0, 0, 0))
borderCurve:AddPoint(4,  CreateColor(0, 0, 0, 0))
borderCurve:AddPoint(9,  CreateColor(0, 0, 0, 0))
borderCurve:AddPoint(11, CreateColor(0, 0, 0, 0))

---------------------------------------------------------------------------
-- Indicator frame
---------------------------------------------------------------------------
local indicator = CreateFrame("Frame", "ArcMayhemIndicator", UIParent)

indicator.borderOverlays = {}
indicator.fillOverlays   = {}

local function MakeOverlay(parent)
    local ov = CreateFrame("StatusBar", nil, parent)
    ov:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    ov:SetMinMaxValues(0, 1)
    ov:SetValue(1)
    ov:GetStatusBarTexture():SetVertexColor(0, 0, 0, 0)
    return ov
end

local function RebuildOverlayAnchors()
    local bw = db.borderWidth
    for i, fov in ipairs(indicator.fillOverlays) do
        fov:ClearAllPoints()
        fov:SetPoint("TOPLEFT", indicator, "TOPLEFT", bw, -bw)
        fov:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -bw, bw)
    end
end

local function GetOverlayPair(index)
    if not indicator.borderOverlays[index] then
        local bov = MakeOverlay(indicator)
        bov:SetAllPoints(indicator)
        indicator.borderOverlays[index] = bov

        local bw = db.borderWidth
        local fov = MakeOverlay(indicator)
        fov:SetPoint("TOPLEFT", indicator, "TOPLEFT", bw, -bw)
        fov:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -bw, bw)
        fov:SetFrameLevel(bov:GetFrameLevel() + 1)
        indicator.fillOverlays[index] = fov
    end
    return indicator.borderOverlays[index], indicator.fillOverlays[index]
end

local function ClearOverlays(fromIndex)
    for j = fromIndex, #indicator.borderOverlays do
        indicator.borderOverlays[j]:GetStatusBarTexture():SetVertexColor(0, 0, 0, 0)
        indicator.fillOverlays[j]:GetStatusBarTexture():SetVertexColor(0, 0, 0, 0)
    end
end

---------------------------------------------------------------------------
-- Layout helpers
---------------------------------------------------------------------------
local function ApplySize()
    local total = db.size + db.borderWidth * 2
    indicator:SetSize(total, total)
end

local function ApplyPosition()
    indicator:ClearAllPoints()
    indicator:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
end

local function SavePosition()
    local point, _, relPoint, x, y = indicator:GetPoint()
    db.point    = point
    db.relPoint = relPoint
    db.x        = x
    db.y        = y
end

---------------------------------------------------------------------------
-- Mover anchor
---------------------------------------------------------------------------
local anchor = CreateFrame("Frame", nil, indicator, "BackdropTemplate")
anchor:SetPoint("BOTTOMLEFT", indicator, "TOPLEFT", 0, 2)
anchor:SetSize(100, 18)
anchor:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
anchor:SetBackdropColor(0.15, 0.55, 0.85, 0.85)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetScript("OnDragStart", function()
    indicator:StartMoving()
end)
anchor:SetScript("OnDragStop", function()
    indicator:StopMovingOrSizing()
    SavePosition()
end)
anchor:Hide()

local anchorText = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
anchorText:SetPoint("CENTER")
anchorText:SetText("ArcMayhem")
anchorText:SetTextColor(1, 1, 1)

---------------------------------------------------------------------------
-- Update logic
---------------------------------------------------------------------------
local function UpdateIndicator()
    if not UnitExists("target") then
        ClearOverlays(1)
        return
    end

    local i = 1
    while i <= SCAN_CAP do
        local aura = GetAuraDataByIndex("target", i, "HARMFUL|PLAYER")
        if not aura then break end

        local bov, fov = GetOverlayPair(i)

        local bc = GetAuraDispelTypeColor("target", aura.auraInstanceID, borderCurve)
        if bc then
            bov:GetStatusBarTexture():SetVertexColor(bc:GetRGBA())
        else
            bov:GetStatusBarTexture():SetVertexColor(0, 0, 0, 0)
        end

        local fc = GetAuraDispelTypeColor("target", aura.auraInstanceID, fillCurve)
        if fc then
            fov:GetStatusBarTexture():SetVertexColor(fc:GetRGBA())
        else
            fov:GetStatusBarTexture():SetVertexColor(0, 0, 0, 0)
        end

        i = i + 1
    end
    ClearOverlays(i)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
indicator:SetMovable(true)
indicator:SetClampedToScreen(true)

local function CheckSpec()
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    if specID == DESTRO_SPEC_ID and IsPlayerSpell(MAYHEM_SPELL_ID) then
        if not specGatePassed then
            specGatePassed = true
            indicator:RegisterEvent("UNIT_AURA")
            indicator:RegisterEvent("PLAYER_TARGET_CHANGED")
        end
        indicator:Show()
        UpdateIndicator()
    else
        specGatePassed = false
        indicator:UnregisterEvent("UNIT_AURA")
        indicator:UnregisterEvent("PLAYER_TARGET_CHANGED")
        ClearOverlays(1)
        indicator:Hide()
    end
end

indicator:RegisterEvent("ADDON_LOADED")
indicator:RegisterEvent("PLAYER_LOGIN")
indicator:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
indicator:RegisterEvent("TRAIT_CONFIG_UPDATED")

indicator:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "ArcMayhem" then
        -- Init saved variables with defaults
        if not ArcMayhemDB then ArcMayhemDB = {} end
        for k, v in pairs(DEFAULTS) do
            if ArcMayhemDB[k] == nil then ArcMayhemDB[k] = v end
        end
        db = ArcMayhemDB
        ApplySize()
        ApplyPosition()
        indicator:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED" then
        CheckSpec()
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateIndicator()
    elseif event == "UNIT_AURA" and arg1 == "target" then
        UpdateIndicator()
    end
end)

---------------------------------------------------------------------------
-- Slash commands: /mayhem
---------------------------------------------------------------------------
SLASH_ARCMAYHEM1 = "/mayhem"
SlashCmdList["ARCMAYHEM"] = function(msg)
    if not db then return end
    msg = (msg or ""):lower():trim()

    if msg == "unlock" then
        anchor:Show()
        print("|cff9966ff ArcMayhem|r unlocked — drag the header to reposition.")
    elseif msg == "lock" then
        anchor:Hide()
        SavePosition()
        print("|cff9966ffArcMayhem|r locked.")
    elseif msg == "reset" then
        for k, v in pairs(DEFAULTS) do db[k] = v end
        ApplySize()
        ApplyPosition()
        RebuildOverlayAnchors()
        print("|cff9966ffArcMayhem|r reset to defaults.")
    elseif msg:match("^size%s+(%d+)$") then
        local newSize = tonumber(msg:match("^size%s+(%d+)$"))
        if newSize and newSize >= 10 and newSize <= 400 then
            db.size = newSize
            ApplySize()
            print("|cff9966ffArcMayhem|r size set to " .. newSize .. "px.")
        else
            print("|cff9966ffArcMayhem|r size must be 10-400.")
        end
    else
        print("|cff9966ffArcMayhem|r commands:")
        print("  /mayhem unlock — show drag handle")
        print("  /mayhem lock — hide drag handle & save position")
        print("  /mayhem size <px> — set indicator size (10-400)")
        print("  /mayhem reset — restore defaults")
        print("NOTE: This works off any curse cast by the player. So unfortunately, Curse of Weakness, etc. will register as a false positive. I don't have a good way to get around this issue yet.")
    end
end

---------------------------------------------------------------------------
-- Load message
---------------------------------------------------------------------------
print("|cff9966ffArcMayhem|r loaded — /mayhem for commands")
