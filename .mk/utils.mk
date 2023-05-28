.PHONY: prereqs
prereqs:
	@echo -e "\n==> Checking if prerequisites are met" 
	@jq --version >/dev/null 2>&1 || (echo -e "\n!!! prereq failed !!!: jq is required.\n"; exit 1)
	@echo -e "==> Everything is good :-)\n" 
