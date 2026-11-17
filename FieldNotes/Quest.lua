local _, ns = ...

-- Reads everything the panel shows for a quest in your log: title, level,
-- live objective progress, the objective summary and the story text.
-- Every call is pcall-wrapped and every string checked for secret values,
-- since Forever runs on the Midnight client's API restrictions.

local Quest = {}
ns.Quest = Quest

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
end

local function clean(text)
	text = ns.Str(text)
	if not text then return nil end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	return text ~= "" and text or nil
end

function Quest.GetFocusedQuestID()
	local id = C_SuperTrack and call(C_SuperTrack.GetSuperTrackedQuestID)
	if type(id) ~= "number" or ns.IsSecret(id) or id <= 0 then return nil end
	return id
end

function Quest.GetLogIndex(questID)
	local index = call(C_QuestLog.GetLogIndexForQuestID, questID)
	if type(index) ~= "number" or ns.IsSecret(index) or index <= 0 then return nil end
	return index
end

local function levelColor(level)
	if type(level) ~= "number" or level <= 0 then return nil end
	local c = call(GetQuestDifficultyColor, level)
	if type(c) == "table" and c.r then
		local function byte(v) return math.floor(v * 255 + 0.5) end
		return ("ff%02x%02x%02x"):format(byte(c.r), byte(c.g), byte(c.b))
	end
end

-- Returns a table describing the quest, or nil if it isn't in your log.
function Quest.Get(questID)
	local logIndex = questID and Quest.GetLogIndex(questID)
	if not logIndex then return nil end

	local info = call(C_QuestLog.GetInfo, logIndex)
	if type(info) ~= "table" then info = {} end

	local data = {
		questID = questID,
		title = clean(info.title) or clean(call(C_QuestLog.GetTitleForQuestID, questID)) or ("Quest " .. questID),
		level = (type(info.level) == "number" and not ns.IsSecret(info.level)) and info.level or nil,
		progress = {},
	}
	data.levelColor = levelColor(data.level)

	local story, objective = call(GetQuestLogQuestText, logIndex)
	data.story = clean(story)
	data.objective = clean(objective)

	local objectives = call(C_QuestLog.GetQuestObjectives, questID)
	if type(objectives) == "table" then
		for _, o in ipairs(objectives) do
			local text = type(o) == "table" and clean(o.text)
			if text then
				data.progress[#data.progress + 1] = { text = text, finished = o.finished == true }
			end
		end
	end

	data.failed = call(C_QuestLog.IsFailed, questID) == true
	data.complete = not data.failed and (
		call(C_QuestLog.ReadyForTurnIn, questID) == true or call(C_QuestLog.IsComplete, questID) == true)

	return data
end
