# Changelog

## [1.1.2](https://github.com/Olensys/terraform-google-cloud-function/compare/v1.1.1...v1.1.2) (2026-10-24)


### Bug Fixes

* **examples:** unique application slug so concurrent integration runs do not collide ([#4](https://github.com/Olensys/terraform-google-cloud-function/issues/4)) ([8b44479](https://github.com/Olensys/terraform-google-cloud-function/commit/8b4447941f7cbcfc331bbe8f65e91e40d69f7585))

## [1.1.1](https://github.com/Olensys/terraform-google-cloud-function/compare/v1.1.0...v1.1.1) (2026-10-24)


### Bug Fixes

* **examples:** pin naming module to v1.0.1 ([52d0591](https://github.com/Olensys/terraform-google-cloud-function/commit/52d0591d8f883f23c0a1a16bcb528e76757c4c21))
* run integration on change and weekly instead of nightly ([14bdc80](https://github.com/Olensys/terraform-google-cloud-function/commit/14bdc8028bb47bc8298fb458fa2bc1ff4171e2cb))

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
