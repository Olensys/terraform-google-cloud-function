# terraform-google-cloud-function

Cloud Functions gen2 with a dedicated service account, secret-backed environment, HTTP or event triggers, and a versioned source bucket

## Opinions

- Gen2 only: `google_cloudfunctions2_function` with a dedicated service account per function (account id is the first 30 characters of `name`, so use at least 6).
- Private by default: ingress is `ALLOW_INTERNAL_AND_GCLB` and no invoker is granted. Only when `invoker_members` contains `allUsers` is ingress `ALLOW_ALL`.
- Source from a local directory is zipped and uploaded to a per-function bucket with uniform access, public access prevention enforced and versioning on. The object name embeds the zip MD5, so code changes redeploy. `force_destroy` is on. Alternatively point `code` at an existing zip in GCS.
- Secrets are exposed as environment variables at version `latest`, and the runtime service account receives `secretAccessor` on each distinct secret.
- Event triggers (`pubsub`, `storage`, `eventarc`) retry on failure, run as the function service account, fire in the function region and grant it `roles/eventarc.eventReceiver`. `storage` fires on object finalize.
- Defaults: 1 CPU, 256Mi, 0 to 10 instances, concurrency 1.
- VPC access uses a Serverless VPC Access connector (`vpc = { connector, egress }`), because gen2 functions take a connector rather than a network and subnet.
- The source input is named `code`, because `source` is a reserved variable name in Terraform.
- Cross-variable rules (trigger requirements, `code` fields per type) are preconditions on `output.uri`.

## Usage

```hcl
module "this" {
  source = "git::https://github.com/Olensys/terraform-google-cloud-function.git?ref=v1.0.0"

  name        = "example-fn"
  context     = local.context
  project_id  = "my-project"
  labels      = module.naming.labels
  region      = "europe-west1"
  runtime     = "python312"
  entry_point = "handler"
  code        = { type = "local_dir", path = "${path.module}/src" }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.4, < 3.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0, < 8.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.4, < 3.0 |
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.0, < 8.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_cloud_run_v2_service_iam_member.invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_cloudfunctions2_function.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function) | resource |
| [google_project_iam_member.eventarc_receiver](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_secret_manager_secret_iam_member.runtime](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_storage_bucket.source](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_object.source](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [archive_file.source](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_code"></a> [code](#input\_code) | Function source (named code because source is a reserved variable name). type local\_dir zips path into a versioned bucket this module creates; type gcs uses an existing zip at bucket/object. path is required for local\_dir, bucket and object for gcs. | <pre>object({<br/>    type   = string<br/>    path   = optional(string)<br/>    bucket = optional(string)<br/>    object = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_context"></a> [context](#input\_context) | Deployment context used for naming, tagging and environment-dependent defaults. | <pre>object({<br/>    organization = string<br/>    environment  = string<br/>    application  = string<br/>    component    = optional(string)<br/>    owner        = string<br/>    cost_center  = string<br/>    extra_tags   = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_entry_point"></a> [entry\_point](#input\_entry\_point) | Name of the function or handler in the source that is executed. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Function name. Lowercase letters, digits and hyphens, starting with a letter, at most 63 characters. The service account id is the first 30 characters, so use at least 6. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project that owns the function, its service account and its source bucket. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the function and of its source bucket. | `string` | n/a | yes |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Function runtime, for example python312, nodejs22 or go123. | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether to create any resources. Set false to create nothing. | `bool` | `true` | no |
| <a name="input_env"></a> [env](#input\_env) | Plain environment variables, env name => value. | `map(string)` | `{}` | no |
| <a name="input_invoker_members"></a> [invoker\_members](#input\_invoker\_members) | IAM members granted roles/run.invoker on the function. Include allUsers to make it public (this also opens ingress to all traffic); the default is private. | `list(string)` | `[]` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels merged onto every labelable resource, applied last. Must already be normalised for GCP. | `map(string)` | `{}` | no |
| <a name="input_resources"></a> [resources](#input\_resources) | Instance resource limits. | <pre>object({<br/>    cpu    = optional(string, "1")<br/>    memory = optional(string, "256Mi")<br/>  })</pre> | `{}` | no |
| <a name="input_scaling"></a> [scaling](#input\_scaling) | Instance scaling: minimum and maximum instances and requests per instance. | <pre>object({<br/>    min         = optional(number, 0)<br/>    max         = optional(number, 10)<br/>    concurrency = optional(number, 1)<br/>  })</pre> | `{}` | no |
| <a name="input_secret_env"></a> [secret\_env](#input\_secret\_env) | Secret-backed environment variables, env name => Secret Manager secret. A short id (same project) or a full projects/<project>/secrets/<id> name for a secret in another project. The latest version is exposed and the runtime service account receives secretAccessor. | `map(string)` | `{}` | no |
| <a name="input_trigger"></a> [trigger](#input\_trigger) | What invokes the function. type is http, pubsub (needs topic), storage (needs bucket; fires on object finalize) or eventarc (needs event\_type, for example google.cloud.audit.log.v1.written). | <pre>object({<br/>    type       = string<br/>    topic      = optional(string)<br/>    bucket     = optional(string)<br/>    event_type = optional(string)<br/>  })</pre> | <pre>{<br/>  "type": "http"<br/>}</pre> | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Serverless VPC Access egress (gen2 functions use a connector, not direct network/subnet). connector is the full connector name projects/<p>/locations/<r>/connectors/<c>; egress is ALL\_TRAFFIC or PRIVATE\_RANGES\_ONLY. Null disables VPC access. | <pre>object({<br/>    connector = string<br/>    egress    = optional(string, "PRIVATE_RANGES_ONLY")<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | Fully qualified function id (projects/<project>/locations/<region>/functions/<name>). Null when create is false. |
| <a name="output_ingress_setting"></a> [ingress\_setting](#output\_ingress\_setting) | Ingress setting applied to the function: ALLOW\_ALL only when allUsers is an invoker, otherwise ALLOW\_INTERNAL\_AND\_GCLB. Null when create is false. |
| <a name="output_labels"></a> [labels](#output\_labels) | Labels applied to every labelable resource, with context.extra\_tags merged in. Null when create is false. |
| <a name="output_name"></a> [name](#output\_name) | Function name. Null when create is false. |
| <a name="output_secret_ids"></a> [secret\_ids](#output\_secret\_ids) | Distinct Secret Manager secrets the runtime service account can access. Null when create is false. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | Invocation URL of the function (same as uri). Null when create is false. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the dedicated runtime service account. Null when create is false. |
| <a name="output_trigger_type"></a> [trigger\_type](#output\_trigger\_type) | Effective trigger type (http, pubsub, storage or eventarc). Null when create is false. |
| <a name="output_uri"></a> [uri](#output\_uri) | Invocation URL of the function. Null when create is false. |
<!-- END_TF_DOCS -->
