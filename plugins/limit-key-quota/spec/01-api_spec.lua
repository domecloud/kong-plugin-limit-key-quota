local cjson   = require "cjson"
local helpers = require "spec.helpers"
local utils = require "kong.tools.utils"

local PLUGIN_NAME = "limit-key-quota"

for _, strategy in helpers.each_strategy() do
  describe("Plugin: limit-key-quota (API) [#" .. strategy .. "]", function()
    local consumer
    local admin_client
    local bp
    local db
    local route1
    local route2

    lazy_setup(function()
      bp, db = helpers.get_db_utils(strategy, {
        "routes",
        "services",
        "plugins",
        "consumers",
        "limit_key_quota_credentials",
      })

      route1 = bp.routes:insert {
        hosts = { "keyauth1.test" },
      }

      route2 = bp.routes:insert {
        hosts = { "keyauth2.test" },
      }

      consumer = bp.consumers:insert({
        username = "bob"
      }, { nulls = true })

      assert(helpers.start_kong({
        database   = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
        plugins = "bundled," .. PLUGIN_NAME,
      }))

      admin_client = helpers.admin_client()
    end)
    lazy_teardown(function()
      if admin_client then
        admin_client:close()
      end

      helpers.stop_kong()
    end)

    describe("/consumers/:consumer/limit-key-quota", function()
      describe("POST", function()
        after_each(function()
          db:truncate("limit_key_quota_credentials")
        end)
        it("creates a limit-key-quota credential with key", function()
          local res = assert(admin_client:send {
            method  = "POST",
            path    = "/consumers/bob/limit-key-quota",
            body    = {
              key   = "1234"
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(201, res)
          local json = cjson.decode(body)
          assert.equal(consumer.id, json.consumer.id)
          assert.equal("1234", json.key)
        end)
        it("creates a limit-key-quota auto-generating a unique key", function()
          local res = assert(admin_client:send {
            method  = "POST",
            path    = "/consumers/bob/limit-key-quota",
            body    = {},
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(201, res)
          local json = cjson.decode(body)
          assert.equal(consumer.id, json.consumer.id)
          assert.is_string(json.key)

          local first_key = json.key
          db:truncate("limit_key_quota_credentials")

          local res = assert(admin_client:send {
            method  = "POST",
            path    = "/consumers/bob/limit-key-quota",
            body    = {},
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(201, res)
          local json = cjson.decode(body)
          assert.equal(consumer.id, json.consumer.id)
          assert.is_string(json.key)

          assert.not_equal(first_key, json.key)
        end)
        it("creates a limit-key-quota credential with tags", function()
          local res = assert(admin_client:send {
            method  = "POST",
            path    = "/consumers/bob/limit-key-quota",
            body    = {
              key   = "limit-key-quota-with-tags",
              tags  = { "tag1", "tag2"},
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(201, res)
          local json = cjson.decode(body)
          assert.equal(consumer.id, json.consumer.id)
          assert.equal("tag1", json.tags[1])
          assert.equal("tag2", json.tags[2])
        end)
        it("creates a limit-key-quota credential with a ttl", function()
          local res = assert(admin_client:send {
            method  = "POST",
            path    = "/consumers/bob/limit-key-quota",
            body    = {
              ttl = 1,
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(201, res)
          local json = cjson.decode(body)
          assert.equal(consumer.id, json.consumer.id)
          assert.is_string(json.key)

          ngx.sleep(3)

          local id = json.id
          local res = assert(admin_client:send {
            method  = "GET",
            path    = "/consumers/bob/limit-key-quota/" .. id,
          })
          assert.res_status(404, res)
        end)
      end)

      describe("GET", function()
        lazy_setup(function()
          for i = 1, 3 do
            assert(bp.limit_key_quota_credentials:insert {
              consumer = { id = consumer.id }
            })
          end
        end)
        lazy_teardown(function()
          db:truncate("limit_key_quota_credentials")
        end)
        it("retrieves the first page", function()
          local res = assert(admin_client:send {
            method  = "GET",
            path    = "/consumers/bob/limit-key-quota"
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.is_table(json.data)
          assert.equal(3, #json.data)
        end)
      end)

      describe("GET #ttl", function()
        lazy_setup(function()
          for i = 1, 3 do
            bp.limit_key_quota_credentials:insert({
              consumer = { id = consumer.id },
            }, { ttl = 10 })
          end
        end)
        lazy_teardown(function()
          db:truncate("limit_key_quota_credentials")
        end)
        it("entries contain ttl when specified", function()
          local res = assert(admin_client:send {
            method  = "GET",
            path    = "/consumers/bob/limit-key-quota"
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.is_table(json.data)
          for _, credential in ipairs(json.data) do
            assert.not_nil(credential.ttl)
          end
        end)
      end)
    end)

    describe("/consumers/:consumer/limit-key-quota/:id", function()
      local credential
      before_each(function()
        db:truncate("limit_key_quota_credentials")
        credential = bp.limit_key_quota_credentials:insert {
          consumer = { id = consumer.id },
        }
      end)
      describe("GET", function()
        it("retrieves limit-key-quota credential by id", function()
          local res = assert(admin_client:send {
            method  = "GET",
            path    = "/consumers/bob/limit-key-quota/" .. credential.id
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.equal(credential.id, json.id)
        end)
        it("retrieves limit-key-quota credential by key", function()
          local res = assert(admin_client:send {
            method  = "GET",
            path    = "/consumers/bob/limit-key-quota/" .. credential.key
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.equal(credential.id, json.id)
        end)
        it("retrieves credential by id only if the credential belongs to the specified consumer", function()
          assert(bp.consumers:insert {
            username = "alice"
          })

          local res = assert(admin_client:send {
            method  = "GET",
            path    = "/consumers/bob/limit-key-quota/" .. credential.id
          })
          assert.res_status(200, res)

          res = assert(admin_client:send {
            method = "GET",
            path   = "/consumers/alice/limit-key-quota/" .. credential.id
          })
          assert.res_status(404, res)
        end)
        it("limit-key-quota credential contains #ttl", function()
          local credential = bp.limit_key_quota_credentials:insert({
            consumer = { id = consumer.id },
          }, { ttl = 10 })
          local res = assert(admin_client:send {
            method  = "GET",
            path    = "/consumers/bob/limit-key-quota/" .. credential.id
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.equal(credential.id, json.id)
          assert.not_nil(json.ttl)
        end)
      end)

      describe("PUT", function()
        after_each(function()
          db:truncate("limit_key_quota_credentials")
        end)
        it("creates a limit-key-quota credential with key", function()
          local res = assert(admin_client:send {
            method  = "PUT",
            path    = "/consumers/bob/limit-key-quota/1234",
            body    = {},
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.equal(consumer.id, json.consumer.id)
          assert.equal("1234", json.key)
        end)
        it("creates a limit-key-quota credential auto-generating the key", function()
          local res = assert(admin_client:send {
            method  = "PUT",
            path    = "/consumers/bob/limit-key-quota/c16bbff7-5d0d-4a28-8127-1ee581898f11",
            body    = {},
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.equal(consumer.id, json.consumer.id)
          assert.is_string(json.key)
        end)
      end)

      describe("PATCH", function()
        it("updates a credential by id", function()
          local res = assert(admin_client:send {
            method  = "PATCH",
            path    = "/consumers/bob/limit-key-quota/" .. credential.id,
            body    = { key = "4321" },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.equal("4321", json.key)
        end)
        it("updates a credential by key", function()
          local res = assert(admin_client:send {
            method  = "PATCH",
            path    = "/consumers/bob/limit-key-quota/" .. credential.key,
            body    = { key = "4321UPD" },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.equal("4321UPD", json.key)
        end)
        describe("errors", function()
          it("handles invalid input", function()
            local res = assert(admin_client:send {
              method  = "PATCH",
              path    = "/consumers/bob/limit-key-quota/" .. credential.id,
              body    = { key = 123 },
              headers = {
                ["Content-Type"] = "application/json"
              }
            })
            local body = assert.res_status(400, res)
            local json = cjson.decode(body)
            assert.same({ key = "expected a string" }, json.fields)
          end)
        end)
      end)

      describe("DELETE", function()
        it("deletes a credential", function()
          local res = assert(admin_client:send {
            method  = "DELETE",
            path    = "/consumers/bob/limit-key-quota/" .. credential.id,
          })
          assert.res_status(204, res)
        end)
        describe("errors", function()
          it("returns 400 on invalid input", function()
            local res = assert(admin_client:send {
              method  = "DELETE",
              path    = "/consumers/bob/limit-key-quota/blah"
            })
            assert.res_status(404, res)
          end)
          it("returns 404 if not found", function()
            local res = assert(admin_client:send {
              method  = "DELETE",
              path    = "/consumers/bob/limit-key-quota/00000000-0000-0000-0000-000000000000"
            })
            assert.res_status(404, res)
          end)
        end)
      end)
    end)
    describe("/plugins for route", function()
      it("fails with invalid key_names", function()
        local key_name = "hello\\world"
        local res = assert(admin_client:send {
          method  = "POST",
          path    = "/plugins",
          body    = {
            name  = "limit-key-quota",
            route = { id = route1.id },
            config     = {
              key_names = {key_name},
            },
          },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })
        assert.response(res).has.status(400)
        local body = assert.response(res).has.jsonbody()
        assert.equal("bad header name 'hello\\world', allowed characters are A-Z, a-z, 0-9, '_', and '-'",
                     body.fields.config.key_names[1])
      end)
      it("succeeds with valid key_names", function()
        local key_name = "hello-world"
        local res = assert(admin_client:send {
          method  = "POST",
          path    = "/plugins",
          body    = {
            route = { id = route2.id },
            name       = "limit-key-quota",
            config     = {
              key_names = {key_name},
            },
          },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })
        assert.response(res).has.status(201)
        local body = assert.response(res).has.jsonbody()
        assert.equal(key_name, body.config.key_names[1])
      end)
    end)
    describe("/limit-key-quotas", function()
      local consumer2

      describe("GET", function()
        lazy_setup(function()
          db:truncate("limit_key_quota_credentials")

          for i = 1, 3 do
            bp.limit_key_quota_credentials:insert {
              consumer = { id = consumer.id },
            }
          end

          consumer2 = bp.consumers:insert {
            username = "bob-the-buidler",
          }

          for i = 1, 3 do
            bp.limit_key_quota_credentials:insert {
              consumer = { id = consumer2.id },
            }
          end
        end)

        it("retrieves all the limit-key-quotas with trailing slash", function()
          local res = assert(admin_client:send {
            method = "GET",
            path = "/limit-key-quotas/",
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.is_table(json.data)
          assert.equal(6, #json.data)
        end)
        it("retrieves all the limit-key-quotas without trailing slash", function()
          local res = assert(admin_client:send {
            method = "GET",
            path = "/limit-key-quotas",
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.is_table(json.data)
          assert.equal(6, #json.data)
        end)
        it("paginates through the limit-key-quotas", function()
          local res = assert(admin_client:send {
            method = "GET",
            path = "/limit-key-quotas?size=3",
          })
          local body = assert.res_status(200, res)
          local json_1 = cjson.decode(body)
          assert.is_table(json_1.data)
          assert.equal(3, #json_1.data)

          res = assert(admin_client:send {
            method = "GET",
            path = "/limit-key-quotas",
            query = {
              size = 3,
              offset = json_1.offset,
            }
          })
          body = assert.res_status(200, res)
          local json_2 = cjson.decode(body)
          assert.is_table(json_2.data)
          assert.equal(3, #json_2.data)

          assert.not_same(json_1.data, json_2.data)
          assert.is_nil(json_2.offset) -- last page
        end)
      end)

      describe("POST", function()
        lazy_setup(function()
          db:truncate("limit_key_quota_credentials")
        end)

        it("does not create limit-key-quota credential when missing consumer", function()
          local res = assert(admin_client:send {
            method = "POST",
            path = "/limit-key-quotas",
            body = {
              key = "1234",
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(400, res)
          local json = cjson.decode(body)
          assert.same("schema violation (consumer: required field missing)", json.message)
        end)

        
      it("do not creates limit-key-quota credential with a string limit_key_quota ", function()
        local res = assert(admin_client:send {
          method = "POST",
          path = "/limit-key-quotas",
          body = {
            key = "1234",
            consumer = {
              id = consumer.id
            },
            limit_key_quota = "str",
          },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })
        assert.res_status(400, res)
      end)

      it("do not creates limit-key-quota credential with  limit_key_quota < 0 ", function()
        local res = assert(admin_client:send {
          method = "POST",
          path = "/limit-key-quotas",
          body = {
            key = "1234",
            consumer = {
              id = consumer.id
            },
            limit_key_quota = -1,
          },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })
        assert.res_status(400, res)
      end)

        it("creates limit-key-quota credential", function()
          local res = assert(admin_client:send {
            method = "POST",
            path = "/limit-key-quotas",
            body = {
              key = "1234",
              consumer = {
                id = consumer.id
              }
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(201, res)
          local json = cjson.decode(body)
          assert.equal("1234", json.key)
        end)
      end)
    end)

    describe("/limit-key-quotas/:credential_key_or_id", function()
      describe("PUT", function()
        lazy_setup(function()
          db:truncate("limit_key_quota_credentials")
        end)

        it("does not create limit-key-quota credential when missing consumer", function()
          local res = assert(admin_client:send {
            method = "PUT",
            path = "/limit-key-quotas/1234",
            body = { },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(400, res)
          local json = cjson.decode(body)
          assert.same("schema violation (consumer: required field missing)", json.message)
        end)

        it("creates limit-key-quota credential", function()
          local res = assert(admin_client:send {
            method = "PUT",
            path = "/limit-key-quotas/1234",
            body = {
              consumer = {
                id = consumer.id
              }
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.equal("1234", json.key)
        end)
      end)
    end)

    describe("/limit-key-quotas/:credential_key_or_id/consumer", function()
      describe("GET", function()
        local credential

        lazy_setup(function()
          db:truncate("limit_key_quota_credentials")
          credential = bp.limit_key_quota_credentials:insert {
            consumer = { id = consumer.id },
          }
        end)

        it("retrieve Consumer from a credential's id", function()
          local res = assert(admin_client:send {
            method = "GET",
            path = "/limit-key-quotas/" .. credential.id .. "/consumer"
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.same(consumer, json)
        end)
        it("retrieve a Consumer from a credential's key", function()
          local res = assert(admin_client:send {
            method = "GET",
            path = "/limit-key-quotas/" .. credential.key .. "/consumer"
          })
          local body = assert.res_status(200, res)
          local json = cjson.decode(body)
          assert.same(consumer, json)
        end)
        it("returns 404 for a random non-existing id", function()
          local res = assert(admin_client:send {
            method = "GET",
            path = "/limit-key-quotas/" .. utils.uuid()  .. "/consumer"
          })
          assert.res_status(404, res)
        end)
        it("returns 404 for a random non-existing key", function()
          local res = assert(admin_client:send {
            method = "GET",
            path = "/limit-key-quotas/" .. utils.random_string()  .. "/consumer"
          })
          assert.res_status(404, res)
        end)
      end)


    end)
  end)
end