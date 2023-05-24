##@ kind

.PHONY: create-kind-clusters
create-kind-clusters: $(KIND) ## Create clusters
	@echo -e "\n==> Create kind clusters\n" 
	docker kill proxy;docker rm proxy; docker run -d --name proxy --restart=always --net=kind -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io registry:2
	$(KIND) create cluster --name $(KIND_CLUSTER_NAME_EAST) --config contrib/kind/kindeastconfig.yaml
	kubectl config use-context kind-east
	kubectl create namespace east
	kubectl config set-context --current --namespace=east
	$(KIND) create cluster --name $(KIND_CLUSTER_NAME_WEST) --config contrib/kind/kindwestconfig.yaml
	kubectl config use-context kind-west
	kubectl create namespace west
	kubectl config set-context --current --namespace=west
	docker network inspect -f '{{.IPAM.Config}}' kind

# REF: https://piotrminkowski.com/2021/07/08/kubernetes-multicluster-with-kind-and-submariner/
.PHONY: deploy-cni
deploy-cni: $(KIND) ## deploy calico cni
	@echo -e "\n==> Deploy calico cni\n" 
	kubectl config use-context kind-east
	kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
	kubectl wait --namespace tigera-operator --for=condition=ready pod --selector=name=tigera-operator --timeout=180s
	kubectl create -f contrib/calico/calicoeastconfig.yaml
	kubectl config use-context kind-west
	kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
	kubectl wait --namespace tigera-operator --for=condition=ready pod --selector=name=tigera-operator --timeout=180s
	kubectl create -f contrib/calico/calicowestconfig.yaml

# REF: https://kind.sigs.k8s.io/docs/user/loadbalancer/
.PHONY: deploy-loadbalancers
deploy-loadbalancers: $(KIND) ## deploy loadbalancers
	@echo -e "\n==> Deploy loadbalancers\n" 
	kubectl config use-context kind-east
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
	kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=600s
	kubectl apply -f contrib/metallb/eastlbconfig.yaml
	kubectl config use-context kind-west
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
	kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=600s
	kubectl apply -f contrib/metallb/westlbconfig.yaml
	
.PHONY: delete-kind-clusters
delete-kind-clusters: $(KIND) ## Delete clusters
	@echo -e "\n==> Delete kind clusters\n" 
	$(KIND) delete cluster --name $(KIND_CLUSTER_NAME_EAST)
	$(KIND) delete cluster --name $(KIND_CLUSTER_NAME_WEST)
