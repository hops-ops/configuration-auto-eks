# configuration-aws-auto-eks-cluster

Production-ready EKS clusters with Auto Mode enabled, removing the operational overhead of node management while maintaining full control over workload scheduling.

## Why EKS Auto Mode?

**Without EKS Auto Mode:**
- Manual node group management with constant right-sizing decisions
- Complex Karpenter configuration and ongoing maintenance
- Separate control plane and data plane infrastructure concerns
- Multiple IAM roles and policies to manage across components
- Operational burden of scaling, patching, and upgrading nodes

**With EKS Auto Mode:**
- AWS manages compute, networking, storage, and load balancing automatically
- No node group configuration required - AWS handles provisioning
- Built-in Karpenter for intelligent workload scheduling
- Simplified IAM with only two roles (control plane + nodes)
- Focus on workloads instead of infrastructure

## The Journey

### Stage 1: Getting Started (Individual/Small Team)

Minimal configuration for getting a production-ready cluster quickly. Perfect for startups, individual projects, or proof-of-concepts that need a solid foundation.

**Why start here?**
- Get a production-ready cluster in minutes, not days
- KMS encryption enabled by default for secrets at rest
- Private API endpoint with no public exposure
- Sensible defaults for node sizing and scaling

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: AutoEKSCluster
metadata:
  name: my-cluster
  namespace: default
spec:
  clusterName: my-cluster
  region: us-east-1
  accountId: "123456789012"
  version: "1.31"
  subnetIds:
    - subnet-aaaaaaaa
    - subnet-bbbbbbbb
    - subnet-cccccccc
```

This creates:
- EKS cluster with Auto Mode enabled
- IAM roles for control plane and nodes
- KMS key for secrets encryption
- Default NodeClass and NodePool for spot instances

### Stage 2: Growing (Small Org)

Add features as your team grows - custom access entries, tags, and node configuration.

**Why expand?**
- Multiple team members need cluster access
- Cost allocation requires proper tagging
- Workloads need custom node requirements (instance types, architectures)

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: AutoEKSCluster
metadata:
  name: staging
  namespace: platform
spec:
  clusterName: staging
  region: us-west-2
  accountId: "123456789012"
  version: "1.31"
  subnetIds:
    - subnet-private-a
    - subnet-private-b
    - subnet-private-c

  tags:
    environment: staging
    team: platform
    cost-center: engineering

  accessEntries:
    - principalArn: arn:aws:iam::123456789012:role/PlatformAdmins
      accessPolicies:
        - policyArn: arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
          accessScope:
            type: cluster

  nodeConfig:
    nodeClass:
      ephemeralStorage:
        size: "100Gi"
    nodePool:
      # Custom requirements for Graviton support
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot"]
      - key: eks.amazonaws.com/instance-category
        operator: In
        values: ["c", "m", "r"]
      - key: eks.amazonaws.com/instance-generation
        operator: Gt
        values: ["6"]
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64", "arm64"]
      - key: kubernetes.io/os
        operator: In
        values: ["linux"]
```

### Stage 3: Enterprise Scale

Full-featured configuration for large organizations with multiple clusters, strict security requirements, and IRSA needs.

**Why this matters at scale?**
- Permissions boundaries for compliance
- OIDC provider for IRSA (IAM Roles for Service Accounts)
- Custom security group rules for network policies
- Multi-architecture support for cost optimization

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: AutoEKSCluster
metadata:
  name: production
  namespace: production
spec:
  clusterName: production
  region: us-east-1
  accountId: "123456789012"
  version: "1.31"
  subnetIds:
    - subnet-prod-a
    - subnet-prod-b
    - subnet-prod-c

  providerConfigRef:
    name: production-aws
    kind: ProviderConfig

  tags:
    environment: production
    compliance: sox
    data-classification: confidential

  permissionsBoundary: arn:aws:iam::123456789012:policy/EKSPermissionsBoundary

  # Enable OIDC for IRSA
  oidc:
    enabled: true

  # Custom security group rules for VPN access
  securityGroupRules:
    enabled: true
    ingress:
      - description: "Allow kubectl from VPN"
        cidrIpv4: "10.100.0.0/16"
        fromPort: 443
        toPort: 443
        ipProtocol: tcp

  accessEntries:
    - principalArn: arn:aws:iam::123456789012:role/ProductionAdmins
      accessPolicies:
        - policyArn: arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
          accessScope:
            type: cluster
    - principalArn: arn:aws:iam::123456789012:role/DeveloperRole
      kubernetesGroups: ["developers"]
      accessPolicies:
        - policyArn: arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy
          accessScope:
            type: namespace
            namespaces: ["app-team"]

  nodeConfig:
    nodeClass:
      ephemeralStorage:
        size: "200Gi"
        iops: 6000
        throughput: 250
    nodePool:
      # Production: on-demand, larger instances, conservative disruption
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["on-demand"]
      - key: eks.amazonaws.com/instance-category
        operator: In
        values: ["c", "m", "r"]
      - key: eks.amazonaws.com/instance-generation
        operator: Gt
        values: ["6"]
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64", "arm64"]
      - key: kubernetes.io/os
        operator: In
        values: ["linux"]
      disruption:
        consolidationPolicy: WhenEmpty  # Conservative for production
        consolidateAfter: "1h"
        budgets:
          - nodes: "5%"
