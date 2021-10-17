local Timer = {}
Timer.__index = Timer

function Timer:setFunction(fn) self.fn = type(fn) == 'function' and fn or function() end end

function Timer:getFunction() return self.fn end

function Timer:setTimescale(t) self.timescale = type(t) == 'number' and math.max(t, 0) or 1 end

function Timer:getTimescale() return self.timescale end




-- Periodic Timer
-- Runs a function at set intervals
TimerPeriodic = setmetatable({}, Timer)
TimerPeriodic.__index = TimerPeriodic

-- <dur> Seconds between function calls
-- <fn> Timer function
-- <noInstantRun> Set to true to disable the first timer call
-- <t> Timescale
function TimerPeriodic:new(dur, fn, noInstantRun, t)
	local newInst = setmetatable({}, self)

	newInst.x = noInstantRun and 0 or 1
	newInst:setDuration(dur)
	newInst:setFunction(fn)
	newInst:setTimescale(t)

	return newInst
end

function TimerPeriodic:setDuration(dur) self.duration = type(dur) == 'number' and dur > 0 and dur or 1 end

function TimerPeriodic:getDuration() return self.duration end

-- Resets the timer cycle. If noInstantRun is false or nil, the timer function will be immedietly run (assuming the step function is also being consistently called)
function TimerPeriodic:reset(noInstantRun) self.x = noInstantRun and 0 or 1 end

-- Extra parameters can be passed to the step function
-- Step function will return anything that the assigned function returns
function TimerPeriodic:step(mFrameTime, ...)
	self.x = self.x + clamp(mFrameTime / FPS / self.duration * self.timescale, 0, 1)
	if self.x >= 1 then
		self.x = self.x - 1
		return self.fn(...)
	end
end



-- Delay Timer
-- Runs a function after a delay
TimerDelay = setmetatable({}, Timer)
TimerDelay.__index = TimerDelay

-- <delay> Delay value. If set, class will automatically trigger a new delay event. If nil or <= 0, class will wait for a newDelay call
-- <fn> Function to run
-- <t> Timescale
-- <noInstantRun> Set to true to disable running the delay immedietly when created. Useful for disabling this behavior even when the delay value is set, This value is ignored if delay is nil

function TimerDelay:new(delay, fn, t, noInstantRun)
	local newInst = setmetatable({}, self)

	newInst:setFunction(fn)
	if type(delay) == 'number' then
		newInst.delay = math.max(delay, 0)
		newInst.x = noInstantRun and 1 or 0
	else
		newInst.delay = 0
		newInst.x = 1
	end
	newInst:setTimescale(t)

	return newInst
end

-- <delay> If delay > 0, will wait that amount of time before running the function. If delay <= 0, will run the function immedietly. If nil, will repeat the last delay amount

function TimerDelay:newDelay(delay)
	if type(delay) == 'number' then self.delay = math.max(delay, 0) end
	self.x = 0
end

-- Extra parameters can be passed to the step function
-- Step function will return anything that the assigned function returns
function TimerDelay:step(mFrameTime, ...)
	if self.x < 1 then
		if self.delay == 0 then
			self.x = 1
			return self.fn(...)
		end
		self.x = self.x + mFrameTime / FPS / self.delay * self.timescale
		if self.x > 1 then self.x = 1 end
		if self.x == 1 then return self.fn(...) end
	end
end





TimerTick = setmetatable({}, Timer)
TimerTick.__index = TimerTick

function TimerTick:new(tps, fn)
	local newInst = setmetatable({t = 0}, self)

	newInst:setTps(tps)
	newInst:setFunction(fn)

	return newInst
end

function TimerTick:setTps(tps)
	self.ft = type(tps) == 'number' and FPS / tps or 1
end
function TimerTick:getTps()
	return FPS / self.ft
end

function TimerTick:step(mFrameTime, ...)
	self.t = self.t + mFrameTime
	while self.t - self.ft > 0 do
		self.fn(self.ft, ...)
		self.t = self.t - self.ft
	end
end