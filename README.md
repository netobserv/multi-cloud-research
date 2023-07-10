# Research the area of multi-cloud network observability

Requirements - 
1. Go version >= 1.18 Needs to be installed manually
1. Kubectl -> Needed to be installed manually
1. jq -> Needs to be installed manually
1. Kind -> Is setup by the script
1. Skupper -> Is setup by the script
1. Submariner -> Is setup by the script

use `make all-in-one-skupper` to deploy skupper environment  

use `make all-in-one-skupper-gui` to deploy skupper environment with GUI revisions to show connection of clusters

use `make all-in-one-mbg` to deploy mbg environment

use `make all-in-one-mbg-gui` to deploy mbg environment with GUI revisions to show connection of clusters

use `make all-in-one-submariner` to deploy submariner environment
