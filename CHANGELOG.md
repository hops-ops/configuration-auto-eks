### What's changed in v0.4.0

* refactor: simplify observed state for m.crossplane.io provider (by @patrickleet)

  Remove legacy array handling - only m.crossplane.io provider is used,
  which returns vpcConfig, identity, and oidc as flat objects.

  Also updates test mocks to use the object format.

  Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>

* chore(deps): update unbounded-tech/workflows-crossplane action to v2.13.0 (#2) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* feat(deps): update crossplane-contrib/provider-kubernetes docker tag to v1.2.0 (#3) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* fix: cluster observation (by @patrickleet)

* fix: faster e2e tests, by using persistent network instead of creating and destroying a new one from a new ipam allocation each time (by @patrickleet)

* feat: node pool / class usage + pc objects (by @patrickleet)

* fix: e2e k8s PC (by @patrickleet)

* fix: e2e k8s PC (by @patrickleet)

* fix: k8s pc apiversion (by @patrickleet)

* fix: k8s pc drc + rbac (by @patrickleet)

* fix: custom readiness policy (by @patrickleet)

* fix: re-add default conditions (by @patrickleet)

* fix: rm debug artifacts (by @patrickleet)

* fix: keep wrapper objects (by @patrickleet)


See full diff: [v0.3.1...v0.4.0](https://github.com/hops-ops/aws-auto-eks-cluster/compare/v0.3.1...v0.4.0)
