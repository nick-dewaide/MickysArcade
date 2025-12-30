local function dartPositionAtTimeApex(magnitude, boardDist, t, gravity, startPos)
    gravity  = gravity or 980
    startPos = startPos or { x = 0, y = 0, z = 0 }

    -- Horizontal direction toward the board plane (x,z); use sway offset directly
    local dx = magnitude.x
    local dz = boardDist
    local horizLen = math.sqrt(dx * dx + dz * dz)
    if horizLen == 0 then
        return { x = startPos.x, y = startPos.y, z = startPos.z }
    end

    -- Horizontal velocities scaled by forward power (magnitude.z)
    local vx = (dx / horizLen) * magnitude.z
    local vz = (dz / horizLen) * magnitude.z

    -- Map tilt (magnitude.y in [-50,50]) to apex height (pixels)
    -- More negative tilt => higher arc
    local baseApex   = 10
    local apexScale  = 2.0
    local apexHeight = math.max(0, baseApex + (-magnitude.y) * apexScale)
    local vy = -math.sqrt(2 * gravity * apexHeight)

    -- Position at time t
    local x = startPos.x + vx * t
    local y = startPos.y + vy * t + 0.5 * gravity * t * t
    local z = startPos.z + vz * t

    return { x = x, y = y, z = z }
end


-- UI config
local powerMin, powerMax = 0, 100      -- power 0..100
local swayRange          = 50          -- magnitude.x in [-50, +50]
local tiltRange          = 50          -- magnitude.y in [-50, +50]
local powerSpeed         = 1.1
local swaySpeed          = 1.4
local tiltSpeed          = 1.2

-- Game/state vars
local boardDist     = 500
local gravityVal    = 980
local throwMagnitude = { x = 0, y = 0, z = 0 }
local throwPos      = { x = 0, y = 0, z = 0 }
local throwActive   = false
local throwTime     = 0
local stuckActive   = false
local stuckTime     = 0
local stuckDuration = 3.0
local stuckPos      = { x = 0, y = 0, z = 0 }
local startPos      = { x = 0, y = 0, z = 0 }
local micky         = nil
-- Input stages: power -> sway -> tilt -> throw
local inputStage = "idle"
local powerVal   = 0
local swayVal    = 0
local tiltVal    = 0
local uiTime     = 0

-- UI config
local powerMin, powerMax = 300, 900
local swayRange          = 120   -- magnitude.x will be in [-swayRange, +swayRange]
local tiltMax            = 140   -- apex height at extremes; near center => low apex
local powerSpeed         = 0.7   -- osc speed (Hz-ish)
local swaySpeed          = 0.5
local tiltSpeed          = 0.6


local sprite_scale = 0.5
-- Set a reasonable start position after we know the window size
function love.load()
    print("load my balls")
    micky = love.graphics.newImage("micky.jpeg")
    love.graphics.setDefaultFilter("nearest", "nearest")
    local winW = micky:getWidth()  * sprite_scale
    local winH = micky:getHeight() * sprite_scale
    love.window.setMode(winW, winH, { resizable = false, vsync = true })
    startPos = { x = winW * 0.5, y = winH - 40, z = 0 }
end

throwMagnitude = {}
boardDist = 500
throwTime = 0


function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    if throwActive or stuckActive then return end

    if inputStage == "idle" then
        -- Capture origin where the player clicked
        startPos = { x = x, y = y, z = 0 }
        inputStage = "power"
        uiTime = 0

    elseif inputStage == "power" then
        local osc = (math.sin(uiTime * powerSpeed * math.pi * 2) * 0.5 + 0.5)
        powerVal = powerMin + osc * (powerMax - powerMin)
        inputStage = "sway"
        uiTime = 0

    elseif inputStage == "sway" then
        local osc = math.sin(uiTime * swaySpeed * math.pi * 2) -- -1..1
        swayVal = osc * swayRange
        inputStage = "tilt"
        uiTime = 0

    elseif inputStage == "tilt" then
        local osc = math.sin(uiTime * tiltSpeed * math.pi * 2) -- -1..1
        -- magnitude.y in [-tiltRange, +tiltRange], negative => higher arc
        tiltVal = osc * tiltRange

        -- Commit throw
        throwMagnitude.z = powerVal
        throwMagnitude.x = swayVal
        throwMagnitude.y = tiltVal
        throwActive = true
        throwTime   = 0
        throwPos    = { x = startPos.x, y = startPos.y, z = startPos.z }
        stuckActive = false
        inputStage  = "idle"
    end
end

stuckDuration = 3.0

function love.update(dt)
    uiTime = uiTime + dt

    if throwActive then
        throwTime = throwTime + dt
        throwPos = dartPositionAtTimeApex(throwMagnitude, boardDist, throwTime, gravityVal, startPos)

        if throwPos.z >= boardDist then
            throwActive = false
            stuckActive = true
            stuckTime   = 0
            stuckPos    = { x = throwPos.x, y = throwPos.y, z = boardDist }
        end
    elseif stuckActive then
        stuckTime = stuckTime + dt
        if stuckTime >= stuckDuration then
            stuckActive = false
        end
    end
