terraform {
  required_providers {
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "7.15.3"
    }
  }
}

# Exposed ArgoCD API - authenticated using `username`/`password`
provider "argocd" {
  server_addr = var.server_addr
  username    = var.username
  password    = var.password
  insecure    = var.insecure
}
