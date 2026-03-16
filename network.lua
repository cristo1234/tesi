local socket = require("socket")

local Network = {}
Network.__index = Network

function Network.new(port, isServer)
    local self = setmetatable({}, Network)
    self.udp = socket.udp()
    self.latency = 0.100 -- 100ms = 200ms RTT
    self.packetLoss = 0.05 -- ESPRESSA IN % 
    self.sendQueue = {}
    self.listeners = {}
    

    self.udp:settimeout(0) -- 0 = NON-BLOCKING
    if isServer then 
        self.udp:setsockname("127.0.0.1", port) 
    else
        self.udp:setsockname("127.0.0.1", 0) -- 0 = S.O. SCEGLIE UNA PORTA CASUALE SUL CLIENT
    end
    
    return self
end

function Network:onReceive(callback) 
    table.insert(self.listeners, callback) 
end

function Network:send(data, ip, port)
    if math.random() < self.packetLoss then return end 
    
    table.insert(self.sendQueue, {
        data = data, ip = ip, port = port,
        deliverAt = love.timer.getTime() + self.latency
    })
end

function Network:update()
    local now = love.timer.getTime()
    local pendingQueue = {}
    for i = 1, #self.sendQueue do
        local packet = self.sendQueue[i]
        if now >= packet.deliverAt then
            if packet.ip and packet.port then 
                self.udp:sendto(packet.data, packet.ip, packet.port)
            else 
                self.udp:send(packet.data) 
            end
        else
            table.insert(pendingQueue, packet)
        end
    end
    self.sendQueue = pendingQueue
    
    while true do
        local data, ip, port = self.udp:receivefrom()
        if not data then break end
        for _, listener in ipairs(self.listeners) do 
            listener(data, ip, port)
        end
    end
end

return Network