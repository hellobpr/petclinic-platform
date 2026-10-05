# Project Workflow — Petclinic Platform

**Last Updated:** 2026-09-24

**Purpose:** End-to-end explanation of what this project is, how its pieces fit together, and
the exact ordered steps to take it from an empty AWS account to running microservices — plus
the day-to-day flow once it is running.

---

## Table of Contents

1. [What this project is for](#1-what-this-project-is-for)
2. [The two repositories](#2-the-two-repositories)
3. [What the running system looks like](#3-what-the-running-system-looks-like)
4. [How the work is organised](#4-how-the-work-is-organised)
5. [Part A — Build the platform from zero](#part-a--build-the-platform-from-zero)
6. [Part B — The day-to-day change flow](#part-b--the-day-to-day-change-flow)
7. [Current status](#7-current-status)
8. [What it costs](#8-what-it-costs)
9. [Known issues and gotchas](#9-known-issues-and-gotchas)
10. [Quick reference](#10-quick-reference)

---

## 1. What this project is for

Take an existing open-source Spring Boot application — [Spring Petclinic
Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices), 8 services
— and build **everything needed to run it properly on AWS**: network, cluster, database,
registry, secrets, DNS, CI, GitOps deployment, observability, and the operational docs a team
would need to inherit it.

The application code is not the point. The platform around it is. Specifically it answers:

- How does infrastructure get created reproducibly, and how do two environments stay separate?
- How does a developer's commit become a running container, without anyone typing `kubectl apply`?
- Where do secrets live, and how do pods get them without secrets in Git?
- What does this cost, and what gets traded away to keep it cheap?

It is a learning project, so several decisions deliberately favour cost over production
rigour. Those are flagged as they come up rather than hidden — understanding the trade-off is
part of the point.

---

## 2. The two repositories

```text
springboot-petclinic/                      <- parent folder (not a git repo)
├── spring-petclinic-microservices/        <- the APPLICATION. READ-ONLY. Never modify.
└── petclinic-platform/                    <- the INFRASTRUCTURE. All work happens here.
```

Everything in this document refers to `petclinic-platform/`. The application repo is a
reference: you read it to learn which ports services use and which need a database, but you
never change it.

### Layout of petclinic-platform

| Path | Holds |
|------|-------|
| `terraform/environments/{dev,prod}/` | One root module per environment. This is what you `apply`. |
| `terraform/modules/` | Reusable modules: vpc, eks, ecr, rds, dns, secrets, observability |
| `helm/petclinic-service/` | **One** generic Helm chart, shared by all 8 services |
| `helm-values/` | Per-service values (`customers-service.yaml`) + per-env (`dev.yaml`, `prod.yaml`) |
| `k8s/base/` | Namespaces, ExternalSecret CRs |
| `k8s/argocd/` | ArgoCD install manifests + one Application CRD per service per env |
| `.github/workflows/` | CI only — build and push. Never deploys. |
| `scripts/` | `bootstrap-state.sh`, env start/stop/status helpers |
| `docs/` | `technical-spec.md` (all the numbers), `jira-backlog.md` (all the work) |
| `.claude/` | Agent guardrails: hooks, rules, agents, skills, prompts |

---

## 3. What the running system looks like

Request path, once everything is deployed:

```text
Internet
   │  HTTPS
   ▼
Route 53  ──>  ACM cert
   │
   ▼
Application Load Balancer          (public subnets, ALB security group: 80/443 from 0.0.0.0/0)
   │  NodePort 30000-32767
   ▼
EKS worker nodes                   (public subnets, t4g.small ARM/Graviton)
   │
   ├─ api-gateway        :8080     <- the only service the ALB routes to
   │     │
   │     ├─> customers-service :8081 ─┐
   │     ├─> visits-service    :8082 ─┼─> RDS MySQL :3306
   │     ├─> vets-service      :8083 ─┘    (public subnet, SG allows nodes ONLY)
   │     └─> genai-service     :8084
   │
   ├─ config-server      :8888     <- starts FIRST, Git-backed config
   ├─ discovery-server   :8761     <- starts SECOND, Eureka registry
   └─ admin-server       :9090
```

Two things about this shape are unusual and deliberate:

**Everything sits in public subnets.** There are no private subnets and no NAT Gateway. That
saves roughly $35–65/month, and it means **security groups are the entire perimeter**. The
RDS security group allowing `3306` from the node security group _only_ is the single most
important rule in the whole configuration, because the database is in a public subnet.

The rationale is ADR-0001. That file (`docs/adr/0001-public-subnets.md`) is written in E-15
(PETPLAT-81) and does not exist yet; until then the decision is recorded in
`docs/technical-spec.md#architecture-decision`.

**Startup order matters.** `config-server` must be up before `discovery-server`, and both
before everything else. Init containers enforce this.

---

## 4. How the work is organised

Three documents drive everything, in this order:

```text
docs/technical-spec.md     ── every concrete value: CIDRs, ports, instance sizes,
                              IAM policies, probe timings, alert thresholds.
                              AUTHORITATIVE. If code and spec disagree, one of them is a bug.
        │
        ▼
docs/jira-backlog.md       ── 17 epics, ~107 stories (PETPLAT-xxx). Each story has
                              acceptance criteria and links to its spec section.
        │
        ▼
.claude/ + CLAUDE.md       ── conventions and guardrails so the work comes out consistent
```

### The epic dependency chain

```text
E-0  Claude Code setup
 └─> E-1  Foundation & remote state
      └─> E-2  VPC
           ├─> E-3  EKS ──> E-8 K8s base ──> E-16 Helm ──> E-17 ArgoCD ──> E-14 Karpenter
           ├─> E-5  RDS ──> E-7 Secrets ──┘
           └─> E-6  DNS & Ingress
     E-4  ECR (parallel, only needs E-1)
     E-10 CI (needs E-4 + E-16)
     E-11 Observability, E-13 Security (parallel after E-3)
     E-15 Docs (ongoing)
```

Read it as: **you cannot build the cluster before the network, or deploy before the chart
exists.** E-4 (ECR) is the one big thing you can do early and in parallel.

### Guardrails (`.claude/`)

| Thing | Where | Does what |
|-------|-------|-----------|
| Hooks | `.claude/hooks/` | Block `terraform destroy`, block `rm -rf` on infra dirs, block `git add .`, warn on `apply` without a saved plan |
| Rules | `.claude/rules/` | Auto-load conventions when editing `*.tf`, `k8s/**`, `helm/**`, `docs/**` |
| Agents | `.claude/agents/` | Read-only reviewers: terraform, k8s, security, cost, docs, pipeline |
| Skills | `.claude/skills/` | `/terraform-plan`, `/deploy-dev`, `/rollback`, `/smoke-test`, … |

The hooks use a 3-tier model: **exit 2 = blocked**, **exit 1 = warn and ask**, **exit 0 =
informational**. They require `jq` on PATH — without it they exit 127, which Claude Code
treats as a non-blocking error, meaning **the guardrails silently fail open**. Verify with:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"terraform destroy"}}' \
  | bash .claude/hooks/block-destroy.sh; echo "exit=$?"   # must print exit=2
```

---

## Part A — Build the platform from zero

Ordered, end to end. Each step maps to epics in `docs/jira-backlog.md`.

### Step 0 — Prerequisites

```bash
aws --version          # AWS CLI v2
terraform version      # >= 1.6.0
kubectl version --client
helm version
jq --version           # required by the safety hooks
aws sts get-caller-identity   # must return your account
```

Open Claude Code with **`petclinic-platform/` as the workspace root**, not the parent folder.
Project-scoped `.mcp.json` resolves relative to the session's working directory; from the
parent, `/mcp` reports "No MCP servers are configured" and none load. Add the app repo back
with `/add-dir ../spring-petclinic-microservices`.

### Step 1 — Remote state  (E-1)

State must live somewhere shared and locked before anything else is created. This runs
_outside_ Terraform, because Terraform cannot manage the bucket holding its own state.

```bash
./scripts/bootstrap-state.sh            # add --dry-run to preview
```

Creates:
- S3 `petclinic-terraform-state-{account-id}` — versioning on, AES256, all 4 public-access blocks on
- DynamoDB `petclinic-terraform-locks` — partition key `LockID` (String)
- `terraform/environments/{dev,prod}/backend.hcl` — gitignored, holds the resolved bucket name

The script is idempotent; re-running it changes nothing.

```bash
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform validate
```

> `backend.tf` is a **partial configuration** — `bucket` is omitted because the name embeds
> the account ID and a `backend` block cannot interpolate. That is why `-backend-config` is
> required; plain `terraform init` will prompt instead.

### Step 2 — Network  (E-2)

```bash
cd terraform/environments/dev
terraform plan -out plan.out      # expect 24 resources
terraform apply plan.out
```

VPC `10.0.0.0/16` (prod: `10.1.0.0/16`), two public subnets across two AZs, IGW, one route
table with `0.0.0.0/0` → IGW, and the four security groups. **No NAT Gateway.** All free.

Verify, rather than trusting the apply output:

```bash
VPC=$(terraform output -raw vpc_id)
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" --query 'length(NatGateways)'   # 0
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].{AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch}' --output table
```

### Step 3 — Cluster  (E-3)

```bash
terraform plan -out plan.out      # expect 16 more resources
terraform apply plan.out          # ~15 min; THIS COSTS MONEY — see section 8
$(terraform output -raw kubeconfig_command)
kubectl get nodes                 # expect 2 Ready
kubectl get pods -n kube-system    # coredns + kube-proxy Running
```

Creates the EKS cluster, OIDC provider for IRSA, a managed node group via launch template,
and four pinned add-ons (vpc-cni, kube-proxy, coredns, aws-ebs-csi-driver).

> The node group needs a **launch template**, not for style but because a bare
> `aws_eks_node_group` has no way to attach your own security group, and because EKS node
> root volumes are **unencrypted by default**, violating security rule 4.

### Step 4 — Registry  (E-4)

8 ECR repositories per environment, scan-on-push, lifecycle policies, `MUTABLE` in dev and
`IMMUTABLE` in prod. Independent of E-2/E-3, so it can be done any time after E-1.

### Step 5 — Database and secrets  (E-5, E-7)

1. RDS MySQL `db.t4g.micro`, single-AZ, encrypted at rest, in the public subnets with the
   RDS security group as its only protection.
2. Credentials go into **AWS Secrets Manager** — never into Terraform outputs or Git.
3. Install External Secrets Operator in the cluster, give it an IRSA role.
4. `ExternalSecret` CRs pull from Secrets Manager and materialise real Kubernetes Secrets.

This is the chain that keeps secrets out of Git entirely:

```text
AWS Secrets Manager ──> External Secrets Operator (IRSA) ──> K8s Secret ──> pod env var
```

### Step 6 — Ingress and DNS  (E-6)

Route 53 hosted zone, ACM certificate, AWS Load Balancer Controller in the cluster, and an
Ingress for `api-gateway`. The controller finds subnets via the
`kubernetes.io/role/elb = 1` tag applied back in E-2 — which is why that tag matters.

### Step 7 — Package the services  (E-8, E-16)

One generic Helm chart in `helm/petclinic-service/` serves all 8 services. Differences live
in values files, not in templates:

```text
helm/petclinic-service/        + helm-values/customers-service.yaml   (ports, env, init containers)
                               + helm-values/dev.yaml                 (1 replica, small limits)
                                 ──────────────────────────────────
                                 = the dev release of customers-service
```

Validate before committing:

```bash
helm template test helm/petclinic-service/ \
  -f helm-values/customers-service.yaml -f helm-values/dev.yaml
```

Every Deployment must have readiness and liveness probes on
`/actuator/health/{readiness,liveness}`, plus resource requests and limits.

### Step 8 — GitOps  (E-17)

```bash
kubectl apply -n argocd -f k8s/argocd/install/
kubectl apply -f k8s/argocd/applications/dev/
kubectl port-forward svc/argocd-server -n argocd 8443:443
```

16 `Application` CRDs — 8 services × 2 environments. **Dev auto-syncs** (prune + self-heal);
**prod requires manual sync**. From here on, nobody runs `kubectl apply` to deploy.

### Step 9 — CI  (E-10)

GitHub Actions with OIDC federation to AWS — no long-lived keys. The role can push to ECR
and nothing else; CI never runs Terraform.

### Step 10 — Harden and observe  (E-11, E-13, E-14)

Prometheus + Grafana, Loki + FluentBit, Zipkin; Checkov scans, network policies, IAM
tightening, Trivy; Karpenter and budget alerts.

---

## Part B — The day-to-day change flow

Once built, this is the loop that matters. **The key idea: CI builds, Git decides, ArgoCD
deploys.** No pipeline ever touches the cluster.

```text
1. Developer pushes application code to main
            │
            ▼
2. GitHub Actions  build-push.yml
   ├─ JDK 17, Docker Buildx + QEMU  (runners are x86, nodes are ARM64 — cross-compile)
   ├─ ./mvnw clean install -P buildDocker -Dcontainer.platform="linux/arm64"
   ├─ Trivy scan — fails the build on CRITICAL CVEs
   └─ Push to ECR, tagged with the 7-char commit SHA. Never "latest".
            │
            ▼
3. GitHub Actions  update-image-tags.yml
   └─ yq -i ".image.tag = \"$SHA\"" helm-values/{service}.yaml
      git commit -m "ci: update image tags to $SHA"
            │
            ▼                         <-- the Git commit IS the deployment trigger
4. ArgoCD notices the commit
   ├─ dev   : auto-syncs immediately (prune + self-heal)
   └─ prod  : shows OutOfSync, waits for a human
            │
            ▼
5. Rolling update in the cluster; probes gate the rollout
```

So: **to deploy, you change a tag in Git.** To roll back, you revert that change — or
`argocd app rollback`. The cluster's desired state is always whatever `main` says, which is
why `self-heal` can safely undo manual `kubectl edit` meddling.

### Promoting dev → prod

```bash
argocd app diff customers-service-prod      # review first
argocd app sync customers-service-prod      # explicit, human-approved
```

### Infrastructure changes (a different loop)

Infrastructure is **not** GitOps-driven. It is applied deliberately by a human:

```bash
cd terraform/environments/dev
terraform fmt -recursive
terraform validate
terraform plan -out plan.out     # review resource counts, and every destroy
terraform apply plan.out         # only ever apply a saved plan
```

Never `terraform apply` without a saved plan — a hook warns, because re-planning at apply
time can produce changes you never reviewed. `terraform destroy` is blocked outright.

---

## 7. Current status

| Epic | State |
|------|-------|
| E-0 Claude Code setup | **Done.** 6 hooks, 5 rules, 6 agents, 9 skills; all hooks exercised and returning correct exit codes |
| E-1 Foundation & state | **Done and live.** S3 bucket + DynamoDB table created and verified; both envs `init` cleanly |
| E-2 VPC | **Done. Dev applied and verified live** (24 resources, 0 NAT). Prod planned only |
| E-3 EKS | **Built, validated, planned — NOT applied.** Dev plan is 16 resources, saved at `terraform/environments/dev/plan.out`. Held at the cost gate |
| E-4 … E-17 | Not started |

Live AWS resources today: the state bucket, the lock table, and the **dev VPC** with its four
security groups. Nothing is running yet, so current spend is ~$0.

Two spec amendments were required because the original values are no longer buildable, both
recorded in the backlog and the spec:

- **Kubernetes `1.29` → `1.35`.** 1.29 can no longer be created; the EKS API offers only
  1.31–1.36 for new clusters.
- **`ami_type` `AL2_ARM_64` → `AL2023_ARM_64_STANDARD`.** Amazon Linux 2 EKS AMIs ended
  after 1.32.

---

## 8. What it costs

E-1 and E-2 are genuinely free. **E-3 is where billing starts**, and the control plane is
charged whether or not any workload runs.

| Item | Est./month (dev) | Notes |
|------|-----------------|-------|
| EKS control plane | ~$73 | $0.10/hr, flat, per cluster. Unavoidable. |
| 2× t4g.small nodes | ~$12 | See the free-trial caveat below |
| 40 GB gp3 EBS | ~$1–4 | 2 × 20 GB |
| CloudWatch Logs | variable | `audit` logging is the usual surprise |
| RDS db.t4g.micro | ~$0–15 | Free tier for 12 months on new accounts |
| ALB | ~$18 | Once E-6 lands |
| NAT Gateway | **$0** | Deliberately none — ADR-0001 |
| **Total** | **~$90–120** | Roughly doubles if prod is also applied |

Estimates from published eu-central-1 rates, not the pricing API. Treat as indicative.

> **Free-trial caveat.** The Graviton free trial is **750 hours/month**. Two nodes running
> continuously is ~1,460 hours, so only about half is covered — the spec's "free trial until
> Dec 2026" note reads as though nodes are free, and they are not. Dropping `desired_size`
> to 1 fits the allowance but gives up the two-AZ resilience the stories ask for.

Use `scripts/stop-env.sh` / `start-env.sh` to park dev when idle. The control plane keeps
billing regardless; only nodes and RDS stop.

---

## 9. Known issues and gotchas

**Git does not work in this repo.** It is owned by `BUILTIN/Administrators` while you run as
a normal user, so every git command aborts with "dubious ownership". Nothing can be
committed until:

```bash
git config --global --add safe.directory C:/Users/2079019/springboot-petclinic/petclinic-platform
```

**Open the workspace at `petclinic-platform/`, not the parent.** Project `.mcp.json` resolves
at the session working directory. From the parent, no MCP servers load at all, while
`CLAUDE.md` and skills still do — which makes it look like an auth problem when it is not.

**Project MCP servers need approval.** Names must be listed in
`.claude/settings.local.json` under `enabledMcpjsonServers`, or they sit at "pending
approval" forever.

**`jq` is a hard dependency of the safety hooks.** Without it they exit 127 and fail open.
Same for `uvx` (`uv`) if you use the stdio MCP servers.

**The RDS security group has no egress rules at all.** A Terraform-managed security group with
no egress rule permits nothing outbound, unlike the AWS console default of allow-all. This is
intentional, but it will confuse you when debugging connectivity in E-5.

**`dynamodb_table` is deprecated** in Terraform 1.15 in favour of S3-native `use_lockfile`.
It still works and the spec mandates DynamoDB locking, so it is kept. `init` warns on both
environments.

**The VPC's default security group is unmanaged.** AWS creates one per VPC allowing all
traffic from itself and all outbound. Nothing uses it, but Checkov flags it
(`CKV_AWS_23`, `CKV2_AWS_12`). Locking it down belongs to PETPLAT-71.

**CI builds ARM64 on x86 runners.** QEMU emulation takes build time from ~2 to ~5 minutes per
image. If you forget `linux/arm64`, images will push fine and then `CrashLoopBackOff` on the
Graviton nodes with an exec-format error.

---

## 10. Quick reference

### Commands

```bash
# State backend (once, before anything)
./scripts/bootstrap-state.sh [--region eu-central-1] [--dry-run]

# Terraform, per environment
cd terraform/environments/{dev,prod}
terraform init -backend-config=backend.hcl
terraform fmt -recursive && terraform validate
terraform plan -out plan.out
terraform apply plan.out
terraform plan -detailed-exitcode        # exit 0 = no drift, 2 = changes pending

# Cluster access
aws eks update-kubeconfig --name petclinic-{env} --region eu-central-1
kubectl get nodes
kubectl get pods -n petclinic-{env}

# Helm render check
helm template test helm/petclinic-service/ \
  -f helm-values/{service}.yaml -f helm-values/{env}.yaml

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8443:443
argocd app diff {service}-{env}
argocd app sync {service}-{env}
argocd app rollback {service}-{env}

# Cost control
./scripts/stop-env.sh dev     # stops nodes + RDS; control plane still bills
./scripts/start-env.sh dev
./scripts/env-status.sh dev
```

### The 8 services

| Service | Port | MySQL | Note |
|---------|------|-------|------|
| config-server | 8888 | No | Starts first |
| discovery-server | 8761 | No | Starts second (Eureka) |
| api-gateway | 8080 | No | Public entry point |
| customers-service | 8081 | Yes | Owners and pets |
| visits-service | 8082 | Yes | Visit records |
| vets-service | 8083 | Yes | Caffeine cache |
| genai-service | 8084 | Optional | Needs `OPENAI_API_KEY` |
| admin-server | 9090 | No | Spring Boot Admin |

### Non-negotiable rules

1. No secrets in code — Secrets Manager + External Secrets Operator
2. No public S3 buckets
3. No open security groups except the ALB on 80/443
4. Encryption everywhere — RDS, S3, EBS
5. Least-privilege IAM, never `*/*`
6. Security groups are the perimeter (everything is in public subnets)
7. No `terraform destroy` via the agent — hooks block it
8. No `*.tfvars`, `.env`, or `backend.hcl` committed

### Where to look

| Question | File |
|----------|------|
| What value should X be? | `docs/technical-spec.md` |
| What work is left? | `docs/jira-backlog.md` |
| What are the conventions? | `CLAUDE.md`, `.claude/rules/` |
| Why is it built this way? | `docs/adr/` |
| How do I run the next epic? | `.claude/prompts/` |
