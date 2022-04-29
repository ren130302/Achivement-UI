return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Achivement UI` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("Achivement UI", {
			mod_script       = "scripts/mods/Achivement UI/Achivement UI",
			mod_data         = "scripts/mods/Achivement UI/Achivement UI_data",
			mod_localization = "scripts/mods/Achivement UI/Achivement UI_localization",
		})
	end,
	packages = {
		"resource_packages/Achivement UI/Achivement UI",
	},
}
