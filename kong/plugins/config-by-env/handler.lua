local singletons = require "kong.singletons"
local config_loader = require "kong.plugins.config-by-env.config"

local pl_utils = require "pl.utils"
local pl_utils = require "pl.utils"
local pl_stringx = require "pl.stringx"

local inspect = require "inspect"

local AppConfigHandler = {PRIORITY = tonumber(os.getenv("PRIORITY_CONFIG_BY_ENV")) or 10000}
kong.log.info("Plugin priority set to " .. AppConfigHandler.PRIORITY .. (os.getenv("PRIORITY_CONFIG_BY_ENV") and " from env" or " by default"))

function AppConfigHandler:access(conf)
    local config, err = config_loader.get_config();
    if not config or err then
        return kong.response.exit(500, {message = "Error in fetching configuration from config-by-env plugin"})
    end

    -- Set config in request context to be shared between all plugins
    kong.ctx.shared.config_by_env = config

    -- Override the service host url from the config
    if conf.set_service_url then
        local service_name = config_loader.get_service_name()
        local service_url = config_loader.get_service_url(service_name)

        local host, port = pl_utils.splitv(service_url, ":")
        if not port then
            port = config["upstream_port"]
        end

        kong.log.debug("Setting upstream url to: " .. host .. ":" .. port)

        kong.service.set_target(host, tonumber(port))
        kong.ctx.shared.upstream_host = host
    end
end

function AppConfigHandler:init_worker()
    local worker_events = singletons.worker_events

    -- listen to all CRUD operations made on Consumers
    worker_events.register(function(data)
        kong.log.debug("Updated entitty:::" .. data["entity"]["name"])
        if data["entity"]["name"] == "config-by-env" then
            kong.log.notice("invalidating config-by-env-final")
            kong.core_cache:invalidate("config-by-env-final", false)
        end
    end, "crud", "plugins:update")
end

return AppConfigHandler
