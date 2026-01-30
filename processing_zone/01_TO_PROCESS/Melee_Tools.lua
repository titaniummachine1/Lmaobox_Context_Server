-- Main entry point for Melee_Tools
-- Imports

-- Module declaration
local Main = {}

-- Local constants / utilities -----

function Main.Initialize()
	-- Load config (initializes G.Menu)
	local okConfig, _ = pcall(require, "Utils.Config")
	if not okConfig then
		client.ChatPrintf("\x07FF0000Failed to load config!")
	end

	-- Load adaptive menu - it registers its own Draw callback for TimMenu
	local okMenu, _ = pcall(require, "Simulation.adaptive_menu")
	if not okMenu then
		client.ChatPrintf("\x07FF0000Failed to load adaptive menu!")
	end
end

-- Self-init (optional) ---
Main.Initialize()

-- Callbacks -----

return Main
