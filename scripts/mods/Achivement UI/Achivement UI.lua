local mod = get_mod("Achivement UI")

local function get_player()
	return Managers.player
end

local function get_local_player()
	return get_player():local_player()
end

local function get_profile()
	local profile_index = get_local_player():profile_index() or 1
	return SPProfiles[profile_index]
end

local function get_player_career_by_index(career_index)
	local profile = get_profile()
	local career = profile.careers[career_index].name
	return career
end

local function get_player_career()
	local career_index =get_local_player():career_index() or 1
	return get_player_career_by_index(career_index)
end

local function get_statistics_db()
	return get_player():statistics_db()
end

local function get_stats_id()
	return get_player():local_player():stats_id()
end

local function get_highest_level_difficulty_index(level_id, career)
    local difficulties = Managers.state.difficulty:get_level_difficulties(level_id)
    local difficulty_index = nil

    for i = #difficulties, 1, -1 do
        local wins = get_statistics_db():get_persistent_stat(get_stats_id(), "completed_career_levels", career, level_id, difficulties[i])

        if wins > 0 then
            difficulty_index = i
			break
        end
    end

	local difficulty_key = difficulties[difficulty_index]

    if not difficulty_key then
        return 0
    end

	mod:debug("difficulty_key -> %s", difficulty_key)
	
    return difficulty_index
end

local function get_lowest_act_difficulty_index(acts, career)
	local lowest_completed_difficulty_index = 100

	for j = 1, #acts, 1 do
		local act_name = acts[j]
		local act_levels = GameActs[act_name]

		if not act_levels then
			mod:error("act_levels is nil value")
			return 0
		end

		for _, level_id in ipairs(act_levels) do
			local difficulty_index = get_highest_level_difficulty_index(level_id, career)

			if difficulty_index < lowest_completed_difficulty_index then
				lowest_completed_difficulty_index = difficulty_index
			end
		end
	end
	return lowest_completed_difficulty_index
end

local function get_selection_frame_by_difficulty_index(difficulty_index)
	local completed_frame_texture = "map_frame_00"

	if difficulty_index and difficulty_index > 0 then
		local difficulty_key = DefaultDifficulties[difficulty_index]
		local settings = DifficultySettings[difficulty_key]
		completed_frame_texture = settings.completed_frame_texture
	end

	return completed_frame_texture
end


mod:debug("hookstart")
-- hook start

mod:debug("hook StartGameWindowMissionSelectionConsole _present_act_levels")
mod:hook_safe(StartGameWindowMissionSelectionConsole,"_present_act_levels" ,function (self, act)
	local career = get_player_career()

	for _, active_node_widgets in pairs(self._node_widgets) do
		local widget = active_node_widgets
		local content = widget.content
		local level_key = content.level_key
		local completed_difficulty_index = get_highest_level_difficulty_index(level_key, career)
        local selection_frame_texture = get_selection_frame_by_difficulty_index(completed_difficulty_index)
		content.frame = selection_frame_texture
	end
end)

mod:debug("hook StartGameWindowAreaSelectionConsole _setup_area_widgets")
mod:hook_safe(StartGameWindowAreaSelectionConsole, "_setup_area_widgets", function (self)
	local career = get_player_career()

	local sorted_area_settings = {}

	for _, settings in pairs(AreaSettings) do
		local sort_order = settings.sort_order
		sorted_area_settings[sort_order] = settings
	end

	local num_areas = #sorted_area_settings

	for i = 1, num_areas, 1 do
		local settings = sorted_area_settings[i]
		local widget = self._area_widgets[i]
		local content = widget.content
		local acts = settings.acts
		local lowest_completed_difficulty_index = get_lowest_act_difficulty_index(acts, career)
		local frame_texture = get_selection_frame_by_difficulty_index(lowest_completed_difficulty_index)
		content.frame = frame_texture
	end
end)

mod:debug("hookend")
-- hook end

-- Your mod code goes here.
-- https://vmf-docs.verminti.de
