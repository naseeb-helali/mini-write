# VM Deployment

## 1. Deployment model

The VM deployment path runs Mini-Write on a Linux host using Docker Compose. Ansible prepares the host and installs/configures the runtime; Nginx provides the HTTP gateway; the deployment adapter applies a selected application image and verifies the runtime according to the VM scripts.

## 2. Provisioning boundary

All VM host configuration belongs to `infra/ansible/`. Its roles cover base host setup, Docker, deployment runtime, security baseline, and GitHub runner installation. The deployment runtime role renders Compose, environment, Nginx, deployment, rollback, and runtime support scripts into the target host's deployment directory.

This is the legacy VM provisioning track. It is intentionally separate from `infra/kubernetes-ec2/ansible/`.

## 3. Runtime topology

The VM Compose template defines API, Worker, Nginx, and supporting runtime services. The application API is configured to listen on port 80 in the VM Ansible template, matching the Nginx upstream and VM health-check expectations. This differs from the 8080 default used in ECS/Kubernetes application containers, where service/task mappings expose the expected port.

The root `.env.example` contains `HTTP_PORT=8080`, while the root Compose healthcheck and Nginx upstream use `api:80`. Treat the example file as a generic template that requires alignment with the selected Compose context; do not use it as proof that every deployment uses the same port.

## 4. Deployment flow

The high-level flow is:

1. CI builds and publishes the API and Worker images.
2. The CD workflow selects the VM deployment target and release identity.
3. The VM adapter performs deployment preflight and applies the requested image references.
4. Runtime verification checks the configured service/health behavior.
5. Deployment state is retained for subsequent rollback/recovery.
6. Rollback uses the previous recorded deployment state rather than inventing a new image identity.

Exact command-line arguments and state transitions are defined by the adapter scripts and rendered runtime templates. Operators should inspect the current scripts before manually invoking destructive or state-changing commands.

## 5. Host and runner relationship

The same VM-oriented Ansible project includes a GitHub Actions runner role. The runner is a privileged operational component because deployment workflows execute from it and it has Docker access. Its availability and credential state affect the VM delivery path and may also be used by other workflows in the repository.

## 6. Observability

The VM runtime role copies Prometheus, Loki, Promtail, Grafana, dashboard, and Alertmanager configuration into the deployment runtime. This is the most complete self-managed observability configuration in the reviewed repository. Actual alert delivery depends on active receiver configuration; commented receiver definitions do not establish outbound notifications.

## 7. Evidence and verification boundary

The repository contains the VM provisioning and deployment implementation. However, the reviewed `evidence/` directory does not contain a dedicated VM deployment/rollback evidence package comparable to the ECS and Kubernetes evidence.

Therefore:

- It is valid to describe the VM deployment architecture and automation present in source.
- It is valid to describe the user's reported deployment history as reported, if needed.
- It is not valid to invent VM deployment duration, rollback duration, or independently verified runtime success from this archive.

## 8. Operational considerations

- Confirm host inventory and SSH access before provisioning.
- Confirm the intended environment variables and port mapping before deployment.
- Ensure the runner has the expected Docker and AWS/GitHub credentials for the workflow being run.
- Preserve deployment state files and lock behavior during recovery.
- Verify Nginx-to-API connectivity and application readiness after a change.

## 9. Source map

- `.github/workflows/cd.yml`
- `docker-compose.yml`
- `proxy/nginx.conf`
- `infra/ansible/inventories/staging/`
- `infra/ansible/playbooks/site.yml`
- `infra/ansible/roles/deploy_runtime/`
- `infra/ansible/roles/security_baseline/`
- `infra/ansible/roles/github_runner/`
- `ci/deployment/adapters/vm/`
- `ci/deployment/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../../06-engineering-evidence/validation-and-limitations.md) where applicable.
