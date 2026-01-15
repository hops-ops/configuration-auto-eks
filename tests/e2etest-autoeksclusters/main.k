# E2E Test for AutoEKSCluster
# ============================
# Tests AutoEKSCluster creation using the persistent hops-test network.
#
# This test creates:
# 1. An AutoEKSCluster using subnet IDs from the persistent hops-test network
#
# Uses persistent network infrastructure from aws-network e2e test (hops-test)
# to speed up test execution by avoiding network creation/deletion.
#
# Prerequisites:
# 1. Create secrets/aws-creds file with AWS credentials in INI format:
#    [default]
#    aws_access_key_id = AKIA...
#    aws_secret_access_key = ...
#
# 2. Ensure the persistent hops-test network exists (from aws-network e2e test)
#
# 3. Run: make e2e

import base64
import file
import datetime
import math
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.ai.com.ops.hops.aws.v1alpha1 as awsv1alpha1

# Read AWS credentials from local file (gitignored)
_creds = file.read("secrets/aws-creds")
_base64_creds = base64.encode(_creds)

# =============================================================================
# Test Configuration
# =============================================================================
_now = str(int(math.floor(datetime.ticks())))
_test_name = "e2e-autoeks-" + _now
_namespace = "default"
_region = "us-east-2"  # Match CI workflow region
_account_id = "034489662075"  # CI test account

# =============================================================================
# Persistent Network Infrastructure (from aws-network e2e test - hops-test)
# =============================================================================
# Private subnet IDs for the EKS cluster - these are already created and orphaned
_private_subnet_ids = [
    "subnet-0ba2f584c25e9435d"  # private-a
    "subnet-02e4d512f8859e684"  # private-b
]

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
            # initResources: No additional packages needed
            # Uses persistent hops-test network - no Network XRD required
            initResources = []

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

            # manifests: AutoEKSCluster (applied after initResources are Ready)
            # Uses persistent hops-test network - no Network manifest needed
            # Resources created in manifests are deleted during cleanup
            manifests = [
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
                        # Use subnet IDs from persistent hops-test network
                        subnetIds = _private_subnet_ids
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
