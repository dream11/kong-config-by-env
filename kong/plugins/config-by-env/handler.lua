local AppConfigHandler = {PRIORITY = 820}
local singletons = require "kong.singletons"
local config_by_env = require "kong.plugins.config-by-env.config"

function AppConfigHandler:access(conf)
    local config, err = config_by_env.get_config();
    if not config or err then
        return kong.response.exit("Error in fetching application config")
    end

    kong.ctx.shared.app_config = config
end

function AppConfigHandler:init_worker()
    local worker_events = singletons.worker_events

    -- listen to all CRUD operations made on Consumers
    worker_events.register(function(data)
        kong.log.debug("Updated entity:::" .. data["entity"]["name"])
        if data["entity"]["name"] == "config-by-env" then
            kong.log.notice("invalidating config-by-env-final")
            kong.core_cache:invalidate("config-by-env-final", false)
        end
    end, "crud", "plugins:update")
end

return AppConfigHandler