end

function love.draw()
    love.graphics.draw(micky, 0, 0, 0, spriteScale, spriteScale)

    -- Active flight
    if throwActive then
        local zRatio = math.min(1, throwPos.z / boardDist)
        local baseRadius  = 10
        local startBoost  = 4
        local minRadius   = 2
        local radius = math.max(minRadius, baseRadius * (1 - zRatio) + startBoost * (1 - zRatio))
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", throwPos.x, throwPos.y, radius)
        love.graphics.setColor(1, 1, 1)
    end

    -- Stuck on board
    if stuckActive then
        local dotRadius = 6
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", stuckPos.x, stuckPos.y, dotRadius)
        local pulseFreq = 6
        local pulseAmp  = 4
        local baseRing  = 14
        local pulse     = math.sin(stuckTime * pulseFreq) * pulseAmp
        local ringR     = baseRing + pulse
        local flash     = 0.6 + 0.4 * math.abs(math.sin(stuckTime * pulseFreq))
        love.graphics.setColor(1, 1, 0, flash)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", stuckPos.x, stuckPos.y, ringR)
        love.graphics.setColor(1, 1, 1)
    end

    -- UI bars
    local w, h = love.graphics.getDimensions()
    local centerX = w * 0.5
    local uiTop = 30
    local barW, barH = 220, 16
    local pad = 28

    if inputStage == "power" then
        local osc = (math.sin(uiTime * powerSpeed * math.pi * 2) * 0.5 + 0.5)
        local fill = osc * barW
        love.graphics.setColor(0.12, 0.12, 0.12, 0.9)
        love.graphics.rectangle("line", centerX - barW/2, uiTop, barW, barH)
        -- ticks
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        for i = 0, 10 do
            local xTick = centerX - barW/2 + i * (barW/10)
            love.graphics.line(xTick, uiTop, xTick, uiTop + barH)
        end
        -- fill
        love.graphics.setColor(0.3, 0.8, 0.3, 0.9)
        love.graphics.rectangle("fill", centerX - barW/2, uiTop, fill, barH)
        -- marker
        love.graphics.setColor(1, 1, 1, 0.9)
        local markerX = centerX - barW/2 + fill
        love.graphics.line(markerX, uiTop - 3, markerX, uiTop + barH + 3)
        -- percent text
        love.graphics.print(string.format("Power: %d", math.floor(powerMin + osc * (powerMax - powerMin) + 0.5)), centerX - 50, uiTop + barH + 6)

    elseif inputStage == "sway" then
        local osc = math.sin(uiTime * swaySpeed * math.pi * 2) -- -1..1
        local pos = osc * (barW/2 - 6)
        love.graphics.setColor(0.12, 0.12, 0.12, 0.9)
        love.graphics.rectangle("line", centerX - barW/2, uiTop + pad, barW, barH)
        -- center highlight
        love.graphics.setColor(0.9, 0.9, 0.2, 0.25)
        love.graphics.rectangle("fill", centerX - 10, uiTop + pad, 20, barH)
        love.graphics.setColor(0.3, 0.5, 0.9, 0.9)
        love.graphics.rectangle("fill", centerX + pos - 6, uiTop + pad, 12, barH)
        love.graphics.setColor(1,1,1)
        love.graphics.print("Sway (center = steady)", centerX - 70, uiTop + pad + barH + 6)

    elseif inputStage == "tilt" then
        -- vertical bar on the right
        local barX = w - 60
        local barY = uiTop
        local barHvert = 160
        local osc = math.sin(uiTime * tiltSpeed * math.pi * 2) -- -1..1
        local pos = osc * (barHvert/2 - 8)
        love.graphics.setColor(0.12, 0.12, 0.12, 0.9)
        love.graphics.rectangle("line", barX, barY, barH, barHvert)
        -- center highlight
        love.graphics.setColor(0.9, 0.9, 0.2, 0.25)
        love.graphics.rectangle("fill", barX, barY + barHvert/2 - 10, barH, 20)
        -- thumb
        love.graphics.setColor(0.9, 0.5, 0.3, 0.9)
        love.graphics.rectangle("fill", barX, barY + barHvert/2 + pos - 8, barH, 16)
        -- arrows: negative tilt (up) => higher arc; positive => lower
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.polygon("fill", barX + barH/2, barY - 10, barX + 6, barY + 6, barX + barH - 6, barY + 6) -- up arrow
        love.graphics.polygon("fill", barX + barH/2, barY + barHvert + 10, barX + 6, barY + barHvert - 6, barX + barH - 6, barY + barHvert - 6) -- down arrow
        love.graphics.print("Tilt (up = higher arc)", barX - 80, barY + barHvert + 12)
    end
end