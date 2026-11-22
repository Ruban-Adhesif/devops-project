terraform {
  # Path is given at init time so each PR gets its own state:
  #   terraform init -backend-config="path=state/pr-42.tfstate"
  backend "local" {}

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

locals {
  app_name  = "myapp"
  app_port  = 3000
  namespace = "pr-${var.pr_number}"
  labels    = { app = local.app_name }
}

resource "kubernetes_namespace_v1" "preview" {
  metadata {
    name = local.namespace
    labels = {
      purpose = "preview"
      pr      = var.pr_number
      owner   = var.owner
      expires = var.expires
    }
  }
}

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.preview.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = local.app_name
          image = var.image

          port {
            container_port = local.app_port
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = local.app_port
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = local.app_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.preview.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = local.labels

    port {
      port        = 80
      target_port = local.app_port
    }

    type = "ClusterIP"
  }
}
