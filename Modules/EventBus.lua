--!strict
local Class = require(script.Parent.ClassSystem)
local Signal = require(script.Parent.Signal)

export type EventCallback<T...> = (source: any, T...) -> (boolean?)
export type EventListener<T...> = {
	callback: EventCallback<T...>,
	priority: number,
	async: boolean,
	source: any?,
}
export type EventBus = {
	_listeners: { [string]: { EventListener<any> } },
	_On: <T...>(self: EventBus, eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?) -> Signal.Connection<T...>,
	_Once: <T...>(self: EventBus, eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?) -> Signal.Connection<T...>,
	_Fire: <T...>(self: EventBus, eventName: string, source: any?, T...) -> boolean,
	_Clear: (self: EventBus, eventName: string?) -> (),
}

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new(): EventBus
	local self = setmetatable({}, EventBus) :: any
	self._listeners = {}
	return self
end

local function createListener<T...>(callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?): EventListener<T...>
	return {
		callback = callback,
		priority = priority or 0,
		async = async ~= false,
		source = source,
	}
end

local function sortListeners(listeners: { EventListener<any> })
	table.sort(listeners, function(a, b)
		return a.priority > b.priority
	end)
end

function EventBus:_On<T...>(eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?): Signal.Connection<T...>
	if not self._listeners[eventName] then
		self._listeners[eventName] = {}
	end
	local listener = createListener(callback, priority, async, source)
	table.insert(self._listeners[eventName], listener)
	sortListeners(self._listeners[eventName])
	local connection: Signal.Connection<T...>
	connection = {
		Connected = true,
		Disconnect = function()
			if not connection.Connected then return end
			connection.Connected = false
			for i, l in ipairs(self._listeners[eventName]) do
				if l == listener then
					table.remove(self._listeners[eventName], i)
					break
				end
			end
		end,
	} :: Signal.Connection<T...>
	return connection
end

function EventBus:_Once<T...>(eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?): Signal.Connection<T...>
	local connection: Signal.Connection<T...>
	connection = self:_On(eventName, function(sourceArg: any, ...: T...)
		connection:Disconnect()
		return callback(sourceArg, ...)
	end, priority, async, source)
	return connection
end

function EventBus:_Fire<T...>(eventName: string, source: any?, ...: T...): boolean
	local listeners = self._listeners[eventName]
	if not listeners then return true end
	for _, listener in ipairs(listeners) do
		if not  listener.async then
			local result = listener.callback(source, ...)
			if result == false then return false 	end
		else
			task.spawn(listener.callback, source, ...)
		end
	end
	local wild = self._listeners["*"]
	if wild then
		for _, listener in ipairs(wild) do
			if not listener.async then
				local result = listener.callback(eventName, source, ...)
				if result == false then return false end
			else
				task.spawn(listener.callback, eventName, source, ...)
			end
		end
	end
	return true
end

function EventBus:_Clear(eventName: string?)
	if eventName then
		self._listeners[eventName] = nil
	else
		self._listeners = {}
	end
end

return EventBus