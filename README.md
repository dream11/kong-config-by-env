[![Continuous Integration](https://github.com/dream11/kong-config-by-env/actions/workflows/ci.yml/badge.svg)](https://github.com/dream11/kong-config-by-env/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Usecase
This plugin provides config with following features:
1. Maintains environment based configuration based on `KONG_ENV`.
2. Configuration is cached as a Lua table.
3. Configuration is set in request context to be accessed across multiple plugins.
4. Interpolate any environment variables in configuration.

Let's say we are connecting to [Redis](https://redis.io/) in 3 different plugins. If redis configuration changes for some reason, then we need to change it in all instances of these plugins. In such cases, it is handy when the configuration is kept at one place.


## Installation

### [luarocks](https://luarocks.org/modules/dream11/config-by-env)
```bash
luarocks install config-by-env
```

### source
Clone this repo and run:
```
luarocks make
```

You will also need to enable this plugin by adding it to the list of enabled plugins using `KONG_PLUGINS` environment variable or the `plugins` key in `kong.conf`

    export KONG_PLUGINS=config-by-env

OR

    plugins=config-by-env

      
This plugin requires `KONG_ENV` environment variable to be set in nginx. To do that check this [article](https://discuss.konghq.com/t/set-multiple-env-nginx-directives/7532). A command like below should work and help you set environment variable in Nginx.

```
export KONG_ENV=production && export KONG_NGINX_MAIN_ENV=KONG_ENV && kong start
```


## How does it work?
1. Let us assume following config is stored in schema.  
**Note**:  *default | docker | production* are possible values of `KONG_ENV` environment variable.
```
   {
        "default": {
            "redis": {
                "host": "localhost",
                "port": 6379,
		"connect_timeout": 1000
            }
        },
	"docker": {
            "redis": {
                "host": "http://redis%TEAM_NAME%.dream11-staging.local",
                "port": 8888
            }
        },
        "production": {
            "redis": {
                "host": "http://redis.dream11.local",
                "port": 9999
            }
        }
    }
```
2. When an nginx worker starts, this plugin reads plugin's config from DB and caches it in memory.
3. Uses plugin's config extracted in step 2 to merges environment specific config with the `default` config. When `KONG_ENV=docker`, config after merging with `default` config will be:
```
    {
	"redis": {
		"host": "http://redis%TEAM_NAME%.dream11-staging.local",
		"port": 8888,
		"connect_timeout": 1000
	 }
    }
```
4. Let's say we set environment variable `TEAM_NAME=user-profile`, then config after interpolating environment variables will be:
```
    {
	"redis": {
		"host": "http://redis-user-profile.dream11-staging.local",
		"port": 8888,
		"connect_timeout": 1000
	 }
    }
```
5. The final config from step 4 will be saved as a Lua table in L1 and L2 cache using [lua-resty-mlcache](https://github.com/thibaultcha/lua-resty-mlcache) library. This config will also be set in request context for other plugins to access this config.
```
local config_by_env = kong.ctx.shared.config_by_env
local redis_host = config_by_env["redis"]["host"]
```

### Parameters

| Key | Type  | Default | Required | Description |
| --- | --- | --- | --- | --- |
| config | string |   | true | Config as JSON |
| set_service_url | boolean | false | false | Overrides service host URL |


## Caveats

1. The plugin uses the kong.core_cache module which in turn uses [lua-resty-mlcache](https://github.com/thibaultcha/lua-resty-mlcache) library.
2. To change the config at runtime, this plugin uses the worker_events module. It adds a listener to all crud events on the "plugin" entity. When there is a change in the config-by-env plugin, it invalidates the local L1 and L2 cache and sends invalidation event to all other nodes using the db which then invalidates their L1 and L2 cache.
3. Enable `set_service_url` in config when you want to override the host url of an upstream service. In a case where the upstream host url changes w.r.t environment, then to manage the service url we have to either keep separate kong.yaml file per environment or we can use config-by-env plugin to override the url as per environment.
