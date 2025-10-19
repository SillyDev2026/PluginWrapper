local PluginWrapper = require(script.PluginWrapper)
local wrapper = PluginWrapper.new(plugin)
local toolbar = wrapper:CreateToolbar("Test")
local button = wrapper:CreateButton(toolbar, "Test", "Opens Test", "") -- the last part is ur icon for the Button

local dockInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false, true,
	350, 420,
	250, 200
)
local widget = wrapper:CreateWidget("Test", dockInfo)
widget.Gui.Title = "🎨 Test Widget"

wrapper:Clicked("Test", function()
	widget:Toggle()
end)

local Frame = Instance.new('Frame')
Frame.Name = 'Background'
Frame.BackgroundTransparency = 0
Frame.BackgroundColor3 = Color3.fromHSV(0, 0, 0.298039)
Frame.Visible = true
Frame.Size = UDim2.new(1, 0, 1, 0)
Frame.Parent = widget.Gui