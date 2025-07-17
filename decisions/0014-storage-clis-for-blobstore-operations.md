# ADR: Introduce Storage CLIs for Blobstore Operations

## Status

🔄 **Under Discussion** - This ADR proposes a shared direction for replacing fog-based blobstore implementations.

| Provider     | Status                    | Notes                                                                                                   |
|--------------|---------------------------|---------------------------------------------------------------------------------------------------------|
| Azure        | 🚧 PoC in Progress        | [PoC](https://github.com/cloudfoundry/cloud_controller_ng/pull/4397) done with `bosh-azure-storage-cli` |
| AWS          | 🧭 Open for Contribution  |                                                                                                         |
| GCP          | 🧭 Open for Contribution  |                                                                                                         |
| Alibaba Cloud| 🧭 Open for Contribution  |                                                                                                         |


## Context

Cloud Controller uses the fog gem family to interface with blobstores like Azure, AWS, GCP, and Alibaba Cloud.
These Ruby gems are largely unmaintained, introducing risks such as:
* Dependency on deprecated SDKs (e.g., Azure SDK for Ruby)
* Blocking Ruby version upgrades
* Potential for unpatched CVEs

Bosh faces similar issues, as it is also written in Ruby and interacts with blobstores. To address this, Bosh introduced standalone CLI tools which shell out from Ruby to handle all blobstore operations:
- https://github.com/cloudfoundry/bosh-azure-storage-cli
- https://github.com/cloudfoundry/bosh-s3cli
- https://github.com/cloudfoundry/bosh-gcscli
- https://github.com/cloudfoundry/bosh-ali-storage-cli

This approach decouples core logic from Ruby gems and has proven to be robust in production.
These CLIs are implemented in Go and use the respective provider SDKs.
All Bosh storage CLIs implement a common interface with the following commands: `put`, `get`, `delete`, `exists`, and `sign`.

A [PoC](https://github.com/cloudfoundry/cloud_controller_ng/pull/4397) has shown that `bosh-azure-storage-cli` can be successfully used in Cloud Controller to push apps.

This ADR does not propose breaking changes to existing Bosh storage CLI commands or their output, but outlines necessary additions to support Cloud Controller use cases. It highlights shared concerns and encourages collaboration between Bosh and Cloud Controller.

## Decision

Cloud Controller will introduce support for CLI based blobstore clients, starting with Azure.
Specifically, we will:
* Add a new blobstore client using `bosh-azure-storage-cli`
* Shell out from Cloud Controller to perform blobstore operations
* Allow opt-in via `blobstore_type` configuration parameter
  * Desired configuration format:
    ```YAML
      packages:
              app_package_directory_key: app-packages
              blobstore_type: storage-cli
              connection_config:
                azure_storage_access_key: <access_key>
                azure_storage_account_name: <account_name>
                container_name: app-packages
                environment: AzureCloud
                provider: AzureRM
              max_package_size: 1610612736
    ```
* Field `provider` will be used to determine the corresponding storage CLI blobstore client class (same approach is used for fog)
* The `fog_connection` field will be renamed to `connection_config` to make it independent
* Values from `connection_config` are used to generate the corresponding config file for the Bosh storage CLIs
* During the transition phase existing parameters like `fog_connection` may be reused and/or supported in parallel    
* Keep the `fog-azure-rm` backend during the transition

The `bosh-azure-storage-cli` needs to be extended with the following commands:
* `copy`
* `list`
* `properties`
* `ensure-bucket-exists`

Other providers (AWS, GCP, Alibaba Cloud) will follow. Each will require equivalent blobstore clients and support for the above commands.
This will eventually allow us to remove all fog related gems from Cloud Controller.

## Tasks

- [x] Align with foundational infrastructure working group on proposed CLI usage and extensions
- [ ] Create RFC in community repository
- [ ] Accept this ADR based on shared agreement
- [ ] Extend `bosh-azure-storage-cli` with:
  - [ ] `copy`
  - [ ] `list`
  - [ ] `properties`
  - [ ] `ensure-bucket-exists`
- [ ] Implement `bosh-azure-storage-cli` based blobstore client in Cloud Controller with extensibility for other providers in mind
- [ ] Add `bosh-azure-storage-cli` package to capi-release
- [ ] Add ops file in cf-deployment to allow opt-in
- [ ] Add support for AWS
- [ ] Add support for GCP
- [ ] Add support for Alibaba Cloud
- [ ] Deprecate/Remove fog once all providers are covered


## Consequences

* Enables the removal of `fog-azure-rm` and all other fog related gems
* Reduces long-term maintenance burden and potential security issues
* Allows providers to be migrated independently
* Increases initial complexity during migration phase
* More maintainers/contributors for the Bosh storage CLIs


* With more consumers, interface changes in the Bosh storage CLIs may require more coordination

## Alternatives Considered

* Replace fog with newer Ruby gems
  *  → Maintenance risk persists and only a short-term solution
  *  → Not possible for Azure because the used [azure-sdk-for-ruby](https://github.com/Azure/azure-sdk-for-ruby) is archived
* Implement own blobstore client in Ruby → High development and testing effort


## Out Of Scope

* Support for CDNs (currently supported by fog)
* Performance optimizations 

## Example Usage of `bosh-azure-storage-cli`

### [Bosh](https://github.com/cloudfoundry/bosh/blob/main/src/bosh-director/lib/bosh/director/blobstore/azurestoragecli_blobstore_client.rb)
```Ruby
def object_exists?(object_id)
  begin
    out, err, status = Open3.capture3(@azure_storage_cli_path.to_s, '-c', @config_file.to_s, 'exists', object_id.to_s)
    return true if status.exitstatus.zero?
    return false if status.exitstatus == 3
  rescue Exception => e
    raise BlobstoreError, e.inspect
  end
  raise BlobstoreError, "Failed to check existence of az storage account object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
end
```

### [Cloud Controller PoC](https://github.com/cloudfoundry/cloud_controller_ng/pull/4397)
```Ruby
def exists?(blobstore_key)
  key = partitioned_key(blobstore_key)
  logger.info("[azure-blobstore] [exists?] Checking existence for: #{key}")
  status = run_cli('exists', key, allow_nonzero: true)

  if status.exitstatus == 0
    return true
  elsif status.exitstatus == 3
    return false
  end

  false
rescue StandardError => e
  logger.error("[azure-blobstore] [exists?] azure-storage-cli exists raised error: #{e.message} for #{key}")
  false
end


def run_cli(command, *args, allow_nonzero: false)
  logger.info("[azure-blobstore] Running azure-storage-cli: #{@cli_path} -c #{@config_file} #{command} #{args.join(' ')}")
  _, stderr, status = Open3.capture3(@cli_path, '-c', @config_file, command, *args)
  return status if allow_nonzero

  raise "azure-storage-cli #{command} failed: #{stderr}" unless status.success?

  status
end
```
