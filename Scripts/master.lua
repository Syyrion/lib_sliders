if __SLIDERS_MASTER_IMPORTED then return end
__SLIDERS_MASTER_IMPORTED = true

u_execDependencyScript("library_extbase", "extbase", "syyrion", "utils.lua")

local __FUNCTION = {
	fn = function (...) end
}
__FUNCTION.__index = __FUNCTION

function __FUNCTION:setFunction(fn) self.fn = type(fn) == 'function' and fn or nil end
function __FUNCTION:getFunction() return self.fn end

local __TIME = setmetatable({
	period = 1,
	timescale = 1
}, __FUNCTION)
__TIME.__index = __TIME

function __TIME:setPeriod(p) self.period = type(p) == 'number' and p > 0 and p or nil end
function __TIME:getPeriod() return self.period end

function __TIME:setTimescale(t) self.timescale = type(t) == 'number' and math.max(t, 0) or nil end
function __TIME:getTimescale() return self.timescale end

function __TIME:advance(mFrameTime)
	self.progress = self.progress + clamp(mFrameTime / FPS / self.period * self.timescale, 0, 1)
end



-- RateTimer
-- Similar to periodic timer but meant for modifying the tickrate of the game from its default 240 tps
TimerRate = setmetatable({
	threshold = 0.25
}, __FUNCTION)
TimerRate.__index = TimerRate

function TimerRate:new(hz, fn)
	local newInst = setmetatable({
		progress = 0
	}, self)
	newInst:setRate(hz)
	newInst:setFunction(fn)
	return newInst
end

function TimerRate:setRate(hz) self.threshold = type(hz) == 'number' and hz > 0 and (FPS / hz) or nil end
function TimerRate:getRate() return FPS / self.threshold end

function TimerRate:step(mFrameTime, ...)
	self.progress = self.progress + mFrameTime
	while self.progress >= self.threshold do
		self.progress = self.progress - self.threshold
		self.fn(self.threshold, ...)
	end
end



-- Delay Timer
-- Runs a function after a delay
TimerDelay = setmetatable({
	period = 0
}, __TIME)
TimerDelay.__index = TimerDelay

-- <delay> Delay value. If set, class will automatically trigger a new delay event. If nil or <= 0, class will wait for a newDelay call
-- <fn> Function to run
-- <t> Timescale
-- <noInstantRun> Set to true to disable running the delay immedietly when created. Useful for disabling this behavior even when the delay value is set, This value is ignored if delay is nil
function TimerDelay:new(delay, fn, t, noInstantRun)
	local newInst = setmetatable({
		progress = 0,
		running = not noInstantRun
	}, self)
	newInst:setPeriod(delay)
	newInst:setFunction(fn)
	newInst:setTimescale(t)
	return newInst
end

-- Override setPeriod to allow a period to equal 0
function TimerDelay:setPeriod(p) self.period = type(p) == 'number' and math.max(p, 0) or nil end

-- <delay> If delay > 0, will wait that amount of time before running the function.
-- If delay <= 0 or nil, will run the function immedietly
function TimerDelay:newDelay(delay)
	self:setPeriod(delay)
	self.running = true
end

-- Stops the timer.
function TimerDelay:stop() self.progress, self.running = 0, false end

-- Extra parameters can be passed to the step function
-- Step function will return anything that the assigned function returns
function TimerDelay:step(mFrameTime, ...)
	if self.running then
		local FN = function (...)
			self:stop()
			return self.fn(...)
		end
		if self.period == 0 then return FN(...) end
		self:advance(mFrameTime)
		if self.progress >= 1 then return FN(...) end
	end
end




-- Periodic Timer
-- Runs a function at set intervals
TimerPeriodic = setmetatable({}, __TIME)
TimerPeriodic.__index = TimerPeriodic

