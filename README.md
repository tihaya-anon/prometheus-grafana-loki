# Prometheus, Grafana, Loki, and Tempo

This observability stack is designed for a single Linux Docker host:

- Prometheus stores metrics.
- Loki stores Docker container logs.
- Tempo stores OpenTelemetry traces.
- Grafana queries and correlates metrics, logs, and traces.
- Grafana Alloy discovers Docker container logs and receives OTLP metrics and traces from applications.
- node-exporter and cAdvisor provide host and container metrics.

The configuration uses pinned image versions, Docker named volumes, provisioned data sources, and retention policies for metrics, logs, and traces. It is suitable for development, home labs, and single-host services. Multi-node production environments should use object storage and an orchestration platform.

## Start

Requirements:

- Linux
- Docker Engine
- Docker Compose v2
- Permission to access the Docker socket

Create the local environment file:

```bash
cp .env.example .env
```

Change `GRAFANA_ADMIN_PASSWORD` in `.env`, then start and verify the stack:

```bash
make validate
make up
make smoke
```

Default endpoints:

| Service | Address |
| --- | --- |
| Grafana | http://127.0.0.1:3000 |
| Prometheus | http://127.0.0.1:9090 |
| Loki | http://127.0.0.1:3100 |
| Tempo | http://127.0.0.1:3200 |
| Alloy | http://127.0.0.1:12345 |
| cAdvisor | http://127.0.0.1:8080 |
| node-exporter | http://127.0.0.1:9100 |

Grafana automatically provisions Prometheus, Loki, and Tempo as data sources. Use Grafana Explore or the corresponding Drilldown view to query the data.

## Send Metrics and Traces

Applications running on the host can send OTLP data to Alloy:

```bash
export OTEL_SERVICE_NAME=my-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

If the application also runs in Docker, attach it to the `observability` network and use:

```text
http://alloy:4318
```

Example Compose configuration:

```yaml
services:
  app:
    networks:
      - default
      - observability
    environment:
      OTEL_SERVICE_NAME: app
      OTEL_EXPORTER_OTLP_ENDPOINT: http://alloy:4318
      OTEL_EXPORTER_OTLP_PROTOCOL: http/protobuf

networks:
  observability:
    external: true
```

OTLP/gRPC uses port `4317`, and OTLP/HTTP uses port `4318`. Alloy converts OTLP metrics to Prometheus format and writes them to Prometheus, while traces are batched and sent to Tempo. Tempo's `metrics-generator` also produces span metrics and service graph metrics and writes them to Prometheus.

## Log Correlation

Alloy discovers containers through the Docker socket and adds the `service_name`, `container`, `compose_project`, and `stream` labels to their logs.

For links from logs to Tempo traces, application logs should contain a 32-character hexadecimal trace ID:

```text
request failed trace_id=5b8efff798038103d269b633813fc60c
```

For links from Tempo spans to logs, use the same OpenTelemetry `service.name` and Docker Compose service name.

## Data Retention

The default values can be changed in `.env`:

- Prometheus metrics: 15 days
- Loki logs: 360 hours, or 15 days
- Tempo traces: 168 hours, or 7 days

Data is stored in Docker named volumes. A normal `docker compose down` preserves the data. Running `docker compose down -v` permanently deletes all observability data.

## Security

Prometheus, Loki, Tempo, and Alloy do not have authentication enabled in this stack, so their management endpoints bind to `127.0.0.1` by default. Do not expose them publicly by changing `BIND_ADDRESS` to `0.0.0.0` without also configuring a firewall, TLS, and an authenticated reverse proxy.

OTLP ports bind to `0.0.0.0` by default so applications on other hosts or in other containers can send metrics and traces. Set `OTLP_BIND_ADDRESS=127.0.0.1` when only local applications should send telemetry.

Alloy has read access to the Docker socket, and cAdvisor runs in privileged mode to read container cgroups. Deploy these capabilities only on trusted hosts.

## Common Commands

```bash
make ps
make logs
make restart
make down
```
