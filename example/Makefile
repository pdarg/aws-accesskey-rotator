build:
	GOOS=linux go build -o tester-lambda lambda/tester/*.go

init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply

reset:
	../bin/reset_secrets.sh
	../bin/delete_keys.sh

destroy: reset
	terraform destroy
	# Secret Manager secrets are soft deleted. This script force deletes now
	../bin/delete_secrets.sh
