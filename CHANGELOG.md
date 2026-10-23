# Changelog

## 1.1.0

### Fixes

- normalise `context.extra_tags` keys and values to valid GCP label syntax (lowercase, invalid characters to `-`, 63 characters); `labels` still win

### Tests

- `test_tags_contract` covers a mixed-case tag key and a value with a space

### Docs

- README usage shows the naming module

### Behaviour changes

- `context.extra_tags` entries now appear as normalised labels (for example `Team = "Core Team"` becomes `team = "core-team"`). Callers that relied on unnormalised keys must read the normalised ones; values that previously failed GCP label validation now succeed.

## 1.0.1

### Fixes

- grant the Cloud Storage service agent pubsub.publisher for storage triggers

## 1.0.0

- Cloud Functions gen2 with a dedicated service account, secret-backed environment, HTTP or event triggers, private-by-default ingress and a versioned source bucket.
