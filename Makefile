build: build-rotate build-cleanup build-test

plan:
	cd terraform && terraform plan

deploy:
	cd terraform && terraform apply

build-rotate:
	GOOS=linux go build -o build/rotate-lambda lambda/rotator/*.go

build-cleanup:
	GOOS=linux go build -o build/cleanup-lambda lambda/cleanup/*.go

build-test:
	GOOS=linux go build -o build/tester-lambda lambda/tester/*.go

clean:
	rm build/*
