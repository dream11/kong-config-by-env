[![Continuous Integration](https://github.com/dream11/kong-config-by-env/actions/workflows/ci.yml/badge.svg)](https://github.com/dream11/kong-config-by-env/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Usecase
This plugin provides config with following features:
1. Maintains environment based configuration
2. Configuration is cached as a Lua table
3. Configuration is set in request context to be accessed across multiple plugins
4. Interpolate any env variables in config 

Let's say we are connecting to Redis in 3 different plugins. If redis configuration changes for some reason, then we need to change it in all instances of these plugins. In such cases, it is handy when the configuration is kept at one place.

## Installation

### [luarocks](https://luarocks.org/modules/dream11/kong-config-by-env)
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

## How does it work?
1. Let us assume following config is stored in schema:
    Sample Config:
```
   {
        "default": {
            "redis": {
                "url": "localhost",
                "port": 6379,
				"connect_timeout": 1000
            }
        },
		"docker": {
            "redis": {
                "url": "http://redis%%TEAM_NAME%%.dream11-staging.local",
                "port": 8888
            }
        }
        "production": {
            "redis": {
                "url": "http://redis.dream11.local",
                "port": 9999
            }
        },
    }
```
2. When an nginx worker is instantiated, config is loaded from DB/file.
3. Merge environment specific config with the default config. When KONG_ENV=docker, config after merging with default config will be:
```
{
	"redis": {
		"url": "http://redis%%TEAM_NAME%%.dream11-staging.local",
		"port": 8888,
		"connect_timeout": 1000
	}
}
```
4. Interpolate environment variables. Let's envionment variable TEAM_NAME=user-profile then config will be:
```
{
	"redis": {
		"url": "http://redis-user-profile.dream11-staging.local",
		"port": 8888,
		"connect_timeout": 1000
	}
}
```
5. The final config from step 4 will be saved as a Lua table in L1 and L2 cache using [lua-resty-mlcache](https://github.com/thibaultcha/lua-resty-mlcache) library. This config will also be set in request context for other plugins to access this config.


## Caveats

1. The plugin uses the kong.core_cache module which in turn uses [lua-resty-mlcache](https://github.com/thibaultcha/lua-resty-mlcache) library.
2. To change the config at runtime, this plugin uses the worker_events module. It adds a listener to all crud events on the "plugin" entity. When there is a change in the config-by-env plugin, it invalidates the local L1 and L2 cache and sends invalidation event to all other nodes using the db which then invalidate their L1 and L2 cache.
   

### Parameters

| Key | Type  | Required | Description |
| --- | --- | --- | --- |
| config |  | string | true | Config as JSON |
