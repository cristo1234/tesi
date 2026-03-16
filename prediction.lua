local Shared = require("shared")

local Prediction = {}
Prediction.__index = Prediction

function Prediction.new(startX, startY)
    local self = setmetatable({}, Prediction)
    self.state = { x = startX, y = startY }
    self.pendingInputs = {} 
    self.lastAcknowledgedSequence = 0
    self.rollbackCount = 0
    self.reconciliationEnabled = true -- CAPITOLO 2.3
    
    return self
end

-- CAPITOLO 2.1 
function Prediction:addInput(input, dt)
    table.insert(self.pendingInputs, input)
    Shared.applyInput(self.state, input, dt)
end

-- CAPITOLO 2.3 
function Prediction:reconcile(serverState, ackedSequence)
    if ackedSequence <= self.lastAcknowledgedSequence then return end
    self.lastAcknowledgedSequence = ackedSequence

    -- SCARTIAMO GLI INPUT CHE IL SERVER HA VALIDATO
    local unacknowledged = {}
    for _, input in ipairs(self.pendingInputs) do
        if input.sequence > ackedSequence then
            table.insert(unacknowledged, input)
        end
    end
    self.pendingInputs = unacknowledged
    
    -- CALCOLIAMO LA NOSTRA POSIZIONE TEORICA
    local predictedState = { x = serverState.x, y = serverState.y }
    for _, input in ipairs(self.pendingInputs) do
        Shared.applyInput(predictedState, input, Shared.TICK_RATE)
    end
    
    -- EFFETTUIAMO IL ROLL BACK SE C'E' UN GROSSO MARGINE  (DISTANZA DEL VETTORE ERRORE)
    if not self.reconciliationEnabled then return end --QUANDO LO ATTIVIAMO CON [R] 
    
    local distSq = (self.state.x - predictedState.x)^2 + (self.state.y - predictedState.y)^2
    if distSq > 0.1 then
        self.state.x = predictedState.x
        self.state.y = predictedState.y
        self.rollbackCount = self.rollbackCount + 1
    end
end

return Prediction