# E2E Test for AutoEKSCluster with Network dependency
# =====================================================
# Tests AutoEKSCluster creation with Network as a dependency.
#
# This test creates:
# 1. A Network (from aws-network configuration) to provision VPC and subnets
# 2. An AutoEKSCluster using subnet selector to find Network's private subnets
#
# The Network labels its subnets, and AutoEKSCluster uses subnetSelector to find them.
# This removes the need for hardcoded subnet IDs.
#
# Prerequisites:
# 1. Create secrets/aws-creds file with AWS credentials in INI format:
#    [default]
#    aws_access_key_id = AKIA...
#    aws_secret_access_key = ...
#
# 2. Run: make e2e

import base64
import file
import datetime
import math
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.ai.com.ops.hops.aws.v1alpha1 as awsv1alpha1

# Read AWS credentials from local file (gitignored)
_creds = file.read("secrets/aws-creds")
_base64_creds = base64.encode(_creds)

# Generate unique name using timestamp to avoid CI conflicts
_now = str(int(math.floor(datetime.ticks())))
_test_name = "e2e-autoeks-" + _now
_namespace = "default"
_region = "us-east-2"  # Match CI workflow region
_account_id = "034489662075"  # CI test account

# IPAM Pool - from aws-ipam e2e test
# Get pool IDs: aws ec2 describe-ipam-pools --query 'IpamPools[*].[IpamPoolId,AddressFamily,Description]' --output table
_ipv4_private_pool_id = "ipam-pool-0607416fa3707147a"

_items = [
    metav1alpha1.E2ETest {
        metadata.name = "autoekscluster"
        spec = {
            crossplane = {
                version = "2.0.2-up.5"
                autoUpgrade.channel = "None"
            }
            defaultConditions = ["Ready"]
            timeoutSeconds = 5400  # 90 minutes for EKS cluster creation
            cleanupTimeoutSeconds = 1800  # 30 minutes for cleanup
            skipDelete = False
            # initResources: Called before package install
            initResources = [
                # aws-network Configuration package (provides Network XRD)
                {
                    apiVersion = "pkg.crossplane.io/v1"
                    kind = "Configuration"
                    metadata = {
                        name = "aws-network"
                    }
                    spec = {
                        package = "ghcr.io/hops-ops/aws-network:v0.4.0"
                    }
                }
            ]

            # extraResources: Credentials, ProviderConfig, and dependency packages
            # Applied after package install
            extraResources = [
                # AWS credentials secret
                {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "aws-creds"
                        namespace = _namespace
                    }
                    data = {
                        creds = _base64_creds
                    }
                }
                # AWS ProviderConfig using Secret credentials
                {
                    apiVersion = "aws.m.upbound.io/v1beta1"
                    kind = "ProviderConfig"
                    metadata = {
                        name = "default"
                        namespace = _namespace
                    }
                    spec = {
                        credentials = {
                            source = "Secret"
                            secretRef = {
                                namespace = _namespace
                                name = "aws-creds"
                                key = "creds"
                            }
                        }
                    }
                }
            ]

            # Manifests: Network and AutoEKSCluster (applied after initResources are Ready)
            # Uses subnetSelector to find Network's private subnets by label
            # Resources created in manifests are deleted during cleanup
            manifests = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Network"
                    metadata = {
                        name = _test_name
                        namespace = _namespace
                    }
                    spec = {
                        region = _region
                        providerConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        tags = {
                            "e2etest" = "true"
                            "test-run" = _now
                        }
                        # Use IPAM to auto-allocate VPC CIDR
                        ipam = {
                            ipv4 = {
                                enabled = True
                                poolId = _ipv4_private_pool_id
                                netmaskLength = 16
                            }
                        }
                        # Subnet layout - subnets calculated from VPC CIDR
                        subnetLayout = {
                            availabilityZones = ["a", "b"]
                            public = {
                                enabled = True
                                netmaskLength = 24
                            }
                            private = {
                                enabled = True
                                netmaskLength = 20
                            }
                        }
                        # Disable NAT to speed up test (EKS Auto Mode uses VPC endpoints)
                        nat = {
                            enabled = False
                        }
                    }
                }
                awsv1alpha1.AutoEKSCluster {
                    metadata = {
                        name = _test_name
                        namespace = _namespace
                    }
                    spec = {
                        clusterName = _test_name
                        region = _region
                        accountId = _account_id
                        version = "1.34"
                        # Use subnet selector to find private subnets from Network
                        subnetSelector = {
                            matchLabels = {
                                "hops.ops.com.ai/network" = _test_name
                                "hops.ops.com.ai/tier" = "private"
                            }
                        }
                        providerConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        tags = {
                            "e2etest" = "true"
                            "test-run" = _now
                        }
                        # Enable public endpoint so e2e test can reach cluster API
                        publicAccess = True
                        # Use default node config (spot, c/m/r, gen4+, amd64)
                        nodeConfig = {
                            enabled = True
                        }
                        # Enable OIDC for testing IRSA functionality
                        oidc = {
                            enabled = True
                        }
                    }
                }
            ]
        }
    }
]

items = _items
