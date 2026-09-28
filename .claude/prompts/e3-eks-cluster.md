# Prompt: implement EPIC E-3 (EKS Cluster)

Reusable prompt for driving E-3, shaped like the E-2 VPC build. Lives in `.claude/`
rather than `docs/` because it is agent tooling, not team documentation —
`.claude/rules/docs.md` fixes the `docs/` layout.

---

Read EPIC E-3: EKS Cluster from docs/jira-backlog.md and implement everything these
stories require. Follow the acceptance criteria exactly.

## Read first

- docs/jira-backlog.md — EPIC E-3, stories PETPLAT-12 through PETPLAT-17
- docs/technical-spec.md#eks-cluster — cluster config, IAM roles, OIDC, node group,
  add-ons. This is authoritative for every value.
- .claude/rules/terraform.md — module layout (main/variables/outputs/versions.tf),
  naming `petclinic-{env}-{resource}`, snake_case identifiers, required tags
- terraform/modules/vpc/ — follow this module's structure and comment style
- ADR-0001 — all-public subnet design; the cluster and nodes go in public subnets

## Stories

| Story | Deliverable | Spec |
|---|---|---|
| PETPLAT-12 | EKS module: cluster, cluster IAM role, OIDC provider | #eks-cluster, #cluster-iam-role, #oidc-provider |
| PETPLAT-13 | Managed node group + node IAM role | #managed-node-group, #node-iam-role-policies |
| PETPLAT-14 | kubectl access: EKS access entry + kubeconfig output | #eks-cluster |
| PETPLAT-15 | Wire into dev, pass VPC module outputs | #eks-cluster |
| PETPLAT-16 | Apply to dev, verify ACTIVE + 2 Ready nodes | #eks-cluster |
| PETPLAT-17 | Wire into prod — PLAN ONLY, do not apply | #eks-cluster |

## Blocker to resolve before writing any code

The spec pins Kubernetes `1.29`. That version is no longer available for new EKS
clusters — `aws eks describe-cluster-versions --region eu-central-1` returns only
1.31-1.36 (default 1.36), and 1.31 is already past end of standard support. Applying
1.29 will fail.

Pick a supported version, update docs/technical-spec.md#cluster-configuration to match,
and record the change in the PETPLAT-12 story notes. Do not silently diverge from the
spec — amend it.

| Version | End of standard support |
|---|---|
| 1.34 | 2026-12-02 |
| 1.35 | 2027-03-27 |
| 1.36 | 2027-08-02 (AWS default) |

Also re-check `ami_type`. The spec says `AL2_ARM_64`, but Amazon Linux 2 EKS AMIs were
discontinued after 1.32, so a supported version likely requires
`AL2023_ARM_64_STANDARD`. Verify against the provider/AWS before applying rather than
trusting either the spec or this note.

## Cost — confirm with the user before applying

Unlike E-2, this epic is not free. The EKS control plane bills ~$0.10/hr (~$73/month)
per cluster regardless of load. Nodes are 2x t4g.small, covered by the Graviton free
trial until Dec 2026. Stop and report the projected monthly cost before running apply
on dev.

## Conventions

- Node group in the public subnets from `module.vpc.subnet_ids`
- Security groups from `module.vpc.security_group_ids` — do not create new ones
- Cluster logging: api, audit, authenticator
- Authentication mode: API_AND_CONFIG_MAP
- Add-on versions pinned, never `latest`; aws-ebs-csi-driver needs IRSA
- Instance types, min/max/desired size, and disk size all as variables with spec values
  as defaults
- Run `terraform fmt -recursive` and `terraform validate` after every edit

## Definition of done

1. `terraform fmt -check -recursive terraform/` is clean
2. `terraform validate` passes in the eks module and both environments
3. Dev applied; verified against live AWS via CLI, not assumed from apply output:
   cluster ACTIVE, `kubectl get nodes` shows 2 Ready, OIDC provider exists in IAM,
   coredns and kube-proxy Running in kube-system
4. Dev re-plans with no drift (`terraform plan -detailed-exitcode` returns 0)
5. Prod planned only, resource count and cluster name reported
6. Every AC checkbox in PETPLAT-12..17 ticked in docs/jira-backlog.md, with a
   **Notes:** block per story recording: verified evidence, any AC interpreted or
   deviated from and why, and anything deferred to a later story
7. Report what was created, what it costs, and anything left undone

---

## Reusing this for later epics

Swap the epic number, story range, and spec anchors. The parts worth keeping verbatim:
the "Read first" list, the conventions, and the definition of done — especially
**verify against live AWS via CLI rather than trusting apply output**, which is what
caught the yanked-package and version-availability problems in E-1 and E-3.
