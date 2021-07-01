local inspect = require "inspect"
local function replaceStringEnvVariables(s)
	local result =
		string.gsub(
		s,
		"%%[A-Z_]+%%",
		function(str)
            local env_variable = string.sub(str, 2, string.len(str) - 1)
            local result = os.getenv(env_variable)
            kong.log.notice("Fetching from env:: " .. env_variable)
            kong.log.notice("Value::" .. inspect(result))
            result = result:gsub("\\([nt])", {n="\n", t="\t"})
            return result
		end
	)
	return result
end

local function traverseTableAndTransformLeaves(e, transform_function)
	for k, v in pairs(e) do -- for every element in the table
		if type(v) == "table" then
			traverseTableAndTransformLeaves(e[k], transform_function)
		else
			if type(v) == "string" then
				e[k] = transform_function(v)
			end
		end
	end
end

local function tableMerge(t1, t2)
    if not t2 then
        return t1
    end
	for k, v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k] or false) == "table" then
				tableMerge(t1[k] or {}, t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
	return t1
end

local _M = {}
_M.replaceStringEnvVariables = replaceStringEnvVariables
_M.traverseTableAndTransformLeaves = traverseTableAndTransformLeaves
_M.tableMerge = tableMerge

return _M
