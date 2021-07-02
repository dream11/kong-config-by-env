local inspect = require("inspect")
local cjson_safe = require "cjson.safe"
local utils = require "kong.plugins.config-by-env.utils"

local function load_plugin_from_db(key)
	local row, err = kong.db.plugins:select_by_cache_key(key)
	if err then
		return nil, tostring(err)
	end
	return row
end

local function load_plugin_from_cache(name)
	local cache_key = kong.db.plugins:cache_key(name)
	local opts = {ttl = 0}
	local plugin, err = kong.core_cache:get(cache_key, opts, load_plugin_from_db, cache_key)
	if err then
		kong.log.err(err)
		return false, {status = 500, message = "Error in loading from cache"}
	end
	return plugin
end

local function load_config_from_db()
	kong.log.debug("Fetching config-by-env")
	local plugin, err = load_plugin_from_cache("config-by-env")
	if err then
		kong.log.err(err)
		return false, {
			status = 500,
			message = "Error in loading config-by-env from cache",
		}
	end
	local config, err1 = cjson_safe.decode(plugin["config"]["config"])
	if err1 then
		kong.log.err(err1)
		return false, {status = 500, message = "Error in parsing config-by-env as table"}
	end
	local env = os.getenv("KONG_ENV")
	local final_config = utils.tableMerge(config["default"], config[env])
	utils.traverseTableAndTransformLeaves(final_config, utils.replaceStringEnvVariables)
	kong.log.notice("Final config" .. inspect(final_config))
	return final_config
end

local function get_config()
	local config, err = kong.core_cache:get("config-by-env-final", nil, load_config_from_db)
	if err then
		kong.log.err(err)
		return false, {
			status = 500,
			message = "Error in loading config-by-env-final from cache",
		}
	end
	return config
end

local function get_service_url(service_name)
	kong.log.debug("Fetching url from config::" .. service_name)
	local config, err = get_config()
	if err then
		kong.log.err(err)
		return false, {status = 500, message = "Error in loading config-by-env"}
	end
	kong.log.debug("Fetched url from config::" .. config["services"][service_name])
	return config["services"][service_name]
end


local _M = {}
_M.get_config = get_config
_M.get_service_url = get_service_url
return _M
