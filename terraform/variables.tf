variable "project" {
    description = "Project id in the cloud"
}

variable "region" {
    description = "Region where the resources will be created"
}

variable "service_key" {
    description = "Caminho para a chave de serviço para autenticação"
    sensitive = true
}

variable "spotify_client_id" {
  description = "Spotify client id"
  type        = string
  sensitive   = true
}

variable "spotify_client_secret" {
  description = "Spotify client secret"
  type        = string
  sensitive   = true
}
