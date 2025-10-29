# Deploying a minimal go application onto Kubernetes using Docker Desktop and Terraform

## Prerequisites

- [The Go Programming Language](https://golang.org/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Docker Hub Account](https://hub.docker.com/)
- [HashiCorp Terraform](https://www.terraform.io/downloads.html)

## Create Test App

Using sample http app in [go](https://golang.org/) that responds with "Hello, World" to request received on port 8080:

Using your favorite editor create a file named *main.go* with the following code:

``` golang
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		fmt.Fprint(writer, "Hello, World")
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

Compile the application:

``` bash
go run main.go
```

Test the app works as expected by navigating to http://localhost:8080/ in your browser where you should see 'Hello, World' displayed.

## Create Docker Image

Using your favorite editor create a multi-stage Dockerfile named *Dockerfile* with the following code:

``` Dockerfile
FROM golang:alpine as builder
RUN mkdir /build
ADD . /build/
WORKDIR /build
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main .
FROM scratch
COPY --from=builder /build/main /app/
WORKDIR /app
ENV PORT 8080
EXPOSE 8080
ENTRYPOINT ["./main"]
```

Build a minimal docker image:

``` bash
docker build -t docker-test .
docker image ls | grep docker-test
```

Test the image using docker:

``` bash
docker run -d -p 8080:8080 docker-test
docker ps | grep docker-test
curl http://localhost:8080
docker container stop <CONTAINER-ID>
```

Tag the image and push to Docker Hub:

``` bash
docker tag docker-test <DOCKERHUB-ACCOUNT>/docker-test
docker push <DOCKERHUB-ACCOUNT>/docker-test
```

## Use Terraform to Deploy to Kubernetes

Using your favorite editor create a file named *app.tf* with the following code:

``` hcl
provider "kubernetes" {}

resource "kubernetes_namespace" "docker-test" {
  metadata {
    name = "test"
  }
}

resource "kubernetes_replication_controller" "docker-test" {
  metadata {
    name = "docker-test"
    namespace = "test"
    labels {
      App = "DockerTest"
    }
  }

  spec {
    replicas = 2
    selector {
      App = "DockerTest"
    }
    template {
      container {
        image = "<DOCKERHUB-ACCOUNT>/docker-test"
        name  = "docker-test"

        port {
          container_port = 8080
        }

        resources {
          limits {
            cpu    = "0.5"
            memory = "512Mi"
          }
          requests {
            cpu    = "250m"
            memory = "50Mi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "docker-test" {
  metadata {
    name = "docker-test"
    namespace = "test"
  }
  spec {
    selector {
      App = "${kubernetes_replication_controller.docker-test.metadata.0.labels.App}"
    }
    port {
      port = 8000
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

```

Initialize Terraform providers:

``` bash
terraform init
```

Use terraform to deploy our service to Kubernetes:

``` bash
terraform apply
```

Type 'yes' to confirm.

## Validate Deployment

### Using Command Line

Use kubectl to check deployment:

``` bash
kubectl get pods --namespace test
```

### Using Kubernetes Dashboard

Deploy the Kubernetes dashboard using the following command:

``` bash
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
```

Use the kubectl command line proxy to access the dashboard:

``` bash
kubectl proxy
```

The Kubernetes dashboard should now be available at:
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

### Using curl

Test the deployed service using curl:

``` bash
curl http://localhost:8000
```

## Clean Up

Use Terraform to teardown the environment:

``` bash
terraform destroy
```

Type 'yes' to confirm.


## References

- [Containerize This! How to build Golang Dockerfiles](https://www.cloudreach.com/blog/containerize-this-golang-dockerfiles/)
- [Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Terraform Kubernetes Provider](https://www.terraform.io/docs/providers/kubernetes/index.html)

## CI: GitHub Actions (build & push Docker image)

This repository includes a GitHub Actions workflow at `.github/workflows/ci.yml` that:

- Builds the Go binary (sanity check)
- Builds the Docker image
- Pushes the image to Docker Hub

Before using the workflow, add the following repository Secrets (Settings → Secrets → Actions):

- `DOCKERHUB_USERNAME` — your Docker Hub username
- `DOCKERHUB_TOKEN` — a Docker Hub access token (or password)

The workflow will push the image as `DOCKERHUB_USERNAME/docker-test:latest` and also tag it with the Git SHA.

If you prefer GitHub Packages (GHCR) or another registry, update `.github/workflows/ci.yml` accordingly and set secrets for that registry.

## Kubernetes manifests

I added example Kubernetes manifests in the `k8s/` folder:

- `k8s/deployment.yaml` — Deployment (2 replicas) using image `<DOCKERHUB_USERNAME>/docker-test:latest`
- `k8s/service.yaml` — Service of type `LoadBalancer` mapping port `8000` → `8080`

To apply them to a cluster (or Docker Desktop Kubernetes):

```bash
# create namespace if it doesn't exist
kubectl create namespace test || true

# apply manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# verify
kubectl get pods -n test
kubectl get svc -n test
```

To use the image pushed by the CI workflow, replace `<DOCKERHUB_USERNAME>` in `k8s/deployment.yaml` with your Docker Hub username (or update the image field to point to your registry and tag).

## Local development: Makefile

There is a `Makefile` at the repository root with convenience targets:

- `make build` — build the Go binary locally
- `make docker-build` — build the Docker image (tags as `docker-test` by default)
- `make docker-run` — run the built image locally, mapping port 8080
- `make docker-push DOCKERHUB=youruser` — tag and push image to Docker Hub

Example:

```bash
make docker-build
make docker-run
# in another terminal
curl http://localhost:8080
```

## Private registries and imagePullSecrets

If your image is hosted in a private registry, you must create an image pull secret and reference it from your `Deployment`.

Quick way to create the secret (Docker Hub example):

```bash
kubectl create namespace test || true
kubectl create secret docker-registry regcred \
  --docker-username=<DOCKER_USERNAME> \
  --docker-password=<DOCKER_PASSWORD_OR_TOKEN> \
  --docker-server=https://index.docker.io/v1/ \
  --namespace test
```

You can also use the provided template `k8s/docker-registry-secret.yaml` (replace `.dockerconfigjson` with your base64-encoded docker config JSON).

To reference the secret from the `Deployment` add the `imagePullSecrets` entry in `k8s/deployment.yaml` under `spec.template.spec`:

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: regcred
      containers:
        - name: docker-test
          image: <DOCKERHUB_USERNAME>/docker-test:latest
```


## How I updated the repository in this session

- Initialized the local Git repository and pushed the initial commit to `origin` (main branch).
- Added a GitHub Actions workflow to build and push Docker images.
- Added `k8s/` manifests to deploy the app to Kubernetes.

If you want, I can also:

1. Build the Docker image locally and run it (I can run `docker build` / `docker run` if Docker is available here).
2. Update the GitHub Actions workflow to publish to GHCR instead of Docker Hub.
3. Add a `skaffold.yaml` or Helm chart to simplify iterative deploys.
