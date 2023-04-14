--[[
    Precision variable control for Open Hexagon.
    https://github.com/vittorioromeo/SSVOpenHexagon

    Copyright (C) 2021 Ricky Cui

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <https://www.gnu.org/licenses/>.

    Email: cuiricky4@gmail.com
    GitHub: https://github.com/Syyrion
]]

u_execDependencyScript("library_extbase", "extbase", "syyrion", "utils.lua")

local __FUNCTION = {
    fn = function (...) end
}
__FUNCTION.__index = __FUNCTION

function __FUNCTION:setFunction(fn) self.fn = type(fn) == 'function' and fn or nil end
function __FUNCTION:getFunction() return self.fn end



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
        if self.period == 0 then
            self:stop()
            self.fn(...)
        elseif self.progress < 1 then
            self:advance(mFrameTime)
            if self.progress >= 1 then
                self:stop()
                self.fn(...)
            end
        end
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
        self.fn(...)
    end
end




-- Inherits from __TIME
local __VALUE = setmetatable({
    value = 0
}, __TIME)
__VALUE.__index = __VALUE

function __VALUE:setValue(v) self.value = type(v) == 'number' and v or nil end
function __VALUE:getValue() return self.value end

local __EASE = setmetatable({
    ease = function (x) return x end
}, __VALUE)
__EASE.__index = __EASE

function __EASE:setEaseFunction(ease) self.ease = type(ease) == 'function' and ease or nil end
function __EASE:getEaseFunction() return self.ease end



SliderTarget = setmetatable({}, __EASE)
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
        self.progress = 0
        self.running = target ~= self.value
    end
end

-- Stops the slider. The value remains at its current position.
function SliderTarget:stop() self.running = false end

-- Advances the slider until target is reached
function SliderTarget:step(mFrameTime, ...)
    if self.running then
        self:advance(mFrameTime)
        if self.progress >= 1 then
            self.progress = 1
            self.running = false
            self.fn(...)
        end
        self.value = lerp(self.start, self.target, self.ease(self.progress))
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
    self:advance(mFrameTime)
    if self.progress >= 1 then
        self.progress = self.progress - 1
        self:next()
        self.fn(...)
    end
    self.value = lerp(self.yBegin, self.yEnd, easeInOutSine(self.progress))
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
        self.fn(...)
    elseif  self.progress < 0 then
        self.progress = self.progress + 1
        self.fn(...)
    end
end

function __WAVE:step(mFrameTime, ...)
    self:advance(mFrameTime, ...)
    self.value = self.amplitude * self.wave(self.progress - self.phase) + self.yOffset
end

SliderSquare = setmetatable({
    dutyCycle = 0.5,
    wave = Wave.square
}, __WAVE)
SliderSquare.__index = SliderSquare

function SliderSquare:setDutyCycle(d) self.dutyCycle = type(d) == 'number' and d or nil end
function SliderSquare:getDutyCycle() return self.dutyCycle end

function SliderSquare:step(mFrameTime, ...)
    self:advance(mFrameTime, ...)
    self.value = self.amplitude * self.wave(self.progress - self.phase, self.dutyCycle) + self.yOffset
end

SliderTriangle = setmetatable({
    asymmetry = 0.5,
    wave = Wave.triangle
}, __WAVE)
SliderTriangle.__index = SliderTriangle

function SliderTriangle:setAsymmetry(d) self.asymmetry = type(d) == 'number' and d or nil end
function SliderTriangle:getAsymmetry() return self.asymmetry end

function SliderTriangle:step(mFrameTime, ...)
    self:advance(mFrameTime, ...)
    self.value = self.amplitude * self.wave(self.progress - self.phase, self.asymmetry) + self.yOffset
end

SliderSawtooth = setmetatable({
    wave = Wave.sawtooth
}, __WAVE)
SliderSawtooth.__index = SliderSawtooth

