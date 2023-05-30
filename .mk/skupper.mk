##@ skupper

.PHONY: deploy-skupper
deploy-skupper: $(KIND) ##Deploy skupper
	@echo -e "\n==> Deploy skupper\n" 
	curl https://skupper.io/install.sh | sh	
	kubectl config use-context kind-west
	skupper init --enable-console --enable-flow-collector
	skupper status
	@echo -e "\nUse password:\n"
	kubectl get secret skupper-console-users -o jsonpath={.data.admin} | base64 -d
	@echo -e "\n"
	kubectl config use-context kind-east
	skupper init --enable-console --enable-flow-collector
	skupper status
	@echo -e "\nUse password:\n"
	kubectl get secret skupper-console-users -o jsonpath={.data.admin} | base64 -d
	@echo -e "\n"
	sleep 5
	kubectl config use-context kind-west
	skupper token create /tmp/skupper-connection-token.yaml
	sleep 5
	kubectl config use-context kind-east
	skupper link create /tmp/skupper-connection-token.yaml
	sleep 5
	skupper link status
	make skupper-connect-workload

.PHONY: delete-skupper
delete-skupper: $(KIND) ##Delete skupper
	@echo -e "\n==> Delete skupper\n" 
	kubectl config use-context kind-east
	-skupper delete
	kubectl config use-context kind-west
	-skupper delete

.PHONY: skupper-connect-workload
skupper-connect-workload: $(KIND)
	@echo -e "\n==> Connect workload\n"
	kubectl config use-context kind-west
	skupper expose service details --address details --protocol http
	kubectl config use-context kind-east
