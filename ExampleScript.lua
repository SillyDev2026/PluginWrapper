local PluginWrapper = require(script.PluginWrapper)
local wrapper = PluginWrapper.new(plugin)
local toolbar = wrapper:CreateToolbar("Test")
local button = wrapper:CreateButton(toolbar, "Test", "Opens Test", "")

local dockInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false, true,
	350, 420, -- Default size
	250, 200  -- Min size
)
local widget = wrapper:CreateWidget("Test", dockInfo)
widget.Gui.Title = "🎨 Test Widget"

wrapper:Clicked("Test", function()
	widget:Toggle()
	print('Hi')
end)