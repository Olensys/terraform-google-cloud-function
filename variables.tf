variable "name" {
  description = "Function name. Lowercase letters, digits and hyphens, starting with a letter, at most 63 characters. The service account id is the first 30 characters, so use at least 6."
  type        = string
  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.name)) && length(var.name) <= 63
    error_message = "name must match ^[a-z]([a-z0-9-]*[a-z0-9])?$ and be at most 63 characters."
  }
}

variable "context" {
  description = "Deployment context used for naming, tagging and environment-dependent defaults."
  type = object({
    organization = string
    environment  = string
    application  = string
    component    = optional(string)
    owner        = string
    cost_center  = string
    extra_tags   = optional(map(string), {})
  })
  validation {
    condition     = contains(["dev", "staging", "prod", "test", "shared"], var.context.environment)
    error_message = "context.environment must be one of dev, staging, prod, test, shared."
  }
}

variable "project_id" {
  description = "GCP project that owns the function, its service account and its source bucket."
  type        = string
}

variable "create" {
  description = "Whether to create any resources. Set false to create nothing."
  type        = bool
  default     = true
}

variable "region" {
  description = "Region of the function and of its source bucket."
  type        = string
}

variable "runtime" {
  description = "Function runtime, for example python312, nodejs22 or go123."
  type        = string
  validation {
    condition     = length(trimspace(var.runtime)) > 0
    error_message = "runtime must not be empty."
  }
}

variable "entry_point" {
  description = "Name of the function or handler in the source that is executed."
  type        = string
}

variable "code" {
  description = "Function source (named code because source is a reserved variable name). type local_dir zips path into a versioned bucket this module creates; type gcs uses an existing zip at bucket/object. path is required for local_dir, bucket and object for gcs."
  type = object({
    type   = string
    path   = optional(string)
    bucket = optional(string)
    object = optional(string)
  })
  validation {
    condition     = contains(["local_dir", "gcs"], var.code.type)
    error_message = "code.type must be local_dir or gcs."
  }
}

variable "env" {
  description = "Plain environment variables, env name => value."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Secret-backed environment variables, env name => Secret Manager secret. A short id (same project) or a full projects/<project>/secrets/<id> name for a secret in another project. The latest version is exposed and the runtime service account receives secretAccessor."
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for v in values(var.secret_env) : can(regex("^([a-zA-Z0-9_-]+|projects/[^/]+/secrets/[a-zA-Z0-9_-]+)$", v))])
    error_message = "Every secret_env value must be a secret id or projects/<project>/secrets/<id>."
  }
}

variable "resources" {
  description = "Instance resource limits."
  type = object({
    cpu    = optional(string, "1")
    memory = optional(string, "256Mi")
  })
  default = {}
}

variable "scaling" {
  description = "Instance scaling: minimum and maximum instances and requests per instance."
  type = object({
    min         = optional(number, 0)
    max         = optional(number, 10)
    concurrency = optional(number, 1)
  })
  default = {}
  validation {
    condition     = var.scaling.min >= 0 && var.scaling.max >= 1 && var.scaling.min <= var.scaling.max && var.scaling.concurrency >= 1 && var.scaling.concurrency <= 1000
    error_message = "scaling requires 0 <= min <= max, max >= 1 and 1 <= concurrency <= 1000."
  }
}

variable "trigger" {
  description = "What invokes the function. type is http, pubsub (needs topic), storage (needs bucket; fires on object finalize) or eventarc (needs event_type, for example google.cloud.audit.log.v1.written)."
  type = object({
    type       = string
    topic      = optional(string)
    bucket     = optional(string)
    event_type = optional(string)
  })
  default = { type = "http" }
  validation {
    condition     = contains(["http", "pubsub", "storage", "eventarc"], var.trigger.type)
    error_message = "trigger.type must be http, pubsub, storage or eventarc."
  }
}

variable "invoker_members" {
  description = "IAM members granted roles/run.invoker on the function. Include allUsers to make it public (this also opens ingress to all traffic); the default is private."
  type        = list(string)
  default     = []
}

variable "vpc" {
  description = "Serverless VPC Access egress (gen2 functions use a connector, not direct network/subnet). connector is the full connector name projects/<p>/locations/<r>/connectors/<c>; egress is ALL_TRAFFIC or PRIVATE_RANGES_ONLY. Null disables VPC access."
  type = object({
    connector = string
    egress    = optional(string, "PRIVATE_RANGES_ONLY")
  })
  default = null
  validation {
    condition     = var.vpc == null || contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], try(var.vpc.egress, ""))
    error_message = "vpc.egress must be ALL_TRAFFIC or PRIVATE_RANGES_ONLY."
  }
}

variable "labels" {
  description = "Labels merged onto every labelable resource, applied last. Must already be normalised for GCP."
  type        = map(string)
  default     = {}
}
