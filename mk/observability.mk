##@ observability

FLP_DOCKER_TAG ?= latest
FLP_DOCKER_IMG ?= quay.io/netobserv/flowlogs-pipeline

.PHONY: deploy-observability
deploy-observability: ## Deploy observability  
	@echo -e "\n MAKE_TYPE = " $(MAKE_TYPE) "\n"
	make push-observability-namespaces
	make set-permissions
	make MAKE_TYPE=$(MAKE_TYPE) NS_PARAM=east go-east deploy-loki deploy-prometheus deploy-flp deploy-ebpf-agent deploy-console
	make MAKE_TYPE=$(MAKE_TYPE) NS_PARAM=west go-west deploy-flp deploy-ebpf-agent
	make pop-namespaces
	make go-east
	@echo -e "\n==> Done (Deploy Observability)\n" 

.PHONY: delete-observability
delete-observability: ## Delete observability  
	make push-observability-namespaces
	make go-east undeploy-loki undeploy-prometheus undeploy-flp undeploy-ebpf-agent undeploy-console
	make go-west undeploy-flp undeploy-ebpf-agent 
	make pop-namespaces
	make go-east
	@echo -e "\n==> Done (Delete Observability)\n" 

.PHONY: go-east
go-east:
	kubectl config use-context kind-east

.PHONY: go-west
go-west:
	kubectl config use-context kind-west

.PHONY: set-permissions
set-permissions:
	@echo -e "\n==> Setting permissions\n" 
	kubectl config use-context kind-east
	kubectl create clusterrolebinding east-admin --clusterrole=cluster-admin --serviceaccount=netobserv:default --dry-run=client -o yaml | kubectl apply -f - 2>&1
	kubectl config use-context kind-west
	kubectl create clusterrolebinding west-admin --clusterrole=cluster-admin --serviceaccount=netobserv:default --dry-run=client -o yaml | kubectl apply -f - 2>&1

.PHONY: push-observability-namespaces
push-observability-namespaces:
	@echo -e "\n==> Creating and setting observability namespaces\n" 
	kubectl config use-context kind-east
	-kubectl create namespace netobserv
	kubectl config set-context --current --namespace=netobserv
	kubectl config use-context kind-west
	-kubectl create namespace netobserv
	kubectl config set-context --current --namespace=netobserv

.PHONY: pop-namespaces
pop-namespaces:
	@echo -e "\n==> Moving back to namespaces\n" 
	kubectl config use-context kind-east
	kubectl config set-context --current --namespace=east
	kubectl config use-context kind-west
	kubectl config set-context --current --namespace=west

.PHONY: deploy-console
 deploy-console:
	@echo -e "\n==> Deploy Console\n" 
	sleep 5
	kubectl apply -f contrib/observability/deployment-console.yaml
	kubectl rollout status "deploy/console" --timeout=600s
	kubectl expose deployment console --port=9001 --target-port=9001 --name=console-lb --type=LoadBalancer
	sleep 1; \
	export URL=`kubectl get service console-lb -o jsonpath="http://{.status.loadBalancer.ingress[].ip}:{.spec.ports[].targetPort}"`; \
	echo "Access URL: $$URL"; \
	sleep 5; \

.PHONY: undeploy-console
undeploy-console:
	@echo -e "\n==> Undeploy Console\n" 
	kubectl --ignore-not-found=true delete -f contrib/observability/deployment-console.yaml || true
	-kubectl delete service console-lb

.PHONY: deploy-ebpf-agent
deploy-ebpf-agent:
	@echo -e "\n==> Deploy eBPF Agent\n" 
	sleep 5
	kubectl apply -f contrib/observability/deployment-ebpf-agent.yaml
	kubectl rollout status "deploy/ebpf-agent" --timeout=600s

.PHONY: undeploy-ebpf-agent
undeploy-ebpf-agent:
	@echo -e "\n==> Undeploy eBPF Agent\n" 
	kubectl --ignore-not-found=true delete -f contrib/observability/deployment-ebpf-agent.yaml || true

.PHONY: deploy-flp
deploy-flp:
	@echo -e "\n==> Deploy FLP\n"
	@echo -e "\n MAKE_TYPE = " $(MAKE_TYPE) "\n"
	sed 's|%DOCKER_IMG%|$(FLP_DOCKER_IMG)|g;s|%DOCKER_TAG%|$(FLP_DOCKER_TAG)|g' contrib/observability/deployment-flp.yaml > /tmp/deployment.yaml
