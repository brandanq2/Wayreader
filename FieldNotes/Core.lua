local ADDON_NAME, ns = ...

local DB_VERSION = 2

local DEFAULTS = {
	enabled = true,
	hideInCombat = false,
	showStory = true,
	fontSize = 13,
	bgAlpha = 0.88,
	borderStyle = "gold", -- gold | ornate | simple (Panel.lua STYLES)
	-- "tracker": beside the focused quest in the objective tracker.
	-- "custom": wherever you dragged it in Edit Mode (customX/customY = top-left corner).
	placement = "tracker",
	-- width / maxHeight stay nil until you resize the panel, so the default
	-- size follows your screen and UI scale (see ns.GetWidth / ns.GetMaxHeight).
}

local CHAR_DEFAULTS = {
	-- The quest whose panel you collapsed. It stays collapsed until you focus a
	-- different quest, then the panel opens on its own again.
	collapsedQuestID = nil,
}

local function applyDefaults(db, defaults)
	for k, v in pairs(defaults) do
		if db[k] == nil then db[k] = v end
	end
end

local function migrate(db)
	if (db.version or 1) < 2 then
		-- v1 saved fixed 300x360 defaults; switch to the screen-relative size.
		db.width, db.maxHeight = nil, nil
	end
	db.version = DB_VERSION
end

function ns.Print(msg)
	print("|cffd9a441FieldNotes|r: " .. msg)
end

function ns.IsSecret(v)
	return issecretvalue and issecretvalue(v)
end

-- A usable (non-secret, non-empty) string, or nil.
function ns.Str(v)
	if type(v) ~= "string" or ns.IsSecret(v) or v == "" then return nil end
	return v
end

local function clamp(n, lo, hi)
	return math.max(lo, math.min(hi, math.floor(n + 0.5)))
end

ns.WIDTH_MIN, ns.WIDTH_MAX = 200, 700
ns.HEIGHT_MIN, ns.HEIGHT_MAX = 120, 900

-- Panel size in UI units. Until resized, about a fifth of the screen wide and
-- a third tall, so it shrinks with the screen and with larger UI scales.
function ns.GetWidth()
	return FieldNotesDB.width or clamp(UIParent:GetWidth() * 0.2, 240, 340)
end

function ns.GetMaxHeight()
	return FieldNotesDB.maxHeight or clamp(UIParent:GetHeight() * 0.34, 180, 420)
end

-- Key Bindings, in their own collapsible "FieldNotes" section of the Keybindings
-- menu (Bindings.xml category). They work without hovering the panel; mouse
-- wheel combos such as Shift + Mouse Wheel can be bound too.
BINDING_CATEGORY_FIELDNOTES = "FieldNotes"
BINDING_NAME_FIELDNOTES_SCROLLDOWN = "Scroll Down"
BINDING_NAME_FIELDNOTES_SCROLLUP = "Scroll Up"
BINDING_NAME_FIELDNOTES_PAGEDOWN = "Page Down"
BINDING_NAME_FIELDNOTES_PAGEUP = "Page Up"
BINDING_NAME_FIELDNOTES_TOGGLE = "Collapse / Open Panel"

FieldNotes = {
	Scroll = function(dir) if ns.Panel.frame then ns.Panel:ScrollLines(dir * 3) end end,
	Page = function(dir) if ns.Panel.frame then ns.Panel:ScrollPage(dir) end end,
	ToggleCollapse = function() if ns.Panel.frame then ns.Panel:ToggleCollapse() end end,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		FieldNotesDB = FieldNotesDB or {}
		FieldNotesCharDB = FieldNotesCharDB or {}
		migrate(FieldNotesDB)
		applyDefaults(FieldNotesDB, DEFAULTS)
		applyDefaults(FieldNotesCharDB, CHAR_DEFAULTS)
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		ns.Panel:Init()
	end
end)

local function parseNumber(text, lo, hi)
	local n = tonumber(text)
	return n and clamp(n, lo, hi) or nil
end

SLASH_FIELDNOTES1 = "/fieldnotes"
SLASH_FIELDNOTES2 = "/fn"
SlashCmdList.FIELDNOTES = function(input)
	local cmd, arg = strtrim(input or ""):lower():match("^(%S*)%s*(.-)$")
	if cmd == "toggle" then
		FieldNotesDB.enabled = not FieldNotesDB.enabled
		ns.Print("panel " .. (FieldNotesDB.enabled and "enabled" or "disabled") .. ".")
	elseif cmd == "open" then
		FieldNotesCharDB.collapsedQuestID = nil
		FieldNotesDB.enabled = true
	elseif cmd == "unlock" or cmd == "move" or cmd == "edit" then
		ns.EditMode:SetEditing(true, "slash")
		return
	elseif cmd == "lock" then
		ns.EditMode:SetEditing(false)
		return
	elseif cmd == "attach" then
		FieldNotesDB.placement = "tracker"
		ns.Print("panel attached to the objective tracker.")
	elseif cmd == "combat" then
		FieldNotesDB.hideInCombat = not FieldNotesDB.hideInCombat
		ns.Print("panel " .. (FieldNotesDB.hideInCombat and "hides" or "stays up") .. " in combat.")
	elseif cmd == "story" then
		FieldNotesDB.showStory = not FieldNotesDB.showStory
		ns.Print("quest story " .. (FieldNotesDB.showStory and "shown" or "hidden") .. ".")
	elseif cmd == "font" and parseNumber(arg, 9, 24) then
		FieldNotesDB.fontSize = parseNumber(arg, 9, 24)
		ns.Print("font size " .. FieldNotesDB.fontSize .. ".")
	elseif cmd == "width" and parseNumber(arg, ns.WIDTH_MIN, ns.WIDTH_MAX) then
		FieldNotesDB.width = parseNumber(arg, ns.WIDTH_MIN, ns.WIDTH_MAX)
		ns.Print("width " .. FieldNotesDB.width .. ".")
	elseif cmd == "height" and parseNumber(arg, ns.HEIGHT_MIN, ns.HEIGHT_MAX) then
		FieldNotesDB.maxHeight = parseNumber(arg, ns.HEIGHT_MIN, ns.HEIGHT_MAX)
		ns.Print("max height " .. FieldNotesDB.maxHeight .. ".")
	elseif cmd == "border" and tContains(ns.BORDER_STYLES, arg) then
		FieldNotesDB.borderStyle = arg
		ns.Print("border style " .. arg .. ".")
	elseif cmd == "debug" then
		ns.Tracker:Debug()
		return
	elseif cmd == "reset" then
		wipe(FieldNotesDB)
		migrate(FieldNotesDB)
		applyDefaults(FieldNotesDB, DEFAULTS)
		FieldNotesCharDB.collapsedQuestID = nil
		ns.Print("settings, size and position reset.")
	else
		ns.Print("Open Edit Mode and click the panel to move it and change its size, text and background (or /fn unlock).")
		ns.Print("/fn toggle | open | unlock | lock | attach | story | combat | border <gold/ornate/simple> | font <9-24> | width <n> | height <n> | reset | debug")
		return
	end
	ns.Panel:ApplySettings()
end
