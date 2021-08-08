-- Periodic Timer
-- Runs a function at set intervals
TimerPeriodic = {}
TimerPeriodic.__index = TimerPeriodic

-- <dur> Seconds between function calls
-- <func> Timer function
-- <noInstantRun> Set to true to disable the first timer call
-- <t> Timescale
function TimerPeriodic:new(dur, func, noInstantRun, t)
	local newInst = {}
	setmetatable(newInst, self)

	newInst.x = noInstantRun and 0 or 1
	newInst:setDuration(dur)
	newInst:setFunction(func)
	newInst:setTimescale(t)

	return newInst
end

function TimerPeriodic:setDuration(dur) self.duration = dur and dur > 0 and dur or 1 end

function TimerPeriodic:getDuration() return self.duration end

function TimerPeriodic:setFunction(func) self.func = type(func) == 'function' and func or function() end end

function TimerPeriodic:getFunction() return self.func end

function TimerPeriodic:setTimescale(t) self.timescale = t and math.max(t, 0) or 1 end

function TimerPeriodic:getTimescale() return self.timescale end

-- Resets the timer cycle. If noInstantRun is false or nil, the timer function will be immedietly run (assuming the step function is also being consistently called)
function TimerPeriodic:reset(noInstantRun) self.x = noInstantRun and 0 or 1 end

-- Extra parameters can be passed to the step function
-- Step function will return anything that the assigned function returns
function TimerPeriodic:step(mFrameTime, ...)
	self.x = self.x + clamp(mFrameTime / FPS / self.duration * self.timescale, 0, 1)
	if self.x >= 1 then
		self.x = self.x - 1
		return self.func(...)
	end
end



-- Delay Timer
-- Runs a function after a delay
TimerDelay = {}
TimerDelay.__index = TimerDelay

-- <delay> Delay value. If set, class will automatically trigger a new delay event. If nil or <= 0, class will wait for a newDelay call
-- <func> Function to run
-- <t> Timescale
-- <noInstantRun> Set to true to disable running the delay immedietly when created. Useful for disabling this behavior even when the delay value is set, This value is ignored if delay is nil

function TimerDelay:new(delay, func, t, noInstantRun)
	local newInst = {}
	setmetatable(newInst, self)

	newInst:setFunction(func)
	if delay then
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
	if delay then self.delay = math.max(delay, 0) end
	self.x = 0
end

function TimerDelay:setFunction(func) self.func = type(func) == 'function' and func or function() end end

function TimerDelay:getFunction() return self.func end

function TimerDelay:setTimescale(t) self.timescale = t and math.max(t, 0) or 1 end

function TimerDelay:getTimescale() return self.timescale end

-- Extra parameters can be passed to the step function
-- Step function will return anything that the assigned function returns
function TimerDelay:step(mFrameTime, ...)
	if self.x < 1 then
		if self.delay == 0 then
			self.x = 1
			return self.func(...)
		end
		self.x = self.x + mFrameTime / FPS / self.delay * self.timescale
		if self.x > 1 then self.x = 1 end
		if self.x == 1 then return self.func(...) end
	end
end