local cjson = require "cjson"
local helpers = require "spec.helpers"
local fixtures = require "spec.config-by-env.fixtures"

for _, strategy in helpers.each_strategy() do
    describe("config-by-env plugin [#" .. strategy .. "]", function()
        local proxy_client;
        local bp
        local db
        local mock_host = helpers.mock_upstream_host;
        local mock_port = 10001
        local admin_client
        local app_config_plugin
        setup(function()
            bp, db = helpers.get_db_utils(strategy, {"routes", "services", "plugins"}, {"config-by-env"});

            assert(bp.routes:insert({
                hosts = {"test.com"},
                protocols = {"http"},
                service = bp.services:insert(
                    {
                        protocol = "http",
                        host = mock_host, -- Just a dummy value. Not honoured
                        port = mock_port, -- Just a dummy value. Not honoured
                        name = "test"
                    })
            }))

            local input = {
                default = {
                    services = {test = mock_host .. ":" .. mock_port},
                    upstream_port = mock_port
                },
                staging = {},
                prod = {}
            }

            app_config_plugin = bp.plugins:insert{
                name = "config-by-env",
                config = {
                    config = cjson.encode(input),
                    set_service_url = true
                }
            }

            assert(helpers.start_kong({
                database = strategy,
                plugins = "bundled, config-by-env",
                nginx_conf = "spec/fixtures/custom_nginx.template"
            }, nil, nil, fixtures.fixtures))

            proxy_client = helpers.proxy_client()
            admin_client = helpers.admin_client()

        end)

        lazy_teardown(function()
            helpers.stop_kong()
            db:truncate()
        end)

        describe("Cache is invalidated on updating config-by-env", function()
            it("Initially request should be proxied to old port", function()
                local res = assert(proxy_client:send(
                                       {
                        method = "GET",
                        path = "/test",
                        headers = {Host = "test.com"}
                    }))

                assert(res.status == 200)
                local body_data = assert(res:read_body())
                assert(body_data == '10001')
            end)

            it("After updating config request shoud be proxied to new port", function()

                local input1 = {
                    default = {
                        services = {test = mock_host .. ":" .. 10002}, -- this is a new service url
                        upstream_port = mock_port
                    },
                    staging = {},
                    prod = {}
                }

                local url = "/plugins/" .. app_config_plugin["id"]

                local admin_res = assert(
                                      admin_client:patch(url, {
                        headers = {["Content-Type"] = "application/json"},
                        body = {
                            name = "config-by-env",
                            config = {config = cjson.encode(input1)}
                        }
                    }))
                assert.res_status(200, admin_res)

                local res1 = assert(proxy_client:send(
                                        {
                        method = "GET",
                        path = "/test",
                        headers = {Host = "test.com"}
                    }))

                assert(res1.status == 200)
                local body_data1 = assert(res1:read_body())
                assert(body_data1 == '10002')
            end)

        end)
    end)
end
