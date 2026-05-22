variable "username" {
  type        = string
  description = "Username Value"
}

variable "password" {
  type        = string
  description = "Password value"
}

variable "server_addr" {
  type        = string
  description = "server address value"
}

variable "namespace" {
  type        = string
  description = "ArgoCD namespace"
}

variable "destination_namespace" {
  type        = string
  description = "Destination namespace value"
}

variable "destination_server" {
  type        = string
  description = "Destination server URL"
}

variable "repo_url" {
  type        = string
  description = "repo url value"
}

variable "path" {
  type        = string
  description = "Target revision value"
}

variable "target_revision" {
  type        = string
  description = "Target_revision value"
}

variable "values_files" {
  type        = list(string)
  description = "Values_files Value as a list"
}

variable "insecure" {
  type        = bool
  description = "insecure Value as a boolean"
}
