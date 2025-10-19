--!strict
export type PropertyDef = {
	default: any?,
	validate: ((value: any) -> boolean)?, 
	signal: boolean?,
	readonly: boolean?,
}

export type ClassOptions = {
	name: string?,
	base: any?,
	abstract: boolean?,
	properties: { [string]: PropertyDef }?,
	static: { [string]: any }?,
	constructor: ((self: any, ...any) -> ())?,
	mixins: { any }?,
	interfaces: { any }?,
	methods: {[string]: (...any) -> any}?,
}

export type Class<T> = {
	new: (...any) -> T,
	__index: Class<T>,
	__type: string,
	__base: Class<T>?,
	IsA: (self: T | Class<T>, className: string) -> boolean,
	GetClassName: (self: T | Class<T>) -> string,
}

local Class = {}

local function copyProps(target: any, source: any)
	for k, v in pairs(source) do
		target[k] = v
	end
end

local function createPropertySignal()
	local signal = {} :: {
		Connect: (self: any, ( ...any) -> ()) -> { Disconnect: () -> () },
		Fire: (self: any, ...any) -> ()	}
	local connections = {} :: { ((...any) -> ()) }
	function signal:Connect(callback: (...any) -> ())
		table.insert(connections, callback)
		return {
			Disconnect = function()
				for i, c in ipairs(connections) do
					if c == callback then
						table.remove(connections, i)
						break
					end
				end
			end,
		}
	end
	function signal:Fire(...: any)
		for _, c in ipairs(connections) do
			c(...)
		end
	end
	setmetatable(signal, {
		__tostring = function()
			return "PropertySignal"
		end,
	})
	return signal
end

function Class.define<T>(options: ClassOptions): Class<T>
	local name = options.name or "UnnamedClass"
	local base = options.base
	local constructor = options.constructor
	local class = {} :: any
	class.__index = class
	class.__type = name
	class.__base = base
	class.__abstract = options.abstract or false
	class.__mixins = options.mixins or {}
	class.__interfaces = options.interfaces or {}
	if options.methods then
		for methodName, fn in pairs(options.methods) do
			class[methodName] = fn
		end
	end

	if base then
		setmetatable(class, { __index = base })
	end

	if options.static then
		for k, v in pairs(options.static) do
			class[k] = v
		end
	end

	for _, mixin in ipairs(class.__mixins) do
		copyProps(class, mixin)
	end

	local defaults = {}
	local validators = {}
	local readonlyProps = {}
	local signals = {}
	if options.properties then
		for prop, def in pairs(options.properties) do
			defaults[prop] = def.default
			if def.validate then
				validators[prop] = def.validate
			end
			if def.readonly then
				readonlyProps[prop] = true
			end
			if def.signal then
				signals[prop] = createPropertySignal()
			end
		end
	end

	function class.new(...): T
		assert(not class.__abstract, `Cannot instantiate abstract class {class.__type}`)

		local self = {} :: any
		for prop, val in pairs(defaults) do
			self[prop] = val
		end

		local mt = {}
		mt.__index = class
		local rawSet = function(tbl, key, value)
			rawset(tbl, key, value)
		end
		mt.__newindex = function(tbl, key, value)
			if readonlyProps[key] then
				error(`Property {key} is read-only`)
			end
			if validators[key] and not validators[key](value) then
				error(`Invalid value for property {key}`)
			end
			if signals[key] then
				signals[key]:Fire(value)
			end
			rawSet(tbl, key, value)
		end

		setmetatable(self, mt)

		local typedSelf = self :: any

		if base and base.init then
			base.init(typedSelf, ...)
		end

		if constructor then
			constructor(typedSelf, ...)
		elseif class.init then
			class.init(typedSelf, ...)
		end

		for prop, sig in pairs(signals) do
			typedSelf[prop .. "Changed"] = sig
		end

		if #class.__interfaces > 0 then
			for _, iface in ipairs(class.__interfaces) do
				for k, _ in pairs(iface) do
					if type(typedSelf[k]) ~= "function" then
						error(`Class {class.__type} does not implement interface method {k}`)
					end
				end
			end
		end

		return typedSelf :: T
	end

	function class:IsA(className: string): boolean
		local current = self
		while current do
			if current.__type == className then
				return true
			end
			current = rawget(current, "__base")
		end
		return false
	end

	function class:GetClassName(): string
		return class.__type
	end

	function class:__tostring()
		return `Instance of {class.__type}`
	end

	setmetatable(class, {
		__call = function(_, ...)
			return class.new(...)
		end,
	})

	return class
end

function Class.new()
	local self = {}
	self.__index = self
	self.__type = "AnonymousClass"
	return setmetatable(self, self)
end

return Class
