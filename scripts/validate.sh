#!/bin/sh
set -eu

docker compose config --quiet
docker compose run --rm --no-deps --entrypoint promtool prometheus \
  check config /etc/prometheus/prometheus.yml
docker compose run --rm --no-deps loki \
  -config.file=/etc/loki/loki.yml \
  -config.expand-env=true \
  -verify-config=true
docker compose run --rm --no-deps alloy \
  validate /etc/alloy/config.alloy

echo "Configuration validation passed."
