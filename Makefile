build: build-rotate build-cleanup

build-rotate:
	cd rotator/lambda/rotate && GOOS=linux go build -o rotate-lambda *.go

build-cleanup:
	cd rotator/lambda/cleanup && GOOS=linux go build -o cleanup-lambda *.go

clean:
	rm -f build/*
