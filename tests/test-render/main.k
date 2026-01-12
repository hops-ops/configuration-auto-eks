import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.ai.com.ops.hops.aws.v1alpha1 as awsv1alpha1

_items = [

    # Test: Minimal cluster renders IAM roles
    metav1alpha1.CompositionTest{
        metadata.name = "minimal-renders-iam-roles"
        spec = {
            compositionPath = "apis/autoeksclusters/composition.yaml"
            xrdPath = "apis/autoeksclusters/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = awsv1alpha1.AutoEKSCluster{
                metadata.name = "test-cluster"
                spec = {
                    clusterName = "test-cluster"
                    region = "us-east-1"
                    accountId = "123456789012"
                    version = "1.31"
                    subnetIds = ["subnet-aaa", "subnet-bbb"]
                }
            }
            assertResources = [
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Role"
                    metadata.name = "test-cluster-controlplane"
                }
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Role"
                    metadata.name = "test-cluster-node"
                }
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Policy"
                    metadata.name = "test-cluster-resource-tagging"
                }
            ]
        }
    }

    # Test: Encryption enabled creates KMS key
    metav1alpha1.CompositionTest{
        metadata.name = "encryption-creates-kms"
        spec = {
            compositionPath = "apis/autoeksclusters/composition.yaml"
            xrdPath = "apis/autoeksclusters/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = awsv1alpha1.AutoEKSCluster{
                metadata.name = "test-encrypted"
                spec = {
                    clusterName = "test-encrypted"
                    region = "us-west-2"
                    accountId = "123456789012"
                    version = "1.31"
                    subnetIds = ["subnet-aaa"]
                    encryptionEnabled = True
                }
            }
            assertResources = [
                {
                    apiVersion = "kms.aws.m.upbound.io/v1beta1"
                    kind = "Key"
                    metadata.name = "test-encrypted-secrets"
                }
                {
                    apiVersion = "kms.aws.m.upbound.io/v1beta1"
                    kind = "Alias"
                    metadata.name = "test-encrypted-secrets"
                }
            ]
        }
    }

    # Test: Tags are merged with defaults
    metav1alpha1.CompositionTest{
        metadata.name = "tags-merged-with-defaults"
        spec = {
            compositionPath = "apis/autoeksclusters/composition.yaml"
            xrdPath = "apis/autoeksclusters/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = awsv1alpha1.AutoEKSCluster{
                metadata.name = "test-tags"
                spec = {
                    clusterName = "test-tags"
                    region = "us-east-1"
                    accountId = "123456789012"
                    version = "1.31"
                    subnetIds = ["subnet-aaa"]
                    tags = {environment = "test", team = "platform"}
                }
            }
            assertResources = [
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Role"
                    metadata.name = "test-tags-controlplane"
                    spec.forProvider.tags = {
                        "hops.ops.com.ai/managed" = "true"
                        "hops.ops.com.ai/autoekscluster" = "test-tags"
                        environment = "test"
                        team = "platform"
                    }
                }
            ]
        }
    }

]

items = _items
