local cjson_safe = require "cjson.safe"
local utils = require "kong.plugins.config-by-env.utils"

local function process_config(conf)
    local config, err = cjson_safe.decode(conf.config)
    local env = os.getenv("KONG_ENV")
    if err then
        kong.log.err(err)
        error("Error in parsing config-by-env as table")
        return nil
    end

    local final_config = utils.tableMerge(config["default"], config[env])
    local success, err = utils.traverseTableAndTransformLeaves(final_config, utils.replaceStringEnvVariables)
    if not success then
        error(err)
    end

    kong.log.inspect("Processed Config:", final_config)
    return final_config
end

local function get_config_from_db(conf)
    local key = kong.db.plugins:cache_key("config-by-env")
    local row, err = kong.db.plugins:select_by_cache_key(key)
	if err then
        -- cache the old db entry for 20 seconds before retrying
        kong.log.err("Failed to fetch config from db due to "..tostring(err)..", using config from db")
		return process_config(conf), nil, 20
	end
    return process_config(row.config)
end

local function get_config(conf)
    local config, err = kong.cache:get("config-by-env-final", {
        ttl = 0
    }, get_config_from_db, conf)

    if err then
        return false
    end
    return config
end

local _M = {}
_M.get_config = get_config

return _M
