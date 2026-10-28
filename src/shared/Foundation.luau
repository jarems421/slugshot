--!strict
-- Setup probe only. This module has no gameplay responsibilities.
local Foundation = {}

function Foundation.message(context: string): string
	return string.format("[Slugshot] %s foundation ready", context)
end

return table.freeze(Foundation)
