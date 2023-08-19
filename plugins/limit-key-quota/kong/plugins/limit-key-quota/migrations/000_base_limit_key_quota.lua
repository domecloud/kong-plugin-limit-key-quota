return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "limit_key_quota_credentials" (
        "id"                  UUID                      PRIMARY KEY,
        "created_at"          TIMESTAMP WITH TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "ttl"                 TIMESTAMP WITH TIME ZONE,
        "consumer_id"         UUID                      REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "key"                 TEXT                      UNIQUE,
        "limit_key_quota"     INTEGER,
        "tags"                TEXT[]
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "limit_key_quota_key_idx" ON "limit_key_quota_credentials" ("key");
        CREATE INDEX IF NOT EXISTS "limit_key_quota_consumer_idx" ON "limit_key_quota_credentials" ("consumer_id");
        CREATE INDEX IF NOT EXISTS "limit_key_quota_limit_key_quota_idx" ON "limit_key_quota_credentials" ("limit_key_quota");
        CREATE INDEX IF NOT EXISTS "limit_key_quota_tags_idex_tags_idx" ON "limit_key_quota_credentials" USING GIN("tags");
        CREATE INDEX IF NOT EXISTS "limit_key_quota_credentials_ttl_idx" ON "limit_key_quota_credentials" ("ttl");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DROP TRIGGER IF EXISTS limit_key_quota_sync_tags_trigger ON limit_key_quota_credentials;

      DO $$
      BEGIN
        CREATE TRIGGER limit_key_quota_sync_tags_trigger
        AFTER INSERT OR UPDATE OF tags OR DELETE ON limit_key_quota_credentials
        FOR EACH ROW
        EXECUTE PROCEDURE sync_tags();
      EXCEPTION WHEN UNDEFINED_COLUMN OR UNDEFINED_TABLE THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },
}
