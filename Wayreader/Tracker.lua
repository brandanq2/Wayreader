local _, ns = ...

-- Finds the objective tracker block for a quest and works out where the panel
-- should sit beside it. Nothing here hooks or modifies Blizzard's tracker: the
-- panel only reads block positions, so it can't taint the tracker's secure
-- item buttons.

local Tracker = {}
ns.Tracker = Tracker

-- 11.0+ tracker modules first, then the 10.x module globals as a fallback in
-- case Forever's client is laid out the older way.
local MODULE_NAMES = {
	"QuestObjectiveTracker",
	"CampaignQuestObjectiveTracker",
	"WorldQuestObjectiveTracker",
	"BonusObjectiveTracker",
	"QUEST_TRACKER_MODULE",
	"CAMPAIGN_QUEST_TRACKER_MODULE",
}

local function isBlockFor(block, questID)
	if type(block) ~= "table" or type(block.IsVisible) ~= "function" then return false end
	-- Blocks are pooled; make sure this one hasn't been handed to another quest.
	if block.id ~= nil and block.id ~= questID then return false end
	return true
end

local function blockFromModule(module, questID)
	if type(module) ~= "table" then return nil end
	if type(module.GetExistingBlock) == "function" then
		local ok, block = pcall(module.GetExistingBlock, module, questID)
		if ok and isBlockFor(block, questID) then return block end
	end
	local used = rawget(module, "usedBlocks")
	if type(used) == "table" then
		if isBlockFor(used[questID], questID) then return used[questID] end -- usedBlocks[id]
		for _, byID in pairs(used) do -- usedBlocks[template][id]
			if type(byID) == "table" and isBlockFor(byID[questID], questID) then return byID[questID] end
		end
	end
	return nil
end

-- Returns the visible tracker block for questID and the module name it came from.
function Tracker.FindBlock(questID)
	for _, name in ipairs(MODULE_NAMES) do
		local block = blockFromModule(_G[name], questID)
		if block and block:IsVisible() then return block, name end
	end
	return nil
end

function Tracker.GetFrame()
	local f = _G.ObjectiveTrackerFrame
	if f and f:IsVisible() then return f end
	return nil
end

-- Edge position converted to UIParent units, or nil if unavailable.
local function edge(frame, method)
	if not frame or type(frame[method]) ~= "function" then return nil end
	local ok, v = pcall(frame[method], frame)
	if not ok or type(v) ~= "number" or ns.IsSecret(v) then return nil end
	return v * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end
Tracker.Edge = edge

-- Where the panel should go for questID, in UIParent units:
--   { top = y, left = x (tracker's left edge incl. POI buttons), right = x (tracker's right edge) }
-- or nil when the quest has no visible place in the tracker.
function Tracker.GetAnchor(questID)
	local trackerFrame = Tracker.GetFrame()
	if not trackerFrame then return nil end

	local block = Tracker.FindBlock(questID)
	local top = edge(block, "GetTop")
	if not top then return nil end

	local left, right = edge(trackerFrame, "GetLeft"), edge(trackerFrame, "GetRight")
	-- The quest's POI button hangs off the block's left edge; keep clear of it.
	for _, key in ipairs({ "self", "poiButton", "POIButton" }) do
		local region = key == "self" and block or block[key]
		local l, r = edge(region, "GetLeft"), edge(region, "GetRight")
		if l and (not left or l < left) then left = l end
		if r and (not right or r > right) then right = r end
	end
	if not left or not right then return nil end
	return { top = top, left = left, right = right }
end

-- The tracker's own top edge, for Edit Mode when no quest block is showing.
function Tracker.GetFallbackAnchor()
	local f = _G.ObjectiveTrackerFrame
	local top, left, right = edge(f, "GetTop"), edge(f, "GetLeft"), edge(f, "GetRight")
	if top and left and right then return { top = top, left = left, right = right } end
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	return { top = h * 0.75, left = w * 0.75, right = w * 0.75 }
end

function Tracker:Debug()
	local questID = ns.Quest.GetFocusedQuestID()
	ns.Print(("focused quest: %s, log index: %s"):format(tostring(questID), tostring(questID and ns.Quest.GetLogIndex(questID))))
	ns.Print("ObjectiveTrackerFrame: " .. (_G.ObjectiveTrackerFrame and (Tracker.GetFrame() and "visible" or "hidden") or "missing"))
	for _, name in ipairs(MODULE_NAMES) do
		local module = _G[name]
		if module then
			local block = questID and blockFromModule(module, questID)
			ns.Print(("  %s: %s"):format(name, block and (block:IsVisible() and "block (visible)" or "block (hidden)") or "no block"))
		end
	end
	local a = questID and Tracker.GetAnchor(questID)
	ns.Print(a and ("anchor top=%.0f left=%.0f right=%.0f"):format(a.top, a.left, a.right) or "no anchor: panel hidden")
end
