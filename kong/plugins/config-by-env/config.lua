local cjson_safe = require "cjson.safe"
local utils = require "kong.plugins.config-by-env.utils"

local fallback_config = {}

local function get_fallback_config()
    return fallback_config.config
end

local function set_fallback_config(db_config)
    fallback_config.config = db_config
end

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

local function get_config_from_db()
    local key = kong.db.plugins:cache_key("config-by-env")
    local row, err = kong.db.plugins:select_by_cache_key(key)
	if err then
		return nil, tostring(err)
	end
    local fetched_config = process_config(row.config)
    set_fallback_config(fetched_config)
    return fetched_config
end

local function get_config(conf)
    local config, err = kong.cache:get("config-by-env-final", {
        ttl = 0
    }, get_config_from_db)

    if err then
        return get_fallback_config()
    end
    return config
end

local _M = {}
_M.get_config = get_config

return _M
