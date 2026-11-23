output "namespace" {
  value = kubernetes_namespace_v1.preview.metadata[0].name
}

output "port_forward" {
  value = "kubectl port-forward svc/${local.app_name} 8080:80 -n ${kubernetes_namespace_v1.preview.metadata[0].name}"
}
