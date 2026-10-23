locals {
  labels = merge(var.context.extra_tags, var.labels)

  local_source = var.create && var.code.type == "local_dir"
  event_driven = var.trigger.type != "http"

  source_bucket = local.local_source ? google_storage_bucket.source[0].name : coalesce(var.code.bucket, "unset")
  source_object = local.local_source ? google_storage_bucket_object.source[0].name : coalesce(var.code.object, "unset")

  # secret_env values are short ids (this project) or full projects/<p>/secrets/<id> names.
  secret_refs = {
    for s in distinct(values(var.secret_env)) : s => {
      project = startswith(s, "projects/") ? split("/", s)[1] : var.project_id
      secret  = startswith(s, "projects/") ? split("/", s)[3] : s
    }
  }

  event_types = {
    pubsub   = "google.cloud.pubsub.topic.v1.messagePublished"
    storage  = "google.cloud.storage.object.v1.finalized"
    eventarc = coalesce(var.trigger.event_type, "unset")
  }

  ingress_setting = contains(var.invoker_members, "allUsers") ? "ALLOW_ALL" : "ALLOW_INTERNAL_AND_GCLB"
}

data "archive_file" "source" {
  count = local.local_source ? 1 : 0

  type        = "zip"
  source_dir  = coalesce(var.code.path, "unset")
  output_path = "${path.cwd}/.terraform/${var.name}-source.zip"
}

resource "google_storage_bucket" "source" {
  count = local.local_source ? 1 : 0

  name                        = trim(substr("${var.project_id}-${var.name}-src", 0, 63), "-")
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
  labels                      = local.labels

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_object" "source" {
  count = local.local_source ? 1 : 0

  name   = "source-${data.archive_file.source[0].output_md5}.zip"
  bucket = google_storage_bucket.source[0].name
  source = data.archive_file.source[0].output_path
}

resource "google_service_account" "this" {
  count = var.create ? 1 : 0

  project      = var.project_id
  account_id   = trim(substr(var.name, 0, 30), "-")
  display_name = "Cloud Function ${var.name}"
}

resource "google_secret_manager_secret_iam_member" "runtime" {
  for_each = var.create ? local.secret_refs : {}

  project   = each.value.project
  secret_id = each.value.secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.this[0].email}"
}

resource "google_project_iam_member" "eventarc_receiver" {
  count = var.create && local.event_driven ? 1 : 0

  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.this[0].email}"
}

resource "google_cloudfunctions2_function" "this" {
  count = var.create ? 1 : 0

  name     = var.name
  project  = var.project_id
  location = var.region
  labels   = local.labels

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point

    source {
      storage_source {
        bucket = local.source_bucket
        object = local.source_object
      }
    }
  }

  service_config {
    available_cpu                    = var.resources.cpu
    available_memory                 = var.resources.memory
    min_instance_count               = var.scaling.min
    max_instance_count               = var.scaling.max
    max_instance_request_concurrency = var.scaling.concurrency
    service_account_email            = google_service_account.this[0].email
    ingress_settings                 = local.ingress_setting
    environment_variables            = var.env

    vpc_connector                 = try(var.vpc.connector, null)
    vpc_connector_egress_settings = try(var.vpc.egress, null)

    dynamic "secret_environment_variables" {
      for_each = var.secret_env
      content {
        key        = secret_environment_variables.key
        project_id = local.secret_refs[secret_environment_variables.value].project
        secret     = local.secret_refs[secret_environment_variables.value].secret
        version    = "latest"
      }
    }
  }

  dynamic "event_trigger" {
    for_each = local.event_driven ? [1] : []
    content {
      event_type            = local.event_types[var.trigger.type]
      trigger_region        = var.region
      retry_policy          = "RETRY_POLICY_RETRY"
      service_account_email = google_service_account.this[0].email
      pubsub_topic          = var.trigger.type == "pubsub" ? coalesce(var.trigger.topic, "unset") : null

      dynamic "event_filters" {
        for_each = var.trigger.type == "storage" ? [1] : []
        content {
          attribute = "bucket"
          value     = coalesce(var.trigger.bucket, "unset") # null is rejected by the output.uri precondition
        }
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.runtime,
    google_project_iam_member.eventarc_receiver,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = var.create ? toset(var.invoker_members) : toset([])

  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.this[0].service_config[0].service
  role     = "roles/run.invoker"
  member   = each.value
}
