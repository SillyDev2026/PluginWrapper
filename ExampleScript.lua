local PluginWrapper = require(script.PluginWrapper)
local wrapper = PluginWrapper.new(plugin)
local toolbar = wrapper:CreateToolbar("Test")
local button = wrapper:CreateButton(toolbar, "Test", "Opens Test", "")

local dockInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false, true,
	350, 420,
	250, 200
)
local widget = wrapper:CreateWidget("Test", dockInfo)
widget.Title = "🎨 Test Widget"

wrapper:Clicked("Test", function()
	widget:Toggle()
end)

local data = wrapper:Set('Data', {Example = false})