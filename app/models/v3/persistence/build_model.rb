module VCAP::CloudController
  class BuildModel < Sequel::Model
    BUILD_STATES = [
      STAGING_STATE = 'STAGING'.freeze,
    ].freeze

    one_to_one :droplet,
      class: 'VCAP::CloudController::DropletModel',
      key: :build_guid,
      primary_key: :guid
  end
end