```

### Stage 4: Import Existing (Optional)

Bring existing EKS cluster resources under management without recreating them.

**Why import?**
- Preserve existing cluster and workloads
- Gradual adoption of infrastructure as code
- No disruption to running applications

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: AutoEKSCluster
metadata:
  name: imported-cluster
  namespace: default
spec:
  clusterName: my-existing-cluster
  region: us-east-1
  accountId: "123456789012"
  version: "1.31"
  subnetIds:
    - subnet-existing-a
    - subnet-existing-b

  # Exclude Delete to safely import without risk of accidental deletion
  managementPolicies:
    - Create
    - Observe
    - Update
    - LateInitialize

  # External names of existing AWS resources to import
  imports:
    cluster: my-existing-cluster
    controlPlaneRole: my-existing-cluster-controlplane
    nodeRole: my-existing-cluster-node
    kmsKey: 12345678-1234-1234-1234-123456789012
    # oidcProvider: arn:aws:iam::123456789012:oidc-provider/...

  # Disable node config initially during import
  nodeConfig:
    enabled: false
```

**Import workflow:**
1. Get the external names of your existing resources (cluster name, role names, KMS key ID)
2. Apply the manifest - Crossplane will adopt the resources
3. Once stable, optionally add "Delete" to managementPolicies for full management

## Using AutoEKSCluster

Reference the cluster's status fields in downstream resources:

```yaml
# Reference the cluster in a Helm Release
apiVersion: helm.crossplane.io/v1beta1
kind: Release
metadata:
  name: my-app
spec:
  providerConfigRef:
    name: production  # Matches the cluster name
  forProvider:
    chart:
      name: my-app
      repository: https://charts.example.com
    namespace: app
```

## Status

| Field | Description |
|-------|-------------|
| `clusterName` | Name of the EKS cluster |
| `clusterEndpoint` | API server endpoint URL |
| `clusterSecurityGroupId` | Cluster security group ID |
| `oidc` | OIDC provider URL (without https://) |
| `controlPlaneStatus` | Control plane status (e.g., "Available") |
| `encryptionKeyArn` | ARN of the KMS encryption key |
| `nodeRoleArn` | ARN of the node IAM role |
| `controlPlaneRoleArn` | ARN of the control plane IAM role |

## Composed Resources

| Resource | Purpose | Condition |
|----------|---------|-----------|
| `iam.Role` (controlplane) | EKS control plane permissions | Always |
| `iam.Role` (node) | Node instance permissions | Always |
| `iam.Policy` (resource-tagging) | Auto Mode resource tagging | Always |
| `iam.RolePolicyAttachment` (6x) | AWS managed policy attachments | When roles ready |
| `kms.Key` + `kms.Alias` | Secrets encryption | When encryption enabled |
| `eks.Cluster` | EKS cluster with Auto Mode | When IAM/KMS ready |
| `eks.ClusterAuth` | Kubeconfig generation | When cluster ready |
| `eks.AccessEntry` + `AccessPolicyAssociation` | Cluster access | When cluster ready |
| `iam.OpenIDConnectProvider` | IRSA support | When OIDC enabled |
| `ec2.SecurityGroupIngressRule` | Custom ingress rules | When SG rules enabled |
| `kubernetes.Object` (NodeClass) | Karpenter node configuration | When cluster auth ready |
| `kubernetes.Object` (NodePool) | Karpenter workload scheduling | When node config enabled |
| `kubernetes.ProviderConfig` | K8s provider for in-cluster (uses namespace from claim) | When cluster auth ready |
| `helm.ProviderConfig` | Helm provider for in-cluster (uses namespace from claim) | When cluster auth ready |

## Configuration Reference

**Namespace behavior:** The `metadata.namespace` of the claim is automatically used for the kubeconfig secret location. The generated Kubernetes and Helm ProviderConfigs reference this namespace to find the cluster credentials.

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `clusterName` | Yes | - | Name of the EKS cluster |
| `region` | Yes | - | AWS region |
| `accountId` | Yes | - | AWS account ID |
| `version` | Yes | - | Kubernetes version (e.g., "1.31") |
| `subnetIds` | Yes | - | Subnet IDs for cluster |
| `providerConfigRef.name` | No | `default` | AWS ProviderConfig name |
| `providerConfigRef.kind` | No | `ProviderConfig` | Provider config kind |
| `managementPolicies` | No | `["*"]` | Crossplane management policies |
| `imports.cluster` | No | - | External name of existing EKS cluster to import |
| `imports.controlPlaneRole` | No | - | External name of existing control plane IAM role |
| `imports.nodeRole` | No | - | External name of existing node IAM role |
| `imports.kmsKey` | No | - | External name of existing KMS key for encryption |
| `imports.oidcProvider` | No | - | External name (ARN) of existing OIDC provider |
| `tags` | No | `{hops: "true"}` | Additional AWS tags |
| `permissionsBoundary` | No | - | IAM permissions boundary ARN |
| `privateAccess` | No | `true` | Enable private API endpoint |
| `publicAccess` | No | `false` | Enable public API endpoint |
| `encryptionEnabled` | No | `true` | Enable KMS secrets encryption |
| `accessEntries` | No | `[]` | Custom cluster access entries |
| `securityGroupRules.enabled` | No | `false` | Enable custom SG rules |
| `oidc.enabled` | No | `false` | Create OIDC provider for IRSA |
| `nodeConfig.enabled` | No | `true` | Create NodeClass/NodePool |
| `nodeConfig.nodeClass.name` | No | `hops-default` | NodeClass name |
| `nodeConfig.nodePool.requirements` | No | spot, c/m/r, gen4+, amd64 | Karpenter node requirements |

## Development

```bash
# Render examples
make render:all

# Validate examples
make validate:all

# Run unit tests
make test

# Run E2E tests
make e2e
```

## License

Apache-2.0
