build:
	GOOS=linux go build -o ../build/tester-lambda lambda/tester/*.go

init:
	terraform init

get:
	terraform get -update

plan: get
	terraform plan

apply: get
	terraform apply

reset:
	../bin/reset_secrets.sh
	../bin/delete_keys.sh

destroy:
	terraform destroy
	# Bypass secrets' retention window
	../bin/delete_secrets.sh
