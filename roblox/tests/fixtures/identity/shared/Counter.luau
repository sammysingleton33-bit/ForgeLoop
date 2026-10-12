-- Shared state: every requirer must see the same table.
local Counter = { value = 0 }

function Counter.bump(): number
	Counter.value += 1
	return Counter.value
end

return Counter
