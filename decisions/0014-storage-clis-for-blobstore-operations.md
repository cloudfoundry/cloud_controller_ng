# ADR: Introduce Storage CLIs for Blobstore Operations

## Status

🔄 **Under Discussion** – This ADR proposes a shared direction for replacing fog-based blobstore implementations. It has not yet been accepted.

| Provider | Status                   | Notes                                                                                                   |
|----------|--------------------------|---------------------------------------------------------------------------------------------------------|
| Azure    | 🚧 PoC in Progress       | [PoC](https://github.com/cloudfoundry/cloud_controller_ng/pull/4397) done with `bosh-azure-storage-cli` |
| AWS      | 🧭 Open for Contribution |                                                                                                         |
| GCP      | 🧭 Open for Contribution |                                                                                                         |
| Alicloud | 🧭 Open for Contribution |                                                                                                         |


## Context

Cloud Controller uses the fog gem family to interface with blobstores like Azure, AWS, GCP, and Alibaba Cloud.
These Ruby gems are largely unmaintained, introducing risks such as:
* Dependency on deprecated SDKs (e.g., Azure SDK for Ruby)
* Blocking Ruby version upgrades
* Potential for unpatched CVEs

Bosh faces similar issues, as it is also written in Ruby and must interact with blobstores. To address this, BOSH introduced standalone CLI tools (e.g., `bosh-azure-storage-cli`, `bosh-s3cli`) which shell out from Ruby to handle all blobstore operations:
- https://github.com/cloudfoundry/bosh-azure-storage-cli
- https://github.com/cloudfoundry/bosh-s3cli
- https://github.com/cloudfoundry/bosh-gcscli
- https://github.com/cloudfoundry/bosh-ali-storage-cli

This approach decouples core logic from Ruby gems and has proven to be robust in production.
These CLIs are implemented in Go and use the respective provider SDKs.
All BOSH storage CLIs currently implement a common interface with the following commands: `put`, `get`, `delete`, `exists`, and `sign`.

A [PoC](https://github.com/cloudfoundry/cloud_controller_ng/pull/4397) has shown that `bosh-azure-storage-cli` can be successfully used in Cloud Controller to push apps.

## Decision

Cloud Controller will introduce support for CLI-based blobstore clients, starting with Azure.
Specifically, we will:
* Add a new blobstore client using `bosh-azure-storage-cli`
* Shell out from Cloud Controller to perform blobstore operations
* Allow opt-in via configuration parameter
* Keep the `fog-azure-rm` backend during the transition

The `bosh-azure-storage-cli` needs to be extended with the following commands:
* `copy`
* `list`
* `properties`
* `ensure-bucket-exists`

Other providers (AWS, GCP, Alibaba) will follow. Each will require equivalent blobstore clients and support for the above commands.
This will eventually allow us to remove all fog-related gems from Cloud Controller.

## Consequences

* Enables removing of `fog-azure-rm` and all other fog related gems
* Reduces long-term maintenance burden and potential security issues
* Allows providers to be migrated independently
* Increases initial complexity during migration phase
* With more consumers, interface changes in the BOSH storage CLIs may require more coordination

## Alternatives Considered

* Replace fog with newer Ruby gems → Maintenance risk persists
* Implement own blobstore client in Ruby → High development and testing effort


