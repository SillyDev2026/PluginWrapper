--!strict
local Modules = script.Parent.Modules
local Class = require(Modules.ClassSystem)
local EventBus = require(Modules.EventBus)

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
	Gui: {Title: string},
	Toggle: (self: StudioWidget) -> (),
	Open: (self: StudioWidget, enable: boolean) -> (),
	Close: (self: StudioWidget, enable: boolean) -> (),
	_events: typeof(EventBus.new())
}

export type PluginWrapper = {
	Plugin: any,
	_events: typeof(EventBus.new()),
	_buttons: { [string]: StudioButton },
	_widgets: { [string]: StudioWidget },
	_settings: {[string]: any},
	CreateToolbar: (self: PluginWrapper, name: string) -> StudioToolbar,
	CreateButton: (self: PluginWrapper, toolbar: StudioToolbar, name: string, tooltip: string, icon: string) -> StudioButton,
	CreateWidget: (self: PluginWrapper, name: string, info: DockWidgetPluginGuiInfo) -> StudioWidget,
	Clicked: (self: PluginWrapper, name: string, callback: (button: StudioButton) -> ()) -> (),
	ClickedOnce: (self: PluginWrapper, name: string, callback: (button: StudioButton) -> ()) -> (),
	FireClicked: (self: PluginWrapper, name: string) -> (),
	Toggled: (self: PluginWrapper, name: string, callback: (widget: StudioWidget) -> ()) -> (),
	Set: (self: PluginWrapper, key: string, value: any, saveToPlugin: boolean?) -> (),
	Get: (self: PluginWrapper, key: string) -> any,
}

local function shallowClone(tbl)
	if type(tbl) ~= 'table' then return tbl end
	local clone = {}
	for key, values in pairs(tbl) do
		clone[key] = values
	end
	return clone
end

local PluginWrapper = Class.define({
	name = "PluginWrapper",

	constructor = function(self: PluginWrapper, plugin: any)
		self.Plugin = plugin
		self._events = EventBus.new()
		self._buttons = {}
		self._widgets = {}
		self._settings = {}
	end,

	methods = {
		CreateToolbar = function(self: PluginWrapper, name: string): StudioToolbar
			return self.Plugin:CreateToolbar(name)
		end,

		CreateButton = function(self: PluginWrapper, toolbar: StudioToolbar, name: string, tooltip: string, icon: string): StudioButton
			local button = toolbar:CreateButton(name, tooltip, icon)
			button.ClickableWhenViewportHidden = true
			self._buttons[name] = button

			button.Click:Connect(function()
				self._events:_Fire("Clicked_" .. name, button)
			end)

			return button
		end,

		CreateWidget = function(self: PluginWrapper, name: string, info: DockWidgetPluginGuiInfo): StudioWidget
			local widget = self.Plugin:CreateDockWidgetPluginGui(name, info)
			local wrapper: any

			wrapper = {
				Gui = widget,
				Name = name,
				Title = widget.Title,
				Enabled = widget.Enabled,
			}

			local pluginWrapper = self

			function wrapper:Open()
				widget.Enabled = true
				wrapper.Enabled = true
				pluginWrapper._events:_Fire("Toggled_" .. name, wrapper)
			end

			function wrapper:Close()
				widget.Enabled = false
				wrapper.Enabled = false
				pluginWrapper._events:_Fire("Toggled_" .. name, wrapper)
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

		Clicked = function(self: PluginWrapper, name: string, callback: (button: StudioButton) -> ())
			self._events:_On("Clicked_" .. name, callback)
		end,

		ClickedOnce = function(self: PluginWrapper, name: string, callback: (button: StudioButton) -> ())
			self._events:_Once("Clicked_" .. name, callback)
		end,

		FireClicked = function(self: PluginWrapper, name: string)
			local button = self._buttons[name]
			if button then
				self._events:_Fire("Clicked_" .. name, button)
			end
		end,

		Toggled = function(self: PluginWrapper, name: string, callback: (widget: StudioWidget) -> ())
			self._events:_On("Toggled_" .. name, callback)
		end,
		Set = function(self:PluginWrapper, key: string, val: TSetting, saveToPlugin: boolean?)
			local storedVal = shallowClone(val)
			self._settings[key] = storedVal
			if saveToPlugin and self.Plugin and self.Plugin.SetSetting then
				pcall(function()
					self.Plugin.SetSetting(key, storedVal)
				end)
			end
			return storedVal
		end,
		Get = function(self: PluginWrapper, key: string)
			return self._settings[key]
		end,
	}
})

local Plugin = {}

function Plugin.new(plug: any): PluginWrapper
	return (PluginWrapper.new(plug))::PluginWrapper
end

return Plugin