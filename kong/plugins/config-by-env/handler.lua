local AppConfigHandler = {PRIORITY = 10000}
local singletons = require "kong.singletons"
local config_by_env = require "kong.plugins.config-by-env.config"
local pl_utils = require "pl.utils"
local inspect = require "inspect"

function AppConfigHandler:access(conf)
    local config, err = config_by_env.get_config();
    if not config or err then
        return kong.response.exit(500, {message = "Error in fetching configuration from config-by-env plugin"})
    end

    -- Set config in request context to be shared between all plugins
    kong.ctx.shared.config_by_env = config

    -- Override the service host url from the config
    if conf.set_service_url then
        local service_url = config["services"][kong.router.get_service()["name"]]
        local host, port = pl_utils.splitv(service_url, ":")
        if not port then port = config["upstream_port"] end
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
