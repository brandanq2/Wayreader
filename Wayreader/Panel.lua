local _, ns = ...

-- The reading panel for the focused quest and the small book tab it collapses
-- into. Moving and resizing live in EditMode.lua.

local Panel = {}
ns.Panel = Panel

local PAD = 10
local GAP = 6            -- space between the panel and the tracker
local HEADER_GAP = 8     -- divider spacing under the title
local SECTION_GAP = 10
local LABEL_GAP = 3
local SCROLLBAR_W = 3
local TAB_SIZE = 28
local MIN_VIEW = 60

local COLOR = {
	bg = { 0.05, 0.045, 0.04 },
	divider = { 0.82, 0.66, 0.36 },
	title = { 1, 0.82, 0 },
	label = { 0.85, 0.64, 0.25 },
	body = { 0.93, 0.90, 0.82 },
	progress = { 1, 1, 1 },
	complete = { 0.3, 0.85, 0.3 },
	failed = { 1, 0.3, 0.3 },
}
local DONE_COLOR = "ff8c8c8c"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t "
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local TOOLTIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background"

-- Border looks, all built from the game's own art so they pick up Forever's
-- styling. "gold" (default) is the rounded tooltip edge tinted Forever's
-- gold-bronze, as on its unit frames and tracker headers.
local STYLES = {
	gold = {
		pad = 12,
		backdrop = { bgFile = TOOLTIP_BG, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
		border = { 0.82, 0.66, 0.36, 1 },
		tabInset = 4,
	},
	ornate = {
		pad = 16,
		backdrop = { bgFile = TOOLTIP_BG, edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
			tile = true, tileSize = 16, edgeSize = 22, insets = { left = 5, right = 5, top = 5, bottom = 5 } },
		border = { 1, 1, 1, 1 },
		tabStyle = "gold", -- too heavy for a 28px tab
	},
	simple = {
		pad = 10,
		backdrop = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 },
		border = { 0.85, 0.64, 0.25, 0.55 },
		tabInset = 2,
	},
}
ns.BORDER_STYLES = { "gold", "ornate", "simple" }

local function currentStyle()
	return STYLES[WayreaderDB.borderStyle] or STYLES.gold
end

-- Shown while editing with no quest focused, so there is something to size.
local SAMPLE = {
	questID = 0,
	title = "Wayreader",
	progress = { { text = "Focus a quest to read it here", finished = false } },
	objective = "Drag this panel to place it anywhere. Change its size, text and background "
		.. "in the Wayreader window, or tick Attach to Objective Tracker to put it back "
		.. "beside your focused quest.",
	story = "Size it so the story reads comfortably without covering anything you need to see. "
		.. "On a smaller screen, a narrower panel along the edge of the screen works well, "
		.. "and longer text scrolls with the mouse wheel.",
}

local titleFont = CreateFont("WayreaderTitleFont")
local labelFont = CreateFont("WayreaderLabelFont")
local bodyFont = CreateFont("WayreaderBodyFont")

local function round(n) return math.floor(n + 0.5) end
ns.Round = round

local function paintBox(frame, style, alpha)
	frame:SetBackdrop(style.backdrop)
	frame:SetBackdropColor(COLOR.bg[1], COLOR.bg[2], COLOR.bg[3], alpha)
	frame:SetBackdropBorderColor(unpack(style.border))
end

-- Gold rule that fades out at both ends, like the tracker's header bars.
local function fade(tex, fromAlpha, toAlpha)
	local c = COLOR.divider
	if CreateColor and tex.SetGradient and pcall(tex.SetGradient, tex, "HORIZONTAL",
		CreateColor(c[1], c[2], c[3], fromAlpha), CreateColor(c[1], c[2], c[3], toAlpha)) then
		return
	end
	tex:SetVertexColor(c[1], c[2], c[3], (fromAlpha + toAlpha) / 2)
end

local function styleBox(frame)
	-- Unit frames live in LOW and raise themselves to its top when you target
	-- something, so draw one stratum up to stay readable over them. A low level
	-- inside MEDIUM keeps bags and other windows opening on top of the panel.
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(2)
	frame:SetClampedToScreen(true)
end

-- Frames the panel tries not to cover when it sits beside the tracker.
local OBSTACLES = { "TargetFrame", "FocusFrame", "PlayerFrame" }
local AVOID_MIN_HEIGHT = 140 -- below this, overlap a little rather than shrink further

