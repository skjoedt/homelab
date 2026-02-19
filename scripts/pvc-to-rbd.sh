#!/bin/bash

# Script to find the RBD image name from a Kubernetes PVC
# Usage: ./pvc-to-rbd.sh <pvc-name> [namespace]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print usage
usage() {
    echo "Usage: $0 <pvc-name> [namespace]"
    echo ""
    echo "Find the RBD image name for a given PVC"
    echo ""
    echo "Arguments:"
    echo "  pvc-name    Name of the PersistentVolumeClaim"
    echo "  namespace   Kubernetes namespace (optional, defaults to current namespace)"
    echo ""
    echo "Examples:"
    echo "  $0 radarr-config-pvc arr"
    echo "  $0 my-pvc"
    echo ""
    exit 1
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: PVC name is required${NC}"
    usage
fi

PVC_NAME="$1"
NAMESPACE_FLAG=""

# Set namespace if provided
if [ $# -eq 2 ]; then
    NAMESPACE="$2"
    NAMESPACE_FLAG="-n $NAMESPACE"
    echo -e "${BLUE}Looking for PVC '${PVC_NAME}' in namespace '${NAMESPACE}'...${NC}"
else
    echo -e "${BLUE}Looking for PVC '${PVC_NAME}' in current namespace...${NC}"
fi

# Check if PVC exists
if ! kubectl get pvc "$PVC_NAME" $NAMESPACE_FLAG &>/dev/null; then
    echo -e "${RED}Error: PVC '$PVC_NAME' not found${NC}"    
    exit 1
fi

# Get PV name
echo -e "${BLUE}Getting PV name...${NC}"
PV_NAME=$(kubectl get pvc "$PVC_NAME" $NAMESPACE_FLAG -o jsonpath='{.spec.volumeName}')

if [ -z "$PV_NAME" ]; then
    echo -e "${RED}Error: PVC is not bound to any PV${NC}"
    exit 1
fi

echo -e "${BLUE}PV Name: ${PV_NAME}${NC}"

# Get PV details
echo -e "${BLUE}Getting RBD image information...${NC}"

# Check if PV uses CSI
CSI_DRIVER=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.csi.driver}' 2>/dev/null || echo "")

if [ -z "$CSI_DRIVER" ]; then
    echo -e "${RED}Error: PV is not using CSI driver${NC}"
    exit 1
fi

if [[ "$CSI_DRIVER" != *"rbd.csi.ceph.com"* ]]; then
    echo -e "${YELLOW}Warning: PV is using CSI driver '$CSI_DRIVER', not Ceph RBD${NC}"
fi

# Check if this is a static volume
STATIC_VOLUME=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.csi.volumeAttributes.staticVolume}' 2>/dev/null || echo "")

# Get RBD image name based on volume type
if [[ "$STATIC_VOLUME" == "true" ]]; then
    # For static volumes, the image name is in volumeHandle
    RBD_IMAGE=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.csi.volumeHandle}' 2>/dev/null || echo "")
else
    # For dynamic volumes, use the imageName attribute
    RBD_IMAGE=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.csi.volumeAttributes.imageName}' 2>/dev/null || echo "")
fi

POOL=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.csi.volumeAttributes.pool}' 2>/dev/null || echo "")
VOLUME_HANDLE=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.csi.volumeHandle}' 2>/dev/null || echo "")

# Output results
if [ -n "$RBD_IMAGE" ]; then
    echo -e "${YELLOW}RBD Image:${NC} $RBD_IMAGE"
else
    echo -e "${RED}RBD Image: Not found${NC}"
fi

if [ -n "$POOL" ]; then
    echo -e "${YELLOW}Pool:${NC} $POOL"
fi

echo ""