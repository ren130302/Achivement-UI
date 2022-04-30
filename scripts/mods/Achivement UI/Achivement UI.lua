local mod = get_mod("Achivement UI")

local function _get_selection_frame_by_difficulty_index(difficulty_index)
	local completed_frame_texture = "map_frame_00"

	if difficulty_index and difficulty_index > 0 then
		local difficulty_key = DefaultDifficulties[difficulty_index]
		local settings = DifficultySettings[difficulty_key]
		completed_frame_texture = settings.completed_frame_texture
	end

	return completed_frame_texture
end

local function get_player()
	mod:debug("get_player")
	local player = Managers.player:local_player()

	if not player then
		mod:error("player is nil value")
		return nil
	end
	
	return Managers.player:local_player()
end

local function get_player_career()
	local player = get_player()
	local profile_index = player:profile_index() or 1
	local profile = SPProfiles[profile_index]
	local career_index =player:career_index() or 1
	local career = profile.careers[career_index].name

	if not career then
		mod:error("cant get career from player.")
		return nil
	end
	
	return career
end

local function get_player_stats()
	local player = get_player()
	local stats_id = player:stats_id()
	if not stats_id then
		mod:error("cant get stats_id from player.")
		return nil
	end
	
	return stats_id
end

local function get_difficulty_manager()
	local difficulty_manager = Managers.state.difficulty

    if not difficulty_manager then
        mod:error("difficulty_manager is nil value")
		return nil
    end

	return difficulty_manager
end

local function get_highest_level_difficulty_index(statistics_db, stats_id, level_id, career)
	mod:debug("get_highest_level_difficulty_index")
	local difficulty_manager = get_difficulty_manager()

    local difficulties = difficulty_manager:get_level_difficulties(level_id)
    local difficulty_index = nil

    for i = #difficulties, 1, -1 do
        local wins = statistics_db:get_persistent_stat(stats_id, "completed_career_levels", career, level_id, difficulties[i])

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

local function get_lowest_act_difficulty_index(statistics_db, stats_id, acts, career)
	mod:debug("get_lowest_act_difficulty_index")

	local lowest_completed_difficulty_index = 100

	for j = 1, #acts, 1 do
		local act_name = acts[j]
		local act_levels = GameActs[act_name]

		if not act_levels then
			mod:error("act_levels is nil value")
			return 0
		end

		for _, level_id in ipairs(act_levels) do
			local difficulty_index = get_highest_level_difficulty_index(statistics_db, stats_id, level_id, career)

			if difficulty_index < lowest_completed_difficulty_index then
				lowest_completed_difficulty_index = difficulty_index
			end
		end
	end
	return lowest_completed_difficulty_index
end

local definitions = local_require("scripts/ui/views/character_selection_view/states/definitions/character_selection_state_character_definitions")
local scenegraph_definition = definitions.scenegraph_definition
local function create_area_widget(i, specific_scenegraph_id)
	local scenegraph_id = specific_scenegraph_id
	local size = {
		100,
		100
	}

	if not scenegraph_id then
		scenegraph_id = "area_root_" .. i
		scenegraph_definition[scenegraph_id] = {
			vertical_alignment = "center",
			horizontal_alignment = "center",
			parent = "screen",
			size = size,
			position = {
				0,
				0,
				1
			}
		}
	end

	local widget = {element = {}}
	local passes = {
		{
			pass_type = "texture",
			style_id = "icon",
			texture_id = "icon"
		},
		{
			pass_type = "texture",
			style_id = "frame",
			texture_id = "frame"
		}
	}
	local style = {
		frame = {
			vertical_alignment = "center",
			horizontal_alignment = "center",
			texture_size = {180,180},
			offset = {0,0,6},
			color = {255,255,255,255}
		},
		icon = {
			vertical_alignment = "center",
			horizontal_alignment = "center",
			texture_size = {168,168},
			offset = {0,0,0},
			color = {255,255,255,255}
		},
	}
	widget.element.passes = passes
	widget.content = content
	widget.style = style
	widget.offset = {0,0,0}
	widget.scenegraph_id = scenegraph_id

	return widget
end

mod:debug("hookstart")
-- hook start

mod:debug("hook StartGameWindowMissionSelectionConsole _present_act_levels")
mod:hook_safe(StartGameWindowMissionSelectionConsole,"_present_act_levels" ,function (self, act)
	local career = get_player_career()
	local statistics_db = self._statistics_db
	local stats_id = get_player_stats()

	for _, active_node_widgets in pairs(self._node_widgets) do
		local widget = active_node_widgets
		local content = widget.content
		local level_key = content.level_key
		local completed_difficulty_index = get_highest_level_difficulty_index(statistics_db, stats_id, level_key, career)
        local selection_frame_texture = _get_selection_frame_by_difficulty_index(completed_difficulty_index)
		content.frame = selection_frame_texture
	end
end)

mod:debug("hook StartGameWindowAreaSelectionConsole _setup_area_widgets")
mod:hook_safe(StartGameWindowAreaSelectionConsole, "_setup_area_widgets", function (self)
	local career = get_player_career()
	local statistics_db = self.statistics_db
	local stats_id = get_player_stats()
	
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
		local lowest_completed_difficulty_index = get_lowest_act_difficulty_index(statistics_db, stats_id, acts, career)
		local frame_texture = _get_selection_frame_by_difficulty_index(lowest_completed_difficulty_index)
		content.frame = frame_texture
	end
end)

mod:debug("hookend")
-- hook end


-- Your mod code goes here.
-- https://vmf-docs.verminti.de
