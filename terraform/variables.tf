variable "location" { type = string default = "eastus" }
variable "project"  { type = string default = "agentic-rag" }
variable "env"      { type = string default = "dev" }

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
