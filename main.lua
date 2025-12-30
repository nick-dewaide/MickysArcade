local micky =  nil

function love.load()
    micky = love.graphics.newImage("micky.jpeg")
    love.graphics.setDefaultFilter("nearest", "nearest")

    love.window.setMode(micky:getWidth(), micky:getHeight(), { resizable = false, vsync = true })
end

function love.update(dt)

end

function love.draw()
    love.graphics.draw(micky, 0, 0)
end