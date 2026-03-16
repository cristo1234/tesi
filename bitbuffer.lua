local bit = require("bit")

local BitBuffer = {}
BitBuffer.__index = BitBuffer

function BitBuffer.new()
    return setmetatable({ buffer = {}, bitIndex = 0, readIndex = 0 }, BitBuffer)
end

function BitBuffer.fromString(str)
    local bb = BitBuffer.new()
    for i = 1, #str do bb.buffer[i] = string.byte(str, i) end
    return bb
end

-- CAPITOLO 3.2
function BitBuffer:writeBits(value, numBits)
    for i = 0, numBits - 1 do
        local bitValue = bit.band(bit.rshift(value, i), 1)
        local byteIndex = math.floor(self.bitIndex / 8) + 1
        local bitOffset = self.bitIndex % 8
        
        self.buffer[byteIndex] = self.buffer[byteIndex] or 0
        if bitValue == 1 then
            self.buffer[byteIndex] = bit.bor(self.buffer[byteIndex], bit.lshift(1, bitOffset))
        end
        self.bitIndex = self.bitIndex + 1
    end
end

function BitBuffer:readBits(numBits)
    local value = 0
    for i = 0, numBits - 1 do
        local byteIndex = math.floor(self.readIndex / 8) + 1
        local bitOffset = self.readIndex % 8
        local byte = self.buffer[byteIndex] or 0
        
        local bitValue = bit.band(bit.rshift(byte, bitOffset), 1)
        if bitValue == 1 then
            value = bit.bor(value, bit.lshift(1, i))
        end
        self.readIndex = self.readIndex + 1
    end
    return value
end

function BitBuffer:writeBool(value)
    if value then
        self:writeBits(1, 1)
    else
        self:writeBits(0, 1)
    end
end

function BitBuffer:readBool()
    local bitValue = self:readBits(1)
    if bitValue == 1 then
        return true
    else
        return false
    end
end

-- CAPITOLO 3.3: COMPRESSIONE DEI DATI
function BitBuffer:writeFloat(value, min, max, bits)
    local range = max - min
    local clamped = math.max(min, math.min(max, value))
    local normalized = (clamped - min) / range
    local maxInt = (2 ^ bits) - 1
    local quantized = math.floor(normalized * maxInt + 0.5)
    self:writeBits(quantized, bits)
end

function BitBuffer:readFloat(min, max, bits)
    local maxInt = (2 ^ bits) - 1
    local quantized = self:readBits(bits)
    local normalized = quantized / maxInt
    return min + (normalized * (max - min))
end

function BitBuffer:toString()
    local str = ""
    for i = 1, #self.buffer do 
        str = str .. string.char(self.buffer[i]) 
    end
    return str
end

return BitBuffer