ifeq ($(MAKE_TYPE),SUBMARINER)
	$(eval PRODUCTPAGE_POD_ID := $(shell kubectl get pods --context kind-east -n east --selector="app=productpage" --no-headers=true -o wide | awk '{print $$6}' ))
	@echo -e "\n PRODUCTPAGE_POD_ID = " $(PRODUCTPAGE_POD_ID) "\n"
	$(eval DETAILS_SERVICE_IP := $(shell kubectl get services -n west --selector=app=details --no-headers=true --context kind-west | awk '{print $$3}' ))
	@echo -e "\n DETAILS_SERVICE_IP = " $(DETAILS_SERVICE_IP) "\n"
	export LOKI_URL=`cat /tmp/loki_url.addr`; \
	sed 's|%LOKI_URL%|'$$LOKI_URL'|g; s|%PRODUCTPAGE_POD_ID%|$(PRODUCTPAGE_POD_ID)|g; s|%DETAILS_SERVICE_IP%|$(DETAILS_SERVICE_IP)|g;' \
	contrib/observability/conf/flp.conf.submariner.yaml > /tmp/flp.conf.yaml
else ifeq ($(MAKE_TYPE),MBG)
	@echo -e "\n NS_PARAM = " $(NS_PARAM) "\n"
	$(eval EAST_GATEWAY_IP := $(shell kubectl get pods --context kind-east -n east --selector=app=mbg --no-headers=true -o wide | awk '{print $$6}' ))
	$(eval WEST_GATEWAY_IP := $(shell kubectl get pods --context kind-west -n west --selector=app=mbg --no-headers=true -o wide | awk '{print $$6}' ))
	$(eval MBG_LOG_IP := $(shell kubectl get services -n $(NS_PARAM) --selector=app=mbg --no-headers=true -o jsonpath={.items[1].spec.clusterIP}))
	$(eval MBG_LOG_PORT := $(shell kubectl get services -n $(NS_PARAM) --selector=app=mbg --no-headers=true -o jsonpath={.items[1].spec.ports[].targetPort}))
	@echo -e "\n EAST_GATEWAY_IP = " $(EAST_GATEWAY_IP) "\n"
	@echo -e "\n WEST_GATEWAY_IP = " $(WEST_GATEWAY_IP) "\n"
	@echo -e "\n MBG_LOG_IP = " $(MBG_LOG_IP) "\n"
	@echo -e "\n MBG_LOG_PORT = " $(MBG_LOG_PORT) "\n"
	export LOKI_URL=`cat /tmp/loki_url.addr`; \
	sed 's|%LOKI_URL%|'$$LOKI_URL'|g; s|%EAST_GATEWAY_IP%|$(EAST_GATEWAY_IP)|g; s|%WEST_GATEWAY_IP%|$(WEST_GATEWAY_IP)|g; s|%MBG_LOG_IP%|$(MBG_LOG_IP)|g; s|%MBG_LOG_PORT%|$(MBG_LOG_PORT)|g;' \
	contrib/observability/conf/flp.conf.mbg.yaml > /tmp/flp.conf.yaml
else ifeq ($(MAKE_TYPE),MBG2)
	@echo -e "\n NS_PARAM = " $(NS_PARAM) "\n"
	$(eval MBG_LOG_IP := $(shell kubectl get services -n $(NS_PARAM) --selector=app=mbg --no-headers=true -o jsonpath={.items[1].spec.clusterIP}))
	$(eval MBG_LOG_PORT := $(shell kubectl get services -n $(NS_PARAM) --selector=app=mbg --no-headers=true -o jsonpath={.items[1].spec.ports[].targetPort}))
	@echo -e "\n EAST_GATEWAY_IP = " $(EAST_GATEWAY_IP) "\n"
	@echo -e "\n WEST_GATEWAY_IP = " $(WEST_GATEWAY_IP) "\n"
	@echo -e "\n MBG_LOG_IP = " $(MBG_LOG_IP) "\n"
	@echo -e "\n MBG_LOG_PORT = " $(MBG_LOG_PORT) "\n"
	export LOKI_URL=`cat /tmp/loki_url.addr`; \
	sed 's|%LOKI_URL%|'$$LOKI_URL'|g; s|%EAST_GATEWAY_IP%|$(EAST_GATEWAY_IP)|g; s|%WEST_GATEWAY_IP%|$(WEST_GATEWAY_IP)|g; s|%MBG_LOG_IP%|$(MBG_LOG_IP)|g; s|%MBG_LOG_PORT%|$(MBG_LOG_PORT)|g;' \
	contrib/observability/conf/flp.conf.mbg.yaml > /tmp/flp.conf.yaml
