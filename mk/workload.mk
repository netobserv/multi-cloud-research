##@ workload

.PHONY: deploy-workload
deploy-workload: $(KIND) ## Deploy demo workload
	@echo -e "\n==> Deploy workload\n" 
	kubectl config use-context kind-west
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/platform/kube/bookinfo.yaml -l account=details
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/platform/kube/bookinfo.yaml -l app=details
	kubectl config use-context kind-east
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account in (ratings, reviews, productpage)'
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (ratings, reviews, productpage)'
	kubectl expose deployment productpage-v1 --port=9080 --target-port=9080 --name=productpage-lb --type=LoadBalancer
	sleep 1; \
	export URL=`kubectl get service productpage-lb -o jsonpath="http://{.status.loadBalancer.ingress[].ip}:{.spec.ports[].targetPort}/productpage?u=normal"`; \
	echo "Access URL: $$URL"; \
	sleep 5; \
	kubectl run stress --image curlimages/curl -- sh -c "while true; do curl $$URL; sleep 1; done"

.PHONY: delete-workload
delete-workload: $(KIND) ## Delete demo workload
	@echo -e "\n==> Delete workload\n" 
	kubectl config use-context kind-west
	-kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/platform/kube/bookinfo.yaml -l account=details
	-kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/platform/kube/bookinfo.yaml -l app=details
	kubectl config use-context kind-east
	-kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account in (ratings, reviews, productpage)'
	-kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (ratings, reviews, productpage)'
	-kubectl delete service productpage-lb
	-kubectl delete pod stress
