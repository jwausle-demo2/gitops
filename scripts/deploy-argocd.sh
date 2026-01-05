# * require helm, kubectl
SCRIPT_DIR=$(dirname "$0")

ARGOCD_DIR="$SCRIPT_DIR"
ARGOCD_REPO="https://argoproj.github.io/argo-helm"
ARGOCD_VERSION="9.2.4"
ARGOCD_APP_VERSION="3.2.3" # Should in sync with `Chart.yaml$.appVersion`
ARGOCD_APP_REPO_TOKEN="ghp_" # Split token into two parts to avoid github security issue
ARGOCD_APP_REPO_TOKEN+="YcukYDwxbW6Ja4i58hXGnobh26bh670GvcE2"
ARGOCD_APP_REPO_TOKEN=${GITLAB_ACCESS_TOKEN:-${ARGOCD_APP_REPO_TOKEN}}
ARGOCD_APP_REPO="https://github.com/jwausle/gitops.git"

# There are some hardcoded drawbacks in used argocd/**/*.yaml files regarding namespace
ARGOCD_RELEASE_NAME="argocd"
ARGOCD_RELEASE_NAMESPACE="argocd"

if ! [[ "$KUBECONFIG" =~ "treboul" ]] && ! [[ "$*" =~ "--skip-config-check" ]]; then
  echo "KUBECONFIG is not in directory of /treboul/ - '$KUBECONFIG'"
  exit 1
fi

HELMCHART_ONLY=false
if [[ "$*" =~ "--helm-only" ]]; then
  HELMCHART_ONLY=true
fi

APPLICATION_ONLY=false
if [[ "$*" =~ "--app-only" ]]; then
  APPLICATION_ONLY=true
fi

install-argocd-helm() {
  helm repo add argocd-repo $ARGOCD_REPO
  helm upgrade --install $ARGOCD_RELEASE_NAME \
       argocd-repo/argo-cd \
       --namespace $ARGOCD_RELEASE_NAMESPACE --create-namespace \
       --version $ARGOCD_VERSION \
       -f "$ARGOCD_DIR"/deploy-argocd-values.yaml
}

install-argocd-crds() {
  kubectl create namespace $ARGOCD_RELEASE_NAMESPACE

  # Install ArgoCD crds (only) - with a unclear workaround
  # - Unclear why it is not working with ...
  # - kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=$ARGOCD_APP_VERSION
  # - Then the argocd-applicationset-controller and argocd-server not starting (CrashLoopBackOff)
  kubectl apply -k "$ARGOCD_RELEASE_CRDS_DIR"
  kubectl delete ClusterRoleBindings --selector 'app.kubernetes.io/part-of=argocd'
  kubectl delete ClusterRoles --selector 'app.kubernetes.io/part-of=argocd'
  kubectl delete namespace $ARGOCD_RELEASE_NAMESPACE
}

install-argocd-crds-offline() {
  kubectl create namespace $ARGOCD_RELEASE_NAMESPACE
  kubectl apply -k "$ARGOCD_RELEASE_CRDS_DIR-offline"
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
    path: argocd/apps/localhost
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

if [ "$HELMCHART_ONLY" = "true" ]; then
  install-argocd-helm
elif [ "$APPLICATION_ONLY" = "true" ]; then
  install-argocd-apps-secret
  install-argocd-apps
else
  # Install ArgoCD crds
  # install-argocd-crds-offline
  # Install ArgoCD
  install-argocd-helm

  echo
  wait-until-argocd-is-ready

  # Install ArgoCD apps
  install-argocd-apps-secret
  install-argocd-apps
fi

