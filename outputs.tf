output "id" {
  description = "Fully qualified function id (projects/<project>/locations/<region>/functions/<name>). Null when create is false."
  value       = var.create ? google_cloudfunctions2_function.this[0].id : null
}

output "name" {
  description = "Function name. Null when create is false."
  value       = var.create ? google_cloudfunctions2_function.this[0].name : null
}

output "self_link" {
  description = "Invocation URL of the function (same as uri). Null when create is false."
  value       = var.create ? google_cloudfunctions2_function.this[0].url : null
}

output "uri" {
  description = "Invocation URL of the function. Null when create is false."
  value       = var.create ? google_cloudfunctions2_function.this[0].url : null

  precondition {
    condition     = var.trigger.type != "pubsub" || var.trigger.topic != null
    error_message = "trigger.topic is required when trigger.type is pubsub."
  }
  precondition {
    condition     = var.trigger.type != "storage" || var.trigger.bucket != null
    error_message = "trigger.bucket is required when trigger.type is storage."
  }
  precondition {
    condition     = var.trigger.type != "eventarc" || var.trigger.event_type != null
    error_message = "trigger.event_type is required when trigger.type is eventarc."
  }
  precondition {
    condition     = var.code.type != "local_dir" || var.code.path != null
    error_message = "code.path is required when code.type is local_dir."
  }
  precondition {
    condition     = var.code.type != "gcs" || (var.code.bucket != null && var.code.object != null)
    error_message = "code.bucket and code.object are required when code.type is gcs."
  }
}

output "service_account_email" {
  description = "Email of the dedicated runtime service account. Null when create is false."
  value       = var.create ? google_service_account.this[0].email : null
}

output "labels" {
  description = "Labels applied to every labelable resource, with context.extra_tags merged in. Null when create is false."
  value       = var.create ? local.labels : null
}

output "trigger_type" {
  description = "Effective trigger type (http, pubsub, storage or eventarc). Null when create is false."
  value       = var.create ? var.trigger.type : null
}

output "ingress_setting" {
  description = "Ingress setting applied to the function: ALLOW_ALL only when allUsers is an invoker, otherwise ALLOW_INTERNAL_AND_GCLB. Null when create is false."
  value       = var.create ? local.ingress_setting : null
}

output "secret_ids" {
  description = "Distinct Secret Manager secrets the runtime service account can access. Null when create is false."
  value       = var.create ? toset(values(var.secret_env)) : null
}
