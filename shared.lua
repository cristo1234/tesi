local Shared = {}

Shared.TICK_RATE = 1 / 60 
Shared.SPEED = 120 
Shared.WORLD_WIDTH = 800
Shared.WORLD_HEIGHT = 600

-- CAPITOLO 2.1 - command pattern
function Shared.applyInput(state, input, dt)
    local dx, dy = 0, 0
    if input.left then dx = dx - 1 end
    if input.right then dx = dx + 1 end
    if input.up then dy = dy - 1 end
    if input.down then dy = dy + 1 end

    if dx ~= 0 and dy ~= 0 then
        local len = math.sqrt(dx*dx + dy*dy)
        dx, dy = dx / len, dy / len
    end

    local speedMult = input.speedMult or 1

    state.x = state.x + dx * Shared.SPEED * speedMult * dt
    state.y = state.y + dy * Shared.SPEED * speedMult * dt

    -- LIMITO AI BORDI MAPPA
    state.x = math.max(15, math.min(Shared.WORLD_WIDTH - 15, state.x))
    state.y = math.max(15, math.min(Shared.WORLD_HEIGHT - 15, state.y))
end

return Shared