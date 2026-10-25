# AWS Infrastructure

## 1. Overview

AWS infrastructure in Mini-Write supports the ECS deployment path and the self-managed Kubernetes-on-EC2 path. The Staging Terraform environment defines shared networking and data services alongside platform-specific compute resources.

## 2. Network foundation

The VPC module and Staging environment define the network boundary, subnets, routing, and security groups. The ALB provides an external entry point for the configured AWS deployment path. Security groups govern communication among the load balancer, compute nodes, database, and cache.

For Kubernetes, the security group configuration includes cluster communication such as TCP 6443 for the Kubernetes API, TCP 10250 for kubelet, Calico-related networking ports, and NodePort 30080 from the ALB. The presence of the NodePort rule must not be mistaken for a working application path: the reviewed workload Services are ClusterIP and no corresponding NodePort/Ingress/Gateway integration was identified.

## 3. Compute

### ECS

The ECS Terraform configuration defines the managed container runtime path. Task definitions and services use ECR image references and connect to the configured AWS data services.

### Kubernetes on EC2

The Kubernetes EC2 module defines the control-plane and worker instances. The reviewed target is one control-plane node and two worker nodes. The control-plane is a single point of control-plane availability; this is a practical learning topology, not an HA cluster.

Nodes are configured as private instances, use Ubuntu 24.04 in the reviewed configuration, and are prepared for containerd and kubeadm. IMDSv2 is required and encrypted gp3 disks are configured. The cluster is self-managed; this is not EKS.

## 4. Container registry

ECR stores the API and Worker container images used by AWS deployment paths. CI builds images and the delivery workflows use immutable SHA/digest identity rather than relying on a mutable `latest` tag for normal release promotion.

The ECS task definition bootstrap configuration includes a `latest` reference in the reviewed Terraform source while the CI workflow publishes SHA-tagged artifacts. This is a first-provisioning alignment concern and should be checked before describing initial task startup as fully consistent with the CI artifact contract.

## 5. Database

The RDS module provisions PostgreSQL for AWS deployment contexts. The reviewed Staging configuration includes Multi-AZ enabled, backup retention set to zero, deletion protection disabled, and final snapshot skipping enabled. These are Staging choices and must not be represented as a hardened Production database policy.

The PostgreSQL parameter configuration sets `rds.force_ssl=0`; do not claim database-side mandatory TLS enforcement based on the current configuration.

## 6. Cache and queue backend

The Terraform ElastiCache module configures Valkey, while local Compose uses Redis. The AWS Staging configuration uses a single cache node without automatic failover and with at-rest encryption enabled; transit encryption is disabled in the reviewed configuration.

BullMQ uses the Redis-compatible service as its queue backend. The distinction between Redis locally and Valkey in AWS should be preserved in technical descriptions.

## 7. Object storage

The S3 module configures bucket versioning and server-side encryption using AES256, and blocks public access. Application storage integration is implemented through the S3 provider.

The MinIO provider remains available for non-AWS/local deployment contexts. The use of an abstraction does not imply cross-environment replication.

## 8. Secrets and IAM

Secrets Manager resources provide AWS-side secret storage. IAM roles and policies support infrastructure automation, runner deployment, node access, and application/runtime needs.

The Kubernetes nodes use an EC2 instance role that includes permissions for image pulls and selected AWS services. The reviewed repository does not demonstrate per-Pod identity through IRSA or an equivalent mechanism. Avoid claiming workload-level identity isolation.

GitHub OIDC is configured for workflow access to AWS. The Kubernetes workflow uses the existing `mini-write-github-cd-runner` role with Kubernetes-related permissions; a separately defined Kubernetes CD role appears in the Terraform source but is not the role referenced by the workflow configuration. Document the active role reference, not merely the existence of an IAM resource.

## 9. CloudWatch

CloudWatch resources are defined for AWS operational visibility. The configuration supports AWS-side monitoring/logging for the ECS-oriented environment. It should not be described as a complete Kubernetes cluster observability stack.

## 10. Infrastructure evidence and limitations

The infrastructure automation closure records successful Terraform plan/apply and a post-apply no-change plan for the tested Staging scope. It also records the IAM policy inventory for the inspected apply role. That inventory does not by itself prove least privilege for all possible operations.

The Production Terraform directory is a scaffold in the reviewed archive. There is no evidence of a separate Production AWS environment being provisioned from it.

## 11. Source map

- `infra/terraform/environments/staging/`
- `infra/terraform/modules/vpc/`
- `infra/terraform/modules/security-groups/`
- `infra/terraform/modules/alb/`
- `infra/terraform/modules/ecs/`
- `infra/terraform/modules/kubernetes-ec2/`
- `infra/terraform/modules/rds/`
- `infra/terraform/modules/elasticache/`
- `infra/terraform/modules/s3/`
- `infra/terraform/modules/ecr/`
- `infra/terraform/modules/secrets/`
- `infra/terraform/modules/iam/`
- `infra/terraform/modules/cloudwatch/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
