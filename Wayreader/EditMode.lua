local _, ns = ...

-- Edit Mode support that behaves like Blizzard's own frames:
--   * while Edit Mode is open the panel shows a blue outline;
--   * click it to select it (yellow outline + name) and open its settings window;
--   * drag it to move it anywhere.
-- Nothing here writes to Blizzard's Edit Mode state. We only listen for it
-- opening/closing and for other frames being selected, so saving Edit Mode
-- layouts stays untainted.

local EditMode = {}
ns.EditMode = EditMode

local Panel = ns.Panel
local NAME = "Wayreader"
local DIALOG_W = 360
local ROW_W = DIALOG_W - 40
local WHITE = "Interface\\Buttons\\WHITE8X8"
local HIGHLIGHT = { 0.35, 0.65, 1 }
local SELECTED = { 1, 0.82, 0 }

---------------------------------------------------------------- selection outline

-- Lookalike of Blizzard's selection frame, used if the native template is
-- missing or misbehaves on this client.
local function buildFallbackSelection(parent)
	local sel = CreateFrame("Frame", nil, parent)
	local tint = sel:CreateTexture(nil, "BACKGROUND")
	tint:SetAllPoints()
	local lines = {}
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local line = sel:CreateTexture(nil, "BORDER")
		line:SetPoint(side[1])
		line:SetPoint(side[2])
		if side[3] then line:SetHeight(2) else line:SetWidth(2) end
		lines[#lines + 1] = line
	end
	local label = sel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	label:SetPoint("CENTER")
	label:SetText(NAME)

	local function paint(c)
		tint:SetColorTexture(c[1], c[2], c[3], 0.15)
		for _, line in ipairs(lines) do line:SetColorTexture(c[1], c[2], c[3], 0.9) end
	end
	function sel:ShowHighlighted() paint(HIGHLIGHT); label:Hide(); self:Show() end
	function sel:ShowSelected() paint(SELECTED); label:Show(); self:Show() end
	return sel
end

-- Blizzard's own selection frame, so the outline and label match native frames.
local function buildNativeSelection(parent)
	local ok, sel = pcall(CreateFrame, "Frame", nil, parent, "EditModeSystemSelectionTemplate")
	if not ok or not sel then return nil end
	if type(sel.ShowHighlighted) ~= "function" or type(sel.ShowSelected) ~= "function" then
		sel:Hide()
		return nil
	end
	-- Some client versions read the label from the parent "system".
	parent.GetSystemName = parent.GetSystemName or function() return NAME end
	if sel.SetGetLabelTextFunction then pcall(sel.SetGetLabelTextFunction, sel, function() return NAME end) end
	if not (pcall(sel.ShowSelected, sel) and pcall(sel.ShowHighlighted, sel)) then
		sel:Hide()
		return nil
	end
	if sel.Label and sel.Label.SetText then sel.Label:SetText(NAME) end
	sel:Hide()
	return sel
end

function EditMode:SetupSelection(sel, native)
	local f = Panel.frame
	sel:SetAllPoints(f)
	sel:SetFrameLevel(f:GetFrameLevel() + 20)
	sel:EnableMouse(true)
	sel:RegisterForDrag("LeftButton")
	-- Replace the template's handlers: they expect a Blizzard Edit Mode system.
	sel:SetScript("OnMouseDown", function() EditMode:Select() end)
	sel:SetScript("OnMouseUp", nil)
	sel:SetScript("OnEnter", nil)
	sel:SetScript("OnLeave", nil)
	sel:SetScript("OnDragStart", function()
		EditMode:Select()
		Panel.moving = true
		f:StartMoving()
	end)
	sel:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		Panel.moving = false
		Panel:SaveCustomPosition()
		Panel:Reposition()
		EditMode:RefreshDialog()
	end)
	sel:Hide()
	self.selection, self.native = sel, native
end

function EditMode:ShowSelection(selected)
	local sel = self.selection
	local ok = pcall(selected and sel.ShowSelected or sel.ShowHighlighted, sel)
	if not ok and self.native then
		-- Native template failed at runtime; swap to the lookalike for good.
		sel:Hide()
		self:SetupSelection(buildFallbackSelection(Panel.frame), false)
		sel = self.selection
		if selected then sel:ShowSelected() else sel:ShowHighlighted() end
	end
	sel:Show()