else ifeq ($(MAKE_TYPE),SKUPPER)
	$(eval EAST_GATEWAY_IP := $(shell kubectl get pods --context kind-east -n east --selector=app.kubernetes.io/name=skupper-service-controller --no-headers=true -o wide | awk '{print $$6}' ))
	$(eval WEST_GATEWAY_IP := $(shell kubectl get pods --context kind-west -n west --selector=app.kubernetes.io/name=skupper-service-controller --no-headers=true -o wide | awk '{print $$6}' ))
	@echo -e "\n EAST_GATEWAY_IP = " $(EAST_GATEWAY_IP) "\n"
	@echo -e "\n WEST_GATEWAY_IP = " $(WEST_GATEWAY_IP) "\n"
	export LOKI_URL=`cat /tmp/loki_url.addr`; \
	sed 's|%LOKI_URL%|'$$LOKI_URL'|g; s|%EAST_GATEWAY_IP%|$(EAST_GATEWAY_IP)|g; s|%WEST_GATEWAY_IP%|$(WEST_GATEWAY_IP)|g;' \
	contrib/observability/conf/flp.conf.skupper.yaml > /tmp/flp.conf.yaml
else
	export LOKI_URL=`cat /tmp/loki_url.addr`; \
	sed 's|%LOKI_URL%|'$$LOKI_URL'|g;' \
	contrib/observability/conf/flp.conf.yaml > /tmp/flp.conf.yaml
endif
	kubectl create configmap flowlogs-pipeline-configuration --from-file=flowlogs-pipeline.conf.yaml=/tmp/flp.conf.yaml
	kubectl apply -f /tmp/deployment.yaml
	kubectl rollout status "deploy/flowlogs-pipeline" --timeout=600s

.PHONY: undeploy-flp
undeploy-flp:
	@echo -e "\n==> Undeploy FLP\n" 
	sed 's|%DOCKER_IMG%|$(FLP_DOCKER_IMG)|g;s|%DOCKER_TAG%|$(FLP_DOCKER_TAG)|g' contrib/observability/deployment-flp.yaml > /tmp/deployment.yaml
	kubectl --ignore-not-found=true  delete configmap flowlogs-pipeline-configuration || true
	kubectl --ignore-not-found=true delete -f /tmp/deployment.yaml || true

.PHONY: deploy-loki
deploy-loki:
	@echo -e "\n==> Deploy Loki\n" 
	kubectl apply -f contrib/observability/deployment-loki-storage.yaml
	kubectl apply -f contrib/observability/deployment-loki.yaml
	kubectl rollout status "deploy/loki" --timeout=600s
	-pkill --oldest --full "3100:3100"
	kubectl expose deployment loki --port=3100 --target-port=3100 --name=loki-lb --type=LoadBalancer
	kubectl get service loki-lb -o jsonpath="http://{.status.loadBalancer.ingress[].ip}:{.spec.ports[].targetPort}" > /tmp/loki_url.addr
	kubectl port-forward --address 0.0.0.0 svc/loki 3100:3100 2>&1 >/dev/null &
	@echo -e "\nloki endpoint is available on http://localhost:3100\n"

.PHONY: undeploy-loki
undeploy-loki:
	@echo -e "\n==> Undeploy Loki\n" 
	kubectl --ignore-not-found=true delete -f contrib/observability/deployment-loki.yaml || true
	kubectl --ignore-not-found=true delete -f contrib/observability/deployment-loki-storage.yaml || true
	-kubectl delete service loki-lb
	-pkill --oldest --full "3100:3100"

.PHONY: deploy-prometheus
deploy-prometheus:
	@echo -e "\n==> Deploy prometheus\n" 
	kubectl apply -f contrib/observability/deployment-prometheus.yaml
	kubectl rollout status "deploy/prometheus" --timeout=600s
	-pkill --oldest --full "9090:9090"
	kubectl port-forward --address 0.0.0.0 svc/prometheus 9090:9090 2>&1 >/dev/null &
	@echo -e "\nprometheus ui is available on http://localhost:9090\n"

.PHONY: undeploy-prometheus
undeploy-prometheus:
	@echo -e "\n==> Undeploy prometheus\n" 
	kubectl --ignore-not-found=true delete -f contrib/observability/deployment-prometheus.yaml || true
	-pkill --oldest --full "9090:9090"


# need to get the relevant interfaces by running:
# kubectl get pods -n calico-system -l k8s-app=calico-node
# and for each pod:
# kubectl exec -it calico-node-5rnj7 -n calico-system -c calico-node -- calico-node -show-status
# and find the names of the interfaces by the IP addresses 
# for example: 10.240.134.199
# | 10.240.134.199/32 | N/A	| cali410cd4daa3c | kernel1         | *       |
# we know that the interface is `cali410cd4daa3c` 
# :-) 
## kubectl exec -it calico-node-b64kv -n calico-system -c calico-node -- calico-node -show-status | grep "| cali" | awk '{print $6}'
