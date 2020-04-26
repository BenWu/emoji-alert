.PHONY: init plan deploy tfvar tfinit apply clean refresh

tfvar:
	cd terraform && ./init.sh

tfinit:
	cd terraform && terraform init

apply:
	cd terraform && terraform apply

init: tfvar tfinit

plan:
	cd terraform && terraform plan

refresh:
	cd terraform && terraform refresh

db:
	gcloud sql connect emoji-alert-instance --user=postgres --quiet

deploy:
	cp emoji_alert/alert.py main.py
	zip ./emoji_alert.zip main.py requirements.txt
	rm main.py
	$(MAKE) apply

clean:
	rm emoji_alert.zip
	rm terraform/terraform.tfvar
	terraform destroy