local function newText(parent, font)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(font)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	fs:SetSpacing(2)
	return fs
end

local function showTooltip(owner, title, line)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:SetText(title, COLOR.title[1], COLOR.title[2], COLOR.title[3])
	if line then GameTooltip:AddLine(line, 1, 1, 1, true) end
	GameTooltip:Show()
end

---------------------------------------------------------------- construction

function Panel:Build()
	local f = CreateFrame("Frame", "WayreaderPanel", UIParent, "BackdropTemplate")
	styleBox(f)
	f:SetMovable(true)
	-- Position lives in WayreaderDB, not the client's layout cache.
	if f.SetDontSavePosition then f:SetDontSavePosition(true) end
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta)
		Panel:ScrollLines(-delta * 3)
	end)
	f:Hide()
	self.frame = f

	local collapse = CreateFrame("Button", nil, f)
	collapse:SetSize(18, 18)
	local bar = collapse:CreateTexture(nil, "ARTWORK")
	bar:SetTexture(WHITE)
	bar:SetSize(9, 2)
	bar:SetPoint("CENTER")
	bar:SetVertexColor(unpack(COLOR.label))
	local hl = collapse:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.12)
	collapse:SetScript("OnClick", function() Panel:Collapse() end)
	collapse:SetScript("OnEnter", function(btn) showTooltip(btn, "Collapse", "Reopens when you focus another quest.") end)
	collapse:SetScript("OnLeave", GameTooltip_Hide)
	self.collapseButton = collapse

	self.title = newText(f, titleFont)
	self.title:SetMaxLines(2)
	self.title:SetTextColor(unpack(COLOR.title))

	local divider = CreateFrame("Frame", nil, f)
	divider:SetHeight(1)
	local left = divider:CreateTexture(nil, "ARTWORK")
	left:SetTexture(WHITE)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMRIGHT", divider, "BOTTOM")
	fade(left, 0, 0.85)
	local right = divider:CreateTexture(nil, "ARTWORK")
	right:SetTexture(WHITE)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMLEFT", divider, "BOTTOM")
	fade(right, 0.85, 0)
	self.divider = divider

	local scroll = CreateFrame("ScrollFrame", nil, f)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)
	self.scroll, self.content = scroll, content

	self.thumb = f:CreateTexture(nil, "OVERLAY")
	self.thumb:SetTexture(WHITE)
	self.thumb:SetVertexColor(COLOR.label[1], COLOR.label[2], COLOR.label[3], 0.7)
	self.thumb:SetWidth(SCROLLBAR_W)

	self.status = newText(content, labelFont)
	self.progress = newText(content, bodyFont)
	self.objectiveLabel = newText(content, labelFont)
	self.objective = newText(content, bodyFont)
	self.storyLabel = newText(content, labelFont)
	self.story = newText(content, bodyFont)

	local tab = CreateFrame("Button", "WayreaderTab", UIParent, "BackdropTemplate")
	styleBox(tab)
	tab:SetSize(TAB_SIZE, TAB_SIZE)
	local icon = tab:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(BOOK_ICON)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	self.tabIcon = icon
	local tabHl = tab:CreateTexture(nil, "HIGHLIGHT")
	tabHl:SetAllPoints(icon)
	tabHl:SetColorTexture(1, 1, 1, 0.15)
	tab:SetScript("OnClick", function() Panel:Expand() end)
	tab:SetScript("OnEnter", function(btn)
		showTooltip(btn, "Wayreader", Panel.data and ("Read: " .. Panel.data.title) or nil)
	end)
	tab:SetScript("OnLeave", GameTooltip_Hide)
	tab:Hide()
	self.tab = tab

	self:ApplyStyle()
end

-- Applies the border style to the panel and tab, and the padding it needs.
function Panel:ApplyStyle()
	local style = currentStyle()
	PAD = style.pad
	paintBox(self.frame, style, WayreaderDB.bgAlpha)

	self.title:ClearAllPoints()
	self.title:SetPoint("TOPLEFT", PAD, -PAD)
	self.collapseButton:ClearAllPoints()
	self.collapseButton:SetPoint("TOPRIGHT", -(PAD - 5), -(PAD - 5))

	local tabStyle = STYLES[style.tabStyle] or style
	paintBox(self.tab, tabStyle, 0.9)
	local inset = tabStyle.tabInset or 4
	self.tabIcon:ClearAllPoints()
	self.tabIcon:SetPoint("TOPLEFT", inset, -inset)
	self.tabIcon:SetPoint("BOTTOMRIGHT", -inset, inset)
