terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.0, < 8.0" }
  }
}

variable "project_id" {
  description = "GCP project that will own the function."
  type        = string
}

locals {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
}

module "naming" {
  source = "git::https://github.com/Olensys/terraform-null-naming.git?ref=v1.0.1"

  context = local.context
}

module "this" {
  source = "../../"

  name        = "example-fn"
  context     = local.context
  project_id  = var.project_id
  labels      = module.naming.labels
  region      = "europe-west1"
  runtime     = "python312"
  entry_point = "handler"
  code        = { type = "local_dir", path = "${path.module}/src" }
}

output "uri" {
  description = "Invocation URL of the example function."
  value       = module.this.uri
}
