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
	Title: string,
	Toggle: (self: StudioWidget) -> (),
	Open: (self: StudioWidget, enable: boolean) -> (),
	Close: (self: StudioWidget, enable: boolean) -> (),
	_events: typeof(EventBus.new())
}

export type PluginWrapper<TKey, TSetting> = {
	Plugin: any,
	_events: typeof(EventBus.new()),
	_buttons: { [string]: StudioButton },
	_widgets: { [string]: StudioWidget },
	_settings: {[string]: TSetting},
	CreateToolbar: (self: PluginWrapper<TKey, TSetting>, name: string) -> StudioToolbar,
	CreateButton: (self: PluginWrapper<TKey, TSetting>, toolbar: StudioToolbar, name: string, tooltip: string, icon: string) -> StudioButton,
	CreateWidget: (self: PluginWrapper<TKey, TSetting>, name: string, info: DockWidgetPluginGuiInfo) -> StudioWidget,
	Clicked: (self: PluginWrapper<TKey, TSetting>, name: string, callback: (button: StudioButton) -> ()) -> (),
	ClickedOnce: (self: PluginWrapper<TKey, TSetting>, name: string, callback: (button: StudioButton) -> ()) -> (),
	FireClicked: (self: PluginWrapper<TKey, TSetting>, name: string) -> (),
	Toggled: (self: PluginWrapper<TKey, TSetting>, name: string, callback: (widget: StudioWidget) -> ()) -> (),
	Set: (self: PluginWrapper<TKey, TSetting>, key: TKey, value: TSetting) -> (),
	Get: (self: PluginWrapper<TKey, TSetting>, key: TKey) -> TSetting,
}

local PluginWrapper = Class.define({
	name = "PluginWrapper",

	constructor = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, plugin: any)
		self.Plugin = plugin
		self._events = EventBus.new()
		self._buttons = {}
		self._widgets = {}
		self._settings = {}
	end,

	methods = {
		CreateToolbar = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, name: string): StudioToolbar
			return self.Plugin:CreateToolbar(name)
		end,

		CreateButton = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, toolbar: StudioToolbar, name: string, tooltip: string, icon: string): StudioButton
			local button = toolbar:CreateButton(name, tooltip, icon)
			button.ClickableWhenViewportHidden = true
			self._buttons[name] = button

			button.Click:Connect(function()
				self._events:_Fire("Clicked_" .. name, button)
			end)

			return button
		end,

		CreateWidget = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, name: string, info: DockWidgetPluginGuiInfo): StudioWidget
			local widget = self.Plugin:CreateDockWidgetPluginGui(name, info)
			local wrapper: any

			wrapper = {
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

		Clicked = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, name: string, callback: (button: StudioButton) -> ())
			self._events:_On("Clicked_" .. name, callback)
		end,

		ClickedOnce = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, name: string, callback: (button: StudioButton) -> ())
			self._events:_Once("Clicked_" .. name, callback)
		end,

		FireClicked = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, name: string)
			local button = self._buttons[name]
			if button then
				self._events:_Fire("Clicked_" .. name, button)
			end
		end,

		Toggled = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, name: string, callback: (widget: StudioWidget) -> ())
			self._events:_On("Toggled_" .. name, callback)
		end,
		Set = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, key: TKey, val: TSetting)
			self._settings[key] = val
			if self.Plugin and self.Plugin.SetSetting then
				pcall(function()
					self.Plugin:SetSetting(key, val)
				end)
			end
			return self._settings[key]
		end,
		Get = function<TKey, TSetting>(self: PluginWrapper<TKey, TSetting>, key: TKey): TSetting
			local stored = self._settings[key]
			if stored ~= nil then
				return stored
			end
			if self.Plugin and self.Plugin.GetSetting then
				local ok, result = pcall(function()
					return self.Plugin:GetSetting(key)
				end)
				if ok then
					self._settings[key] = result
					return result
				end
			end
			return nil:: any
		end,
	}
})

local Plugin = {}

function Plugin.new<TKey, TSetting>(plug: any): PluginWrapper<TKey, TSetting>
	return (PluginWrapper.new(plug))::PluginWrapper<TKey, TSetting>
end

return Plugin