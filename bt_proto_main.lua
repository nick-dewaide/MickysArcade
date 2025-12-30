-- Configuration
local assets = require("assets")
local BOARD_Z = 600
local GRAVITY = 800
local DEV_MODE = false 

-- Assets
local imgBackground, imgBoard, imgDart

-- Game State
local state = "aiming"
local resultMessage = ""
local dart = {
    x = 0, y = 0, z = 0,
    vx = 0, vy = 0, vz = 0,
    scale = 1.0,
    power = 0
}

local board = { x = 0, y = 0, size = 200 }
local obstacle = {
    z = 300, baseX = 0, y = 0, 
    w = 150, h = 25, 
    currentX = 0, speed = 3, range = 200 
}

function love.load()
    -- Load using paths from assets.lua
    imgBackground = love.graphics.newImage(assets.background)
    imgBoard = love.graphics.newImage(assets.board)
    imgDart = love.graphics.newImage(assets.dart)

    local bgW, bgH = imgBackground:getDimensions()
    love.window.setMode(bgW, bgH)
    
    board.x, board.y = bgW / 2, bgH / 2
    obstacle.baseX, obstacle.y = bgW / 2, bgH * 0.6
    
    resetDart()
end

-- Refactored collision logic to allow for "Instant" Dev Mode impact
function checkImpact(finalX, finalY)
    -- Check Obstacle first (even in Dev Mode, it can be blocked)
    -- Note: In immediate dev mode, we check against the obstacle's current position
    local obsScale = 1 - (obstacle.z / (BOARD_Z * 1.5))
    local halfW = (obstacle.w * obsScale) / 2
    local halfH = (obstacle.h * obsScale) / 2
    
    -- For simplicity in dev mode, we assume the dart "passed" the obstacle Z
    if finalX > obstacle.currentX - halfW and finalX < obstacle.currentX + halfW and
       finalY > obstacle.y - halfH and finalY < obstacle.y + halfH then
        resultMessage = "BLOCKED!"
        return
    end

    -- Check Board
    local distToCenter = math.sqrt((finalX - board.x)^2 + (finalY - board.y)^2)
    if distToCenter < board.size / 4 then
        resultMessage = "BULLSEYE!"
    elseif distToCenter < board.size / 2 then
        resultMessage = "HIT!"
    else
        resultMessage = "MISSED!"
    end
end

function resetDart()
    state = "aiming"
    dart.z = 0
    dart.power = 0
    resultMessage = ""
end

function love.update(dt)
    obstacle.currentX = obstacle.baseX + math.sin(love.timer.getTime() * obstacle.speed) * obstacle.range

    if state == "aiming" or state == "charging" then
        dart.x, dart.y = love.mouse.getPosition()
        if state == "charging" then
            dart.power = math.min(dart.power + 500 * dt, 1200)
        end
    elseif state == "flying" then
        dart.z = dart.z + dart.vz * dt
        dart.x = dart.x + dart.vx * dt
        dart.y = dart.y + dart.vy * dt
        dart.vy = dart.vy + GRAVITY * dt
        dart.scale = math.max(0.2, 1 - (dart.z / (BOARD_Z * 1.5)))

        -- Check for obstacle mid-flight
        if math.abs(dart.z - obstacle.z) < 15 then
            local obsScale = 1 - (obstacle.z / (BOARD_Z * 1.5))
            if dart.x > obstacle.currentX - (obstacle.w * obsScale)/2 and 
               dart.x < obstacle.currentX + (obstacle.w * obsScale)/2 and
               dart.y > obstacle.y - (obstacle.h * obsScale)/2 and 
               dart.y < obstacle.y + (obstacle.h * obsScale)/2 then
                state = "result"
                resultMessage = "BLOCKED!"
            end
        end

        if dart.z >= BOARD_Z then
            state = "result"
            checkImpact(dart.x, dart.y)
        end
    end
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgBackground, 0, 0)

    -- Draw Board
    local bS = board.size / imgBoard:getWidth()
    love.graphics.draw(imgBoard, board.x, board.y, 0, bS, bS, imgBoard:getWidth()/2, imgBoard:getHeight()/2)

    -- Draw Obstacle
    local oS = 1 - (obstacle.z / (BOARD_Z * 1.5))
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", obstacle.currentX - (obstacle.w * oS)/2, obstacle.y - (obstacle.h * oS)/2, obstacle.w * oS, obstacle.h * oS)
    
    -- Draw Dart 
    -- Offset applied: Origin X is middle (width/2), Origin Y is bottom (height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgDart, dart.x, dart.y, 0, dart.scale, dart.scale, imgDart:getWidth()/2, imgDart:getHeight())

    -- Dev Mode Green Dot
    if DEV_MODE then
        love.graphics.setColor(0, 1, 0)
        love.graphics.circle("fill", love.mouse.getX(), love.mouse.getY(), 4)
    end

    -- UI
    love.graphics.setColor(1, 1, 1)
    if state == "charging" then
        love.graphics.rectangle("fill", 10, 10, (dart.power/1200) * 100, 20)
    elseif state == "result" then
        love.graphics.printf(resultMessage .. "\n'R' to Reset", 0, 50, love.graphics.getWidth(), "center")
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and state == "aiming" then state = "charging" end
end

function love.mousereleased(x, y, button)
    if button == 1 and state == "charging" then
        if DEV_MODE then
            -- Immediate Impact
            state = "result"
            checkImpact(x, y)
        else
            -- Physics Flight
            state = "flying"
            dart.vz = dart.power * 1.2
            dart.vy = -(dart.power * 0.35)
            dart.vx = 0
        end
    end
end

function love.keypressed(key)
    if key == "r" then resetDart() end
    if key == "d" then DEV_MODE = not DEV_MODE end
end