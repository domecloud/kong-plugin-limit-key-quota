local typedefs = require "kong.db.schema.typedefs"

return {
  {
    ttl = true,
    primary_key = { "id" },
    name = "limit_key_quota_credentials",
    endpoint_key = "key",
    cache_key = { "key" },
    workspaceable = true,
    generate_admin_api = true,
    admin_api_name = "limit-key-quotas",
    admin_api_nested_name = "limit-key-quota",
    fields = {
      { id = typedefs.uuid },
      { created_at = typedefs.auto_timestamp_s },
      { consumer = { type = "foreign", reference = "consumers", required = true, on_delete = "cascade", }, },
      { key = { type = "string", required = false, unique = true, auto = true }, },
      { limit_key_quota = { type = "integer", required = false, default = 0, gt = -1 }, },
      { tags = typedefs.tags },
    },
  },
}
