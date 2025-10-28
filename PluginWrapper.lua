local TweenService = game:GetService('TweenService')
local Modules = script.Parent.Modules
local Class = require(Modules.ClassSystem)
local EventBus = require(Modules.EventBus)
local User = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
export type StudioToolbar = {
	CreateButton: (self: any, name: string, tooltip: string, icon: string) -> StudioButton,
}

export type StudioButton = {
	Name: string,
	ClickableWhenViewportHidden: boolean,
	Click: RBXScriptSignal,
}

export type StudioWidget = {
	Name: string,
	Enabled: boolean,
	Gui: DockWidgetPluginGuiInfo,
	Toggle: (self: StudioWidget) -> (),
	Open: (self: StudioWidget, enable: boolean) -> (),
	Close: (self: StudioWidget, enable: boolean) -> (),
	_events: typeof(EventBus.new())
}

type Size = {
	xScale: number?,
	yScale: number?,
	xOffset: number?,
	yOffset: number?
}

type ColorVarients = {
	Red: number?,
	Green: number?,
	Blue: number?
}

type Apply = {
	Apply: Enum.ApplyStrokeMode?,
	Line: Enum.LineJoinMode?,
	color: ColorVarients?,
	Thickness: number?,
	Enabled: boolean?,
	Transparency: number?
}

type AnchorPoint = {
	X: number?,
	Y: number?
}

type Text = {
	TextScaled: boolean,
	TextWrapped: boolean,
	RichText: boolean,
	TextSize: number,
	Visible: boolean,
	TextColor: ColorVarients,
	Transparency: number,
	XAlignment: Enum.TextXAlignment,
	YAlignment: Enum.TextYAlignment,
	text: string,
}

type UiObject = TextLabel | TextButton | Frame | ScrollingFrame | ImageButton | ImageLabel

export type Ui = {
	Color: (self: Ui, color: ColorVarients) -> Ui,
	Corner: (self: Ui, corner: AnchorPoint) -> Ui,
	Size: (self: Ui, size: Size) -> Ui,
	Position: (self: Ui, position: Size) -> Ui,
	Transparency: (self: Ui, alpha: number) -> Ui,
	Border: (self: Ui, thickness: number, color: ColorVarients?) -> Ui,
	Stroke: (self: Ui, options: Apply) -> Ui,
	OnHover: (self: Ui, onEnter: (object: UiObject) -> (), onLeave: (object: UiObject) -> ()?) -> Ui,
	Parent: (self: Ui, parent: any) -> Ui,
	Name: (self: Ui) -> Ui,
	Anchor: (self: Ui, vector: AnchorPoint) -> Ui,
	Text: (self: Ui, options: Text) -> Ui,
}

type UiTypes = 'Frame'| 'TextLabel'| 'TextButton'| 'TextBox'| 'ImageLabel'| 'ImageButton'| 'ScrollingFrame'| 'UIListLayout'| 'UIGridLayout'| 'UITableLayout'| 'UIPadding'| 'UIStroke'| 'UICorner'| 'UIAspectRatioConstraint'| 'UIScale'| 'UIGradient'| 'UIGradient'| 'UITextSizeConstraint'| 'UIConstraint'

export type PluginWrapper<data> = {
	Plugin: any,
	_events: typeof(EventBus.new()),
	_buttons: { [string]: StudioButton },
	_widgets: { [string]: StudioWidget },
	_settings: {[string]: data},
	_notifications: Frame?,
	_notificationCount: number,
	_activeToasts: {Frame},
	Debug: boolean,
	CreateToolbar: (self: PluginWrapper<data>, name: string) -> StudioToolbar,
	CreateButton: (self: PluginWrapper<data>, toolbar: StudioToolbar, name: string, tooltip: string, icon: string) -> StudioButton,
	CreateWidget: (self: PluginWrapper<data>, name: string, info: DockWidgetPluginGuiInfo) -> StudioWidget,
	Clicked: (self: PluginWrapper<data>, name: string, callback: (button: StudioButton) -> ()) -> (),
	ClickedOnce: (self: PluginWrapper<data>, name: string, callback: (button: StudioButton) -> ()) -> (),
	FireClicked: (self: PluginWrapper<data>, name: string) -> (),
	Toggled: (self: PluginWrapper<data>, name: string, callback: (widget: StudioWidget) -> ()) -> (),
	Set: (self: PluginWrapper<data>, key: string, value: data, saveToPlugin: boolean?) -> (),
	Get: (self: PluginWrapper<data>, key: string) -> data,
	AddUi: (self: PluginWrapper<data>, instance: UiTypes) -> Ui,
	Notify: (self: PluginWrapper<data>, message: string, color: Color3?) -> (),
}

local function shallowClone(tbl: any): any
	if type(tbl) ~= 'table' then return tbl end
	local clone = {}
	for key, values in pairs(tbl) do
		clone[key] = values
	end
	return clone
end

