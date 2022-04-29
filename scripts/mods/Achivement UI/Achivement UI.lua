local mod = get_mod("Achivement UI")

local get_player_career = function()
	mod:debug("get_player_career")
	local player = Managers.player:local_player()
	local profile_index = player:profile_index() or 1
	local profile = SPProfiles[profile_index]
	local career_index = player:career_index() or 1
	local career = profile.careers[career_index].name

	if not career then
		mod:error("cant get career from player.")
		return nil
	end
	
	return career
end

local get_difficulty_manager = function()
	local difficulty_manager = Managers.state.difficulty

    if not difficulty_manager then
        mod:error("difficulty_manager is nil value")
		return nil
    end

	return difficulty_manager
end

local get_highest_level_difficulty_index = function (statistics_db, stats_id, level_id, career)
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

local get_lowest_act_difficulty_index = function (statistics_db, stats_id, acts, career)
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

mod:hook_origin(StartGameWindowMissionSelectionConsole,"_present_act_levels" ,function (self, act)
	local career = get_player_career()



	local node_widgets = self._node_widgets
	local statistics_db = self._statistics_db
	local stats_id = self._stats_id
	local assigned_widgets = {}
	local act_widgets = {}
	local level_width_spacing = 190
	local level_height_spacing = 190
	local max_act_number = 4
	local levels_by_act = self._levels_by_act

	for act_key, levels in pairs(levels_by_act) do
		local act_verified = self:_verify_act(act_key)

		if act_verified and (not act or act == act_key) then
			local act_settings = ActSettings[act_key]
			local act_sorting = act_settings.sorting
			local act_index = (act_sorting - 1) % max_act_number + 1
			local is_end_act = max_act_number < act_sorting
			local act_position_y = 0
			local act_widget = nil

			if not is_end_act then
				act_position_y = -level_height_spacing + (max_act_number - act_index) * level_height_spacing
				act_widget = self._act_widgets[act_index]
			else
				act_widget = self._end_act_widget
			end

			act_widgets[#act_widgets + 1] = act_widget
			act_widget.offset[2] = act_position_y
			local act_display_name = act_settings.display_name
			act_widget.content.background = act_settings.banner_texture
			act_widget.content.text = (act_display_name and Localize(act_display_name)) or ""
			local area_name_width = UIUtils.get_text_width(self._ui_renderer, act_widget.style.text, act_widget.content.text)
			local num_levels_in_act = #levels
			local level_position_x = area_name_width - 50
			local level_position_y = 0

			for i = 1, num_levels_in_act, 1 do
				local level_data = levels[i]

				if is_end_act then
					level_position_x = level_width_spacing * 4
				end

				local index = #assigned_widgets + 1
				local widget = node_widgets[index]
				local content = widget.content
				local level_key = level_data.level_id
				local boss_level = level_data.boss_level
				local level_display_name = level_data.display_name
				content.text = Localize(level_display_name)
				local level_unlocked = LevelUnlockUtils.level_unlocked(statistics_db, stats_id, level_key)
				local completed_difficulty_index = get_highest_level_difficulty_index(statistics_db, stats_id, level_key, career)
                local selection_frame_texture = self:_get_selection_frame_by_difficulty_index(completed_difficulty_index)
				content.frame = selection_frame_texture
				content.locked = not level_unlocked
				content.act_key = act_key
				content.level_key = level_key
				local level_image = level_data.level_image

				if level_image then
					content.icon = level_image
				else
					content.icon = "icons_placeholder"
				end

				content.level_data = level_data
				content.boss_level = boss_level
				local offset = widget.offset
				offset[1] = level_position_x
				offset[2] = act_position_y + level_position_y
				assigned_widgets[index] = widget
				level_position_x = level_position_x + level_width_spacing
			end
		end
	end

	self._active_node_widgets = assigned_widgets
	self._active_act_widgets = act_widgets
end)

mod:hook_origin(StartGameWindowAreaSelectionConsole, "_setup_area_widgets", function (self)
	local definitions = local_require("scripts/ui/views/start_game_view/windows/definitions/start_game_window_area_selection_console_definitions")
	local scenegraph_definition = definitions.scenegraph_definition
	local career = get_player_career()
	


	local sorted_area_settings = {}

	for _, settings in pairs(AreaSettings) do
		local sort_order = settings.sort_order
		sorted_area_settings[sort_order] = settings
	end

	local num_areas = #sorted_area_settings
	local widget_size = scenegraph_definition.area_root.size
	local widget_width = widget_size[1]
	local spacing = 100
	local total_width = widget_width * num_areas + spacing * (num_areas - 1)
	local width_offset = -(total_width / 2) + widget_width / 2
	local statistics_db = self.statistics_db
	local stats_id = self._stats_id
	local assigned_widgets = {}

	for i = 1, num_areas, 1 do
		local settings = sorted_area_settings[i]
		local widget = self._area_widgets[i]
		assigned_widgets[i] = widget
		local level_image = settings.level_image
		local content = widget.content
		content.icon = level_image
		local unlocked = true
		local dlc_name = settings.dlc_name

		if dlc_name then
			unlocked = Managers.unlock:is_dlc_unlocked(dlc_name)
		end

		local name = settings.name
		content.locked = not unlocked
		content.area_name = name
		local acts = settings.acts
		local lowest_completed_difficulty_index = get_lowest_act_difficulty_index(statistics_db, stats_id, acts, career)
		local frame_texture = self:_get_selection_frame_by_difficulty_index(lowest_completed_difficulty_index)
		content.frame = frame_texture
		local offset = widget.offset
		offset[1] = width_offset
		width_offset = width_offset + widget_width + spacing
	end

	self._active_area_widgets = assigned_widgets
end)

-- mod:hook_origin(CharacterSelectionStateCharacter,"create_ui_elements",function (self, params)
-- 	self.ui_scenegraph = UISceneGraph.init_scenegraph(scenegraph_definition)
-- 	local widgets = {}
-- 	local info_widgets = {}
-- 	local bot_selection_widgets = {}
-- 	local widgets_by_name = {}

-- 	for name, widget_definition in pairs(widget_definitions) do
-- 		local widget = UIWidget.init(widget_definition)
-- 		widgets[#widgets + 1] = widget
-- 		widgets_by_name[name] = widget
-- 	end

-- 	for name, widget_definition in pairs(info_widget_definitions) do
-- 		local widget = UIWidget.init(widget_definition)
-- 		info_widgets[#info_widgets + 1] = widget
-- 		widgets_by_name[name] = widget
-- 	end

-- 	for name, widget_definition in pairs(bot_selection_widget_definitions) do
-- 		local widget = UIWidget.init(widget_definition)
-- 		bot_selection_widgets[#bot_selection_widgets + 1] = widget
-- 		widgets_by_name[name] = widget
-- 	end

-- 	self._widgets = widgets
-- 	self._info_widgets = info_widgets
-- 	self._bot_selection_widgets = bot_selection_widgets
-- 	self._widgets_by_name = widgets_by_name

-- 	self:_setup_hero_selection_widgets()
-- 	UIRenderer.clear_scenegraph_queue(self.ui_top_renderer)

-- 	self.ui_animator = UIAnimator:new(self.ui_scenegraph, animation_definitions)
-- end)

-- mod:hook_origin(CharacterSelectionStateCharacter, "create_ui_elements",function (self, params)
-- 	self.ui_scenegraph = UISceneGraph.init_scenegraph(scenegraph_definition)
-- 	local widgets = {}
-- 	local info_widgets = {}
-- 	local bot_selection_widgets = {}
-- 	local widgets_by_name = {}

-- 	for name, widget_definition in pairs(widget_definitions) do
-- 		local widget = UIWidget.init(widget_definition)
-- 		widgets[#widgets + 1] = widget
-- 		widgets_by_name[name] = widget
-- 	end

-- 	for name, widget_definition in pairs(info_widget_definitions) do
-- 		local widget = UIWidget.init(widget_definition)
-- 		info_widgets[#info_widgets + 1] = widget
-- 		widgets_by_name[name] = widget
-- 	end

-- 	for name, widget_definition in pairs(bot_selection_widget_definitions) do
-- 		local widget = UIWidget.init(widget_definition)
-- 		bot_selection_widgets[#bot_selection_widgets + 1] = widget
-- 		widgets_by_name[name] = widget
-- 	end

-- 	local area_widgets = {}
-- 	local area_widgets_by_name = {}

-- 	for name, widget_definition in pairs(area_widget_definitions) do
-- 		local widget = UIWidget.init(widget_definition)
-- 		area_widgets[#area_widgets + 1] = widget
-- 		area_widgets_by_name[name] = widget
-- 	end

-- 	self._area_widgets = area_widgets
-- 	self._area_widgets_by_name = area_widgets_by_name

-- 	self._widgets = widgets
-- 	self._info_widgets = info_widgets
-- 	self._bot_selection_widgets = bot_selection_widgets
-- 	self._widgets_by_name = widgets_by_name

-- 	self:_setup_hero_selection_widgets()
-- 	UIRenderer.clear_scenegraph_queue(self.ui_top_renderer)

-- 	self.ui_animator = UIAnimator:new(self.ui_scenegraph, animation_definitions)
-- end)

-- mod:hook_origin(CharacterSelectionStateCharacter,"draw",function (self, dt)
-- 	local definitions = local_require("scripts/ui/views/character_selection_view/states/definitions/character_selection_state_character_definitions")
-- 	local scenegraph_definition = definitions.scenegraph_definition

-- 	local area_widgets = {}

-- 	for i = 1, 10, 1 do
-- 		area_widgets[i] = create_area_widget(i)
-- 	end

-- 	local ui_top_renderer = self.ui_top_renderer
-- 	local ui_scenegraph = self.ui_scenegraph
-- 	local input_manager = self.input_manager
-- 	local parent = self.parent
-- 	local input_service = self:input_service()
-- 	local render_settings = self.render_settings
-- 	local gamepad_active = Managers.input:is_device_active("gamepad")
-- 	self._widgets_by_name.bottom_panel.content.visible = gamepad_active

-- 	UIRenderer.begin_pass(ui_top_renderer, ui_scenegraph, input_service, dt, nil, render_settings)

-- 	render_settings.alpha_multiplier = render_settings.main_alpha_multiplier

-- 	for _, widget in ipairs(self._widgets) do
-- 		UIRenderer.draw_widget(ui_top_renderer, widget)
-- 	end

-- 	for _, widget in ipairs(self._hero_widgets) do
-- 		UIRenderer.draw_widget(ui_top_renderer, widget)
-- 	end

-- 	for _, widget in ipairs(self._hero_icon_widgets) do
-- 		UIRenderer.draw_widget(ui_top_renderer, widget)
-- 	end

-- 	print("start")
-- 	local sorted_area_settings = {}

-- 	for _, settings in pairs(AreaSettings) do
-- 		local sort_order = settings.sort_order
-- 		sorted_area_settings[sort_order] = settings
-- 	end

-- 	local num_areas = #sorted_area_settings
-- 	local widget_size = scenegraph_definition.screen.size
-- 	local widget_width = widget_size[1]
-- 	local spacing = 100
-- 	local total_width = widget_width * num_areas + spacing * (num_areas - 1)
-- 	local width_offset = -(total_width / 2) + widget_width / 2
-- 	local statistics_db = self.statistics_db
-- 	local stats_id = self._stats_id
-- 	local assigned_widgets = {}

-- 	for i = 1, num_areas, 1 do
-- 		local settings = sorted_area_settings[i]
-- 		local widget = area_widgets[i]
-- 		assigned_widgets[i] = widget
-- 		local level_image = settings.level_image
-- 		local content = widget.content
-- 		content.icon = level_image
-- 		local unlocked = true
-- 		local dlc_name = settings.dlc_name

-- 		if dlc_name then
-- 			unlocked = Managers.unlock:is_dlc_unlocked(dlc_name)
-- 		end

-- 		local name = settings.name
-- 		content.locked = not unlocked
-- 		content.area_name = name
-- 		local acts = settings.acts
-- 		local lowest_completed_difficulty_index = get_lowest_act_difficulty_index(statistics_db, stats_id, acts, career)
-- 		local frame_texture = self:_get_selection_frame_by_difficulty_index(lowest_completed_difficulty_index)
-- 		content.frame = frame_texture
-- 		local offset = widget.offset
-- 		offset[1] = width_offset
-- 		width_offset = width_offset + widget_width + spacing
-- 	end

-- 	for _, widget in ipairs(assigned_widgets) do
-- 		UIRenderer.draw_widget(ui_top_renderer, widget)
-- 	end
-- 	print("end")

-- 	if not self._draw_video_next_frame then
-- 		if self._video_widget and not self._prepare_exit then
-- 			if not self._video_created then
-- 				UIRenderer.draw_widget(ui_top_renderer, self._video_widget)
-- 			else
-- 				self._video_created = nil
-- 			end
-- 		end
-- 	elseif self._draw_video_next_frame then
-- 		self._draw_video_next_frame = nil
-- 	end

-- 	render_settings.alpha_multiplier = render_settings.info_alpha_multiplier

-- 	for _, widget in ipairs(self._info_widgets) do
-- 		UIRenderer.draw_widget(ui_top_renderer, widget)
-- 	end

-- 	render_settings.alpha_multiplier = render_settings.bot_selection_alpha_multiplier

-- 	for _, widget in ipairs(self._bot_selection_widgets) do
-- 		UIRenderer.draw_widget(ui_top_renderer, widget)
-- 	end

-- 	UIRenderer.end_pass(ui_top_renderer)

-- 	if gamepad_active then
-- 		self.menu_input_description:draw(ui_top_renderer, dt)
-- 	end
-- end)

-- Your mod code goes here.
-- https://vmf-docs.verminti.de