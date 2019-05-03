#!/bin/bash

set -euxo pipefail

USAGE="USAGE: $0 <google-cloud-project>"
PROJECT=${1:?Please specify the google cloud project: $USAGE}

# Source the main configuration file.
source ./k8s_deploy.conf

# Create a string representing region and zone variable names for this project.
GCE_REGION_VAR="GCE_REGION_${PROJECT//-/_}"
GCE_ZONES_VAR="GCE_ZONES_${PROJECT//-/_}"

# Dereference the region and zones variables.
GCE_REGION="${!GCE_REGION_VAR}"
GCE_ZONES="${!GCE_ZONES_VAR}"

GCE_ZONE="${GCE_REGION}-$(echo ${GCE_ZONES} | awk '{print $1}')"
GCE_ARGS=("--zone=${GCE_ZONE}" "--project=${PROJECT}" "--quiet")
GCE_NAME="${GCE_BASE_NAME}-${GCE_ZONE}"

GCS_BUCKET_K8S="GCS_BUCKET_K8S_${PROJECT//-/_}"

# Create the json configuration for the entire cluster (except for secrets)
jsonnet \
   --ext-str GCE_ZONE=${GCE_ZONE} \
   --ext-str K8S_CLUSTER_CIDR=${K8S_CLUSTER_CIDR} \
   --ext-str K8S_FLANNEL_VERSION=${K8S_FLANNEL_VERSION} \
   --ext-str PROJECT_ID=${PROJECT} \
   ../system.jsonnet > system.json

# Download every secret, and turn each one into a config.
mkdir -p secrets
mkdir -p secret-configs

# Fetch and configure all the secrets.
gsutil cp -R gs://${!GCS_BUCKET_K8S}/ndt-tls secrets/.
gsutil cp gs://${!GCS_BUCKET_K8S}/pusher-credentials.json secrets/pusher.json
gsutil cp gs://${!GCS_BUCKET_K8S}/fluentd-credentials.json secrets/fluentd.json
mkdir -p secrets/etcd-tls
gsutil cp gs://${!GCS_BUCKET_K8S}/pki/etcd/peer.* secrets/etcd-tls/
gsutil cp -R gs://${!GCS_BUCKET_K8S}/reboot-api secrets/.

# Convert secret data into configs.
kubectl create secret generic pusher-credentials --from-file secrets/pusher.json \
    --dry-run -o json > secret-configs/pusher-credentials.json
kubectl create secret generic ndt-tls --from-file secrets/ndt-tls/ \
    --dry-run -o json > secret-configs/ndt-tls.json
kubectl create secret generic fluentd-credentials --from-file secrets/fluentd.json \
    --dry-run -o json > secret-configs/fluentd-credentials.json
kubectl create secret generic etcd-tls --from-file secrets/etcd-tls/ \
    --dry-run -o json > secret-configs/etcd-tls.json
kubectl create secret generic reboot-api-credentials --from-file secrets/reboot-api/ \
    --dry-run -o json > secret-configs/reboot-api-credentials.json