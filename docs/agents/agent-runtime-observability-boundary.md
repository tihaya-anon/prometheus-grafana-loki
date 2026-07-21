# Agent Runtime Observability Boundary

Status: guidance for Agent Run integration.

This repository provides observability infrastructure only. It should not own Agent Run runtime
semantics, Python graph behavior, or TypeScript product API behavior.

## Owned Here

- Prometheus metrics storage and scraping.
- Loki log storage.
- Tempo trace storage.
- Grafana dashboards and data sources.
- Alloy collection and OTLP routing.

## Owned Elsewhere

- `agent-runtime-python` owns LangGraph execution and runtime-internal telemetry attributes emitted
  by the Python worker/service.
- `agent-workbench` owns `POST /api/agent-runs`, browser-facing stream semantics, runtime profile
  policy, behavior-version acceptance, and product-path tests.

## Integration Guidance

Agent Run services can send traces and metrics to Alloy over OTLP:

```text
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

Keep `service.name` stable and distinct, for example `teach-everything-api` for the TS gateway and
`agent-runtime-python` for the Python runtime. Use the same Agent Run id attribute across services
so traces, logs, and metrics can be correlated.

This repository may add dashboards or smoke checks that observe an Agent Run path, but those checks
must not define the runtime protocol or product API contract. Contract tests belong in
`agent-workbench`; graph/runtime tests belong in `agent-runtime-python`.
