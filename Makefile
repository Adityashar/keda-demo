PROJECT_NAME?=keda-demo

KIND_VERSION?=v1.23.4
KIND_CLUSTER_NAME?=${PROJECT_NAME}-${KIND_VERSION}
KIND_CONTEXT?=kind-${KIND_CLUSTER_NAME}

kind-create:
	kind create cluster --name ${KIND_CLUSTER_NAME} --image kindest/node:${KIND_VERSION}

kind-context:
	kubectl config use ${KIND_CONTEXT}

kind-clean:
	kind delete clusters ${KIND_CLUSTER_NAME}

helm-setup:
	helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
	helm repo add kedacore https://kedacore.github.io/charts
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

keda-setup: kind-context
	helm upgrade -i metrics-server metrics-server/metrics-server --namespace metrics-server --create-namespace --set args={--kubelet-insecure-tls}
	helm upgrade -i keda kedacore/keda --namespace keda --version 2.8.2 --create-namespace

prometheus-setup: kind-context 
	helm upgrade -i prometheus prometheus-community/kube-prometheus-stack --namespace -f manifests/values.yaml prometheus --create-namespace

hello-setup: kind-context
	kubectl apply -f manifests/hello.yaml
	kubectl apply -f manifests/monitor.yaml
	kubectl apply -f manifests/keda.yaml

demo-setup: kind-context helm-setup prometheus-setup keda-setup hello-setup

# EXPERIMENTS

load: kind-context
	kubectl apply -f manifests/load.yaml

increase-load: kind-context
	REPLICA_COUNT=$$((`kubectl get deploy load -n load -o jsonpath='{.spec.replicas}'`+2)) && kubectl scale --replicas=$$REPLICA_COUNT deployment/load -n load

decrease-load: kind-context
	REPLICA_COUNT=$$((`kubectl get deploy load -n load -o jsonpath='{.spec.replicas}'`-2)) && kubectl scale --replicas=$$((REPLICA_COUNT>0?REPLICA_COUNT:1)) deployment/load -n load

clean-load:
	kubectl delete -f manifests/load.yaml