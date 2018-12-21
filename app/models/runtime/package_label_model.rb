module VCAP::CloudController
  class PackageLabelModel < Sequel::Model(:package_labels)
    many_to_one :package,
      class: 'VCAP::CloudController::PackageModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