end

function Panel:ApplyFonts()
	local path, _, flags = GameFontHighlight:GetFont()
	local size = WayreaderDB.fontSize
	titleFont:SetFont(path, size + 2, flags or "")
	labelFont:SetFont(path, size - 1, flags or "")
	bodyFont:SetFont(path, size, flags or "")
end

---------------------------------------------------------------- layout

-- Stacks the content sections at the given width; returns total height.
function Panel:LayoutContent(width)
	local data, y = self.data, 0
	local function place(fs, text, color, gap)
		if not text then
			fs:Hide()
			return
		end
		if y > 0 then y = y + gap end
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
		fs:SetWidth(width)
		fs:SetText(text)
		fs:SetTextColor(unpack(color))
		fs:Show()
		y = y + fs:GetStringHeight()
	end

	local status = data.failed and "Failed" or data.complete and "Ready to turn in"
	place(self.status, status, data.failed and COLOR.failed or COLOR.complete, 0)

	local lines = {}
	for i, o in ipairs(data.progress) do
		lines[i] = o.finished and ("|c%s%s%s|r"):format(DONE_COLOR, CHECK, o.text) or ("- " .. o.text)
	end
	place(self.progress, #lines > 0 and table.concat(lines, "\n") or nil, COLOR.progress, LABEL_GAP)

	place(self.objectiveLabel, data.objective and "Objective", COLOR.label, SECTION_GAP)
	place(self.objective, data.objective, COLOR.body, LABEL_GAP)

	local story = WayreaderDB.showStory and data.story
	place(self.storyLabel, story and "Story", COLOR.label, SECTION_GAP)
	place(self.story, story or nil, COLOR.body, LABEL_GAP)

	return math.max(y, 1)
end

function Panel:Layout()
	local data = self.data
	if not data then return end
	local width = ns.GetWidth()
	local inner = width - PAD * 2
	self.frame:SetWidth(width)

	local title = data.title
	if data.level then
		title = ("|c%s[%d]|r %s"):format(data.levelColor or "ffffffff", data.level, title)
	end
	self.title:SetWidth(inner - 16)
	self.title:SetText(title)
	local headerH = self.title:GetStringHeight()

	self.divider:ClearAllPoints()
	self.divider:SetPoint("TOPLEFT", PAD, -(PAD + headerH + HEADER_GAP / 2))
	self.divider:SetPoint("TOPRIGHT", -PAD, -(PAD + headerH + HEADER_GAP / 2))

	local viewTop = PAD + headerH + HEADER_GAP
	local maxView = math.max(MIN_VIEW, (self.effectiveMax or ns.GetMaxHeight()) - viewTop - PAD)
	local contentW = inner
	local contentH = self:LayoutContent(contentW)
	if contentH > maxView then
		-- Make room for the scroll thumb and wrap again.
		contentW = inner - SCROLLBAR_W - 6
		contentH = self:LayoutContent(contentW)
	end
	-- While editing, show the full size so you see the real maximum you're setting.
	local viewH = self.editing and maxView or math.min(contentH, maxView)

	self.scroll:ClearAllPoints()
	self.scroll:SetPoint("TOPLEFT", PAD, -viewTop)
	self.scroll:SetSize(contentW, viewH)
	self.content:SetSize(contentW, contentH)
	self.frame:SetHeight(viewTop + viewH + PAD)

	self.viewH, self.contentH = viewH, contentH
	self.maxScroll = math.max(0, contentH - viewH)
	self:SetScroll(self.scrollPos)
end

function Panel:SetScroll(pos)
	local maxScroll = self.maxScroll or 0
	pos = math.max(0, math.min(maxScroll, pos or 0))
	self.scrollPos = pos
	self.scroll:SetVerticalScroll(pos)

	if maxScroll <= 0 then
		self.thumb:Hide()
		return
	end
	local viewH = self.viewH
	local thumbH = math.max(16, viewH * viewH / self.contentH)
	local offset = (viewH - thumbH) * pos / maxScroll
	self.thumb:SetHeight(thumbH)
	self.thumb:ClearAllPoints()
	self.thumb:SetPoint("TOPRIGHT", self.scroll, "TOPRIGHT", SCROLLBAR_W + 4, -offset)
	self.thumb:Show()
end

-- Smooth scrolling: wheel and key bindings set a target and the panel glides
-- to it, so your eye can follow the text instead of losing its place.
local function animateScroll(frame, elapsed)
	local p = Panel
	local target = math.max(0, math.min(p.maxScroll or 0, p.scrollTarget or p.scrollPos))
	local diff = target - p.scrollPos
	if math.abs(diff) < 0.5 then
		p:SetScroll(target)
		p.scrollTarget = nil
		frame:SetScript("OnUpdate", nil)
		return
	end
	p:SetScroll(p.scrollPos + diff * math.min(1, elapsed * 14))
end

function Panel:ScrollBy(delta)
	if not self.frame:IsShown() or (self.maxScroll or 0) <= 0 then return end
	local from = self.scrollTarget or self.scrollPos
	self.scrollTarget = math.max(0, math.min(self.maxScroll, from + delta))
	self.frame:SetScript("OnUpdate", animateScroll)
end

local function lineHeight()
	return WayreaderDB.fontSize + 2 -- font size plus line spacing
end

function Panel:ScrollLines(lines)
	self:ScrollBy(lines * lineHeight())
end

-- Nearly a full view per page, keeping two lines of overlap for context.
function Panel:ScrollPage(dir)
	local view = self.viewH or 0
	self:ScrollBy(dir * math.max(lineHeight(), view - lineHeight() * 2))
end

function Panel:ToggleCollapse()
	if WayreaderCharDB.collapsedQuestID and WayreaderCharDB.collapsedQuestID == self.questID then
		self:Expand()
	elseif self.questID then
		self:Collapse()
	end
end

---------------------------------------------------------------- state

local function signature(data)
	local parts = { data.title, tostring(data.level), tostring(data.complete), tostring(data.failed),
		data.objective or "", data.story or "" }
	for _, o in ipairs(data.progress) do
		parts[#parts + 1] = (o.finished and "1" or "0") .. o.text
	end
	return table.concat(parts, "\031")
end

function Panel:Refresh()
	local questID = ns.Quest.GetFocusedQuestID()
	if questID and questID ~= self.lastQuestID then
		-- Focusing a different quest reopens a collapsed panel.
		if self.lastQuestID then WayreaderCharDB.collapsedQuestID = nil end
		self.lastQuestID = questID
		self.scrollPos = 0
		self.scrollTarget = nil
		self.signature = nil
	end
	self.questID = questID
	self.data = questID and ns.Quest.Get(questID) or nil
	if not self.data and self.editing then self.data = SAMPLE end

	local sig = self.data and signature(self.data)
	if sig ~= self.signature then
		self.signature = sig
		self:Layout()
	end
end

-- Where the panel goes: the saved spot in custom placement, otherwise beside
-- the focused quest's tracker block (or the tracker itself while editing).
function Panel:GetAnchor()
	local db = WayreaderDB
	if db.placement == "custom" and db.customX and db.customY then
		return { x = db.customX, y = db.customY }
	end
	local anchor = self.questID and ns.Tracker.GetAnchor(self.questID)
	if not anchor and self.editing then anchor = ns.Tracker.GetFallbackAnchor() end
	return anchor
end

-- Pins frame at anchor. Beside the tracker it goes on the left, or on the right
-- when there isn't room (tracker moved to the left side of the screen).
local function pin(frame, anchor, width)
	local point, x, y
	if anchor.x then
		point, x, y = "TOPLEFT", anchor.x, anchor.y
	else
		if anchor.left - GAP - width >= 0 then
			point, x = "TOPRIGHT", anchor.left - GAP
		else
			point, x = "TOPLEFT", anchor.right + GAP
		end
		y = anchor.top
	end
	x, y = round(x), round(y)
	if frame.fnPoint ~= point or frame.fnX ~= x or frame.fnY ~= y then
		frame:ClearAllPoints()
		frame:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
		frame.fnPoint, frame.fnX, frame.fnY = point, x, y
	end
end

-- Max height at this anchor. Beside the tracker, the panel stops just above any
-- unit frame below it in the same horizontal band (positions are read even when
-- the frame is hidden, so the panel doesn't jump as you target things). A panel
-- you placed yourself, or one being edited, always gets its full height.
function Panel:EffectiveMaxHeight(anchor)
	local maxHeight = ns.GetMaxHeight()
	if self.editing or anchor.x then return maxHeight end

	local width = ns.GetWidth()
	local left, right
	if anchor.left - GAP - width >= 0 then
		right = anchor.left - GAP
		left = right - width
	else
		left = anchor.right + GAP
		right = left + width
	end
	local top = anchor.top

	local edge = ns.Tracker.Edge
	for _, name in ipairs(OBSTACLES) do
		local f = _G[name]
		local oLeft, oRight, oTop = edge(f, "GetLeft"), edge(f, "GetRight"), edge(f, "GetTop")
		if oLeft and oRight and oTop and oLeft < right and oRight > left
			and oTop < top and oTop > top - maxHeight then
			maxHeight = math.max(AVOID_MIN_HEIGHT, top - oTop - GAP)
		end
	end
	return math.min(maxHeight, ns.GetMaxHeight())
end

function Panel:Reposition()
	if self.moving then return end -- don't fight a drag in progress
	local db = WayreaderDB
	local anchor
	if self.data and (self.editing or (db.enabled and not (db.hideInCombat and InCombatLockdown()))) then
		anchor = self:GetAnchor()
	end
	if not anchor then
		self.frame:Hide()
		self.tab:Hide()
		return
	end

	if not self.editing and WayreaderCharDB.collapsedQuestID == self.questID then
		self.frame:Hide()
		pin(self.tab, anchor, TAB_SIZE)
		self.tab:Show()
		return
	end

	self.tab:Hide()
	local maxHeight = self:EffectiveMaxHeight(anchor)
	if maxHeight ~= self.effectiveMax then
		self.effectiveMax = maxHeight
		self:Layout()
	end
	pin(self.frame, anchor, ns.GetWidth())
	if not self.frame:IsShown() then
		self.frame:Show()
		self:Layout() -- re-measure text now that it's on screen
	end
end

function Panel:SaveCustomPosition()
	local left, top = self.frame:GetLeft(), self.frame:GetTop()
	if not left or not top then return end
	WayreaderDB.placement = "custom"
	WayreaderDB.customX, WayreaderDB.customY = round(left), round(top)
	self.frame.fnPoint = nil
end

function Panel:Collapse()
	WayreaderCharDB.collapsedQuestID = self.questID
	GameTooltip:Hide()
	self:Reposition()
end

function Panel:Expand()
	WayreaderCharDB.collapsedQuestID = nil
	GameTooltip:Hide()
	self:Reposition()
end

-- Re-applies every setting immediately (sliders call this as they move).
function Panel:ApplySettings()
	self:ApplyFonts()
	if not self.frame then return end
	self:ApplyStyle()
	self.signature = nil
	self.effectiveMax = nil -- recomputed for the new size on Reposition
	self.frame.fnPoint = nil
	self:Refresh()
	self:Reposition()
end

---------------------------------------------------------------- driver

local EVENTS = {
	"SUPER_TRACKING_CHANGED",
	"QUEST_LOG_UPDATE",
	"QUEST_WATCH_LIST_CHANGED",
	"QUEST_ACCEPTED",
	"QUEST_REMOVED",
	"QUEST_TURNED_IN",
	"PLAYER_ENTERING_WORLD",
	"UI_SCALE_CHANGED",
	"DISPLAY_SIZE_CHANGED",
}

function Panel:Init()
	self:Build()
	self:ApplyFonts()
	self.scrollPos = 0
	self.editing = false
	self.dirty = true
	ns.EditMode:Init()

	local driver = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do
		pcall(driver.RegisterEvent, driver, event)
	end
	driver:SetScript("OnEvent", function(_, event)
		if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
			Panel.signature = nil -- the default size follows the screen
		end
		Panel.dirty = true
	end)

	-- Tracker blocks move as quests are added, completed or scrolled, and the
	-- tracker exposes no event for that, so follow the block on a short timer.
	local since = 0
	driver:SetScript("OnUpdate", function(_, elapsed)
		since = since + elapsed
		if since < 0.1 then return end
		since = 0
		if Panel.dirty then
			Panel.dirty = false
			Panel:Refresh()
		end
		Panel:Reposition()
	end)
end
