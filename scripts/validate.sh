#!/bin/sh
set -eu

datasource_file=grafana/provisioning/datasources/datasources.yml

if awk '
  /^[[:space:]]*-[[:space:]]name:[[:space:]]Tempo[[:space:]]*$/ {
    in_tempo = 1
    next
  }
  /^[[:space:]]*-[[:space:]]name:/ && in_tempo {
    in_tempo = 0
    in_streaming = 0
  }
  in_tempo && /^[[:space:]]*streamingEnabled:[[:space:]]*$/ {
    in_streaming = 1
    next
  }
  in_tempo && in_streaming && /^[[:space:]]*metrics:[[:space:]]*true[[:space:]]*$/ {
    found = 1
  }
  END {
    exit found ? 0 : 1
  }
' "$datasource_file"; then
  echo "Tempo datasource must not enable streamingEnabled.metrics against the HTTP Tempo URL." >&2
  exit 1
fi

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
