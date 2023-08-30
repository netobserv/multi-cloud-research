##@ mbg

.PHONY: deploy-mbg
deploy-mbg: $(KIND) ##Deploy mbg 
	@echo -e "\n==> Deploy mbg\n" 
	kubectl config use-context kind-east
	kubectl create clusterrolebinding east-admin --clusterrole=cluster-admin --serviceaccount=east:default --dry-run=client -o yaml | kubectl apply -f - 2>&1 
	kubectl apply -f contrib/mbg/mbg.yaml;
	sleep 5
	kubectl wait --for=condition=ready pod --selector=app=mbg --timeout=600s;
	kubectl wait --for=condition=ready pod --selector=app=mbgctl --timeout=600s;
	kubectl config use-context kind-west;
	kubectl create clusterrolebinding west-admin --clusterrole=cluster-admin --serviceaccount=west:default --dry-run=client -o yaml | kubectl apply -f - 2>&1 
	kubectl apply -f contrib/mbg/mbg.yaml
	sleep 5
	kubectl wait --for=condition=ready pod --selector=app=mbg --timeout=600s;
	kubectl wait --for=condition=ready pod --selector=app=mbgctl --timeout=600s;
	make start-mbg
	make mbg-connect-workload

.PHONY: delete-mbg
delete-mbg: $(KIND) ##Delete mbg 
	@echo -e "\n==> Delete mbg\n" 
	kubectl config use-context kind-east
	-kubectl delete service details 
	kubectl delete -f contrib/mbg/mbg.yaml
	kubectl wait --for=delete pod --selector=app=mbg --timeout=60s
	kubectl wait --for=delete pod --selector=app=mbgctl --timeout=60s
	kubectl delete service mbg
	kubectl delete service mbg-log
	kubectl config use-context kind-west
	kubectl delete -f contrib/mbg/mbg.yaml
	kubectl wait --for=delete pod --selector=app=mbg --timeout=60s
	kubectl wait --for=delete pod --selector=app=mbgctl --timeout=60s
	kubectl delete service mbg
	kubectl delete service mbg-log

.PHONY: start-mbg
start-mbg: $(KIND) 
	@echo -e "\n==> Start mbg\n" 
	kubectl config use-context kind-east
	export MBG_EAST=`kubectl get pods -l app=mbg -o custom-columns=:metadata.name`; \
	export MBG_EAST_NODEIP=`kubectl get nodes -o jsonpath={.items[0].status.addresses[0].address}`; \
	export MBG_EAST_PODIP=`kubectl get pod $$MBG_EAST --template '{{.status.podIP}}'`; \
	export MBGCTL_EAST=`kubectl get pods -l app=mbgctl -o custom-columns=:metadata.name`; \
	kubectl exec $$MBG_EAST -- sh -c "./mbg start --id mbg1 --ip $$MBG_EAST_NODEIP --cport 30443 --cportLocal 8443 --dataplane mtls --rootCa ./mtls/ca.crt --certificate ./mtls/mbg1.crt --key ./mtls/mbg1.key &> /dev/null &"; \
	kubectl exec $$MBGCTL_EAST -- ./mbgctl create --id mbg1 --mbgIP $$MBG_EAST_PODIP:8443 --dataplane mtls --rootCa ./mtls/ca.crt --certificate ./mtls/mbg1.crt --key ./mtls/mbg1.key; \
	kubectl exec -i $$MBG_EAST -- ./mbg get state;
	kubectl create service nodeport mbg --tcp=8443:8443 --node-port=30443 --dry-run=client -o yaml | kubectl apply -f - 2>&1;
	kubectl config use-context kind-west
	export MBG_WEST=`kubectl get pods -l app=mbg -o custom-columns=:metadata.name`; \
	export MBG_WEST_NODEIP=`kubectl get nodes -o jsonpath={.items[0].status.addresses[0].address}`; \
	export MBG_WEST_PODIP=`kubectl get pod $$MBG_WEST --template '{{.status.podIP}}'`; \
	export MBGCTL_WEST=`kubectl get pods -l app=mbgctl -o custom-columns=:metadata.name`; \
	kubectl exec $$MBG_WEST -- sh -c "./mbg start --id mbg2 --ip $$MBG_WEST_NODEIP --cport 30443 --cportLocal 8443 --dataplane mtls --rootCa ./mtls/ca.crt --certificate ./mtls/mbg1.crt --key ./mtls/mbg1.key &> /dev/null &"; \
	kubectl exec $$MBGCTL_WEST -- ./mbgctl create --id mbg2 --mbgIP $$MBG_WEST_PODIP:8443 --dataplane mtls --rootCa ./mtls/ca.crt --certificate ./mtls/mbg1.crt --key ./mtls/mbg1.key; \
	kubectl exec -i $$MBG_WEST -- ./mbg get state;
	kubectl create service nodeport mbg --tcp=8443:8443 --node-port=30443 --dry-run=client -o yaml | kubectl apply -f - 2>&1;

.PHONY: mbg-connect-workload
mbg-connect-workload: $(KIND)
	@echo -e "\n==> Connect workload\n" 
	kubectl config use-context kind-east; \
	export MBG_EAST=`kubectl get pods -l app=mbg -o custom-columns=:metadata.name`; \
	export MBGCTL_EAST=`kubectl get pods -l app=mbgctl -o custom-columns=:metadata.name`; \
	kubectl config use-context kind-west; \
	export MBG_WEST=`kubectl get pods -l app=mbg -o custom-columns=:metadata.name`; \
	export MBGCTL_WEST=`kubectl get pods -l app=mbgctl -o custom-columns=:metadata.name`; \
	export MBG_WEST_NODEIP=`kubectl get nodes -o jsonpath={.items[0].status.addresses[0].address}`; \
	kubectl config use-context kind-east; \
	kubectl exec -i $$MBGCTL_EAST -- ./mbgctl add peer --id "mbg2" --target $$MBG_WEST_NODEIP --port 30443; \
	kubectl exec -i $$MBGCTL_EAST -- ./mbgctl hello; \
	kubectl exec -i $$MBG_EAST -- ./mbg get state; \
	kubectl expose deployment mbg-deployment --port=9091 --target-port=9091 --name=mbg-log --type=NodePort; \
	kubectl config use-context kind-west; \
	export DETAILS_POD_IP=`kubectl get pods -l app=details -o jsonpath={.items[0].status.podIP}`; \
	export DETAILS_POD_PORT=`kubectl get pods -l app=details -o jsonpath={.items[0].spec.containers[0].ports[0].containerPort}`; \
	kubectl exec -i $$MBGCTL_WEST -- ./mbgctl add service --id details --target $$DETAILS_POD_IP --port $$DETAILS_POD_PORT --description details; \
	kubectl exec -i $$MBGCTL_WEST -- ./mbgctl expose --service details; \
	kubectl exec -i $$MBG_WEST -- ./mbg get state; \
	kubectl expose deployment mbg-deployment --port=9091 --target-port=9091 --name=mbg-log --type=NodePort; \
	kubectl config use-context kind-east; \
	kubectl exec -i $$MBG_EAST -- ./mbg get state; \
	export MBG_EAST_PORT_TMP=`kubectl exec -it $$MBG_EAST -- cat ./root/.mbg/mbgApp`; \
	export MBG_EAST_PORT=`echo "$$MBG_EAST_PORT_TMP" | jq -r '.Connections.details.Local | gsub("[:]"; "")'`; \
	kubectl create service clusterip details --tcp=9080:$$MBG_EAST_PORT; 
	kubectl patch service details -p '{"spec":{"selector":{"app": "mbg"}}}';
