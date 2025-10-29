.PHONY: build docker-build docker-run docker-push clean

BINARY=main
IMAGE?=docker-test
DOCKERHUB?=yourdockerhubuser

build:
	go build -v -o $(BINARY) ./...

docker-build:
	docker build -t $(IMAGE) .

docker-run:
	docker run --rm -p 8080:8080 $(IMAGE)

docker-push:
	@echo "Pushing image to $(DOCKERHUB)/$(IMAGE):latest"
	docker tag $(IMAGE) $(DOCKERHUB)/$(IMAGE):latest
	docker push $(DOCKERHUB)/$(IMAGE):latest

clean:
	rm -f $(BINARY)