end

---------------------------------------------------------------- settings window

local function newSlider(parent, label, minV, maxV, step, format, get, set)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(ROW_W, 30)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT")
	text:SetText(label)

	local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	value:SetPoint("RIGHT")
	value:SetWidth(44)
	value:SetJustifyH("RIGHT")

	local slider = CreateFrame("Slider", nil, row)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(130, 18)
	slider:SetPoint("RIGHT", value, "LEFT", -8, 0)
	slider:SetMinMaxValues(minV, maxV)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(0.3, 0.3, 0.3, 0.9)
	track:SetHeight(4)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(self, delta)
		self:SetValue(self:GetValue() + delta * step)
	end)
	slider:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v / step + 0.5) * step
		value:SetText(format(v))
		if not row.updating and v ~= get() then set(v) end
	end)

	function row:Refresh()
		self.updating = true
		slider:SetValue(get())
		value:SetText(format(get()))
		self.updating = false
	end
	return row
end

local function newCheck(parent, label, get, set)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(ROW_W, 28)
	local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	check:SetSize(26, 26)
	check:SetPoint("LEFT", -4, 0)
	local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetText(label)
	check:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	function row:Refresh() check:SetChecked(get() and true or false) end
	return row
end

local function newButton(parent, label, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

local function apply() Panel:ApplySettings() end

function EditMode:BuildDialog()
	local db = function() return WayreaderDB end
	local d = CreateFrame("Frame", "WayreaderEditDialog", UIParent, "BackdropTemplate")
	d:SetFrameStrata("DIALOG")
	d:SetWidth(DIALOG_W)
	d:SetClampedToScreen(true)
	d:EnableMouse(true)
	d:SetMovable(true)
	d:RegisterForDrag("LeftButton")
	d:SetScript("OnDragStart", d.StartMoving)
	d:SetScript("OnDragStop", d.StopMovingOrSizing)
	if d.SetDontSavePosition then d:SetDontSavePosition(true) end
	d:Hide()

	-- Same border as Blizzard's Edit Mode settings dialog, if available.
	local ok, border = pcall(CreateFrame, "Frame", nil, d, "DialogBorderTranslucentTemplate")
	if ok and border then
		border:SetAllPoints()
		border:SetFrameLevel(d:GetFrameLevel())
	else
		d:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 } })
		d:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
		d:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	end

	-- Controls live on a layer above the border so its fill never covers them.
	local body = CreateFrame("Frame", nil, d)
	body:SetAllPoints()
	body:SetFrameLevel(d:GetFrameLevel() + 5)

	local title = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOP", 0, -16)
	title:SetText(NAME)

	local close = CreateFrame("Button", nil, body, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function() EditMode:CloseDialog() end)

	local rows = {
		newSlider(body, "Width", ns.WIDTH_MIN, ns.WIDTH_MAX, 10, tostring,
			function() return ns.GetWidth() end,
			function(v) db().width = v; apply() end),
		newSlider(body, "Max Height", ns.HEIGHT_MIN, ns.HEIGHT_MAX, 10, tostring,
			function() return ns.GetMaxHeight() end,
			function(v) db().maxHeight = v; apply() end),
		newSlider(body, "Text Size", 9, 24, 1, tostring,
			function() return db().fontSize end,
			function(v) db().fontSize = v; apply() end),
		newSlider(body, "Background Opacity", 0, 100, 5, function(v) return v .. "%" end,
			function() return ns.Round(db().bgAlpha * 100) end,
			function(v) db().bgAlpha = v / 100; apply() end),
		newCheck(body, "Attach to Objective Tracker",
			function() return db().placement ~= "custom" end,
			function(on)
				if on then
					db().placement = "tracker"
				else
					Panel:SaveCustomPosition() -- stay where it is, but stop following
				end
				apply()
			end),
		newCheck(body, "Show Story",
			function() return db().showStory end,
			function(on) db().showStory = on; apply() end),
		newCheck(body, "Hide in Combat",
			function() return db().hideInCombat end,
			function(on) db().hideInCombat = on; apply() end),
	}

	local y = -46
	for _, row in ipairs(rows) do
		row:SetPoint("TOPLEFT", 20, y)
		y = y - row:GetHeight() - 2
	end

	local half = (ROW_W - 8) / 2
	local resetSize = newButton(body, "Reset Size", half, function()
		db().width, db().maxHeight = nil, nil
		apply()
		EditMode:RefreshDialog()
	end)
	resetSize:SetPoint("TOPLEFT", 20, y - 8)
	local resetPos = newButton(body, "Reset Position", half, function()
		db().placement = "tracker"
		apply()
		EditMode:RefreshDialog()
	end)
	resetPos:SetPoint("LEFT", resetSize, "RIGHT", 8, 0)

	d:SetHeight(-(y - 8 - 22) + 20)
	self.rows = rows
	self.dialog = d
