package = "kong-plugin-limit-key-quota"
version = "3.4.0"

local pluginName = package:match("^kong%-plugin%-(.+)$")

supported_platforms = {"linux", "macosx"}
source = {
  url = "git://gitlab.com:domecloud-system-engineer/kong-plugin-limit-key-quota.git",
}

description = {
  summary = "Add api key and referer",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins."..pluginName..".migrations.000_base_limit_key_quota"] = "kong/plugins/"..pluginName.."/migrations/000_base_limit_key_quota.lua",
    ["kong.plugins."..pluginName..".migrations.003_200_to_210"] = "kong/plugins/"..pluginName.."/migrations/003_200_to_210.lua",
    ["kong.plugins."..pluginName..".migrations.004_320_to_330"] = "kong/plugins/"..pluginName.."/migrations/004_320_to_330.lua",
    ["kong.plugins."..pluginName..".migrations.init"] = "kong/plugins/"..pluginName.."/migrations/init.lua",
    ["kong.plugins."..pluginName..".daos"] = "kong/plugins/"..pluginName.."/daos.lua",
    ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
    ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
  }
}
