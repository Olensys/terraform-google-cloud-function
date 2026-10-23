mock_provider "google" {}
mock_provider "archive" {}

variables {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
  name        = "example"
  project_id  = "example-project"
  region      = "europe-west1"
  runtime     = "python312"
  entry_point = "handler"
  code        = { type = "local_dir", path = "./src" }
}

run "test_http_trigger_default" {
  command = plan

  assert {
    condition     = output.trigger_type == "http" && length(google_cloudfunctions2_function.this[0].event_trigger) == 0
    error_message = "Default trigger must be http with no event_trigger block."
  }

  assert {
    condition     = google_cloudfunctions2_function.this[0].service_config[0].max_instance_request_concurrency == 1 && google_cloudfunctions2_function.this[0].service_config[0].available_memory == "256Mi"
    error_message = "Defaults: concurrency 1 and memory 256Mi."
  }

  assert {
    condition     = google_service_account.this[0].account_id == "example" && google_storage_bucket.source[0].name == "example-project-example-src" && google_storage_bucket.source[0].public_access_prevention == "enforced"
    error_message = "Dedicated service account and enforced-private source bucket expected."
  }
}

run "test_pubsub_trigger_requires_topic" {
  command = plan

  variables {
    trigger = { type = "pubsub" }
  }

  expect_failures = [output.uri]
}

run "test_no_public_invoker_default" {
  command = plan

  assert {
    condition     = output.ingress_setting == "ALLOW_INTERNAL_AND_GCLB" && length(google_cloud_run_v2_service_iam_member.invoker) == 0
    error_message = "Without invoker_members the function must not be public and no invoker binding is created."
  }
}

run "test_public_invoker_opens_ingress" {
  command = plan

  variables {
    invoker_members = ["allUsers"]
  }

  assert {
    condition     = output.ingress_setting == "ALLOW_ALL" && length(google_cloud_run_v2_service_iam_member.invoker) == 1
    error_message = "allUsers must open ingress and create one invoker binding."
  }
}

run "test_source_type_validation" {
  command = plan

  variables {
    code = { type = "url", path = "https://example.com/x.zip" }
  }

  expect_failures = [var.code]
}

run "test_gcs_source_requires_object" {
  command = plan

  variables {
    code = { type = "gcs", bucket = "b" }
  }

  expect_failures = [output.uri]
}

run "test_gcs_source_skips_bucket" {
  command = plan

  variables {
    code = { type = "gcs", bucket = "b", object = "o.zip" }
  }

  assert {
    condition     = length(google_storage_bucket.source) == 0 && length(google_storage_bucket_object.source) == 0
    error_message = "gcs source must not create a source bucket or object."
  }
}

run "test_storage_trigger_filters_bucket" {
  command = plan

  variables {
    trigger = { type = "storage", bucket = "uploads" }
  }

  assert {
    condition     = google_cloudfunctions2_function.this[0].event_trigger[0].event_type == "google.cloud.storage.object.v1.finalized" && one(google_cloudfunctions2_function.this[0].event_trigger[0].event_filters).value == "uploads"
    error_message = "Storage trigger must filter on the bucket."
  }

  assert {
    condition     = length(google_project_iam_member.eventarc_receiver) == 1
    error_message = "Event triggers need eventarc.eventReceiver."
  }
}

run "test_storage_trigger_grants_gcs_publisher" {
  command = plan

  variables {
    trigger = { type = "storage", bucket = "uploads" }
  }

  assert {
    condition     = length(google_project_iam_member.gcs_pubsub_publisher) == 1 && google_project_iam_member.gcs_pubsub_publisher[0].role == "roles/pubsub.publisher"
    error_message = "Storage triggers must grant the GCS service agent pubsub.publisher."
  }
}

run "test_http_has_no_gcs_publisher" {
  command = plan

  assert {
    condition     = length(google_project_iam_member.gcs_pubsub_publisher) == 0
    error_message = "Only storage triggers grant the GCS service agent."
  }
}

run "test_storage_trigger_requires_bucket" {
  command = plan

  variables {
    trigger = { type = "storage" }
  }

  expect_failures = [output.uri]
}

run "test_eventarc_requires_event_type" {
  command = plan

  variables {
    trigger = { type = "eventarc" }
  }

  expect_failures = [output.uri]
}

run "test_secret_env_grants_accessor" {
  command = plan

  variables {
    secret_env = {
      DB_PASSWORD = "db-pass"
      API_KEY     = "db-pass"
      OTHER       = "projects/other-project/secrets/shared"
    }
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.runtime) == 2
    error_message = "One accessor grant per distinct secret."
  }

  assert {
    condition     = length(google_cloudfunctions2_function.this[0].service_config[0].secret_environment_variables) == 3 && output.secret_ids == toset(["db-pass", "projects/other-project/secrets/shared"])
    error_message = "All three env vars must be secret-backed."
  }
}

run "test_vpc_connector" {
  command = plan

  variables {
    vpc = { connector = "projects/example-project/locations/europe-west1/connectors/c1" }
  }

  assert {
    condition     = google_cloudfunctions2_function.this[0].service_config[0].vpc_connector_egress_settings == "PRIVATE_RANGES_ONLY"
    error_message = "Default VPC egress must be PRIVATE_RANGES_ONLY."
  }
}

run "test_create_false_plans_nothing" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition     = output.id == null && output.name == null && output.self_link == null && output.uri == null && output.service_account_email == null && output.labels == null && output.trigger_type == null && output.ingress_setting == null && output.secret_ids == null
    error_message = "All outputs must be null when create is false."
  }

  assert {
    condition     = length(google_cloudfunctions2_function.this) == 0 && length(google_service_account.this) == 0 && length(google_storage_bucket.source) == 0
    error_message = "No resources may be planned when create is false."
  }
}

run "test_tags_contract" {
  command = plan

  variables {
    labels = { owner = "x" }
    context = {
      organization = "olensys"
      environment  = "test"
      application  = "example"
      owner        = "platform"
      cost_center  = "eng"
      extra_tags   = { Owner = "y", Team = "Core Team" }
    }
  }

  assert {
    condition     = output.labels.owner == "x" && output.labels.team == "core-team"
    error_message = "var.labels must win and context.extra_tags must be merged."
  }
}

run "test_name_length_validation" {
  command = plan

  variables {
    name = "a234567890123456789012345678901234567890123456789012345678901234"
  }

  expect_failures = [var.name]
}

run "test_name_charset_validation" {
  command = plan

  variables {
    name = "Bad_Name"
  }

  expect_failures = [var.name]
}

run "test_runtime_non_empty" {
  command = plan

  variables {
    runtime = ""
  }

  expect_failures = [var.runtime]
}
