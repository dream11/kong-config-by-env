local helpers = require "spec.helpers"
local config_by_env = require "kong.plugins.config-by-env.config"
local mocker = require "spec.fixtures.mocker"
local cjson = require('cjson')
local pl_utils = require "pl.utils"

local function fetchNestedKey(x, key)

    if type(key) == 'string' then key = pl_utils.split(key, "%.") end
    if table.getn(key) == 1 then return x[key[1]] end
    local root_key = table.remove(key, 1)
    return fetchNestedKey(x[root_key], key)

end

local function setup_it_block(strategy, env)
    local function mock_cache(cache_table, limit)
        return {
            safe_set = function(self, k, v)
                if limit then
                    local n = 0
                    for _, _ in pairs(cache_table) do
                        n = n + 1
                    end
                    if n >= limit then
                        return nil, "no memory"
                    end
                end
                cache_table[k] = v
                return true
            end,
            get = function(self, k, _, fn, arg)
                if cache_table[k] == nil then
                    cache_table[k] = fn(arg)
                end
                return cache_table[k]
            end
        }
    end
    local conf = {
        database = strategy,
        plugins = "bundled, config-by-env",
        nginx_conf = "spec/fixtures/custom_nginx.template"
    }

    mocker.setup(finally, {
        kong = {
            log = {debug = function() end, info = function() end, notice = function() end},
            endconfiguration = conf,
            core_cache = mock_cache({})
        }
    })

    helpers.setenv("KONG_ENV", env.kong_env)
    helpers.setenv("TEAM_SUFFIX", env.team_suffix)
    helpers.setenv("VPC_SUFFIX", env.vpc_suffix)
    return config_by_env.get_config();
end

for _, strategy in helpers.each_strategy() do
    describe("config_by_env.get_config [#" .. strategy .. "]", function()

        local bp = helpers.get_db_utils(strategy, {"plugins"}, {"config-by-env"});
        setup(function()

            local input = {
                default = {
                    a = "default-a%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com",
                    b = "default-b%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com",
                    nested = {
                        c = "default-c%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com",
                        d = "default-d%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com"
                    }
                },
                stag = {
                    b = "stag-b%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com",
                    e = "stag-e%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com",
                    nested = {
                        d = "stag-d%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com",
                        f = "stag-f%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com"
                    }
                },
                prod = {
                    b = "prod-b%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com",
                    e = "prod-e%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com",
                    nested = {
                        d = "prod-d%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com",
                        f = "prod-f%TEAM_SUFFIX%.dream11%VPC_SUFFIX%.com"
                    }
                }
            }

            bp.plugins:insert{
                name = "config-by-env",
                config = {config = cjson.encode(input)}
            }

        end)

        teardown(function() end)

        local env_array = {
            {kong_env = "prod", team_suffix = "", vpc_suffix = ""},
            {kong_env = "stag", team_suffix = "-int-11", vpc_suffix = "-stag"},
            {
                kong_env = "stag",
                team_suffix = "-docker-01",
                vpc_suffix = "-stag"
            }
        }

        for _, env in pairs(env_array) do

            local cases = {
                {
                    case = string.format(
                        "Should preserve keys from default config if not present in env config (Root level) - ENV: %s, TEAM_SUFFIX: %s, VPC_SUFFIX: %s",
                        env.kong_env, env.team_suffix, env.vpc_suffix),
                    key = "a",
                    value = "default-a" .. env.team_suffix .. ".dream11" ..
                        env.vpc_suffix .. ".com"
                }, {
                    case = string.format(
                        "Should overwrite keys from env config (Root level) - ENV: %s, TEAM_SUFFIX: %s, VPC_SUFFIX: %s",
                        env.kong_env, env.team_suffix, env.vpc_suffix),
                    key = "b",
                    value = env.kong_env .. "-b" .. env.team_suffix ..
                        ".dream11" .. env.vpc_suffix .. ".com"
                }, {
                    case = string.format(
                        "Should add keys from env config (Root level) - ENV: %s, TEAM_SUFFIX: %s, VPC_SUFFIX: %s",
                        env.kong_env, env.team_suffix, env.vpc_suffix),
                    key = "e",
                    value = env.kong_env .. "-e" .. env.team_suffix ..
                        ".dream11" .. env.vpc_suffix .. ".com"
                }, {
                    case = string.format(
                        "Should preserve keys from default config if not present in env specific config (Nested level) - ENV: %s, TEAM_SUFFIX: %s, VPC_SUFFIX: %s",
                        env.kong_env, env.team_suffix, env.vpc_suffix),
                    key = "nested.c",
                    value = "default-c" .. env.team_suffix .. ".dream11" ..
                        env.vpc_suffix .. ".com"
                }, {
                    case = string.format(
                        "Should overwrite keys from env config (Nested level) - ENV: %s, TEAM_SUFFIX: %s, VPC_SUFFIX: %s",
                        env.kong_env, env.team_suffix, env.vpc_suffix),
                    key = "nested.d",
                    value = env.kong_env .. "-d" .. env.team_suffix ..
                        ".dream11" .. env.vpc_suffix .. ".com"
                }, {
                    case = string.format(
                        "Should add keys from env config (Nested level) - ENV: %s, TEAM_SUFFIX: %s, VPC_SUFFIX: %s",
                        env.kong_env, env.team_suffix, env.vpc_suffix),
                    key = "nested.f",
                    value = env.kong_env .. "-f" .. env.team_suffix ..
                        ".dream11" .. env.vpc_suffix .. ".com"
                }
            }

            for _, item in pairs(cases) do
                it(item["case"], function()
                    local actual_config = setup_it_block(strategy, env)
                    assert(fetchNestedKey(actual_config, item["key"]) ==
                               item["value"])
                end)
            end
        end
    end)
end