-- <p> Seconds between function calls
-- <fn> Timer function
-- <noInstantRun> Set to true to disable the first timer call
-- <t> Timescale
function TimerPeriodic:new(p, fn, noInstantRun, t)
	local newInst = setmetatable({
		progress = noInstantRun and 0 or 1
	}, self)
	newInst:setPeriod(p)
	newInst:setFunction(fn)
	newInst:setTimescale(t)
	return newInst
end

-- Resets the timer cycle. If noInstantRun is false or nil, the timer function will be immedietly run (assuming the step function is also being consistently called)
function TimerPeriodic:reset(noInstantRun) self.progress = noInstantRun and 0 or 1 end

-- Extra parameters can be passed to the step function
-- Step function will return anything that the assigned function returns
function TimerPeriodic:step(mFrameTime, ...)
	self:advance(mFrameTime)
	if self.progress >= 1 then
		self.progress = self.progress - 1
		return self.fn(...)
	end
end




-- Inherits from __TIME
local __VALUE = setmetatable({
	value = 0
}, __TIME)
__VALUE.__index = __VALUE

function __VALUE:setValue(v) self.value = type(v) == 'number' and v or nil end
function __VALUE:getValue() return self.value end




SliderTarget = setmetatable({
	ease = function (x) return x end
}, __VALUE)
SliderTarget.__index = SliderTarget

function SliderTarget:new(p, ease, start, t, fn)
	start = type(start) == 'number' and start or 0
	local newInst = setmetatable({
		progress = 0,
		running = false
	}, self)
	newInst:setPeriod(p)
	newInst:setEaseFunction(ease)
	newInst:setValue(start)
	newInst:setTimescale(t)
	newInst:setFunction(fn)
	return newInst
end

function SliderTarget:setEaseFunction(ease) self.ease = type(ease) == 'function' and ease or nil end
function SliderTarget:getEaseFunction() return self.ease end

-- Sets the value of the slider and freezes the slider
function SliderTarget:setValue(v)
	v = type(v) == 'number' and v or 0
	self.running, self.value, self.target = false, v, v
end

-- Sets a new target value and allows the animation to continue
-- If the target value is the same as the current, does nothing
-- If the new target value equals the current value, immediately stops the slider at that position
function SliderTarget:newTarget(target)
	if target ~= self.target then
		self.target = target
		self.start = self.value
		self.running = target ~= self.value
	end
end

-- Stops the slider. The value remains at its current position.
function SliderTarget:stop() self.progress, self.running = 0, false end

-- Advances the slider until target is reached
function SliderTarget:step(mFrameTime, ...)
	if self.running then
		local FN = function () self.value = lerp(self.start, self.target, self.ease(self.progress)) end
		self:advance(mFrameTime)
		if self.progress >= 1 then
			self.progress = 1
			FN()
			self:stop()
			return self.fn(...)
		end
		FN()
	end
end




-- Base slider class
local __YAXIS = setmetatable({}, __VALUE)
__YAXIS.__index = __YAXIS

function __YAXIS:setAmplitude(a) self.amplitude = type(a) == 'number' and a or 1 end

function __YAXIS:getAmplitude() return self.amplitude end

function __YAXIS:setYOffset(y) self.yOffset = type(y) == 'number' and y or 0 end

function __YAXIS:getYOffset() return self.yOffset end




-- Simple Perlin noise slider
SliderPerlin = setmetatable({}, __YAXIS)
SliderPerlin.__index = SliderPerlin

-- Values for the LCG
SliderPerlin.M, SliderPerlin.A, SliderPerlin.C = 4294967296, 1664525, 1

-- <p> Period. The amount of time between critical points in seconds.
-- <a> Amplitude. Range of values is equivalent to [-A, A].
-- <y> Y-Offset.
-- <t> Timescale.
-- <s> Seed value. Must be a number between 0 and 1. Seed can only be set once for a slider.
-- Passing nothing for a parameter will set the parameter to it's default
function SliderPerlin:new(p, a, y, t, s, fn)
	local newInst = setmetatable({
		value = 0,
		progress = 0
	}, self)
	newInst:setPeriod(p)
	newInst:setAmplitude(a)
	newInst:setYOffset(y)
	newInst:setTimescale(t)
	newInst:setFunction(fn)
	newInst.Z = math.floor((s or u_rndReal()) * newInst.M)
	newInst.yBegin = newInst.amplitude * (newInst:randLCG() * 2 - 1) + newInst.yOffset
	newInst.yEnd = newInst.amplitude * (newInst:randLCG() * 2 - 1) + newInst.yOffset
	return newInst
