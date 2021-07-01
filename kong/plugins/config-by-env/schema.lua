local typedefs = require "kong.db.schema.typedefs"
local json_safe = require "cjson.safe"
local inspect = require "inspect"

local function json_validator(config_string)
    local config_table, err = json_safe.decode(config_string)

    if config_table == nil then
        return nil, "Invalid Json " .. inspect(err)
    end

    return true
end

local function schema_validator(conf)
	return json_validator(conf.config)
end



return {
	name = "config-by-env",
	fields = {
		{
			consumer = typedefs.no_consumer
		},
		{
			protocols = typedefs.protocols_http
		},
		{
			config = {
				type = "record",
				fields = {
					{config = {type = "string", required = true}}
				},
                custom_validator = schema_validator
			}
		}
	}
}
