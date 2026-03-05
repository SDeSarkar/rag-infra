variable "location" {
  type    = string
  default = "South India"
}
variable "project" {
  type    = string
  default = "agentic-rag"
}
variable "env" {
  type    = string
  default = "dev"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Container image for your FastAPI/LangGraph service
variable "container_image" {
  type        = string
  description = "e.g., ghcr.io/your-org/agent-api:0.1.0"
}

# Optional: lock down public ingress later
variable "containerapp_external_ingress" {
  type    = bool
  default = true
}

# Client IDs to assign sre app role (e.g. test SP, CI pipeline)
variable "raguser_client_ids" {
  type        = list(string)
  description = "List of client IDs to assign sre role to access the API"
  default     = []
}
