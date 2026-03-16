local Network = require("network")
local Shared = require("shared")
local BitBuffer = require("bitbuffer")
local Prediction = require("prediction")

local Client = {}
Client.__index = Client

function Client.new(serverIp, serverPort)
    local self = setmetatable({}, Client)
    self.net = Network.new(0, false)
    
    self.serverIp = serverIp
    self.serverPort = serverPort
    
    self.prediction = Prediction.new(Shared.WORLD_WIDTH/2, Shared.WORLD_HEIGHT/2)
    self.serverGhost = { x = Shared.WORLD_WIDTH/2, y = Shared.WORLD_HEIGHT/2 }
    self.sequence = 0
    self.tickTimer = 0
    self.payloadSize = 0

    self.isCheating = false 
    self.showVector = true 
    
    self.net:onReceive(function(data)
        self.payloadSize = string.len(data)
        local dataReader = BitBuffer.fromString(data)
        local ackSeq = dataReader:readBits(16)
        
        local moved = dataReader:readBool()
        if moved then
            self.serverGhost.x = dataReader:readFloat(0, Shared.WORLD_WIDTH, 16)
            self.serverGhost.y = dataReader:readFloat(0, Shared.WORLD_HEIGHT, 16)
        end
        
        self.prediction:reconcile(self.serverGhost, ackSeq)
    end)
    return self
end

function Client:update(dt)
    self.net:update()
    
    self.tickTimer = self.tickTimer + dt
    while self.tickTimer >= Shared.TICK_RATE do
        self.tickTimer = self.tickTimer - Shared.TICK_RATE
        self.sequence = self.sequence + 1
        
        local input = {
            sequence = self.sequence,
            left = love.keyboard.isDown("a", "left"),
            right = love.keyboard.isDown("d", "right"),
            up = love.keyboard.isDown("w", "up"),
            down = love.keyboard.isDown("s", "down"),
            speedMult = self.isCheating and 4 or 1
        }
        
        self.prediction:addInput(input, Shared.TICK_RATE)
        
        local dataWriter = BitBuffer.new()
        dataWriter:writeBits(input.sequence, 16)
        dataWriter:writeBool(input.left)
        dataWriter:writeBool(input.right)
        dataWriter:writeBool(input.up)
        dataWriter:writeBool(input.down)
        
        self.net:send(dataWriter:toString(), self.serverIp, self.serverPort)
    end
end

function Client:draw()
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 0.2) 
    love.graphics.rectangle("line", 0, 0, Shared.WORLD_WIDTH, Shared.WORLD_HEIGHT)
    love.graphics.setLineWidth(1) 

    -- disegno le entita
    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.circle("fill", self.serverGhost.x, self.serverGhost.y, 15)
    
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.circle("line", self.prediction.state.x, self.prediction.state.y, 15)

    -- Vettore errore F9
    if self.showVector then
        love.graphics.setLineWidth(2)  
        love.graphics.setColor(1, 1, 0, 0.8)  
        love.graphics.line(self.prediction.state.x, self.prediction.state.y, self.serverGhost.x, self.serverGhost.y)
        love.graphics.setLineWidth(1)  
        
        local dist = math.floor(math.sqrt((self.prediction.state.x - self.serverGhost.x)^2 + (self.prediction.state.y - self.serverGhost.y)^2))
        if dist > 1 then
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.print(dist .. "px", (self.prediction.state.x + self.serverGhost.x)/2 + 10, (self.prediction.state.y + self.serverGhost.y)/2)
        end
    end

    -- Simulo JSON che server avrebbe inviato
    local isMovingString = "false"
    -- Usiamo math.abs per evitare bug dovuti alla precisione dei float  
    if math.abs(self.prediction.state.x - self.serverGhost.x) > 0.01 or math.abs(self.prediction.state.y - self.serverGhost.y) > 0.01 then
        isMovingString = "true"
    end
 
    local simulatedJson = string.format('{"seq":%d,"moved":%s,"x":%.2f,"y":%.2f}', 
        self.sequence, 
        isMovingString, 
        self.serverGhost.x, 
        self.serverGhost.y
    )

    -- METRICHE
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("CLIENT - SERVER", 10, 10)
    love.graphics.print("Latenza: " .. (self.net.latency * 2000) .. "ms RTT | Pacchetti Persi: " .. (self.net.packetLoss * 100) .. "%", 10, 30)
    love.graphics.print("Cerchio  Verde: Predizione immediata lato Client", 10, 60)
    love.graphics.print("Cerchio Rosso: Cerchio Autoritativo (Quello che gli altri vedono)", 10, 80)
    

    love.graphics.setColor(1, 1, 0)
    love.graphics.print("--- Metriche ---", 10, 120)
    love.graphics.print("Standard JSON Payload: " .. string.len(simulatedJson) .. " bytes", 10, 140)
    love.graphics.print("BitBuffer Payload (In Movimento): 7 bytes", 10, 160)
    love.graphics.print("BitBuffer Payload (Fermo): 3 bytes", 10, 180)
    love.graphics.print("Grandezza Paylod corrente: " .. self.payloadSize .. " bytes", 10, 200)

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    
    love.graphics.setColor(1, 0.5, 0)
    love.graphics.print("Somma totale Rollbacks: " .. (self.prediction.rollbackCount or 0), 10, 220)
    
    if self.prediction.reconciliationEnabled then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("[R] Server Reconciliation: ON", w - 380, h - 120)
    else
        love.graphics.setColor(1, 0, 1)
        love.graphics.print("[R] Server Reconciliation: OFF", w - 380, h - 120)
    end
    
    -- VETTORE
    if self.showDebugTether then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("[F9] Vettore di discrepanza: ON", w - 380, h - 100)
    else
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.print("[F9] Vettore di discrepanza: OFF", w - 380, h - 100)
    end

    if self.isCheating then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("[E] MODIFICATORE VELOCITA' ATTIVO! [Q] STOP", w - 380, h - 60)
        if self.prediction.reconciliationEnabled then
            love.graphics.print("-> Il Server forza l'effetto \"RudataWriterer-banding\"", w - 380, h - 40)
        else
            love.graphics.print("-> Client ignora il Server (Desync Permanente)", w - 380, h - 40)
        end
    else
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("[E] Hack Velocita' | [Q] Velocita' Default", w - 380, h - 60)
    end
end

return Client