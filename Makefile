build:
	GOOS=linux go build -o rotate-lambda ./main.go
	zip rotate-lambda.zip ./rotate-lambda

deploy: build
	cp rotate-lambda.zip terraform/
	cd terraform && terraform apply
	rm rotate-lambda* terraform/rotate-lambda.zip