end

-- Updates slider to the next value
function SliderPerlin:step(mFrameTime, ...)
	local FN = function () self.value = lerp(self.yBegin, self.yEnd, easeInOutSine(self.progress / self.period)) end
	self:advance(mFrameTime, ...)
	if self.progress >= self.period then
		self:next()
		self.progress = self.progress - self.period
		FN()
		return self.fn(...)
	end
	FN()
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




local __WAVE = setmetatable({
	phase = 0
}, __YAXIS)
__WAVE.__index = __WAVE

function __WAVE:new(p, a, y, x, t, fn)
	local newInst = setmetatable({
		progress = 0,
		value = 0
	}, self)
	newInst:setPeriod(p)
	newInst:setAmplitude(a)
	newInst:setYOffset(y)
	newInst:setXOffset(x)
	newInst:setTimescale(t)
	newInst:setFunction(fn)
	return newInst
end
-- Override timescale to allow negative numbers
function __WAVE:setTimescale(t) self.timescale = type(t) == 'number' and t or nil end
-- Set raw phase value.
function __WAVE:setRawOffset(x) self.phase = type(x) == 'number' and x or nil end
function __WAVE:getRawOffset() return self.phase end
-- Set phase by degrees.
function __WAVE:setPhase(x) self.phase = type(x) == 'number' and x / 360 or nil end
function __WAVE:getPhase() return self.phase * 360 end
-- Set phase relative to period (default).
function __WAVE:setXOffset(x) self.phase = type(x) == 'number' and x / self.period or nil end
function __WAVE:getXOffset() return self.phase * self.period end

function __WAVE:advance(mFrameTime, ...)
	self.progress = self.progress + clamp(mFrameTime / FPS / self.period * self.timescale, -1, 1)
	if self.progress > 1 then
		self.progress = self.progress - 1
		return self.fn(...)
	elseif  self.progress < 0 then
		self.progress = self.progress + 1
		return self.fn(...)
	end
end

SliderSquare = setmetatable({
	dutyCycle = 0.5
}, __WAVE)
SliderSquare.__index = SliderSquare

function SliderSquare:setDutyCycle(d) self.dutyCycle = type(d) == 'number' and clamp(d, 0, 1) or nil end
function SliderSquare:getDutyCycle() return self.dutyCycle end

function SliderSquare:step(mFrameTime, ...)
	local out = {self:advance(mFrameTime, ...)}
	self.value = self.amplitude * squareWave(self.progress - self.phase, 1, self.dutyCycle) + self.yOffset
	return unpack(out)
end

SliderTriangle = setmetatable({}, __WAVE)
SliderTriangle.__index = SliderTriangle

function SliderTriangle:step(mFrameTime, ...)
	local out = {self:advance(mFrameTime, ...)}
	self.value = self.amplitude * triangleWave(self.progress - self.phase, 1) + self.yOffset
	return unpack(out)
end

SliderSawtooth = setmetatable({}, __WAVE)
SliderSawtooth.__index = SliderSawtooth

function SliderSawtooth:step(mFrameTime, ...)
	local out = {self:advance(mFrameTime, ...)}
	self.value = self.amplitude * sawtoothWave(self.progress - self.phase, 1) + self.yOffset
	return unpack(out)
end

SliderSine = setmetatable({}, __WAVE)
SliderSine.__index = SliderSine

function SliderSine:step(mFrameTime, ...)
	local out = {self:advance(mFrameTime, ...)}
	self.value = self.amplitude * math.sin(math.tau * (self.progress - self.phase)) + self.yOffset
	return unpack(out)
end