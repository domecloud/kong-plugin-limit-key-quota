#!/usr/bin/env bash
KONG_VERSION=3.4.0 ./kong-pongo/pongo.sh run -v -o gtest ./plugins/limit-key-quota/spec