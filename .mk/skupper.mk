##@ Skupper

GET_SKUPPER="https://skupper.io/install.sh"

.PHONY: download-skupper
download-skupper:
	@echo -e "\n==> Downloading skupper\n"
ifeq (,$(wildcard ${SKUPPER}))
	curl ${GET_SKUPPER} | sh
else
	@echo "==> ${SKUPPER} exists. skipping download"
endif
	@echo -e "\nDone\n"

.PHONY: deploy-skupper
deploy-skupper: $(KIND) download-skupper ##Deploy Skupper
	@echo -e "\n==> Deploy skupper\n" 
	kubectl config use-context kind-west
	${SKUPPER} init --enable-console --enable-flow-collector
	${SKUPPER} status
	@echo -e "\nUse password:\n"
	kubectl get secret skupper-console-users -o jsonpath={.data.admin} | base64 -d
	@echo -e "\n"
	kubectl config use-context kind-east
	${SKUPPER} init --enable-console --enable-flow-collector
	${SKUPPER} status
	@echo -e "\nUse password:\n"
	kubectl get secret skupper-console-users -o jsonpath={.data.admin} | base64 -d
	@echo -e "\n"
	kubectl wait --namespace east --for=condition=ready pod --selector=app.kubernetes.io/name=skupper-service-controller --timeout=600s
	kubectl config use-context kind-west
	${SKUPPER} token create /tmp/skupper-connection-token.yaml
	sleep 5
	kubectl config use-context kind-east
	${SKUPPER} link create /tmp/skupper-connection-token.yaml
	sleep 5
	${SKUPPER} link status
	make skupperconnect-workload

.PHONY: delete-skupper
delete-skupper: $(KIND) ##Delete Skupper
	@echo -e "\n==> Delete skupper\n" 
	kubectl config use-context kind-east
	-${SKUPPER} delete
	kubectl config use-context kind-west
	-${SKUPPER} delete

.PHONY: skupper-connect-workload
skupper-connect-workload: $(KIND)
	@echo -e "\n==> Connect workload\n"
	kubectl config use-context kind-west
	${SKUPPER} expose service details --address details --protocol http
	kubectl config use-context kind-east