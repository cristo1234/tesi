local Network = require("network")
local Shared = require("shared")
local BitBuffer = require("bitbuffer")

local Server = {}
Server.__index = Server

function Server.new(port)
    local self = setmetatable({}, Server)
    self.net = Network.new(port, true)
    self.clients = {}
    self.tickTimer = 0
    
    self.net:onReceive(function(data, ip, port)
        local clientId = ip .. ":" .. port
        if not self.clients[clientId] then
            self.clients[clientId] = { 
                x = Shared.WORLD_WIDTH/2, 
                y = Shared.WORLD_HEIGHT/2, 
                lastSequence = 0, ip = ip, port = port, lastX = -1, lastY = -1 
            }
        end
        
        local client = self.clients[clientId]
        local dataReader = BitBuffer.fromString(data)
        local sequence = dataReader:readBits(16)
        local input = { left = dataReader:readBool(), right = dataReader:readBool(), up = dataReader:readBool(), down = dataReader:readBool() }
        
        -- SCARTIAMO INPUT NON IN SEQUENZA ( E.S UN PACCHETTO ARRIVATO IN RITARDO)
        if sequence > client.lastSequence then
            Shared.applyInput(client, input, Shared.TICK_RATE)
            client.lastSequence = sequence
        end
    end)
    return self
end

function Server:update(dt)
    self.net:update()
    
    self.tickTimer = self.tickTimer + dt
    while self.tickTimer >= Shared.TICK_RATE do
        self.tickTimer = self.tickTimer - Shared.TICK_RATE
        
        for _, client in pairs(self.clients) do
            local dataWriter = BitBuffer.new()
            dataWriter:writeBits(client.lastSequence, 16)
            
            -- CAPITOLO 3.4
            local moved = (math.abs(client.x - client.lastX) > 0.01) or (math.abs(client.y - client.lastY) > 0.01)
            dataWriter:writeBool(moved)
            
            -- CONTROLLIAMO SE C'E' STATO DAVVERO UN MOVIMENTO O STAREMMO SPRECANDO BYTE
            if moved then
                dataWriter:writeFloat(client.x, 0, Shared.WORLD_WIDTH, 16)
                dataWriter:writeFloat(client.y, 0, Shared.WORLD_HEIGHT, 16)
                client.lastX = client.x
                client.lastY = client.y
            end
            
            self.net:send(dataWriter:toString(), client.ip, client.port)
        end
    end
end

function Server:draw()
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("SERVER AUTORITATIVO (Porta 25565)", 10, 400)
    
    local count = 0
    for id, client in pairs(self.clients) do count = count + 1 end
    love.graphics.print("CLIENT CONNESSI: " .. count, 10, 420)
    
    for id, client in pairs(self.clients) do
        love.graphics.setColor(0, 0.5, 1, 0.3)
        love.graphics.circle("fill", client.x, client.y, 25)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.print("Memoria Server", client.x + 30, client.y)
    end
end

return Server