SliderSine = setmetatable({
    wave = function (x) return math.sin(math.tau * x) end
}, __WAVE)
SliderSine.__index = SliderSine


local Event = setmetatable({
    period = 0,
    setPeriod = TimerDelay.setPeriod,
}, __EASE)
Event.__index = Event

function Event:setTimescale(t) self.timescale = type(t) == 'number' and t > 0 and t or nil end

function Event:new(period, value, fn, easing, timescale, ...)
    local newInst = setmetatable({
        progress = 0,
        args = {...}
    }, self)
    newInst.__index = newInst
    newInst:setPeriod(period)
    newInst:setValue(value)
    newInst:setFunction(fn)
    newInst:setEaseFunction(easing)
    newInst:setTimescale(timescale)
    return newInst
end

Keyframe = {
    value = 0,
    setValue = __VALUE.setValue,
    getValue = __VALUE.getValue,
    __mode = 'k'
}
Keyframe.__index = Keyframe

function Keyframe:setPeriod(period) self.principle:setPeriod(period) end
function Keyframe:getPeriod() return self.principle.period end
function Keyframe:setFunction(fn) self.principle:setFunction(fn) end
function Keyframe:getFunction() return self.principle.fn end
function Keyframe:setEaseFunction(easing) self.principle:setEaseFunction(easing) end
function Keyframe:getEaseFunction() return self.principle.ease end
function Keyframe:setTimescale(timescale) self.principle:setTimescale(timescale) end
function Keyframe:getTimescale() return self.principle.timescale end

function Keyframe:new(...)
    local newPrinciple = Event:new(...)
    local newEvent = newPrinciple:new()
    local newInst = setmetatable({
        principle = newPrinciple
    }, self)
    newInst.current = newEvent
    newInst.terminal = newEvent
    newInst.value = newInst.principle.value
    newInst[newEvent] = false
    return newInst
end

-- Creates a new event
function Keyframe:event(...)
    local newEvent = self.principle:new(...)
    self[self.terminal] = newEvent
    self[newEvent] = false
    self.terminal = newEvent
end

function Keyframe:eval(period, fn, ...)
    self:event(period, nil, fn, nil, nil, ...)
end

function Keyframe:node(period, value, easing)
    self:event(period, value, nil, easing)
end

function Keyframe:isRunning()
    return self.current ~= self.terminal
end

-- Creates events in bulk
function Keyframe:sequence(...)
    local t = {...}
    local len = #t
    for i = 1, len do
        if type(t[i]) == 'table' then
            self:event(unpack(t[i]))
        else
            errorf(2, 'Sequence', 'Argument #%d is not a table.', i)
        end
    end
end

function Keyframe:absolute(...)
    local t = {{0}, ...}
    local len = #t
    table.sort(t, function (a, b)
        return a[1] < b[1]
    end)
    local time = t[1][1]
    for i = 2, len do
        local rel = t[i][1] - time
        time = t[i][1]
        t[i][1] = rel
    end
    self:sequence(unpack(t, 2))
end

function Keyframe:step(mFrameTime)
    local currentEvent = self.current
    local nextEvent = self[currentEvent]
    if nextEvent then
        if nextEvent == 0 then nextEvent = 1
        elseif nextEvent.progress < 1 then nextEvent:advance(mFrameTime) end

        if nextEvent.progress >= 1 then
            local overflow = (nextEvent.progress - 1) / nextEvent.timescale
            repeat
                nextEvent.fn(unpack(nextEvent.args))
                self.current, currentEvent, nextEvent = nextEvent, nextEvent, self[nextEvent]
                if not nextEvent then
                    self.value = currentEvent.value
                    return
                end
            until nextEvent.period > 0
            nextEvent.progress = overflow * nextEvent.timescale
        end
        self.value = lerp(currentEvent.value, nextEvent.value, nextEvent.ease(nextEvent.progress))
    end
end

function Keyframe:clear()
    self.current = self.terminal
end