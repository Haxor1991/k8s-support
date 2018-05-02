#!/bin/bash

exec 2> /tmp/k8s_setup.log 1>&2
set -euxo pipefail

# This should be the final step. Prior to this script running, we should have
# made sure that the disk is partitioned appropriately and mounted in the right
# places (one place to serve as a cache for Docker images, the other two to
# serve as repositories for core system data and experiment data, respectively)

# Make sure to download any and all necessary auth tokens prior to this point.
# It should be a simple wget from the master node to make that happen.
MASTER_NODE=k8s-platform-master.mlab-sandbox.measurementlab.net

# Commands from:
#   https://kubernetes.io/docs/setup/independent/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
systemctl daemon-reload
systemctl enable docker
systemctl start docker

CNI_VERSION="v0.6.0"
mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz

RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"

mkdir -p /opt/bin
cd /opt/bin
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/"${RELEASE}"/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}

curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${RELEASE}/build/debs/kubelet.service" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${RELEASE}/build/debs/10-kubeadm.conf" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl enable kubelet && systemctl start kubelet

TOKEN=$(curl "http://${MASTER_NODE}:8000" | grep token | awk '{print $2}' | sed -e 's/"//g')
export PATH=/sbin:/usr/sbin:/opt/bin:${PATH}
kubeadm join "${MASTER_NODE}:6443" \
  --token "${TOKEN}" \
  --discovery-token-ca-cert-hash sha256:69dc2a47883159b22c97cbfabab65f81136104ece2f854f35d3b8b6a268a2607