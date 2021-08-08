u_execDependencyScript("ohvrvanilla", "base", "vittorio romeo", "utils.lua")

-- Base slider class
local Slider = {}

-- Creates new slider class
-- Values always start at:
-- Period = 1 [seconds]
-- Amplitude = 1 [units] (note that amplitude is half of the wave's height, so the full range of a wave is [-A, A])
-- Y-Offset = 0 [units]
-- X-Offset = 0 [units]
-- Value = 0 [units]
function Slider:new(p, a, y, x, t, func)
	local newInst = {}
	setmetatable(newInst, {__index = self})

	newInst:setPeriod(p)
	newInst:setAmplitude(a)
	newInst:setYOffset(y)
	newInst:setXOffset(x)
	newInst:setTimescale(t)
	newInst:setFunction(func)
	newInst.value = 0

	return newInst
end

function Slider:setPeriod(p)
	p = p and p > 0 and p or 1
	if self.x then self.x = lerp(0, p, inverseLerp(0, self.period, self.x)) end
	self.period = p
end

function Slider:getPeriod() return self.period end

function Slider:setAmplitude(a) self.amplitude = a or 1 end

function Slider:getAmplitude() return self.amplitude end

function Slider:setYOffset(y) self.yOffset = y or 0 end

function Slider:getYOffset() return self.yOffset end

function Slider:setXOffset(x) self.x = x and clamp(x, 0, self.period) or 0 end

function Slider:getXOffset() return self.x end

function Slider:setTimescale(t) self.timescale = t or 1 end

function Slider:getTimescale() return self.timescale end

function Slider:setFunction(func) self.func = type(func) == 'function' and func or function() end end

function Slider:getFunction() return self.func end

function Slider:setValue(v) self.value = v or 0 end

function Slider:getValue() return self.value end

function Slider:advance(mFrameTime, ...)
	self.x = self.x + clamp(mFrameTime / FPS * self.timescale, -self.period, self.period)
	if self.x >= self.period then
		self.x = self.x - self.period
		self.func(...)
	elseif self.x <= 0 then
		self.x = self.x + self.period
		self.func(...)
	end
end

function Slider:printSliderInfo()
	u_log('==============')
	u_log('Period: ' .. self:getPeriod())
	u_log('Amplitude: ' .. self:getAmplitude())
	u_log('Y-Offset: ' .. self:getYOffset())
	u_log('X-Offset: ' .. self:getXOffset())
	u_log('Timescale: ' .. self:getTimescale())
	u_log('Value: ' .. self:getValue())
end




-- Square wave slider
-- Inherits from Slider
SliderSquare = {}
setmetatable(SliderSquare, {__index = Slider})

-- Default value for dutyCycle
SliderSquare.dutyCycle = 0.5

function SliderSquare:new(p, a, y, x, t, d, func)
	local newInst = {}
	setmetatable(newInst, {__index = self})

	newInst:setPeriod(p)
	newInst:setAmplitude(a)
	newInst:setYOffset(y)
	newInst:setXOffset(x)
	newInst:setTimescale(t)
	newInst:setDutyCycle(d)
	newInst:setFunction(func)
	newInst.value = 0

	return newInst
end

function SliderSquare:setDutyCycle(d) self.dutyCycle = d and clamp(d, 0, 1) or 0.5 end

function SliderSquare:getDutyCycle() return self.dutyCycle end

function SliderSquare:step(mFrameTime, ...)
	self:advance(mFrameTime, ...)
	self.value = self.amplitude * square(self.x, self.period, self.dutyCycle) + self.yOffset
end

function SliderSquare:printSliderInfo()
	u_log('==============')
	u_log('Period: ' .. self:getPeriod())
	u_log('Amplitude: ' .. self:getAmplitude())
	u_log('Y-Offset: ' .. self:getYOffset())
	u_log('X-Offset: ' .. self:getXOffset())
	u_log('Timescale: ' .. self:getTimescale())
	u_log('Duty Cycle: ' .. self:getDutyCycle())
	u_log('Value: ' .. self:getValue())
end




-- Triangle wave Slider
-- Inherits from Slider
SliderTriangle = {}
setmetatable(SliderTriangle, {__index = Slider})

function SliderTriangle:step(mFrameTime, ...)
	self:advance(mFrameTime, ...)
	self.value = self.amplitude * triangle(self.x, self.period) + self.yOffset
end




-- Sawtooth wave Slider
-- Inherits from Slider
SliderSawtooth = {}
setmetatable(SliderSawtooth, {__index = Slider})

function SliderSawtooth:step(mFrameTime, ...)
	self:advance(mFrameTime, ...)
	self.value = self.amplitude * sawtooth(self.x, self.period) + self.yOffset
end




-- Sine wave Slider
-- Inherits from Slider
SliderSine = {}
setmetatable(SliderSine, {__index = Slider})

function SliderSine:step(mFrameTime, ...)
	self:advance(mFrameTime, ...)
	self.value = self.amplitude * math.sin(math.tau * self.x / self.period) + self.yOffset
end




-- Sign function
function sgn(x)
	if x > 0 then return 1 end
	if x == 0 then return 0 end
	return -1
end

-- Square wave function with period p at value x with duty cycle d (range [-1, 1])
function square(x, p, d)
	return sgn(math.sin(math.pi * (2 * x / p + 0.5 - d)) - math.cos(math.pi * d))
end

-- Triangle wave function with period p at value x (range [-1, 1])
function triangle(x, p)
	return math.asin(math.sin(math.tau * x / p)) * 2 / math.pi 
end

-- Sawtooth wave function with period p at value x (range [-1, 1])
function sawtooth(x, p)
	return 2 * (x / p - math.floor(0.5 + x / p))
end




-- Manually controlled slider
SliderManual = {}

-- <decKey> Decrement key
-- <incKey> Increment key
-- <delta> Step size (optional, defaults to 1)
-- <start> Starting value (optional, defaults to 0)
-- <min> Lower bound (optional)
-- <max> Upper bound (optional)
-- If no bounds are provided, slider has infinite range.
-- Both <min> and <max> must be set to enable bounds
-- <min> must be less than <max> or else they will not be set
-- <loop> If true, the value will loop between the two limits, instead of just being stopped
function SliderManual:new(decKey, incKey, delta, start, min, max, loop)
	local newInst = {}
	setmetatable(newInst, {__index = self})

	newInst:setValue(start)
	newInst:setDecKey(decKey)
	newInst:setIncKey(incKey)
	newInst:setDelta(delta)
	newInst:setLimits(min, max, loop)
	
	return newInst
end

function SliderManual:setDecKey(decKey) self.decKey = decKey or -1 end

function SliderManual:getDecKey() return self.decKey end

function SliderManual:setIncKey(incKey) self.incKey = incKey or -1 end

function SliderManual:getIncKey() return self.incKey end

function SliderManual:setDelta(delta) self.delta = delta or 1 end

function SliderManual:getDelta() return self.delta end

function SliderManual:setLimits(min, max, loop)
	if min and max and min <= max then
		self.min, self.max = min, max
		if loop then self.range = max - min end
	end
end

function SliderManual:removeLimits() self.min, self.max, self.range = nil, nil, nil end

function SliderManual:getLimits() return self.min, self.max end

function SliderManual:setValue(v) self.value = v and (self.min and self.max and clamp(v, self.min, self.max) or v) or (self.min and self.max and clamp(0, self.min, self.max) or 0) end

function SliderManual:getValue() return self.value end

function SliderManual:step()
	self.value = self.value + (u_isKeyPressed(self.decKey) and -self.delta or 0) + (u_isKeyPressed(self.incKey) and self.delta or 0)
	if self.min and self.max then
		if self.value > self.max then self.value = self.range and self.value - self.range or self.max
		elseif self.value < self.min then self.value = self.range and self.value + self.range or self.min end
	end
end





-- Simple Perlin noise slider
-- Inherits from slider
SliderPerlin = {}
setmetatable(SliderPerlin, {__index = Slider})

-- Values for the LCG
SliderPerlin.M, SliderPerlin.A, SliderPerlin.C = 4294967296, 1664525, 1

-- <p> Period. The amount of time between critical points in seconds.
-- <a> Amplitude. Range of values is equivalent to [-A, A].
-- <y> Y-Offset.
-- <t> Timescale.
-- <s> Seed value. Must be a number between 0 and 1. Seed can only be set once for a slider.
-- <x> X-Offset. Not very useful since outputs are random.
-- Passing nothing for a parameter will set the parameter to it's default
function SliderPerlin:new(p, a, y, t, s, x, func)
	local newInst = {}
	setmetatable(newInst, {__index = self})

	newInst:setPeriod(p)
	newInst:setAmplitude(a)
	newInst:setYOffset(y)
	newInst:setTimescale(t)
	newInst:setXOffset(x)
	newInst:setFunction(func)
	newInst.value = 0
	newInst.Z = math.floor((s or u_rndReal()) * newInst.M)
	newInst.yBegin = newInst.amplitude * (newInst:randLCG() * 2 - 1) + newInst.yOffset
	newInst.yEnd = newInst.amplitude * (newInst:randLCG() * 2 - 1) + newInst.yOffset

	return newInst
end

-- Override default timescale functions as the Perlin slider doesn't support negative timescales
function SliderPerlin:setTimescale(t) self.timescale = t and math.max(t, 0) or 1 end

function SliderPerlin:getTimescale() return self.timescale end

-- Advances x value
-- When wraps around, rolls the next critical point
function SliderPerlin:advance(mFrameTime, ...)
	self.x = self.x + clamp(mFrameTime / FPS * self.timescale, -self.period, self.period)
	if self.x >= self.period then
		self:next()
		self.func(...)
		self.x = self.x - self.period
	end
end

-- Updates slider to the next value
function SliderPerlin:step(mFrameTime, ...)
	self:advance(mFrameTime, ...)
	self.value = lerp(self.yBegin, self.yEnd, easeInOutSine(self.x / self.period))
end

-- Linear Congruential Generator. Separate PRNG that can be seeded. Unique to each individual slider
function SliderPerlin:randLCG()
	self.Z = (self.A * self.Z  + self.C) % self.M
	return self.Z / self.M
end

-- Generates the next critical point
function SliderPerlin:next()
	self.yBegin = self.yEnd
	self.yEnd = self.amplitude * (self:randLCG() * 2 - 1) + self.yOffset
end




-- Extension of the Perlin noise slider
-- Uses multiple Perlin Sliders to create more complex noise
-- Inherits from SliderPerlin
SliderNoise = {}
setmetatable(SliderNoise, {
	__index = function(inst, key)
		-- Exclude certain functions
		if key == 'setPeriod' or key == 'getPeriod' or key == 'setAmplitude' or key == 'getAmplitude' or key == 'setXOffset' or key == 'getXOffset' or key == 'setFunction' or key == 'getFunction' then return end
		return SliderPerlin[key]
	end
})

-- <p> Period. Cannot be changed once set. (Default value 1)
-- <a> Amplitude. Cannot be changed once set. Amplitude for SliderNoise does not set the absolute maximum and minimum possible value but is a measure of how much the value is allowed to migrate from it's center point. (Default value 1)
-- <o> Octaves. Cannot be changed once set. The more octaves, the more "bumpy" the noise will be. (Default value 1)
-- <y> Y-Offset. (Default value 0)
-- <t> Timescale. (Default value 1)
-- <s> Seed value. Seed is only used to set the initial seeds of all child perlin sliders. Must be a number between 0 and 1.
-- <d> Divisor. Cannot be changed once set. For octave calculations. (Default value 2)
-- Function must be run at least once to initialize the class
function SliderNoise:new(p, a, y, o, t, s, d)
	local newInst = {}
	setmetatable(newInst, {__index = self})

	p = p or 1
	a = a or 1
	o = o and math.max(o, 1) or 1
	d = d and math.max(d, 1) or 2
	-- Create unordered set of perlin noise slider classes
	newInst.perlinSet = {}
	newInst.Z = math.floor((s or u_rndReal()) * newInst.M)
	for i = 1, o do
		newInst.perlinSet[i] = SliderPerlin:new(p, a, nil, t or 1, newInst:randLCG())
		p, a = p / d, a / d
	end
	newInst:setYOffset(y)
	newInst.value = 0

	return newInst
end

-- Sets all perlin sliders to the same timescale
function SliderNoise:setTimescale(t)
	if self.perlinSet then
		for k, v in pairs(self.perlinSet) do
			v:setTimescale(t)
		end
	end
end

-- Gets the timescale of the first perlin slider
function SliderNoise:getTimescale() if self.perlinSet then return self.perlinSet[1]:getTimescale() end end

function SliderNoise:step(mFrameTime)
	if self.perlinSet then
		sum = 0
		for k, v in pairs(self.perlinSet) do
			v:step(mFrameTime)
			sum = sum + v:getValue()
		end
		self.value = sum + self.yOffset
	end
end

function Slider:printSliderInfo()
	u_log('==============')
	u_log('Y-Offset: ' .. self:getYOffset())
	u_log('Octaves: ' .. #self.perlinSet)
	u_log('Timescale' .. self:getTimescale())
	u_log('Value: ' .. self:getValue())
end




-- Target Slider
-- Tracks towards a target value with an easing function
SliderTarget = {}

-- Creates new Target Slider
-- <dur> Easing duration. The time it takes to reach a new target value
-- <ease> Easing function. Must be a function that accepts a value from [0,1] and returns a value from [0,1]
-- <start> Starting value. This is only set once per class
-- <t> Timescale.
function SliderTarget:new(dur, ease, start, t, func)
	local newInst = {}
	setmetatable(newInst, {__index = self})

	start = start or 0
	newInst.start = start
	newInst.target = start
	newInst.x = 1
	newInst:setDuration(dur)
	newInst:setEaseFunction(ease)
	newInst:setValue(start)
	newInst:setTimescale(t)
	newInst:setFunction(func)

	return newInst
end

function SliderTarget:setDuration(dur) self.duration = dur and dur > 0 and dur or 1 end

function SliderTarget:getDuration() return self.duration end

function SliderTarget:setTimescale(t) self.timescale = t and math.max(t, 0) or 1 end

function SliderTarget:getTimescale() return self.timescale end

function SliderTarget:setEaseFunction(ease) self.ease = type(ease) == 'function' and ease or function(x) return x end end

function SliderTarget:getEaseFunction() return self.ease end

function SliderTarget:setFunction(func) self.func = type(func) == 'function' and func or function() end end

function SliderTarget:getFunction() return self.func end

-- Sets the value of the slider and freezes the slider
function SliderTarget:setValue(v)
	self.x = 1
	v = v or 0
	self.value = v
	self.target = v
end

function SliderTarget:getValue() return self.value end

-- Sets a new target value and allows the animation to continue
-- If the target value is the same as the current, does nothing
-- If the new target value equals the current value, immediately stops the slider at that position
function SliderTarget:newTarget(target)
	if target ~= self.target then
		self.target = target
		self.start = self.value
		self.x = target == self.value and 1 or 0
	end
end

-- Advances the slider until target is reached
function SliderTarget:step(mFrameTime, ...)
	if self.x < 1 then
		self.x = self.x + mFrameTime / FPS / self.duration * self.timescale
		if self.x > 1 then
			self.x = 1
			self.func(...)
		end
		self.value = lerp(self.start, self.target, self.ease(self.x))
	end
end