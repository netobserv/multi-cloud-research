##@ Submariner

GET_SUBMARINER="https://get.submariner.io"

.PHONY: deploy-submariner
deploy-submariner: $(KIND) ##Deploy Submariner
	@echo -e "\n==> Downloading submariner\n"
ifeq (,$(wildcard ${SUBMARINER}))
	curl -Ls ${GET_SUBMARINER} | bash
else
	@echo "==> ${SUBMARINER} exists. skipping download"
endif
	@echo -e "\n==> Deploy submariner\n"
	@echo -e "\n==> Setting up config.\n"
	cp ~/.kube/config ${BINDIR}/kubeconfig-backup
	kubectl config set-cluster kind-east --server https://$$(kubectl --context kind-east get nodes --field-selector metadata.name=east-control-plane -o=jsonpath='{.items[0].status.addresses[0].address}'):6443/
	kubectl config set-cluster kind-west --server https://$$(kubectl --context kind-west get nodes --field-selector metadata.name=west-control-plane -o=jsonpath='{.items[0].status.addresses[0].address}'):6443/
	@echo -e "\nDeploying brokers\n"
	@echo -e "\n[EAST]\n"
	kubectl config use-context kind-east
	${SUBCTL} deploy-broker
	mv ./broker-info.subm ${BINDIR}/submariner-broker-info.subm
	@echo -e "\nSetting up gateways\n"
	kubectl label node east-worker submariner.io/gateway=true
	${SUBCTL} join ${BINDIR}/submariner-broker-info.subm --natt=false --clusterid kind-east
	@echo -e "\n[WEST]\n"
	kubectl config use-context kind-west
	kubectl label node west-worker submariner.io/gateway=true
	${SUBCTL} join ${BINDIR}/submariner-broker-info.subm --natt=false --clusterid kind-west
	@echo -e "\nWaiting for submariner pods to be Ready.\n"
	-kubectl --context kind-east wait --for=condition=Ready pods --all -n submariner-operator --timeout 300s
	-kubectl --context kind-west wait --for=condition=Ready pods --all -n submariner-operator --timeout 300s
	@echo -e "\nCheck submariner information\n"
	-${SUBCTL} show all
	@echo -e "\nDone\n"
	make submariner-connect-workload

.PHONY: delete-submariner
delete-submariner: $(KIND) ##Delete Submariner
	@echo -e "\n==> Delete submariner\n"
	@echo -e "\n[EAST]\n"
	kubectl config use-context kind-east
	-${SUBCTL} uninstall
	@echo -e "\n[WEST]\n"
	kubectl config use-context kind-west
	-${SUBCTL} uninstall
	@echo -e "\n==> Done\n"

.PHONY: submariner-connect-workload
submariner-connect-workload: $(KIND)
	@echo -e "\n==> Connect workload\n"
	kubectl config use-context kind-west
	${SUBCTL} export service --namespace app details
	@echo -e "\n==> Done\n"
	@echo -e "\n==> Switch to east and set proper details service endpoint\n"
	kubectl config use-context kind-east
	kubectl set env deployment productpage-v1 DETAILS_HOSTNAME=details.app.svc.clusterset.local
	@echo -e "\n==> Done\n"