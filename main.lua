local Shared = require("shared") 
local mode = nil
local serverInstance = nil
local clientInstance = nil

function love.load()
    love.window.setTitle("Compensazione della Latenza e Ottimizzazione dati trasmessi")
    
    love.window.setMode(Shared.WORLD_WIDTH, Shared.WORLD_HEIGHT, {
        resizable = true, 
        minwidth = Shared.WORLD_WIDTH,  
        minheight = Shared.WORLD_HEIGHT
    })
    
    math.randomseed(os.time())
end

function love.update(dt)
    if serverInstance then serverInstance:update(dt) end
    if clientInstance then clientInstance:update(dt) end
end

function love.draw()
    if not mode then
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        love.graphics.print("PREMI [S] PER ATTIVARE IL SERVER", w/2 - 100, h/2 - 30)
        love.graphics.print("PREMI [C] PER ATTIVARE IL CLIENT", w/2 - 100, h/2)
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("PREMI [F] PER ATTIVARE SERVER E CLIENT INSIEME", w/2 - 150, h/2 + 40)
        love.graphics.setColor(1, 1, 1)
    else
        if serverInstance then serverInstance:draw() end
        if clientInstance then clientInstance:draw() end
    end
end

function love.keypressed(key)
    if not mode then
        if key == 's' then
            mode = "server"
            serverInstance = require("server").new(25565)
            love.window.setTitle("Server")
        elseif key == 'c' then
            mode = "client"
            clientInstance = require("client").new("127.0.0.1", 25565)
            love.window.setTitle("Client")
        elseif key == 'f' then
            mode = "both"
            serverInstance = require("server").new(25565)
            clientInstance = require("client").new("127.0.0.1", 25565)
        end
    else
        if clientInstance then
            if key == 'e' then clientInstance.isCheating = true end
            if key == 'q' then clientInstance.isCheating = false end
            if key == 'r' then 
                clientInstance.prediction.reconciliationEnabled = not clientInstance.prediction.reconciliationEnabled 
            end
            if key == 'f9' then 
                clientInstance.showVector = not clientInstance.showVector  
            end
        end
    end
end