local PluginWrapper = Class.define({
	name = "PluginWrapper<data>",

	constructor = function<data>(self: PluginWrapper<data>, plug: any)
		self.Plugin = plug
		self._events = EventBus.new()
		self._buttons = {}
		self._widgets = {}
		self._settings = {}
		self._notifications = nil
		self._notificationCount = 0
		self.Debug = false
	end,

	methods = {
		CreateToolbar = function<data>(self: PluginWrapper<data>, name: string): StudioToolbar
			return self.Plugin:CreateToolbar(name)
		end,

		CreateButton = function<data>(self: PluginWrapper<data>, toolbar: StudioToolbar, name: string, tooltip: string, icon: string): StudioButton
			local button = toolbar:CreateButton(name, tooltip, icon)
			button.ClickableWhenViewportHidden = true
			self._buttons[name] = button

			button.Click:Connect(function()
				self._events:_Fire("Clicked_" .. name, button)
			end)

			return button
		end,

		CreateWidget = function<data>(self: PluginWrapper<data>, name: string, info: DockWidgetPluginGuiInfo): StudioWidget
			local widget = self.Plugin:CreateDockWidgetPluginGui(name, info)
			local wrapper: any

			wrapper = {
				Gui = widget,
				Name = name,
				Title = widget.Title,
				Enabled = widget.Enabled,
			}

			local PluginWrapper = self

			function wrapper:Open()
				widget.Enabled = true
				wrapper.Enabled = true
				PluginWrapper._events:_Fire("Toggled_" .. name, wrapper)
			end

			function wrapper:Close()
				widget.Enabled = false
				wrapper.Enabled = false
				PluginWrapper._events:_Fire("Toggled_" .. name, wrapper)
			end

			function wrapper:Toggle()
				if widget.Enabled then
					wrapper:Close()
				else
					wrapper:Open()
				end
			end

			widget:GetPropertyChangedSignal("Enabled"):Connect(function()
				wrapper.Enabled = widget.Enabled
			end)

			setmetatable(wrapper, {
				__index = function(t, k)
					if k == "Enabled" then return widget.Enabled end
					if k == "Title" then return widget.Title end
					return rawget(t, k)
				end,
				__newindex = function(t, k, v)
					if k == "Enabled" then
						if v then t:Open() else t:Close() end
					elseif k == "Title" then
						widget.Title = v
					else
						rawset(t, k, v)
					end
				end
			})

			self._widgets[name] = wrapper
			return wrapper
		end,

		Clicked = function<data>(self: PluginWrapper<data>, name: string, callback: (button: StudioButton) -> ())
			self._events:_On("Clicked_" .. name, callback)
		end,

		ClickedOnce = function<data>(self: PluginWrapper<data>, name: string, callback: (button: StudioButton) -> ())
			self._events:_Once("Clicked_" .. name, callback)
		end,

		FireClicked = function<data>(self: PluginWrapper<data>, name: string)
			local button = self._buttons[name]
			if button then
				self._events:_Fire("Clicked_" .. name, button)
			end
		end,

		Toggled = function<data>(self: PluginWrapper<data>, name: string, callback: (widget: StudioWidget) -> ())
			self._events:_On("Toggled_" .. name, callback)
		end,
		Set = function<data>(self:PluginWrapper<data>, key: string, val: data, saveToPlugin: boolean?)
			local storedVal = shallowClone(val)
			self._settings[key] = storedVal
			if saveToPlugin and self.Plugin and self.Plugin.SetSetting then
				pcall(function()
					self.Plugin.SetSetting(key, storedVal)
				end)
			end
			return storedVal
		end,
		Get = function<data>(self: PluginWrapper<data>, key: string): data
			return self._settings[key]
		end,		
		Notify = function<data>(self: PluginWrapper<data>, message: string, color: Color3?)
			color = color or Color3.fromRGB(255, 255, 255)
			self._notificationCount += 1

			local firstWidgetName = next(self._widgets)
			if not firstWidgetName then
				warn("[PluginWrapper<data>] Cannot create notification without a widget")
				return
			end
			
			if not self._activeToasts then
				self._activeToasts = {}:: {Frame}
			end

			local widgetGui = self._widgets[firstWidgetName].Gui
			local notif = Instance.new("Frame")
			notif.Size = UDim2.new(1, -10, 0, 30)
			notif.Position = UDim2.new(0, 5, 0, 5 + #self._activeToasts * 35)
			notif.BackgroundTransparency = 0.3
			notif.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			notif.BorderSizePixel = 0
			notif.Parent = widgetGui
			table.insert(self._activeToasts, notif)

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text = message
			label.TextColor3 = color
			label.TextScaled = true
			label.Font = Enum.Font.SourceSans
			label.Parent = notif
			
			local corner = Instance.new('UICorner')
			corner.Name = 'CornerRadius'
			corner.CornerRadius = UDim.new(0.4, 0)
			corner.Parent = notif
			
			local function updatePosition()
				for i, frame in ipairs(self._activeToasts) do
					TweenService:Create(frame, TweenInfo.new(0.2),{
						Position = UDim2.new(0, 5, 0, 5 + (i-1) * 35)
					}):Play()
				end
			end
			
			updatePosition()
			TweenService:Create(notif, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
			TweenService:Create(label, TweenInfo.new(0.2), {TextTransparency = 0}):Play()

			task.spawn(function()
				task.wait(3)
				TweenService:Create(notif, TweenInfo.new(0.4), {BackgroundTransparency = 0.3}):Play()
				TweenService:Create(label, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
				task.wait(0.4)
				notif:Destroy()
				for i, frame in ipairs(self._activeToasts) do
					if frame == notif then
						table.remove(self._activeToasts, i)
						break
					end
				end
				updatePosition()
				self._notificationCount -= 1
			end)
		end,
		AddUi = function<data>(self: PluginWrapper<data>, instance: UiTypes)
			local inst = Instance.new(instance):: Instance
			local uiWrapper: Ui = {}
			uiWrapper._inst = inst
			function uiWrapper:Color(color: ColorVarients)
				local r, g, b = color.Red or 0, color.Green or 0, color.Blue or 0
				inst.BackgroundColor3 = Color3.fromRGB(r, g, b)
				return self
			end
			function uiWrapper:Corner(corner: AnchorPoint)
				if inst:IsA("GuiObject") then
					local uiCorner = inst:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
					local cornerSize = UDim.new(corner.X, corner.Y)
					uiCorner.CornerRadius = cornerSize
					uiCorner.Parent = inst
				end
				return self
			end
			function uiWrapper:Size(size: Size)
				if inst:IsA("GuiObject") then
					inst.Size = UDim2.new(size.xScale or 0, size.xOffset or 0, size.yScale or 0, size.yOffset or 0)
				end
				return self
			end
			function uiWrapper:Position(pos: Size)
				if inst:IsA("GuiObject") then
					inst.Position = UDim2.new(pos.xScale or 0, pos.xOffset or 0, pos.yScale or 0, pos.yOffset or 0)
				end
				return self
			end
			function uiWrapper:Transparency(alpha: number)
				if inst:IsA("GuiObject") then
					inst.BackgroundTransparency = alpha
				end
				return self
			end
			function uiWrapper:Border(thickness: number, color: Color3?)
				if inst:IsA("GuiObject") then
					inst.BorderSizePixel = thickness
					if color then
						inst.BorderColor3 = color
					end
				end
				return self
			end
			function uiWrapper:Stroke(options: Apply)
				if inst:IsA("GuiObject") then
					local color = options.color
					local r, g, b = color.Red or 0, color.Green or 0, color.Blue or 0
					local stroke = inst:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
					stroke.Enabled = options.Enabled or false
					stroke.Transparency = options.Transparency or 0
					stroke.ApplyStrokeMode = options.Apply or Enum.ApplyStrokeMode.Border
					stroke.LineJoinMode = options.Line or Enum.LineJoinMode.Round
					stroke.Color = Color3.fromRGB(r, g, b) or Color3.new(0)
					stroke.Thickness = options.Thickness or 1
					stroke.Parent = inst
				end
				return self
			end	
			function uiWrapper:OnHover(onEnter: (object: UiObject) -> (), onLeave: (object: UiObject) -> ()?)
				if inst:IsA('TextButton') or inst:IsA('ImageButton') then
					inst.MouseEnter:Connect(function()
						onEnter(inst)
					end)
					inst.MouseLeave:Connect(function()
						onLeave(inst)
					end)
				end
				return self
			end
			function uiWrapper:Parent(parent)
				local t = typeof(parent)
				if t == 'table' and parent._inst then
					inst.Parent = parent._inst
				else
					inst.Parent = parent
				end
				return self
			end
			function uiWrapper:Name()
				return inst.Name
			end
			function uiWrapper:Anchor(vector: AnchorPoint)
				if inst:IsA('GuiObject') then
					inst.AnchorPoint = Vector2.new(vector.X or 0, vector.Y or 0)
				end
				return self
			end
			function uiWrapper:Text(options: Text)
				local textColor = options.TextColor
				local r1, g1, b1 = textColor.Red or 0, textColor.Green or 0, textColor.Blue or 0
				local TextColor = Color3.fromRGB(r1, g1, b1)
				local button = Instance.new('TextLabel')
				inst.TextScaled = options.TextScaled
				inst.TextWrapped = options.TextWrapped
				inst.RichText = options.RichText
				inst.TextSize = options.TextSize
				inst.Visible = options.Visible
				inst.TextColor3 = TextColor
				inst.TextTransparency = options.Transparency
				inst.TextXAlignment = options.XAlignment
				inst.TextYAlignment = options.YAlignment
				inst.Text = options.text
				return self
			end
			return uiWrapper
		end,
	}
})

local Plugin = {}

function Plugin.new<data>(plug: any): PluginWrapper<data>
	return PluginWrapper.new(plug)::PluginWrapper<data>
end

return Plugin