build: build-rotate build-cleanup build-test

deploy:
	cd terraform && terraform apply

build-rotate:
	GOOS=linux go build -o rotate-lambda ./rotate.go
	zip rotate-lambda.zip ./rotate-lambda

build-cleanup:
	GOOS=linux go build -o cleanup-lambda ./cleanup.go
	zip cleanup-lambda.zip ./cleanup-lambda

build-test:
	GOOS=linux go build -o test-lambda ./test.go
	zip test-lambda.zip ./test-lambda

clean:
	rm rotate-lambda* cleanup-lambda* test-lambda*
