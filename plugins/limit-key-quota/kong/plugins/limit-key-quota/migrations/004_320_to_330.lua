return {
    postgres = {
      up = [[
        DROP TRIGGER IF EXISTS "limit_key_quota_credentials_ttl_trigger" ON "limit_key_quota_credentials";
  
        DO $$
        BEGIN
          CREATE TRIGGER "limit_key_quota_credentials_ttl_trigger"
          AFTER INSERT ON "limit_key_quota_credentials"
          FOR EACH STATEMENT
          EXECUTE PROCEDURE batch_delete_expired_rows("ttl");
        EXCEPTION WHEN UNDEFINED_COLUMN OR UNDEFINED_TABLE THEN
          -- Do nothing, accept existing state
        END$$;
      ]],
    },
  }
