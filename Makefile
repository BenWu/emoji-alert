.PHONY: init plan deploy tfvar tfinit apply

tfvar:
	cd terraform && ./init.sh

tfinit:
	cd terraform && terraform init

apply:
	cd terraform && terraform apply

init: tfvar tfinit

plan:
	cd terraform && terraform plan

deploy: apply
