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
  app_uid   = 100 # appuser in the Dockerfile
  app_gid   = 101 # appgroup in the Dockerfile
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
  # checkov:skip=CKV_K8S_14:Tag comes from var.image, CI always passes the commit SHA tag
  # checkov:skip=CKV_K8S_43:We pin by commit SHA tag (traceability), not by digest
  # checkov:skip=CKV_K8S_15:Previews on kind use locally loaded images, pull Always would break them
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
        security_context {
          run_as_non_root = true
          run_as_user     = local.app_uid
          run_as_group    = local.app_gid
        }

        container {
          name  = local.app_name
          image = var.image

          port {
            container_port = local.app_port
          }

          security_context {
            allow_privilege_escalation = false
            privileged                 = true
            read_only_root_filesystem  = true
            run_as_non_root            = true

            capabilities {
              drop = ["ALL"]
            }
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
