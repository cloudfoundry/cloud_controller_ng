module VCAP::CloudController
  class PackageDockerDataModel < Sequel::Model(:package_docker_data)
    many_to_one :package,
      class: '::VCAP::CloudController::PackageModel',
      key: :package_guid,
      primary_key: :guid,
      without_guid_generation: true
  end
end
