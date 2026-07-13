# Prometheus, Grafana, Loki, and Tempo

这是一套面向单台 Linux Docker 主机的可观测性环境：

- Prometheus 保存指标。
- Loki 保存 Docker 容器日志。
- Tempo 保存 OpenTelemetry 链路。
- Grafana 查询并关联指标、日志和链路。
- Grafana Alloy 自动发现 Docker 容器日志，并接收应用发送的 OTLP 链路。
- node-exporter 和 cAdvisor 分别提供主机与容器指标。

配置使用固定镜像版本、Docker 命名卷、自动配置的数据源，以及日志和链路保留策略。它适合开发、家庭实验室和单机服务；多节点生产环境应改用对象存储和编排平台。

## 启动

要求 Linux、Docker Engine、Docker Compose v2，以及当前用户访问 Docker socket 的权限。

```bash
cp .env.example .env
```

先修改 `.env` 中的 `GRAFANA_ADMIN_PASSWORD`，然后执行：

```bash
make validate
make up
make smoke
```

默认入口：

| 服务 | 地址 |
| --- | --- |
| Grafana | http://127.0.0.1:3000 |
| Prometheus | http://127.0.0.1:9090 |
| Loki | http://127.0.0.1:3100 |
| Tempo | http://127.0.0.1:3200 |
| Alloy | http://127.0.0.1:12345 |
| cAdvisor | http://127.0.0.1:8080 |
| node-exporter | http://127.0.0.1:9100 |

Grafana 已自动配置 Prometheus、Loki 和 Tempo。进入 Explore 或对应的 Drilldown 页面即可查询数据。

## 发送链路

宿主机上的应用可以将 OTLP 数据发送给 Alloy：

```bash
export OTEL_SERVICE_NAME=my-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

如果应用也运行在 Docker 中，将它加入名为 `observability` 的网络，并使用：

```text
http://alloy:4318
```

Compose 示例：

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

OTLP/gRPC 使用端口 `4317`，OTLP/HTTP 使用端口 `4318`。Alloy 将链路批量发送到 Tempo。Tempo 的 metrics-generator 会生成 span metrics 和 service graph metrics，并写回 Prometheus。

## 日志关联

Alloy 会通过 Docker socket 自动采集当前 Docker daemon 中的容器日志，并添加 `service_name`、`container`、`compose_project` 和 `stream` 标签。

要从日志跳转到 Tempo 链路，应用日志中应包含 32 位十六进制 Trace ID，例如：

```text
request failed trace_id=5b8efff798038103d269b633813fc60c
```

要从 Tempo span 跳转到日志，应用应同时使用一致的 OpenTelemetry `service.name` 和 Docker Compose service 名称。

## 数据保留

默认值可在 `.env` 中修改：

- Prometheus 指标：15 天。
- Loki 日志：360 小时，即 15 天。
- Tempo 链路：168 小时，即 7 天。

数据保存在 Docker 命名卷中。普通的 `docker compose down` 不会删除数据；`docker compose down -v` 会永久删除全部观测数据。

## 安全说明

Prometheus、Loki、Tempo 和 Alloy 本身未在这套配置中启用认证，因此管理接口默认只绑定到 `127.0.0.1`。不要直接把 `BIND_ADDRESS` 改成 `0.0.0.0` 并暴露到公网；远程使用时应配置防火墙、TLS 和带认证的反向代理。

OTLP 端口默认绑定 `0.0.0.0`，让其他主机或容器可以发送链路。若只接收本机应用，将 `OTLP_BIND_ADDRESS` 改为 `127.0.0.1`。

Alloy 对 Docker socket 有读取权限，cAdvisor 使用特权模式读取容器 cgroup。这两项能力只应部署在可信主机上。

## 常用命令

```bash
make ps
make logs
make restart
make down
```
