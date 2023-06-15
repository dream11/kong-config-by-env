local config_loader = require "kong.plugins.config-by-env.config"

local pl_utils = require "pl.utils"
local ngx = ngx

local AppConfigHandler = {}
AppConfigHandler.PRIORITY = tonumber(os.getenv("PRIORITY_CONFIG_BY_ENV")) or 10000
AppConfigHandler.VERSION = "2.2.0"

kong.log.info("Plugin priority set to " .. AppConfigHandler.PRIORITY ..
                  (os.getenv("PRIORITY_CONFIG_BY_ENV") and " from env" or " by default"))

local function get_service_url_from_config(config)
    local service_name = ngx.ctx.service.name

    if config["services"] == nil then
        return nil
    end

    local service_url = config["services"][service_name]
    if service_url == nil then
        kong.log.err("Could not find service URL for service name: " .. service_name)
        return nil
    end

    return service_url
end

function AppConfigHandler:access(conf)
    local config = config_loader.get_config(conf)
    if not config then
        return kong.response.exit(500, {
            message = "Error in fetching configuration from config-by-env plugin"
        })
    end

    -- Set config in request context to be shared between all plugins
    kong.ctx.shared.config_by_env = config

    -- Override the service host url from the config
    if conf.set_service_url then
        local service_url = get_service_url_from_config(config)
        -- If service url not found in config, default to service host, port
        if not service_url then
            return
        end

        local host, port = pl_utils.splitv(service_url, ":")
        port = port or 80

        kong.service.set_target(host, tonumber(port))
        kong.ctx.shared.upstream_host = host
    end
end

function AppConfigHandler:init_worker()
    -- listen to all CRUD operations made on Consumers
    kong.worker_events.register(function(data)
        if data["entity"]["name"] == "config-by-env" then
            kong.log.notice("config-by-env: Invalidating Config")
            kong.cache:invalidate_local("config-by-env-final")
        end
    end, "crud", "plugins:update")
end

return AppConfigHandler
