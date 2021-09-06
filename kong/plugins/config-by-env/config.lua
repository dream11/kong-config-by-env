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
		error("Error in parsing config-by-env as table")
		return nil
	end
	local env = os.getenv("KONG_ENV")
	local final_config = utils.tableMerge(config["default"], config[env])

	local success, err = utils.traverseTableAndTransformLeaves(final_config, utils.replaceStringEnvVariables)
	if not success then
		error(err)
	end

	kong.log.notice("Final config loaded from db: ", inspect(final_config))
	return final_config
end

local function get_config()
	local config, err = kong.core_cache:get("config-by-env-final", nil, load_config_from_db)
	if err then
		return false, "Error in fetching configuration from config-by-env plugin"
	end
	return config
end

local function get_service_name()
	local service_name = kong.router.get_service()["name"]

	if os.getenv("KONG_KIC") == "on" then
		local service_name_og = service_name
		local splitted_service_name = pl_stringx.split(service_name_og, '.')
		if #splitted_service_name == 3 then
			service_name = splitted_service_name[2]
			kong.log.debug(string.format("derived service name for k8 env from %s is %s", service_name_og, service_name))
		end
	end

	return service_name
end

local function get_service_url(service_name)
	local config, err = get_config()
	if err then
		kong.log.err(err)
		return false, {status = 500, message = "Error in loading config-by-env"}
	end

	local service_url = config["services"][service_name]
	if service_url == nil then
		kong.log.err("Could not find service URL for service name: " .. service_name)
	else
		kong.log.debug(string.format("service URL fetched for service %s is %s", service_name, service_url))
	end

	return service_url
end


local _M = {}
_M.get_config = get_config
_M.get_service_url = get_service_url
_M.get_service_name = get_service_name
return _M
