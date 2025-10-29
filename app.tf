provider "kubernetes" {}

# Create namespace
resource "kubernetes_namespace" "docker-test" {
  metadata {
    name = "test"
  }

# Main application deployment
resource "kubernetes_deployment" "docker-test" {
  metadata {
    name      = "docker-test"
    namespace = kubernetes_namespace.docker-test.metadata[0].name
    labels = {
      app = "docker-test"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "docker-test"
      }
    }

    template {
      metadata {
        labels = {
          app = "docker-test"
        }
      }

      spec {
        container {
          image = "ashwinjoeoffl/docker-test:latest"
          name  = "docker-test"

          port {
            container_port = 8080
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

# NodePort service for direct access
resource "kubernetes_service" "docker-test" {
  metadata {
    name      = "docker-test"
    namespace = kubernetes_namespace.docker-test.metadata[0].name
  }
  spec {
    selector = {
      app = "docker-test"
    }
    port {
      port        = 8080
      target_port = 8080
      node_port   = 30080
    }
    type = "NodePort"
  }
}
