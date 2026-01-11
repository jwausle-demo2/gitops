#!/bin/bash
# ============================================
#            Global Configurations
# ============================================
CLUSTER_NAME=${1:-./fluxcd/clusters/localhost}
BRANCH=${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}
GITHUB_USER=${GITHUB_USER:-jwausle}
GITHUB_REPO="https://github.com/jwausle-demo2/gitops.git"
GITHUB_REPO_NAME=${GITHUB_REPO_NAME:-$(echo "${GITHUB_REPO##*/}" | sed 's/.git$//g')}

# Connect flux with the gitrepo (upload ssh key and push flux-system components)
flux bootstrap github \
  --token-auth \
  --owner="${GITHUB_USER}" \
  --repository="${GITHUB_REPO_NAME}" \
  --branch="${BRANCH}" \
  --path=fluxcd/clusters/base \
  --hostname=github.com \
  --private=false \
  --personal=true \
  --interval=1m --verbose

# Setup cluster configuration by name under `./fluxcd/clusters/`
flux create kustomization flux-system-demo \
  --source=flux-system \
  --path="${CLUSTER_NAME}" \
  --prune=true \
  --interval=3m
