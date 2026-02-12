locals {
  workspace = terraform.workspace == "default" ? "dev" : terraform.workspace
  
  common_tags = {
    Project     = var.project_name
    Environment = local.workspace
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }

  # Nombres prefijados con workspace
  resource_prefix = "${var.project_name}-${local.workspace}"
  
  # Dominios con workspace si no es prod
  frontend_domain = local.workspace == "prod" ? var.frontend_domain : "${local.workspace}.${var.frontend_domain}"
  api_domain      = local.workspace == "prod" ? var.api_domain : "${local.workspace}-api.${var.api_domain}"
}
