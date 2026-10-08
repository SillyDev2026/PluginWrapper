--!strict
-- Run this server Script beside a Folder named Modules. PluginWrapper.lua requires Studio plugin context.
local modules = script.Parent:WaitForChild("Modules")
local Class = require(modules:WaitForChild("ClassModule"))
local Signal = require(modules:WaitForChild("Signal"))
local EventBus = require(modules:WaitForChild("EventBus"))

local Parent = Class.define({name = "Parent", methods = {Ping = function() return 9 end}})
local Child = Class.define({name = "Child", base = Parent})
local child = Child.new()
assert(child:Ping() == 9 and child:IsA("Parent"), "Inherited methods broke")

local S = Class.define({name = "S", properties = {Value = {signal = true}}})
local a, b = S.new(), S.new()
assert(a.ValueChanged ~= b.ValueChanged, "Property signals are shared between instances")

local signal = Signal.new()
local calls = 0
signal:Connect(function() calls += 1 end)
signal:Fire()
task.wait()
assert(calls == 1, "Signal did not load or dispatch")

local bus = EventBus.new()
local delivered = 0
bus:_On("Ready", function(_, value) delivered = value end, 0, false)
bus:_Fire("Ready", nil, 8)
assert(delivered == 8, "EventBus did not load or deliver")
print("PluginWrapper module regression PASS: 4 checks")
