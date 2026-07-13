#!/bin/sh
set -eu

BIND_ADDRESS=${BIND_ADDRESS:-127.0.0.1}
GRAFANA_PORT=${GRAFANA_PORT:-3000}
PROMETHEUS_PORT=${PROMETHEUS_PORT:-9090}
LOKI_PORT=${LOKI_PORT:-3100}
TEMPO_PORT=${TEMPO_PORT:-3200}
ALLOY_PORT=${ALLOY_PORT:-12345}

check() {
  name=$1
  url=$2
  printf 'Checking %s... ' "$name"
  curl --fail --silent --show-error "$url" >/dev/null
  echo ok
}

check Grafana "http://${BIND_ADDRESS}:${GRAFANA_PORT}/api/health"
check Prometheus "http://${BIND_ADDRESS}:${PROMETHEUS_PORT}/-/ready"
check Loki "http://${BIND_ADDRESS}:${LOKI_PORT}/ready"
check Tempo "http://${BIND_ADDRESS}:${TEMPO_PORT}/ready"
check Alloy "http://${BIND_ADDRESS}:${ALLOY_PORT}/-/ready"

echo "Smoke test passed."
