local _M = {}

_M.fixtures = {
    http_mock = {
    enrich_req = [[

        server {
            server_name app_config_10001;
            listen 10001;
            charset utf-8;
              charset_types application/json;
              default_type application/json;

            location = "/test" {
                content_by_lua_block {
                  ngx.status = ngx.HTTP_OK
                  ngx.print("10001")
                  return ngx.exit(0)
                }
            }
        }

      server {
        server_name app_config_10002;
        listen 10002;
        charset utf-8;
          charset_types application/json;
          default_type application/json;

        location = "/test" {
            content_by_lua_block {
              ngx.status = ngx.HTTP_OK
              ngx.print("10002")
              return ngx.exit(0)
            }
        }
    }
  ]]
  },
}


return _M