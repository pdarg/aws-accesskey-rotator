build: build-rotate build-cleanup

build-rotate:
	GOOS=linux go build -o build/rotate-lambda lambda/rotator/*.go

build-cleanup:
	GOOS=linux go build -o build/cleanup-lambda lambda/cleanup/*.go

clean:
	rm build/*.zip
