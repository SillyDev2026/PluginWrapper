local Class = require(script.Parent.ClassSystem)

export type Connection<T...> = {
	Connected: boolean,
	Callback: (...any) -> (),
	Signal: Signal<T...>,
	Disconnect: (self: Connection<T...>) -> (),
}

export type Signal<T...> = {
	_connections: { Connection<T...> },
	_waitingThreads: { thread },
	_destroyed: boolean,
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	FireAsync: (self: Signal<T...>, T...) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

local Signal = Class.define({
	name = "Signal",
	constructor = function(self)
		self._connections = {}
		self._waitingThreads = {}
		self._destroyed = false
	end,
})

function createConnection<T...>(signal: Signal<T...>, callback: (T...) -> ()): Connection<T...>
	local connection: Connection<T...>
	connection = {
		Connected = true,
		Callback = callback,
		Signal = signal,
		Disconnect = function(self: Connection<T...>)
			if not self.Connected then return end
			self.Connected = false
			for i, conn in ipairs(self.Signal._connections) do
				if conn == self then
					table.remove(self.Signal._connections, i)
					break
				end
			end
		end,
	}
	return connection
end

function Signal:Connect<T...>(callback: (T...) -> ()): Connection<T...>
	assert(typeof(callback) == "function", "Signal:Connect expects a function")
	assert(not self._destroyed, "Cannot connect to destroyed Signal")
	local connection = createConnection(self, callback)
	table.insert(self._connections, connection)
	return connection
end

function Signal:Once<T...>(callback: (T...) -> ()): Connection<T...>
	local connection: Connection<T...>
	connection = self:Connect(function(...: T...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Wait<T...>(): T...
	assert(not self._destroyed, "Cannot wait on destroyed Signal")
	local thread = coroutine.running()
	table.insert(self._waitingThreads, thread)
	return coroutine.yield()
end

function Signal:Fire<T...>(...: T...)
	if self._destroyed then return end
	local conns = table.clone(self._connections)
	for _, conn in ipairs(conns) do
		if conn.Connected then
			task.spawn(conn.Callback, ...)
		end
	end
	for _, thread in ipairs(self._waitingThreads) do
		task.spawn(coroutine.resume, thread, ...)
	end
	table.clear(self._waitingThreads)
end

function Signal:FireAsync<T...>(...: T...)
	if self._destroyed then return end
	local args = table.pack(...)
	task.defer(function()
		self:Fire(table.unpack(args, 1, args.n))
	end)
end

function Signal:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	for _, conn in ipairs(self._connections) do
		conn.Connected = false
	end
	table.clear(self._connections)
	table.clear(self._waitingThreads)
end

local SignalModule = {}

function SignalModule.new<T...>(): Signal<T...>
	return Signal.new():: Signal<T...>
end

return SignalModule