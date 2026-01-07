# * require helm, kubectl
SCRIPT_DIR=$(dirname "$0")

# ============================================
#            Global Configurations
# ============================================
ARGOCD_DIR="$SCRIPT_DIR"
ARGOCD_REPO="https://argoproj.github.io/argo-helm"
ARGOCD_VERSION="9.2.4"
ARGOCD_APP_REPO_TOKEN=${GITHUB_TOKEN:-${ARGOCD_APP_REPO_TOKEN}}
ARGOCD_APP_REPO="https://github.com/jwausle/gitops.git"

# There are some hardcoded drawbacks in used argocd/**/*.yaml files regarding namespace
ARGOCD_RELEASE_NAME="argocd"
ARGOCD_RELEASE_NAMESPACE="argocd"

HELMCHART_ONLY=false
if [[ "$*" =~ "--helm-only" ]]; then
  HELMCHART_ONLY=true
fi

APPLICATION_ONLY=false
if [[ "$*" =~ "--app-only" ]]; then
  APPLICATION_ONLY=true
fi

WITH_TRAEFIK=false
if [[ "$*" =~ "--with-traefik" ]]; then
  WITH_TRAEFIK=true
fi

print-config() {
  echo "==============================================="
  echo "       Deploy ArgoCD                           "
  echo "==============================================="
  echo
  echo "- KUBECONFIG=$KUBECONFIG"
  echo "- HELMCHART_ONLY=$HELMCHART_ONLY (--helm-only)"
  echo "- APPLICATION_ONLY=$APPLICATION_ONLY (--app-only)"
  echo "- WITH_TRAEFIK=$WITH_TRAEFIK (--with-traefik)"
  echo
  echo "ArgoCD"
  echo "- ARGOCD_REPO=$ARGOCD_REPO"
  echo "- ARGOCD_VERSION=$ARGOCD_VERSION"
  echo "- ARGOCD_APP_REPO=$ARGOCD_APP_REPO"
  echo
  echo "Cluster"
  echo "- ARGOCD_RELEASE_NAME=$ARGOCD_RELEASE_NAME"
  echo "- ARGOCD_RELEASE_NAMESPACE=$ARGOCD_RELEASE_NAMESPACE"
}

install-argocd-helm() {
  helm repo add argocd-repo $ARGOCD_REPO
  helm upgrade --install $ARGOCD_RELEASE_NAME \
       argocd-repo/argo-cd \
       --namespace $ARGOCD_RELEASE_NAMESPACE --create-namespace \
       --version $ARGOCD_VERSION \
       -f "$ARGOCD_DIR"/deploy-argocd-values.yaml
}

install-argocd-apps-secret() {
  TMP_FILE=$(mktemp -t apps-secret-XXX)
  cat <<EOF > "$TMP_FILE"
apiVersion: v1
kind: Secret
metadata:
  name: "argocd-apps-repo"
  namespace: "$ARGOCD_RELEASE_NAMESPACE"
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: "git"
  url: "$ARGOCD_APP_REPO"
  password: "$ARGOCD_APP_REPO_TOKEN"
  username: ""
EOF
  kubectl apply -f "$TMP_FILE" --namespace $ARGOCD_RELEASE_NAMESPACE
}

install-argocd-apps() {
  local source_path=argocd/apps/localhost

  if [ "$WITH_TRAEFIK" == "true" ] ; then
    source_path=argocd/apps/localhost-without-fluxcd
  fi

  TMP_FILE=$(mktemp -t apps-XXX)
  cat <<EOF > "$TMP_FILE"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: $ARGOCD_RELEASE_NAMESPACE
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: default
  source:
    path: $source_path
    repoURL: $ARGOCD_APP_REPO
    targetRevision: master
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
    automated:
      prune: true
EOF
  kubectl apply -f "$TMP_FILE" --namespace $ARGOCD_RELEASE_NAMESPACE
}

wait-until-argocd-is-ready() {
  timeout=300
  index=0

  echo "Waiting until $timeout sec if argocd is ready"
  until kubectl get pods -A | grep argocd-application-controller | grep Running | grep "1/1" || [ $index -eq $timeout ];
  do
    index=$((index+1))
    echo -n "."
    sleep 1;
  done
  if [ $index -eq $timeout ]; then
    echo
    echo "Argocd is not ready after $timeout seconds"
    exit 2
  else
    echo
    echo "Argocd is ready"
  fi
}

print-config

if [ "$HELMCHART_ONLY" = "true" ]; then
  install-argocd-helm
elif [ "$APPLICATION_ONLY" = "true" ]; then
  install-argocd-apps-secret
  install-argocd-apps
else
  # Install ArgoCD
  install-argocd-helm

  echo
  wait-until-argocd-is-ready

  # Install ArgoCD apps
  install-argocd-apps-secret
  install-argocd-apps
fi

