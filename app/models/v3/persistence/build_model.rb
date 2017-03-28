module VCAP::CloudController
  class BuildModel < Sequel::Model(:builds)
    BUILD_STATES = [
      STAGING_STATE = 'STAGING'.freeze,
      STAGED_STATE = 'STAGED'.freeze,
      FAILED_STATE = 'FAILED'.freeze,
    ].freeze

    one_to_one :droplet,
      class: 'VCAP::CloudController::DropletModel',
      key: :build_guid,
      primary_key: :guid,
      without_guid_generation: true
    many_to_one :package,
      class: 'VCAP::CloudController::PackageModel',
      key: :package_guid,
      primary_key: :guid,
      without_guid_generation: true
  end
end
