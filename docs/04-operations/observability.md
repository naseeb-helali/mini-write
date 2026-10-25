# Observability

## 1. Purpose

Observability in Mini-Write supports practical operation of the application and its deployment infrastructure. It provides signals that help determine whether services are alive, whether dependencies are available, whether asynchronous work is progressing, and whether infrastructure is behaving as expected.

The implementation is platform-dependent. The repository does not establish identical observability coverage for VM, ECS, and Kubernetes.

## 2. Application signals

The API and Worker contain observability modules and health interfaces. The API exposes `/health/live`, `/health/ready`, and `/metrics`. The Worker exposes metrics through its configured metrics server (port 9464 in the reviewed source).

Liveness and readiness have different meanings:

- **Liveness** answers whether the process should be considered alive and restarted if it is not.
- **Readiness** answers whether the workload is currently prepared to receive work/traffic given its required dependencies.
- **Metrics** provide time-series measurements for trends, rates, latency, queue behavior, and resource consumption.

A healthy process is not necessarily a ready application. Likewise, a ready API does not prove that every asynchronous job will complete successfully.

## 3. VM / Compose observability stack

The repository includes configuration for:

- Prometheus scraping and rule evaluation.
- Loki log storage.
- Promtail log collection.
- Grafana datasources, dashboard provisioning, and dashboards.
- Alertmanager configuration.
- cAdvisor and host/database/cache exporter integration where defined by the Compose and Prometheus configuration.

Dashboards are grouped around application health, deployment operations, queue operations, and system overview. This is useful for correlating application behavior with deployment and infrastructure signals.

The VM Ansible deployment role copies the observability configuration into the deployed runtime. Alertmanager receiver configuration must be interpreted carefully: commented-out receiver blocks do not prove that outbound notifications are active.

## 4. AWS ECS observability

Terraform defines CloudWatch resources for the AWS environment. ECS tasks emit logs to the configured AWS logging path and CloudWatch alarms/metrics provide selected infrastructure/service signals.

This is not the same stack as the self-managed Prometheus/Loki/Grafana deployment. Do not describe CloudWatch configuration as proof that every application-level metric or log is centrally collected.

## 5. Kubernetes observability

The Kubernetes workload manifests include readiness probes and the deployment workflow checks Pod/container readiness. These are operational health controls, but they are not a complete observability stack.

No Kubernetes-specific Prometheus, Loki, Grafana, or cluster logging deployment was identified in the reviewed repository. Therefore, the documentation should describe Kubernetes readiness verification while clearly stating that centralized Kubernetes metrics/logging coverage is not established by this source snapshot.

## 6. Correlation and troubleshooting

For a typical incident, correlate:

1. External request and Nginx/API behavior.
2. API health and request metrics.
3. Queue depth and Worker processing behavior.
4. Database/cache availability.
5. Object-storage errors.
6. Host/container or cloud service resource signals.
7. Deployment version and rollout events.

This correlation helps distinguish an application defect from a dependency outage, queue backlog, resource constraint, or bad deployment.

## 7. Alerting boundaries

Alert rules and dashboards represent configured detection logic. They do not prove an alert was delivered, acknowledged, or resolved. Evidence of notification delivery and incident response would be required for those claims.

## 8. Source map

- `api/src/observability/`
- `api/src/health/`
- `worker/src/observability/`
- `worker/src/health/`
- `observability/prometheus/`
- `observability/loki/`
- `observability/promtail/`
- `observability/grafana/`
- `observability/alertmanager/`
- `infra/ansible/roles/deploy_runtime/files/observability/`
- `infra/terraform/environments/staging/cloudwatch.tf`
- `infra/terraform/modules/cloudwatch/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
