# GitOps demo with fluxcd/v2 and argocd

> **require** docker, kubectl, git, flux, argocd, kustomize, ssh

## Getting started

> Fork `jwausle/gitops.fluxcd.git`

```
export GITHUB_USER=<your-github-user>                              # jwausle[-demo1|-demo2]
export GITHUB_TOKEN=<your-github-token-rw>                         # ghp_GFHTtbxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export GITHUB_REPO_URL=https://github.com/$GITHUB_USER/gitops.git  # https://github.com/jwausle[-demo1|-demo2]/gitops.git 

git reset demo/0 --hard
bash script/utils/sed-repo-urls.sh $GITHUB_REPO_URL

git add .
git commit -m"Reset repo url $GITHUB_REPO_URL"
git push origin main -f

# Start local cluster
bash scripts/run-cluster-local.sh

export KUBECONFIG=$(pwd)/.k3s/kubeconfig.yaml

# Check
kubectl get pods -A
```

## Required tools

> Open bash

* `git` - current version - e.g. [v2.5.0](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) `git version`
* `docker` - current version - e.g. [desktop:v29.0.1](https://docs.docker.com/desktop/setup/install/) `docker --version`
* `kubectl` - current version - e.g [v1.34.2](https://kubernetes.io/de/docs/tasks/tools/install-kubectl/#installation-der-kubectl-anwendung-mit-curl) `kubectl version`
* `kustomize` - current version - e.g. [v5.8.0](https://github.com/kubernetes-sigs/kustomize/releases/tag/kustomize%2Fv5.8.0) `kustomize version` 
* `fluxcd` - fix [v2.7.5](https://github.com/fluxcd/flux2/releases/tag/v2.7.5) `flux --version`
* `argocd` - current version - e.g. [v3.2.3](https://argo-cd.readthedocs.io/en/stable/cli_installation/) `argocd version`
* `ssh` - current version - only when AWS/EC2 will be used

## Demo kubectl 

```
kubeclt get pods -A 
k get pods -n kube-system
NAME                                      READY   STATUS    RESTARTS   AGE
coredns-54bf7cdff9-twhfz                  1/1     Running   0          3d18h
local-path-provisioner-69879d7dd7-25w2s   1/1     Running   0          3d18h
metrics-server-77dbbf84b-vj2zk            1/1     Running   0          3d18h

bash kubeclt/deploy-traefik.sh            # browse: https://localhost/dashboard/#
bash kubeclt/deploy-weave.sh              # browse: https://localhost/
bash kubeclt/deploy-whoami.sh             # browse: https://localhost/kubectl/whoami/test
```

## Demo - fluxcd

```shell
export GITHUB_USER=<your-github-user>                              # jwausle[-demo1|-demo2]
export GITHUB_TOKEN=<your-github-token-rw>                         # ghp_GFHTtbxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

export KUBECONFIG=$(pwd)/.k3s/kubeconfig.yaml

bash scripts/deploy-fluxcd.sh

# Wait until initial kustomization objects appear
flux get kustomizations -A --watch
NAMESPACE  	NAME                         	REVISION            	SUSPENDED	READY	MESSAGE 
flux-system	flux-system                  	master@sha1:a2160ebd	False    	True 	Applied revision: master@sha1:a2160ebd	
flux-system	flux-system-demo             	master@sha1:a2160ebd	False    	True 	Applied revision: master@sha1:a2160ebd	
flux-system	infrastructure               	master@sha1:a2160ebd	False    	True 	Applied revision: master@sha1:a2160ebd	

# Kubectl can alse be used
k get kustomization -n flux-system -owide
NAME               AGE     READY   STATUS
flux-system        3d18h   True    Applied revision: master@sha1:a2160ebd2b28dad520a2660f7c73f7625528c1c5
flux-system-demo   3d18h   True    Applied revision: master@sha1:a2160ebd2b28dad520a2660f7c73f7625528c1c5
infrastructure     3d18h   True    Applied revision: master@sha1:a2160ebd2b28dad520a2660f7c73f7625528c1c5
```

### Demo 1 - fluxcd

* whoami from yaml is installed

```
git merge origin/demo/1
git push origin main

# Wait until pod appear - e.g. `kubectl get pods -A --watch` 
curl -k https://localhost/whoami/test
```

### Demo 2 - fluxcd

* whoami helmchart is installed

```
git merge origin/demo/2
git push origin main

# Wait until pod appears - e.g. `kubectl get pods -A --watch` 
curl -k https://localhost/fluxcd/whoami-helmchart/test
```

### Demo 3 - fluxcd

* patch helmchart path

```shell
git merge origin/demo/3
git push origin main

# Wait until changes appear - e.g. `flux get kustomizations -A --watch` 
curl -k https://localhost/fluxcd/whoami-helmchart-overwrite/test
```

### Demo 4 - fluxcd

* patch helmrelease path

```
git merge origin/demo/4
git push origin main

# Wait until changes appear - e.g. `flux get kustomizations -A --watch` 
curl -k https://localhost/fluxcd/whoami-helmrelease-overwrite/test
```

### Demo 5 - fluxcd

* unresolved dependsOn 

```
git merge origin/demo/5
git push origin main

# Browse https://localhost/ --> Check state of Application/whoami-helmrelease-indirect-1 after re-sync
# NotReady expected
```

### Demo 6 - fluxcd

* resolve dependsOn

```
git merge origin/demo/6
git push origin main

# Browse https://localhost/ --> Check state of Application/whoami-helmrelease-indirect-1 after re-sync
# Ready expected

curl -k https://localhost/fluxcd/whoami-indirect-2/test
```

### Demo 7 - fluxcd

* install whoami from repository

```
git merge origin/demo/7
git push origin main

# Wait until changes appear - e.g. `flux get kustomizations -A --watch` 
curl -k https://localhost/fluxcd/whoami-repository/test
```

### Demo 8 - fluxcd

* reset to `demo/2`

```
git merge origin/demo/8
git push origin main

# Wait until changes appear - e.g. `flux get kustomizations -A --watch` 
curl -k https://localhost/fluxcd/whoami/test
```

## Demo - argocd

### Demo 9 - argocd

* install argocd `bash scripts/deploy-argocd.sh`

```
bash scripts/deploy-argocd.sh

# Wait until argocd installation appear
kubectl get pods --namespace argocd --watch
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          3d6h
argocd-applicationset-controller-6cc4df4645-24xzf   1/1     Running   0          3d6h
argocd-dex-server-7f5c64d579-bspd6                  1/1     Running   0          3d6h
argocd-notifications-controller-5b9b55b7dc-srwms    1/1     Running   0          3d6h
argocd-redis-55bf5cd796-29ccb                       1/1     Running   0          3d18h
argocd-repo-server-d74dcb684-fqwwt                  1/1     Running   0          3d6h
argocd-server-6f68b9b447-fjb99                      1/1     Running   0          3d6h

# Login command line
DOMAIN=localhost
argocd login $DOMAIN --grpc-web-root-path=/argocd --username=admin --password=admin --grpc-web

# Wait until argocd application appear
argocd app list
NAME                      CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO                                   PATH                                TARGET           
argocd/traefik            https://kubernetes.default.svc  traefik    default  Synced  Healthy  Auto-Prune  <none>      https://github.com/jwausle-demo2/gitops.git  argocd/traefik/localhost            main

# Kubectl can also be used
kubectl get apps -n argocd traefik -owide
NAME      SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
traefik   Synced        Healthy         a2160ebd2b28dad520a2660f7c73f7625528c1c5   default
```

### Demo 10 - argocd

* whoami service installed from yaml

```shell
git merge origin/demo/10
git push origin main

# Wait until changes appear - e.g. `flux get kustomizations -A --watch` 
curl -k https://localhost/argocd/whoami/test
```

### Demo 11 - argocd

* whoami service installed from helmchart

```shell
git merge origin/demo/11
git push origin main

# Wait until changes appear - e.g. `flux get kustomizations -A --watch` 
curl -k https://localhost/argocd/whoami-repository/test
```

### Demo 12 - argocd

* whoami service installed from helm repository

```shell
git merge origin/demo/12
git push origin main

# Wait until changes appear - e.g. `flux get kustomizations -A --watch` 
curl -k https://localhost/argocd/whoami-values/test
```

# Demo - Finish

# Links:

* browse: https://github.com/jwausle - origin 
* browse: https://github.com/jwausle-demo1 - demo user `jwausle-demo1` - aws1
* browse: https://github.com/jwausle-demo2 - demo user `jwausle-demo2` - aws2
* aws1: `ssh ubuntu@ec2-18-192-53-212.eu-central-1.compute.amazonaws.com` - https://ec2-18-192-53-212.eu-central-1.compute.amazonaws.com/
* aws2: `ssh ubuntu@ec2-18-159-224-241.eu-central-1.compute.amazonaws.com` - https://ec2-18-159-224-241.eu-central-1.compute.amazonaws.com/
* aws3: `ssh ubuntu@ec2-3-67-224-236.eu-central-1.compute.amazonaws.com` - https://ec2-3-67-224-236.eu-central-1.compute.amazonaws.com/