end

function EditMode:RefreshDialog()
	if not self.dialog or not self.dialog:IsShown() then return end
	for _, row in ipairs(self.rows) do row:Refresh() end
end

-- Opens beside the panel, on whichever side has room. Placed at a fixed
-- screen position (not anchored to the panel) so it doesn't slide out from
-- under the mouse while a slider resizes the panel.
function EditMode:PlaceDialog()
	local d, f = self.dialog, Panel.frame
	local left, right, top = f:GetLeft(), f:GetRight(), f:GetTop()
	d:ClearAllPoints()
	if not left then
		d:SetPoint("CENTER")
	elseif left > DIALOG_W + 16 then
		d:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - 12, top)
	else
		d:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right + 12, top)
	end
end

---------------------------------------------------------------- state

function EditMode:Select()
	if not Panel.editing then return end
	if not self.selected then
		self.selected = true
		self:ShowSelection(true)
		self:PlaceDialog()
	end
	self.dialog:Show()
	self:RefreshDialog()
end

function EditMode:Deselect()
	if not self.selected then return end
	self.selected = false
	self.dialog:Hide()
	if Panel.editing then self:ShowSelection(false) end
end

function EditMode:CloseDialog()
	-- From /wr unlock there's no Edit Mode window to exit, so closing locks.
	if self.source == "slash" then self:SetEditing(false) else self:Deselect() end
end

-- source: "editmode" (Blizzard's Edit Mode opened) or "slash" (/wr unlock).
function EditMode:SetEditing(on, source)
	on = on and true or false
	if not self.selection then return end
	if Panel.editing == on then
		if on and source == "editmode" then self.source = source end
		return
	end
	Panel.editing = on
	self.source = source
	Panel.collapseButton:SetShown(not on)
	self.selected = false
	self.dialog:Hide()
	if on then
		self:ShowSelection(false)
	else
		self.selection:Hide()
	end
	Panel.frame.fnPoint = nil
	Panel.signature = nil
	Panel:Refresh()
	Panel:Reposition()
	if on and source == "slash" then
		self:Select()
		ns.Print("drag the panel to move it. Close the Wayreader window when you're done.")
	end
end

function EditMode:Init()
	local sel = buildNativeSelection(Panel.frame)
	self:SetupSelection(sel or buildFallbackSelection(Panel.frame), sel ~= nil)
	self:BuildDialog()

	-- Follow Blizzard's Edit Mode. Both signals are listened to because either
	-- may be missing on this client; SetEditing ignores the repeat.
	if EventRegistry and EventRegistry.RegisterCallback then
		EventRegistry:RegisterCallback("EditMode.Enter", function() EditMode:SetEditing(true, "editmode") end, EditMode)
		EventRegistry:RegisterCallback("EditMode.Exit", function() EditMode:SetEditing(false) end, EditMode)
	end
	local manager = _G.EditModeManagerFrame
	if manager then
		manager:HookScript("OnShow", function() EditMode:SetEditing(true, "editmode") end)
		manager:HookScript("OnHide", function() EditMode:SetEditing(false) end)
		-- Selecting a Blizzard frame deselects ours, like native frames do.
		if type(manager.SelectSystem) == "function" then
			hooksecurefunc(manager, "SelectSystem", function() EditMode:Deselect() end)
		end
	end
end
