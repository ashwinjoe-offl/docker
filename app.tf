terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

provider "kubernetes" {}
provider "helm" {}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "example.com"  # Change this to your actual domain
}

# Create namespace
resource "kubernetes_namespace" "docker-test" {
  metadata {
    name = "test"
  }
}

# Install cert-manager via Helm
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Create ClusterIssuer for Let's Encrypt
resource "kubernetes_manifest" "cluster_issuer" {
  depends_on = [helm_release.cert_manager]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = "your-email@example.com"  # Change this
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }
}

# Install NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
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

          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds       = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 15
            period_seconds       = 20
          }
        }
      }
    }
  }
}

# Internal service
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
    }
    type = "ClusterIP"  # Changed to ClusterIP as we'll use Ingress
  }
}

# Ingress with TLS
resource "kubernetes_ingress_v1" "docker-test" {
  depends_on = [kubernetes_manifest.cluster_issuer]

  metadata {
    name      = "docker-test"
    namespace = kubernetes_namespace.docker-test.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "true"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    tls {
      hosts       = [var.domain_name]
      secret_name = "docker-test-tls"
    }

    rule {
      host = var.domain_name
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.docker-test.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}
